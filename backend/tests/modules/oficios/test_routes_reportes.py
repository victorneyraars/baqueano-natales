"""Tests HTTP de los endpoints de reportes del taller (M5.3).

Cubre:
- GET /mis-prestadores/{pid}/reportes (JSON con KPIs + rankings).
- GET /mis-prestadores/{pid}/reportes.csv (descarga CSV).
- Filtros desde/hasta.
- Ownership: usuario ajeno no ve el reporte.
"""
from datetime import date, datetime, timedelta, timezone
from uuid import uuid4

import pytest_asyncio
from httpx import ASGITransport, AsyncClient

from app.core.db import get_db
from app.main import app
from app.modules.auth.deps import get_current_user
from app.modules.auth.models import RolUsuario, Usuario
from app.modules.oficios import services
from app.modules.oficios.models import (
    EstadoOrden,
    OrdenItem,
    OrdenTrabajo,
    TipoItemOrden,
)
from app.modules.prestadores.models import (
    CategoriaOficio,
    EstadoPrestador,
    Prestador,
)


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
async def _crear_orden_entregada(
    db, prestador_test, usuario_cliente, vehiculo_test,
):
    """Crea orden con 1 item y la lleva a ENTREGADO (con total_aprobado)."""
    from app.modules.oficios.schemas import OrdenTrabajoCreate

    data = OrdenTrabajoCreate(
        cliente_id=usuario_cliente.id,
        objeto_servicio_id=vehiculo_test.objeto_servicio_id,
        diagnostico_inicial="Test reportes",
    )
    orden = await services.crear_orden(
        db, prestador_test.id, prestador_test.usuario_id, data,
    )
    # Item aprobado manualmente
    item = OrdenItem(
        orden_id=orden.id,
        tipo=TipoItemOrden.SERVICIO,
        descripcion="Cambio de aceite",
        cantidad=1,
        precio_unitario=50000,
        subtotal=50000,
        aprobado=True,
    )
    db.add(item)
    orden.total_presupuesto = 50000
    orden.total_aprobado = 50000
    orden.estado = EstadoOrden.ENTREGADO
    orden.fecha_entrega_real = datetime.now(timezone.utc)
    await db.flush()
    return orden


# =========================================================
# GET /reportes (JSON)
# =========================================================
async def test_reporte_json_ok(
    client, db, prestador_test, usuario_cliente, vehiculo_test,
):
    """Reporte JSON con ordenes y rankings correctos."""
    await _crear_orden_entregada(
        db, prestador_test, usuario_cliente, vehiculo_test,
    )
    await db.commit()

    r = await client.get(
        f"/api/v1/mis-prestadores/{prestador_test.id}/reportes"
    )
    assert r.status_code == 200, r.text
    body = r.json()

    # Estructura
    assert body["prestador_id"] == str(prestador_test.id)
    assert "desde" in body and "hasta" in body
    assert "kpis" in body
    assert "serie_mensual" in body
    assert "top_servicios" in body
    assert "top_clientes" in body

    # KPIs basicos
    k = body["kpis"]
    assert k["total_ordenes"] >= 1
    assert k["ingresos_totales"] >= 50000
    assert k["ticket_promedio"] >= 50000
    assert k["tasa_aprobacion_items"] == 1.0

    # Serie mensual: al menos 1 mes
    assert len(body["serie_mensual"]) >= 1

    # Top servicios: al menos el item
    assert len(body["top_servicios"]) >= 1
    servicios = [s["descripcion"] for s in body["top_servicios"]]
    assert "Cambio de aceite" in servicios


async def test_reporte_json_vacio(
    client, prestador_test, db,
):
    """Reporte sin ordenes -> KPIs en 0, listas vacias."""
    r = await client.get(
        f"/api/v1/mis-prestadores/{prestador_test.id}/reportes"
    )
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["kpis"]["total_ordenes"] == 0
    assert body["kpis"]["ingresos_totales"] == 0.0
    assert body["serie_mensual"] == []
    assert body["top_servicios"] == []
    assert body["top_clientes"] == []


async def test_reporte_filtro_fechas(
    client, db, prestador_test, usuario_cliente, vehiculo_test,
):
    """Filtro desde/hasta que excluye la orden -> KPIs en 0."""
    await _crear_orden_entregada(
        db, prestador_test, usuario_cliente, vehiculo_test,
    )
    await db.commit()

    ayer = (date.today() - timedelta(days=1)).isoformat()
    anteayer = (date.today() - timedelta(days=2)).isoformat()
    r = await client.get(
        f"/api/v1/mis-prestadores/{prestador_test.id}/reportes",
        params={"desde": anteayer, "hasta": ayer},
    )
    assert r.status_code == 200, r.text
    body = r.json()
    # La orden fue creada hoy -> no cae en el rango
    assert body["kpis"]["total_ordenes"] == 0


# =========================================================
# GET /reportes.csv
# =========================================================
async def test_reporte_csv_ok(
    client, db, prestador_test, usuario_cliente, vehiculo_test,
):
    """Descarga CSV con Content-Disposition + bloques."""
    await _crear_orden_entregada(
        db, prestador_test, usuario_cliente, vehiculo_test,
    )
    await db.commit()

    r = await client.get(
        f"/api/v1/mis-prestadores/{prestador_test.id}/reportes.csv"
    )
    assert r.status_code == 200, r.text
    assert "text/csv" in r.headers["content-type"]
    assert "attachment" in r.headers["content-disposition"]
    assert ".csv" in r.headers["content-disposition"]

    body = r.text
    # Verificar bloques
    assert "# KPIs" in body
    assert "total_ordenes" in body
    assert "# Serie mensual" in body
    assert "# Top servicios" in body
    assert "# Top clientes" in body


# =========================================================
# Ownership
# =========================================================
async def test_usuario_ajeno_no_ve_reporte(
    client, db,
):
    """Usuario ajeno (no dueno del prestador) no ve el reporte -> 403."""
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
    await db.commit()

    # El client usa usuario_cliente (fixture) -> no es dueno del prestador ajeno
    r = await client.get(
        f"/api/v1/mis-prestadores/{prestador_ajeno.id}/reportes"
    )
    assert r.status_code == 403, r.text


async def test_prestador_inexistente_404(client):
    """Prestador que no existe -> 404."""
    r = await client.get(
        f"/api/v1/mis-prestadores/{uuid4()}/reportes"
    )
    assert r.status_code == 404, r.text
