"""Tests del wire de notificaciones in-app en oficios (M5.2).

Cubre:
- crear_orden -> notif IN_APP al cliente.
- cambiar_estado (prestador) -> notif IN_APP al cliente.
- cambiar_estado (cliente) -> notif IN_APP al prestador.
- aprobar_presupuesto -> notif IN_APP al prestador.
- Payload del deep link (tipo=orden + orden_id + estado).

Los tests llaman a los services directamente (no HTTP) porque el wire
esta en el service y asi evitamos crear toda la cadena HTTP.
"""
from sqlalchemy import select

from app.core.notifications.models import (
    CanalNotificacion,
    NotificationLog,
    TipoNotificacion,
)
from app.modules.oficios import services
from app.modules.oficios.models import EstadoOrden
from app.modules.oficios.schemas import (
    OrdenAprobarRequest,
    OrdenItemCreate,
    OrdenTrabajoCreate,
)


# =========================================================
# Helpers
# =========================================================
async def _payload_orden(cliente_id, objeto_id) -> OrdenTrabajoCreate:
    return OrdenTrabajoCreate(
        cliente_id=cliente_id,
        objeto_servicio_id=objeto_id,
        diagnostico_inicial="Test M5.2",
        prioridad="normal",
    )


async def _notifs_in_app_de(db, usuario_id) -> list[NotificationLog]:
    """Lista las notifs IN_APP del usuario, ordenadas DESC."""
    stmt = (
        select(NotificationLog)
        .where(
            NotificationLog.usuario_id == usuario_id,
            NotificationLog.canal == CanalNotificacion.IN_APP,
        )
        .order_by(NotificationLog.creado_en.desc())
    )
    return list((await db.execute(stmt)).scalars().all())


# =========================================================
# crear_orden
# =========================================================
async def test_crear_orden_notifica_al_cliente(
    db, usuario_cliente, prestador_test, vehiculo_test,
):
    """Crear orden genera 1 notif IN_APP al cliente con deep link."""
    data = await _payload_orden(
        usuario_cliente.id, vehiculo_test.objeto_servicio_id,
    )
    orden = await services.crear_orden(
        db, prestador_test.id, prestador_test.usuario_id, data,
    )
    await db.commit()

    notifs = await _notifs_in_app_de(db, usuario_cliente.id)
    assert len(notifs) == 1
    n = notifs[0]
    assert n.tipo == TipoNotificacion.CAMPANA
    assert n.canal == CanalNotificacion.IN_APP
    assert n.estado.value == "enviada"
    assert orden.numero in n.titulo
    # Payload del deep link
    assert n.data is not None
    assert n.data.get("tipo") == "orden"
    assert n.data.get("orden_id") == str(orden.id)
    assert n.data.get("estado") == EstadoOrden.INGRESADO.value


# =========================================================
# cambiar_estado
# =========================================================
async def test_cambiar_estado_prestador_notifica_al_cliente(
    db, usuario_cliente, prestador_test, vehiculo_test,
):
    """Si el prestador cambia estado -> notif al cliente."""
    data = await _payload_orden(
        usuario_cliente.id, vehiculo_test.objeto_servicio_id,
    )
    orden = await services.crear_orden(
        db, prestador_test.id, prestador_test.usuario_id, data,
    )
    await db.commit()

    # Cambiar estado como prestador
    await services.cambiar_estado(
        db,
        orden.id,
        "diagnosticando",
        usuario_id=prestador_test.usuario_id,
        es_prestador=True,
    )
    await db.commit()

    notifs = await _notifs_in_app_de(db, usuario_cliente.id)
    # 1 de crear_orden + 1 de cambiar_estado
    assert len(notifs) == 2
    ultima = notifs[0]
    assert "diagnosticando" in ultima.titulo
    assert ultima.data is not None
    assert ultima.data.get("estado") == "diagnosticando"
    assert ultima.data.get("estado_anterior") == "ingresado"


