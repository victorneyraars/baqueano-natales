"""Tests HTTP de los endpoints de garantias.

Routers:
- router_garantias_cliente: /api/v1/mis-ordenes/{oid}/garantia
- router_garantias_prestador: /api/v1/mis-prestadores/{pid}/ordenes/{oid}/garantia

Foco en:
- Garantia auto-generada al pasar a ENTREGADO (wire cambiar_estado -> generar)
- CRUD manual (prestador)
- Ownership (cliente ajeno no ve, prestador ajeno no crea)
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


def _payload_orden(cliente_id, objeto_id) -> dict:
    return {
        "cliente_id": str(cliente_id),
        "objeto_servicio_id": str(objeto_id),
        "diagnostico_inicial": "Test",
        "prioridad": "normal",
    }


def _payload_item() -> dict:
    return {
        "tipo": "servicio",
        "descripcion": "Item de prueba",
        "cantidad": "1.00",
        "precio_unitario": "10000.00",
        "orden_display": 0,
    }


async def _crear_orden_entregada(client, prestador_test, usuario_cliente, vehiculo_test):
    """Helper: crea orden + item + la lleva a ENTREGADO.

    Flujo: ingresado -> diagnosticando -> presupuestado (con item)
           -> aprobar (todos) -> aprobado -> en_proceso -> listo -> entregado.
    Devuelve (orden_id, pid).
    """
    pid = prestador_test.id
    # Crear orden
    r = await client.post(
        f"/api/v1/mis-prestadores/{pid}/ordenes",
        json=_payload_orden(usuario_cliente.id, vehiculo_test.objeto_servicio_id),
    )
    assert r.status_code == 201, r.text
    oid = r.json()["id"]

    # Agregar item
    r = await client.post(
        f"/api/v1/mis-prestadores/{pid}/ordenes/{oid}/items",
        json=_payload_item(),
    )
    assert r.status_code == 201, r.text

    # ingresado -> diagnosticando -> presupuestado
    for estado in ["diagnosticando", "presupuestado"]:
        r = await client.post(
            f"/api/v1/mis-prestadores/{pid}/ordenes/{oid}/estado",
            json={"nuevo_estado": estado},
        )
        assert r.status_code == 200, r.text

    # Aprobar todos
    r = await client.post(
        f"/api/v1/mis-ordenes/{oid}/aprobar",
        json={"aprobar_todos": True},
    )
    assert r.status_code == 200, r.text
    assert r.json()["estado"] == "aprobado"

    # aprobado -> en_proceso -> listo -> entregado
    for estado in ["en_proceso", "listo", "entregado"]:
        r = await client.post(
            f"/api/v1/mis-prestadores/{pid}/ordenes/{oid}/estado",
            json={"nuevo_estado": estado},
        )
        assert r.status_code == 200, r.text

    return oid, pid


# ==================== Cliente ====================


async def test_obtener_garantia_inexistente(client, prestador_test, usuario_cliente, vehiculo_test):
    """GET a orden sin garantia -> 200 con null."""
    r = await client.post(
        f"/api/v1/mis-prestadores/{prestador_test.id}/ordenes",
        json=_payload_orden(usuario_cliente.id, vehiculo_test.objeto_servicio_id),
    )
    assert r.status_code == 201, r.text
    oid = r.json()["id"]

    r = await client.get(f"/api/v1/mis-ordenes/{oid}/garantia")
    assert r.status_code == 200, r.text
    assert r.json() is None


async def test_garantia_auto_al_entregar(client, prestador_test, usuario_cliente, vehiculo_test):
    """Al pasar a ENTREGADO, la garantia se genera automaticamente (wire)."""
    oid, _ = await _crear_orden_entregada(
        client, prestador_test, usuario_cliente, vehiculo_test
    )
    r = await client.get(f"/api/v1/mis-ordenes/{oid}/garantia")
    assert r.status_code == 200, r.text
    body = r.json()
    assert body is not None, "La garantia no se genero al entregar la orden"
    assert body["tipo"] == "completo"
    assert body["duracion_dias"] == 30
    assert body["orden_id"] == oid


# ==================== Prestador ====================


async def test_obtener_garantia_prestador(client, prestador_test, usuario_cliente, vehiculo_test):
    oid, pid = await _crear_orden_entregada(
        client, prestador_test, usuario_cliente, vehiculo_test
    )
    r = await client.get(
        f"/api/v1/mis-prestadores/{pid}/ordenes/{oid}/garantia"
    )
    assert r.status_code == 200, r.text
    body = r.json()
    assert body is not None
    assert body["orden_id"] == oid


async def test_crear_garantia_manual_actualiza_autogenerada(
    client, prestador_test, usuario_cliente, vehiculo_test
):
    """POST garantia en orden ya entregada -> actualiza la auto-generada."""
    oid, pid = await _crear_orden_entregada(
        client, prestador_test, usuario_cliente, vehiculo_test
    )
    r = await client.post(
        f"/api/v1/mis-prestadores/{pid}/ordenes/{oid}/garantia",
        json={
            "tipo": "mano_obra",
            "duracion_dias": 60,
            "cobertura": "Solo mano de obra",
            "condiciones": "Test",
        },
    )
    assert r.status_code in (200, 201), r.text
    body = r.json()
    assert body["tipo"] == "mano_obra"
    assert body["duracion_dias"] == 60


# ==================== Ownership ====================


async def _crear_orden_ajena_entregada(db):
    """Crea usuario otro + prestador + objeto + orden entregada con garantia."""
    from app.modules.oficios import services
    from app.modules.oficios.schemas import (
        OrdenTrabajoCreate, OrdenItemCreate, OrdenAprobarRequest,
    )
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

    cat = CategoriaOficio(nombre=f"Cat {uuid4().hex[:6]}", slug=f"cat-{uuid4().hex[:6]}")
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

    # Crear orden directo via service (ya entregada)
    data = OrdenTrabajoCreate(
        cliente_id=otro.id,
        objeto_servicio_id=obj_ajeno.id,
        diagnostico_inicial="Ajena",
    )
    orden = await services.crear_orden(db, prestador_ajeno.id, otro.id, data)
    # Forzar estado entregado y generar garantia
    await services.generar_garantia_automatica(db, orden.id)
    return prestador_ajeno.id, orden.id


async def test_usuario_ajeno_no_ve_garantia(client, db):
    """Usuario ajeno no ve garantia de orden de otro cliente -> 403."""
    _, orden_id = await _crear_orden_ajena_entregada(db)
    r = await client.get(f"/api/v1/mis-ordenes/{orden_id}/garantia")
    assert r.status_code == 403, r.text


async def test_usuario_ajeno_no_crea_garantia(client, db):
    """Usuario ajeno no puede crear garantia en orden de prestador ajeno -> 403."""
    prestador_ajeno_id, orden_id = await _crear_orden_ajena_entregada(db)
    r = await client.post(
        f"/api/v1/mis-prestadores/{prestador_ajeno_id}/ordenes/{orden_id}/garantia",
        json={"tipo": "completo", "duracion_dias": 30},
    )
    assert r.status_code in (403, 404), r.text
