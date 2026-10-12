"""Tests HTTP de reviews (M6)."""
from datetime import datetime, timezone

import pytest_asyncio
from httpx import ASGITransport, AsyncClient
from sqlalchemy import select

from app.core.db import get_db
from app.core.notifications.models import CanalNotificacion, NotificationLog
from app.main import app
from app.modules.auth.deps import get_current_user
from app.modules.auth.models import RolUsuario, Usuario
from app.modules.oficios import services
from app.modules.oficios.models import (
    EstadoOrden, ObjetoServicio, OrdenItem, OrdenTrabajo,
    TipoItemOrden, TipoObjetoServicio,
)
from app.modules.oficios.schemas import OrdenTrabajoCreate


@pytest_asyncio.fixture
async def client(db, usuario_cliente):
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


async def _crear_orden_entregada(db, prestador, cliente, vehiculo):
    data = OrdenTrabajoCreate(
        cliente_id=cliente.id,
        objeto_servicio_id=vehiculo.objeto_servicio_id,
        diagnostico_inicial="Test reviews",
    )
    orden = await services.crear_orden(
        db, prestador.id, prestador.usuario_id, data,
    )
    db.add(OrdenItem(
        orden_id=orden.id, tipo=TipoItemOrden.SERVICIO,
        descripcion="Cambio de aceite", cantidad=1,
        precio_unitario=50000, subtotal=50000, aprobado=True,
    ))
    orden.estado = EstadoOrden.ENTREGADO
    orden.fecha_entrega_real = datetime.now(timezone.utc)
    orden.total_presupuesto = 50000
    orden.total_aprobado = 50000
    await db.flush()
    return orden


async def test_crear_review_ok(
    client, db, prestador_test, usuario_cliente, vehiculo_test,
):
    orden = await _crear_orden_entregada(
        db, prestador_test, usuario_cliente, vehiculo_test,
    )
    await db.commit()
    r = await client.post(
        f"/api/v1/mis-ordenes/{orden.id}/review",
        json={"rating": 5, "comentario": "Excelente"},
    )
    assert r.status_code == 201, r.text
    await db.refresh(prestador_test)
    assert prestador_test.total_resenas == 1
    assert float(prestador_test.calificacion_promedio) == 5.0


async def test_crear_review_orden_no_entregada(
    client, db, prestador_test, usuario_cliente, vehiculo_test,
):
    data = OrdenTrabajoCreate(
        cliente_id=usuario_cliente.id,
        objeto_servicio_id=vehiculo_test.objeto_servicio_id,
        diagnostico_inicial="No entregada",
    )
    orden = await services.crear_orden(
        db, prestador_test.id, prestador_test.usuario_id, data,
    )
    await db.commit()
    r = await client.post(
        f"/api/v1/mis-ordenes/{orden.id}/review", json={"rating": 5},
    )
    assert r.status_code == 409, r.text


async def test_crear_review_duplicada(
    client, db, prestador_test, usuario_cliente, vehiculo_test,
):
    orden = await _crear_orden_entregada(
        db, prestador_test, usuario_cliente, vehiculo_test,
    )
    await db.commit()
    r1 = await client.post(
        f"/api/v1/mis-ordenes/{orden.id}/review", json={"rating": 5},
    )
    assert r1.status_code == 201, r1.text
    r2 = await client.post(
        f"/api/v1/mis-ordenes/{orden.id}/review", json={"rating": 3},
    )
    assert r2.status_code == 409, r2.text


async def test_listar_reviews_publicas(
    client, db, prestador_test, usuario_cliente, vehiculo_test,
):
    orden = await _crear_orden_entregada(
        db, prestador_test, usuario_cliente, vehiculo_test,
    )
    await db.commit()
    await client.post(
        f"/api/v1/mis-ordenes/{orden.id}/review",
        json={"rating": 4, "comentario": "Buen servicio"},
    )
    # El endpoint publico no usa auth, asi que podemos dejar los overrides
    # activos (solo importa que get_db comparta la sesion del test).
    r = await client.get(
        f"/api/v1/prestadores/{prestador_test.slug}/reviews"
    )
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["total"] == 1
    assert body["promedio"] == 4.0
    assert body["items"][0]["rating"] == 4
    assert body["items"][0]["comentario"] == "Buen servicio"


async def test_responder_review_ok(
    client, db, prestador_test, usuario_cliente, vehiculo_test,
):
    orden = await _crear_orden_entregada(
        db, prestador_test, usuario_cliente, vehiculo_test,
    )
    await db.commit()
    r1 = await client.post(
        f"/api/v1/mis-ordenes/{orden.id}/review", json={"rating": 5},
    )
    review_id = r1.json()["id"]

    app.dependency_overrides[get_current_user] = lambda: usuario_cliente
    r = await client.post(
        f"/api/v1/mis-prestadores/{prestador_test.id}/"
        f"reviews/{review_id}/respuesta",
        json={"respuesta": "Gracias!"},
    )
    assert r.status_code == 200, r.text
    assert r.json()["respuesta_prestador"] == "Gracias!"
    assert r.json()["respuesta_en"] is not None


async def test_crear_review_notifica_al_prestador(
    client, db, prestador_test, usuario_cliente, vehiculo_test,
):
    orden = await _crear_orden_entregada(
        db, prestador_test, usuario_cliente, vehiculo_test,
    )
    await db.commit()
    r = await client.post(
        f"/api/v1/mis-ordenes/{orden.id}/review", json={"rating": 5},
    )
    assert r.status_code == 201, r.text
    notifs = (
        await db.execute(
            select(NotificationLog).where(
                NotificationLog.usuario_id == prestador_test.usuario_id,
                NotificationLog.canal == CanalNotificacion.IN_APP,
            )
        )
    ).scalars().all()
    assert len(notifs) >= 1
    ultima = notifs[-1]
    assert ultima.data is not None
    assert ultima.data.get("tipo") == "review"
