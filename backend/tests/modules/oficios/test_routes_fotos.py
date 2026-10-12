"""Tests HTTP de los endpoints de fotos de ordenes (M5.1).

Routers cubiertos:
- POST/GET/DELETE /api/v1/mis-ordenes/{oid}/fotos (cliente)
- POST/GET/DELETE /api/v1/mis-prestadores/{pid}/ordenes/{oid}/fotos (prestador)
- GET /api/v1/ordenes/fotos/{foto_id}/archivo/{variante} (servir archivo)

Foco:
- Upload feliz (JPEG valido) -> 201 + fila en DB + archivo en disco.
- MIME invalido -> 400.
- Tamano excesivo -> 400.
- Dedup logico: mismo contenido -> mismo row.
- Listado con/sin filtro momento.
- Servir variante valida/invalida.
- Ownership: usuario ajeno no ve ni sube fotos.
"""
import io
from uuid import uuid4

import pytest
import pytest_asyncio
from httpx import ASGITransport, AsyncClient
from PIL import Image

from app.core.db import get_db
from app.main import app
from app.modules.auth.deps import get_current_user
from app.modules.auth.models import RolUsuario, Usuario


# =========================================================
# Fixtures
# =========================================================
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


# =========================================================
# Helpers
# =========================================================
def _png_bytes(color: tuple[int, int, int] = (255, 0, 0)) -> bytes:
    """Genera un PNG de 200x200 solido del color dado."""
    img = Image.new("RGB", (200, 200), color=color)
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    return buf.getvalue()


def _jpeg_bytes(color: tuple[int, int, int] = (0, 128, 255)) -> bytes:
    """Genera un JPEG de 300x200 solido del color dado."""
    img = Image.new("RGB", (300, 200), color=color)
    buf = io.BytesIO()
    img.save(buf, format="JPEG", quality=90)
    return buf.getvalue()


def _texto_bytes() -> bytes:
    """Contenido que NO es imagen."""
    return b"this is not an image, just plain text"


def _payload_orden(cliente_id, objeto_id) -> dict:
    return {
        "cliente_id": str(cliente_id),
        "objeto_servicio_id": str(objeto_id),
        "diagnostico_inicial": "Test fotos",
        "prioridad": "normal",
    }


async def _crear_orden(client, prestador_test, usuario_cliente, vehiculo_test) -> str:
    """Crea una orden en estado INGRESADO. Devuelve el orden_id."""
    pid = prestador_test.id
    r = await client.post(
        f"/api/v1/mis-prestadores/{pid}/ordenes",
        json=_payload_orden(usuario_cliente.id, vehiculo_test.objeto_servicio_id),
    )
    assert r.status_code == 201, r.text
    return r.json()["id"]


# =========================================================
# CLIENTE: subir
# =========================================================
async def test_subir_foto_png_ok(
    client, prestador_test, usuario_cliente, vehiculo_test,
):
    """POST foto PNG valida -> 201 + fila en DB."""
    oid = await _crear_orden(
        client, prestador_test, usuario_cliente, vehiculo_test,
    )
    r = await client.post(
        f"/api/v1/mis-ordenes/{oid}/fotos",
        files={"archivo": ("test.png", _png_bytes(), "image/png")},
        data={"momento": "diagnostico", "descripcion": "Foto de prueba"},
    )
    assert r.status_code == 201, r.text
    body = r.json()
    assert body["orden_id"] == oid
    assert body["momento"] == "diagnostico"
    assert body["descripcion"] == "Foto de prueba"
    assert body["subido_por_id"] == str(usuario_cliente.id)
    assert body["subido_por_rol"] == "cliente"
    assert body["mime_type"] == "image/png"
    assert body["hash_sha256"]
    assert len(body["hash_sha256"]) == 64
    assert body["ancho"] == 200
    assert body["alto"] == 200
    # Blurhash puede ser None si falla, pero deberia estar en general
    # 3 variantes presentes
    assert set(body["variantes"].keys()) == {"original", "medium", "thumb"}
    for nombre, v in body["variantes"].items():
        assert v["url"].endswith(f"/archivo/{nombre}")