async def test_cambiar_estado_cliente_notifica_al_prestador(
    db, usuario_cliente, prestador_test, vehiculo_test,
):
    """Si el cliente cambia estado (rechaza) -> notif al prestador dueno."""
    data = await _payload_orden(
        usuario_cliente.id, vehiculo_test.objeto_servicio_id,
    )
    orden = await services.crear_orden(
        db, prestador_test.id, prestador_test.usuario_id, data,
    )
    # Avanzar la orden hasta PRESUPUESTADO (prestador)
    await services.cambiar_estado(
        db, orden.id, "diagnosticando",
        usuario_id=prestador_test.usuario_id, es_prestador=True,
    )
    await services.cambiar_estado(
        db, orden.id, "presupuestado",
        usuario_id=prestador_test.usuario_id, es_prestador=True,
    )
    await db.commit()

    notifs_antes = await _notifs_in_app_de(db, prestador_test.usuario_id)

    # Cliente rechaza (presupuestado -> rechazado)
    await services.cambiar_estado(
        db,
        orden.id,
        "rechazado",
        usuario_id=usuario_cliente.id,
        es_prestador=False,
        motivo="Muy caro",
    )
    await db.commit()

    notifs_despues = await _notifs_in_app_de(db, prestador_test.usuario_id)
    assert len(notifs_despues) == len(notifs_antes) + 1
    ultima = notifs_despues[0]
    assert "rechazado" in ultima.titulo.lower()


# =========================================================
# aprobar_presupuesto
# =========================================================
async def test_aprobar_presupuesto_notifica_al_prestador(
    db, usuario_cliente, prestador_test, vehiculo_test,
):
    """Aprobar presupuesto -> notif al prestador dueno."""
    data = await _payload_orden(
        usuario_cliente.id, vehiculo_test.objeto_servicio_id,
    )
    orden = await services.crear_orden(
        db, prestador_test.id, prestador_test.usuario_id, data,
    )
    await db.commit()

    # Agregar un item + avanzar a presupuestado
    item_data = OrdenItemCreate(
        tipo="servicio",
        descripcion="Cambio de aceite",
        cantidad="1.00",
        precio_unitario="50000.00",
        orden_display=0,
    )
    await services.agregar_item(
        db, orden.id, item_data, prestador_test.usuario_id,
    )
    await services.cambiar_estado(
        db,
        orden.id,
        "diagnosticando",
        usuario_id=prestador_test.usuario_id,
        es_prestador=True,
    )
    await services.cambiar_estado(
        db,
        orden.id,
        "presupuestado",
        usuario_id=prestador_test.usuario_id,
        es_prestador=True,
    )
    await db.commit()

    # Contar notifs del prestador ANTES de aprobar
    notifs_antes = await _notifs_in_app_de(db, prestador_test.usuario_id)

    # Aprobar (cliente)
    aprobar = OrdenAprobarRequest(aprobar_todos=True)
    await services.aprobar_presupuesto(
        db, orden.id, usuario_cliente.id, aprobar,
    )
    await db.commit()

    notifs_despues = await _notifs_in_app_de(db, prestador_test.usuario_id)
    assert len(notifs_despues) == len(notifs_antes) + 1
    ultima = notifs_despues[0]
    assert "aprobado" in ultima.titulo.lower()
    assert ultima.data is not None
    assert ultima.data.get("estado") == EstadoOrden.APROBADO.value


# =========================================================
# Idempotencia / no duplicacion
# =========================================================
async def test_notif_in_app_no_requiere_fcm_token(
    db, usuario_cliente, prestador_test, vehiculo_test,
):
    """La notif in-app se crea sin tokens FCM (canal=IN_APP)."""
    # Confirmar que el usuario no tiene tokens FCM
    from app.core.notifications.models import FcmToken
    tokens = (
        await db.execute(
            select(FcmToken).where(
                FcmToken.usuario_id == usuario_cliente.id,
                FcmToken.activo.is_(True),
            )
        )
    ).scalars().all()
    assert len(tokens) == 0

    data = await _payload_orden(
        usuario_cliente.id, vehiculo_test.objeto_servicio_id,
    )
    await services.crear_orden(
        db, prestador_test.id, prestador_test.usuario_id, data,
    )
    await db.commit()

    notifs = await _notifs_in_app_de(db, usuario_cliente.id)
    assert len(notifs) == 1
    assert notifs[0].canal == CanalNotificacion.IN_APP
