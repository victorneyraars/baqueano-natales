"""Tests HTTP de los endpoints de ordenes de trabajo.

Routers:
- router_mis_ordenes (prestador): /api/v1/mis-prestadores/{pid}/ordenes
- router_mis_ordenes_cliente: /api/v1/mis-ordenes

Foco en:
- State machine (transiciones validas e invalidas)
- Aprobacion total/parcial/rechazo
- Historial registrado
- Ownership (usuario ajeno no ve/edita)

Patron de auth: override de get_current_user Y get_db.
"""
from datetime import datetime, timedelta, timezone
from uuid import uuid4

import pytest_asyncio
from httpx import ASGITransport, AsyncClient

from app.core.db import get_db
from app.main import app
from app.modules.auth.deps import get_current_user
from app.modules.auth.models import RolUsuario, Usuario


@pytest_asyncio.fixture
async def client(db, usuario_cliente):
    """Cliente HTTP con get_current_user y get_db overrideados."""

    async def _override_user():
        return usuario_cliente

    async def _override_db():
        yield db

    app.dependency_overrides[get_current_user] = _override_user
    app.dependency_overrides[get_db] = _override_db

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as c:
        yield c

    app.dependency_overrides.clear()


def _payload_orden(cliente_id, objeto_id, **overrides) -> dict:
    base = {
        "cliente_id": str(cliente_id),
        "objeto_servicio_id": str(objeto_id),
        "diagnostico_inicial": "Test diagnostico",
        "prioridad": "normal",
    }
    base.update(overrides)
    return base


def _payload_item(**overrides) -> dict:
    base = {
        "tipo": "servicio",
        "descripcion": "Cambio de aceite",
        "cantidad": "1.00",
        "precio_unitario": "45000.00",
        "orden_display": 0,
    }
    base.update(overrides)
    return base


async def _crear_orden(client, prestador_test, usuario_cliente, vehiculo_test):
    """Helper: crea una orden como prestador para el usuario_cliente."""
    r = await client.post(
        f"/api/v1/mis-prestadores/{prestador_test.id}/ordenes",
        json=_payload_orden(usuario_cliente.id, vehiculo_test.objeto_servicio_id),
    )
    assert r.status_code == 201, r.text
    return r.json()


# ==================== Tests CRUD / state machine ====================


async def test_listar_ordenes_vacio(client, prestador_test):
    r = await client.get(f"/api/v1/mis-prestadores/{prestador_test.id}/ordenes")
    assert r.status_code == 200, r.text
    assert r.json() == []


async def test_crear_orden_basica(client, prestador_test, usuario_cliente, vehiculo_test):
    body = await _crear_orden(client, prestador_test, usuario_cliente, vehiculo_test)
    assert body["estado"] == "ingresado"
    assert body["numero"].startswith("OT-")
    assert body["cliente_id"] == str(usuario_cliente.id)
    assert body["prestador_id"] == str(prestador_test.id)


async def test_detalle_orden_prestador(client, prestador_test, usuario_cliente, vehiculo_test):
    orden = await _crear_orden(client, prestador_test, usuario_cliente, vehiculo_test)
    r = await client.get(
        f"/api/v1/mis-prestadores/{prestador_test.id}/ordenes/{orden['id']}"
    )
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["id"] == orden["id"]
    assert "historial" in body


async def test_agregar_item(client, prestador_test, usuario_cliente, vehiculo_test):
    orden = await _crear_orden(client, prestador_test, usuario_cliente, vehiculo_test)
    r = await client.post(
        f"/api/v1/mis-prestadores/{prestador_test.id}/ordenes/{orden['id']}/items",
        json=_payload_item(),
    )
    assert r.status_code == 201, r.text
    body = r.json()
    assert body["descripcion"] == "Cambio de aceite"
    assert body["tipo"] == "servicio"


async def test_cambiar_estado_valido(client, prestador_test, usuario_cliente, vehiculo_test):
    orden = await _crear_orden(client, prestador_test, usuario_cliente, vehiculo_test)
    r = await client.post(
        f"/api/v1/mis-prestadores/{prestador_test.id}/ordenes/{orden['id']}/estado",
        json={"nuevo_estado": "diagnosticando"},
    )
    assert r.status_code == 200, r.text
    assert r.json()["estado"] == "diagnosticando"


async def test_cambiar_estado_invalido(client, prestador_test, usuario_cliente, vehiculo_test):
    """ingresado -> entregado es invalido (falta todo el medio) -> 409."""
    orden = await _crear_orden(client, prestador_test, usuario_cliente, vehiculo_test)
    r = await client.post(
        f"/api/v1/mis-prestadores/{prestador_test.id}/ordenes/{orden['id']}/estado",
        json={"nuevo_estado": "entregado"},
    )
    assert r.status_code == 409, r.text


