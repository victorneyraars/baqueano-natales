"""Test de integracion: worker de recordatorios -> push FCM."""
from unittest.mock import AsyncMock, patch

from app.modules.oficios import worker
from app.modules.oficios.models import Recordatorio, TipoRecordatorio


async def test_worker_envia_push_al_propietario(
    db, usuario_cliente, objeto_servicio_test, vehiculo_test,
):
    rec = Recordatorio(
        objeto_servicio_id=objeto_servicio_test.id,
        tipo=TipoRecordatorio.KM,
        condicion={"km_umbral": 500},
        mensaje="Test push body",
        enviado=False,
    )
    db.add(rec)
    await db.flush()

    with patch(
        "app.core.push.enviar_push_a_usuario",
        new=AsyncMock(return_value=True),
    ) as mock_push:
        stats = await worker.procesar_recordatorios(db)

    assert stats["enviados"] == 1
    assert stats["pushes"] == 1
    mock_push.assert_awaited_once()
    kwargs = mock_push.await_args.kwargs
    assert kwargs["user_id"] == usuario_cliente.id
    assert kwargs["body"] == "Test push body"
    assert kwargs["data"]["tipo"] == "recordatorio"
    assert kwargs["data"]["recordatorio_id"] == str(rec.id)

    await db.refresh(rec)
    assert rec.enviado is True


async def test_worker_marca_enviado_aunque_push_falle(
    db, usuario_cliente, objeto_servicio_test, vehiculo_test,
):
    rec = Recordatorio(
        objeto_servicio_id=objeto_servicio_test.id,
        tipo=TipoRecordatorio.KM,
        condicion={"km_umbral": 500},
        mensaje="Push va a fallar",
        enviado=False,
    )
    db.add(rec)
    await db.flush()

    with patch(
        "app.core.push.enviar_push_a_usuario",
        new=AsyncMock(return_value=False),
    ):
        stats = await worker.procesar_recordatorios(db)

    assert stats["enviados"] == 1
    assert stats["pushes"] == 0
    assert stats["errores"] == 0

    await db.refresh(rec)
    assert rec.enviado is True