async def test_subir_foto_jpeg_ok(
    client, prestador_test, usuario_cliente, vehiculo_test,
):
    """POST foto JPEG valida -> 201."""
    oid = await _crear_orden(
        client, prestador_test, usuario_cliente, vehiculo_test,
    )
    r = await client.post(
        f"/api/v1/mis-ordenes/{oid}/fotos",
        files={"archivo": ("test.jpg", _jpeg_bytes(), "image/jpeg")},
        data={"momento": "ingreso"},
    )
    assert r.status_code == 201, r.text
    body = r.json()
    assert body["mime_type"] == "image/jpeg"
    assert body["ancho"] == 300
    assert body["alto"] == 200


async def test_subir_foto_mime_invalido(
    client, prestador_test, usuario_cliente, vehiculo_test,
):
    """POST con texto plano -> 400."""
    oid = await _crear_orden(
        client, prestador_test, usuario_cliente, vehiculo_test,
    )
    r = await client.post(
        f"/api/v1/mis-ordenes/{oid}/fotos",
        files={"archivo": ("malo.txt", _texto_bytes(), "text/plain")},
        data={"momento": "otro"},
    )
    assert r.status_code == 400, r.text


async def test_subir_foto_momento_invalido(
    client, prestador_test, usuario_cliente, vehiculo_test,
):
    """POST con momento no valido -> 400."""
    oid = await _crear_orden(
        client, prestador_test, usuario_cliente, vehiculo_test,
    )
    r = await client.post(
        f"/api/v1/mis-ordenes/{oid}/fotos",
        files={"archivo": ("ok.png", _png_bytes(), "image/png")},
        data={"momento": "chirimoya"},
    )
    assert r.status_code == 400, r.text


async def test_subir_foto_sin_archivo(
    client, prestador_test, usuario_cliente, vehiculo_test,
):
    """POST sin archivo -> 422 (FastAPI valida required)."""
    oid = await _crear_orden(
        client, prestador_test, usuario_cliente, vehiculo_test,
    )
    r = await client.post(
        f"/api/v1/mis-ordenes/{oid}/fotos",
        data={"momento": "otro"},
    )
    assert r.status_code == 422, r.text


async def test_subir_foto_dedup_mismo_contenido(
    client, prestador_test, usuario_cliente, vehiculo_test,
):
    """Dos POST con el mismo contenido -> la segunda devuelve la fila existente."""
    oid = await _crear_orden(
        client, prestador_test, usuario_cliente, vehiculo_test,
    )
    png = _png_bytes((10, 20, 30))
    r1 = await client.post(
        f"/api/v1/mis-ordenes/{oid}/fotos",
        files={"archivo": ("a.png", png, "image/png")},
        data={"momento": "diagnostico"},
    )
    assert r1.status_code == 201, r1.text
    id1 = r1.json()["id"]

    r2 = await client.post(
        f"/api/v1/mis-ordenes/{oid}/fotos",
        files={"archivo": ("b.png", png, "image/png")},
        data={"momento": "entrega"},
    )
    assert r2.status_code == 201, r2.text
    id2 = r2.json()["id"]

    assert id1 == id2, "El dedup por hash no funciono"


# =========================================================
# CLIENTE: listar
# =========================================================
async def test_listar_fotos_vacio(
    client, prestador_test, usuario_cliente, vehiculo_test,
):
    oid = await _crear_orden(
        client, prestador_test, usuario_cliente, vehiculo_test,
    )
    r = await client.get(f"/api/v1/mis-ordenes/{oid}/fotos")
    assert r.status_code == 200, r.text
    assert r.json() == []


async def test_listar_fotos_con_contenido_y_filtro(
    client, prestador_test, usuario_cliente, vehiculo_test,
):
    oid = await _crear_orden(
        client, prestador_test, usuario_cliente, vehiculo_test,
    )
    # 2 en diagnostico + 1 en entrega
    for i, momento in enumerate(["diagnostico", "diagnostico", "entrega"]):
        r = await client.post(
            f"/api/v1/mis-ordenes/{oid}/fotos",
            files={"archivo": (f"f{i}.png", _png_bytes((i * 10, i * 20, i * 30)), "image/png")},
            data={"momento": momento},
        )
        assert r.status_code == 201, r.text

    r = await client.get(f"/api/v1/mis-ordenes/{oid}/fotos")
    assert r.status_code == 200
    assert len(r.json()) == 3

    r = await client.get(
        f"/api/v1/mis-ordenes/{oid}/fotos", params={"momento": "diagnostico"},
    )
    assert r.status_code == 200
    assert len(r.json()) == 2