# ==================== Tests de aprobacion ====================


async def _crear_orden_presupuestada(client, prestador_test, usuario_cliente, vehiculo_test):
    """Crea orden + 2 items + la lleva a PRESUPUESTADO."""
    orden = await _crear_orden(client, prestador_test, usuario_cliente, vehiculo_test)
    pid = prestador_test.id
    oid = orden["id"]
    # 2 items
    for desc, precio in [("Item A", "10000.00"), ("Item B", "20000.00")]:
        r = await client.post(
            f"/api/v1/mis-prestadores/{pid}/ordenes/{oid}/items",
            json=_payload_item(descripcion=desc, precio_unitario=precio),
        )
        assert r.status_code == 201, r.text
    # ingresado -> diagnosticando -> presupuestado
    for estado in ["diagnosticando", "presupuestado"]:
        r = await client.post(
            f"/api/v1/mis-prestadores/{pid}/ordenes/{oid}/estado",
            json={"nuevo_estado": estado},
        )
        assert r.status_code == 200, r.text
    # Detalle para obtener los items con id
    r = await client.get(f"/api/v1/mis-prestadores/{pid}/ordenes/{oid}")
    assert r.status_code == 200, r.text
    return r.json()


async def test_aprobar_todos_los_items(client, prestador_test, usuario_cliente, vehiculo_test):
    orden = await _crear_orden_presupuestada(client, prestador_test, usuario_cliente, vehiculo_test)
    r = await client.post(
        f"/api/v1/mis-ordenes/{orden['id']}/aprobar",
        json={"aprobar_todos": True},
    )
    assert r.status_code == 200, r.text
    assert r.json()["estado"] == "aprobado"


async def test_aprobar_parcial(client, prestador_test, usuario_cliente, vehiculo_test):
    """Aprobar 1 de 2 -> estado sigue presupuestado."""
    orden = await _crear_orden_presupuestada(client, prestador_test, usuario_cliente, vehiculo_test)
    items = orden["items"]
    assert len(items) == 2, f"Se esperaban 2 items, hay {len(items)}"
    r = await client.post(
        f"/api/v1/mis-ordenes/{orden['id']}/aprobar",
        json={
            "aprobar_todos": False,
            "items": [{"item_id": items[0]["id"], "aprobado": True}],
        },
    )
    assert r.status_code == 200, r.text
    assert r.json()["estado"] == "presupuestado"


async def test_rechazar_presupuesto(client, prestador_test, usuario_cliente, vehiculo_test):
    """Rechazar todos -> estado rechazado."""
    orden = await _crear_orden_presupuestada(client, prestador_test, usuario_cliente, vehiculo_test)
    items = orden["items"]
    r = await client.post(
        f"/api/v1/mis-ordenes/{orden['id']}/aprobar",
        json={
            "aprobar_todos": False,
            "items": [
                {"item_id": it["id"], "aprobado": False} for it in items
            ],
            "motivo_rechazo": "Muy caro",
        },
    )
    assert r.status_code == 200, r.text
    assert r.json()["estado"] == "rechazado"


async def test_historial_tiene_eventos(client, prestador_test, usuario_cliente, vehiculo_test):
    """Despues de crear + transiciones, el historial tiene >=2 eventos."""
    orden = await _crear_orden(client, prestador_test, usuario_cliente, vehiculo_test)
    r = await client.post(
        f"/api/v1/mis-prestadores/{prestador_test.id}/ordenes/{orden['id']}/estado",
        json={"nuevo_estado": "diagnosticando"},
    )
    assert r.status_code == 200, r.text

    r = await client.get(
        f"/api/v1/mis-prestadores/{prestador_test.id}/ordenes/{orden['id']}"
    )
    assert r.status_code == 200, r.text
    historial = r.json().get("historial", [])
    assert len(historial) >= 2, f"Se esperaban >=2 eventos, hay {len(historial)}"


# ==================== Tests de ownership ====================


