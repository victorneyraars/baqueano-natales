"""Tests HTTP de los endpoints de turnos (agenda).

Routers:
- router_turnos_cliente: /api/v1/mis-turnos
- router_turnos_prestador: /api/v1/mis-prestadores/{pid}/turnos

Foco en:
- State machine (transiciones validas e invalidas por rol)
- Ownership (usuario ajeno no ve/edita)
- Cancelar/rechazar por rol

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


def _payload_turno(prestador_id, objeto_id, **overrides) -> dict:
    base = {
        "prestador_id": str(prestador_id),
        "objeto_servicio_id": str(objeto_id),
        "fecha_inicio": (datetime.now(timezone.utc) + timedelta(days=2)).isoformat(),
        "duracion_min": 30,
        "motivo": "Test turno",
    }
    base.update(overrides)
    return base


# ==================== Turnos cliente ====================


async def test_listar_mis_turnos_vacio(client):
    r = await client.get("/api/v1/mis-turnos")
    assert r.status_code == 200, r.text
    assert r.json() == []


async def test_crear_turno(client, prestador_test, objeto_servicio_test):
    r = await client.post(
        "/api/v1/mis-turnos",
        json=_payload_turno(prestador_test.id, objeto_servicio_test.id),
    )
    assert r.status_code == 201, r.text
    body = r.json()
    assert body["prestador_id"] == str(prestador_test.id)
    assert body["estado"] == "pendiente"


async def test_detalle_mi_turno(client, turno_test):
    r = await client.get(f"/api/v1/mis-turnos/{turno_test.id}")
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["id"] == str(turno_test.id)
    assert body["estado"] == "pendiente"


async def test_editar_turno_pendiente(client, turno_test):
    nueva_fecha = (datetime.now(timezone.utc) + timedelta(days=5)).isoformat()
    r = await client.patch(
        f"/api/v1/mis-turnos/{turno_test.id}",
        json={"fecha_inicio": nueva_fecha, "motivo": "Reprogramado"},
    )
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["motivo"] == "Reprogramado"


async def test_cancelar_mi_turno(client, turno_test):
    r = await client.post(
        f"/api/v1/mis-turnos/{turno_test.id}/cancelar",
        json={"motivo": "Ya no puedo"},
    )
    assert r.status_code == 200, r.text
    assert r.json()["estado"] == "cancelado"


# ==================== Agenda taller ====================


async def test_listar_agenda_taller(client, prestador_test, turno_test):
    r = await client.get(f"/api/v1/mis-prestadores/{prestador_test.id}/turnos")
    assert r.status_code == 200, r.text
    assert isinstance(r.json(), list)


async def test_cambiar_estado_valido(client, prestador_test, turno_test):
    """pendiente -> confirmado es valido (prestador)."""
    r = await client.post(
        f"/api/v1/mis-prestadores/{prestador_test.id}/turnos/{turno_test.id}/estado",
        json={"nuevo_estado": "confirmado"},
    )
    assert r.status_code == 200, r.text
    assert r.json()["estado"] == "confirmado"


async def test_cambiar_estado_invalido(client, prestador_test, turno_test):
    """pendiente -> completado es invalido -> 409."""
    r = await client.post(
        f"/api/v1/mis-prestadores/{prestador_test.id}/turnos/{turno_test.id}/estado",
        json={"nuevo_estado": "completado"},
    )
    assert r.status_code == 409, r.text


async def test_rechazar_turno(client, prestador_test, turno_test):
    r = await client.post(
        f"/api/v1/mis-prestadores/{prestador_test.id}/turnos/{turno_test.id}/rechazar",
        json={"motivo": "Sin cupo"},
    )
    assert r.status_code == 200, r.text
    assert r.json()["estado"] == "rechazado"


# ==================== Ownership ====================


async def _crear_turno_ajeno(db):
    """Crea usuario "otro" + prestador + objeto + turno. Devuelve (prestador_id, turno_id)."""
    from app.modules.oficios import services
    from app.modules.oficios.schemas import TurnoCreate
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

    data = TurnoCreate(
        prestador_id=prestador_ajeno.id,
        objeto_servicio_id=obj_ajeno.id,
        fecha_inicio=datetime.now(timezone.utc) + timedelta(days=2),
        duracion_min=30,
        motivo="Turno ajeno",
    )
    turno = await services.crear_turno(db, otro.id, data)
    return prestador_ajeno.id, turno.id


async def test_usuario_ajeno_no_ve_turno_cliente(client, db):
    """Usuario ajeno no ve turno de otro cliente -> 403."""
    _, turno_id = await _crear_turno_ajeno(db)
    r = await client.get(f"/api/v1/mis-turnos/{turno_id}")
    assert r.status_code == 403, r.text


async def test_usuario_ajeno_no_lista_agenda(client, db):
    """Usuario ajeno no puede ver agenda de prestador ajeno -> 403."""
    prestador_ajeno_id, _ = await _crear_turno_ajeno(db)
    r = await client.get(f"/api/v1/mis-prestadores/{prestador_ajeno_id}/turnos")
    assert r.status_code == 403, r.text


async def test_usuario_ajeno_no_cambia_estado_turno(client, db):
    """Usuario ajeno no puede cambiar estado de turno ajeno -> 403/404."""
    prestador_ajeno_id, turno_id = await _crear_turno_ajeno(db)
    r = await client.post(
        f"/api/v1/mis-prestadores/{prestador_ajeno_id}/turnos/{turno_id}/estado",
        json={"nuevo_estado": "confirmado"},
    )
    assert r.status_code in (403, 404), r.text


async def test_usuario_ajeno_no_rechaza_turno(client, db):
    """Usuario ajeno no puede rechazar turno ajeno -> 403/404."""
    prestador_ajeno_id, turno_id = await _crear_turno_ajeno(db)
    r = await client.post(
        f"/api/v1/mis-prestadores/{prestador_ajeno_id}/turnos/{turno_id}/rechazar",
        json={"motivo": "Hack"},
    )
    assert r.status_code in (403, 404), r.text