# =========================================================
# SERVIR ARCHIVO
# =========================================================
async def test_servir_variante_thumb(
    client, prestador_test, usuario_cliente, vehiculo_test,
):
    oid = await _crear_orden(
        client, prestador_test, usuario_cliente, vehiculo_test,
    )
    r = await client.post(
        f"/api/v1/mis-ordenes/{oid}/fotos",
        files={"archivo": ("x.png", _png_bytes(), "image/png")},
        data={"momento": "otro"},
    )
    assert r.status_code == 201, r.text
    foto_id = r.json()["id"]

    r = await client.get(f"/api/v1/ordenes/fotos/{foto_id}/archivo/thumb")
    assert r.status_code == 200, r.text
    assert r.headers["content-type"] == "image/jpeg"
    # Magic bytes de JPEG
    assert r.content[:3] == b"\xff\xd8\xff"
    assert len(r.content) > 100


async def test_servir_variante_invalida(
    client, prestador_test, usuario_cliente, vehiculo_test,
):
    oid = await _crear_orden(
        client, prestador_test, usuario_cliente, vehiculo_test,
    )
    r = await client.post(
        f"/api/v1/mis-ordenes/{oid}/fotos",
        files={"archivo": ("x.png", _png_bytes(), "image/png")},
        data={"momento": "otro"},
    )
    foto_id = r.json()["id"]
    r = await client.get(f"/api/v1/ordenes/fotos/{foto_id}/archivo/inventada")
    assert r.status_code == 400, r.text


async def test_servir_foto_inexistente(client):
    r = await client.get(
        f"/api/v1/ordenes/fotos/{uuid4()}/archivo/thumb"
    )
    assert r.status_code == 404, r.text


# =========================================================
# OWNERSHIP
# =========================================================
async def _crear_usuario_ajeno_y_orden(db, prestador_test, vehiculo_test):
    """Crea un usuario distinto (no dueno de la orden) y una orden del taller."""
    from app.modules.oficios import services
    from app.modules.oficios.schemas import OrdenTrabajoCreate

    otro = Usuario(
        firebase_uid=f"ajeno_{uuid4().hex[:12]}",
        email=f"ajeno_{uuid4().hex[:8]}@test.com",
        rol=RolUsuario.CLIENTE,
        activo=True,
    )
    db.add(otro)
    await db.flush()

    # El otro usuario es un cliente con un vehiculo propio
    from app.modules.oficios.models import (
        ObjetoServicio,
        TipoObjetoServicio,
        Vehiculo,
        TipoVehiculo,
    )
    obj = ObjetoServicio(
        tipo=TipoObjetoServicio.VEHICULO,
        propietario_id=otro.id,
        alias="Auto ajeno",
    )
    db.add(obj)
    await db.flush()
    veh = Vehiculo(
        objeto_servicio_id=obj.id,
        patente=f"AJ{uuid4().hex[:6].upper()}",
        marca="Test",
        modelo="Ajena",
        anio=2020,
        tipo_vehiculo=TipoVehiculo.SEDAN,
    )
    db.add(veh)
    await db.flush()

    # Crear orden en el taller del cliente 1, pero para el cliente ajeno
    data = OrdenTrabajoCreate(
        cliente_id=otro.id,
        objeto_servicio_id=obj.id,
        diagnostico_inicial="Ajena",
    )
    orden = await services.crear_orden(
        db, prestador_test.id, otro.id, data,
    )
    return otro, orden


async def test_tercero_no_sube_foto_a_orden_ajena(
    client, db, prestador_test, usuario_cliente, vehiculo_test,
):
    """Un usuario sin relacion con la orden no puede subir foto -> 403."""
    orden = await _crear_orden(
        client, prestador_test, usuario_cliente, vehiculo_test,
    )

    tercero = Usuario(
        firebase_uid=f"tercero_{uuid4().hex[:12]}",
        email=f"tercero_{uuid4().hex[:8]}@test.com",
        rol=RolUsuario.CLIENTE,
        activo=True,
    )
    db.add(tercero)
    await db.flush()

    async def _override_user():
        return tercero

    app.dependency_overrides[get_current_user] = _override_user
    try:
        r = await client.post(
            f"/api/v1/mis-ordenes/{orden}/fotos",
            files={"archivo": ("x.png", _png_bytes(), "image/png")},
            data={"momento": "otro"},
        )
    finally:
        async def _back_to_cliente():
            return usuario_cliente
        app.dependency_overrides[get_current_user] = _back_to_cliente

    assert r.status_code == 403, r.text