async def _crear_orden_ajena(db):
    """Crea usuario "otro" + prestador + objeto + orden. Devuelve (prestador_id, orden_id)."""
    from app.modules.oficios import services
    from app.modules.oficios.schemas import OrdenTrabajoCreate
    from app.modules.oficios.models import ObjetoServicio, TipoObjetoServicio
    from app.modules.prestadores.models import (
        CategoriaOficio, EstadoPrestador, Prestador,
    )

    otro = Usuario(
        firebase_uid=f"otro_{uuid4().hex[:12]}",
        email=f"otro_{uuid4().hex[:8]}@test.com",
        rol=RolUsuario.CLIENTE,
        activo=True,
    )
    db.add(otro)
    await db.flush()

    cat = CategoriaOficio(
        nombre=f"Cat {uuid4().hex[:6]}",
        slug=f"cat-{uuid4().hex[:6]}",
    )
    db.add(cat)
    await db.flush()

    prestador_ajeno = Prestador(
        usuario_id=otro.id,
        categoria_id=cat.id,
        nombre="Taller Ajeno",
        slug=f"taller-ajeno-{uuid4().hex[:6]}",
        estado=EstadoPrestador.VERIFICADO,
    )
    db.add(prestador_ajeno)
    await db.flush()

    obj_ajeno = ObjetoServicio(
        tipo=TipoObjetoServicio.VEHICULO,
        propietario_id=otro.id,
        alias="Ajeno",
    )
    db.add(obj_ajeno)
    await db.flush()

    data = OrdenTrabajoCreate(
        cliente_id=otro.id,
        objeto_servicio_id=obj_ajeno.id,
        diagnostico_inicial="Ajena",
    )
    orden = await services.crear_orden(db, prestador_ajeno.id, otro.id, data)
    return prestador_ajeno.id, orden.id


async def test_usuario_ajeno_no_lista_ordenes(client, db):
    """El usuario_cliente no puede listar ordenes de un prestador ajeno -> 403."""
    prestador_ajeno_id, _ = await _crear_orden_ajena(db)
    r = await client.get(f"/api/v1/mis-prestadores/{prestador_ajeno_id}/ordenes")
    assert r.status_code == 403, r.text


async def test_usuario_ajeno_no_ve_orden_cliente(client, db):
    """El usuario_cliente no ve la orden de otro cliente -> 403."""
    _, orden_id = await _crear_orden_ajena(db)
    r = await client.get(f"/api/v1/mis-ordenes/{orden_id}")
    assert r.status_code == 403, r.text


async def test_usuario_ajeno_no_cambia_estado(client, db):
    """El usuario_cliente no puede cambiar estado de la orden ajena -> 403/404."""
    prestador_ajeno_id, orden_id = await _crear_orden_ajena(db)
    r = await client.post(
        f"/api/v1/mis-prestadores/{prestador_ajeno_id}/ordenes/{orden_id}/estado",
        json={"nuevo_estado": "diagnosticando"},
    )
    assert r.status_code in (403, 404), r.text


async def test_usuario_ajeno_no_ve_orden_taller(client, db):
    """Usuario ajeno no puede GET detalle de orden de otro prestador -> 403/404."""
    prestador_ajeno_id, orden_id = await _crear_orden_ajena(db)
    r = await client.get(
        f"/api/v1/mis-prestadores/{prestador_ajeno_id}/ordenes/{orden_id}"
    )
    assert r.status_code in (403, 404), r.text


async def test_usuario_ajeno_no_actualiza_orden(client, db):
    """Usuario ajeno no puede PATCH orden de otro prestador -> 403/404."""
    prestador_ajeno_id, orden_id = await _crear_orden_ajena(db)
    r = await client.patch(
        f"/api/v1/mis-prestadores/{prestador_ajeno_id}/ordenes/{orden_id}",
        json={"diagnostico_inicial": "Hackeado"},
    )
    assert r.status_code in (403, 404), r.text


async def test_usuario_ajeno_no_agrega_item(client, db):
    """Usuario ajeno no puede POST items a orden de otro prestador -> 403/404."""
    prestador_ajeno_id, orden_id = await _crear_orden_ajena(db)
    r = await client.post(
        f"/api/v1/mis-prestadores/{prestador_ajeno_id}/ordenes/{orden_id}/items",
        json=_payload_item(),
    )
    assert r.status_code in (403, 404), r.text


async def test_usuario_ajeno_no_edita_item(client, db):
    """Usuario ajeno no puede PATCH items de orden de otro prestador -> 403/404."""
    prestador_ajeno_id, orden_id = await _crear_orden_ajena(db)
    item_id = "00000000-0000-4000-8000-000000000000"
    r = await client.patch(
        f"/api/v1/mis-prestadores/{prestador_ajeno_id}/ordenes/{orden_id}/items/{item_id}",
        json={"descripcion": "Hackeado"},
    )
    assert r.status_code in (403, 404), r.text


async def test_usuario_ajeno_no_elimina_item(client, db):
    """Usuario ajeno no puede DELETE items de orden de otro prestador -> 403/404."""
    prestador_ajeno_id, orden_id = await _crear_orden_ajena(db)
    item_id = "00000000-0000-4000-8000-000000000000"
    r = await client.delete(
        f"/api/v1/mis-prestadores/{prestador_ajeno_id}/ordenes/{orden_id}/items/{item_id}"
    )
    assert r.status_code in (403, 404), r.text
