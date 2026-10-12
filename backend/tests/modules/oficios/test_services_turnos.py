"""Tests de services de turnos (con DB)."""
import pytest
from datetime import datetime, timedelta, timezone
from uuid import uuid4

from fastapi import HTTPException

from app.modules.oficios import services
from app.modules.oficios.models import EstadoTurno
from app.modules.oficios.schemas import (
    TurnoCancelarRequest,
    TurnoCreate,
    TurnoUpdate,
)


def _futuro(dias: int = 2) -> datetime:
    return datetime.now(timezone.utc) + timedelta(days=dias)


# ------------------------------------------------------------ crear

@pytest.mark.asyncio
async def test_crear_turno_ok(
    db, usuario_cliente, prestador_test, objeto_servicio_test
):
    data = TurnoCreate(
        prestador_id=prestador_test.id,
        objeto_servicio_id=objeto_servicio_test.id,
        fecha_inicio=_futuro(),
        duracion_min=30,
        motivo="Cambio de aceite",
    )
    turno = await services.crear_turno(db, usuario_cliente.id, data)
    await db.flush()

    assert turno.id is not None
    assert turno.estado == EstadoTurno.PENDIENTE
    assert turno.motivo == "Cambio de aceite"


@pytest.mark.asyncio
async def test_crear_turno_prestador_inexistente_404(
    db, usuario_cliente, objeto_servicio_test
):
    data = TurnoCreate(
        prestador_id=uuid4(),
        objeto_servicio_id=objeto_servicio_test.id,
        fecha_inicio=_futuro(),
    )
    with pytest.raises(HTTPException) as exc:
        await services.crear_turno(db, usuario_cliente.id, data)
    assert exc.value.status_code == 404


@pytest.mark.asyncio
async def test_crear_turno_objeto_ajeno_403(
    db, usuario_cliente, prestador_test
):
    from app.modules.auth.models import RolUsuario, Usuario
    from app.modules.oficios.models import ObjetoServicio, TipoObjetoServicio

    otro = Usuario(
        firebase_uid=f"x_{uuid4().hex[:12]}",
        email=f"x_{uuid4().hex[:6]}@t.com",
        rol=RolUsuario.CLIENTE,
        activo=True,
    )
    db.add(otro)
    await db.flush()

    obj_ajeno = ObjetoServicio(
        tipo=TipoObjetoServicio.VEHICULO,
        propietario_id=otro.id,
    )
    db.add(obj_ajeno)
    await db.flush()

    data = TurnoCreate(
        prestador_id=prestador_test.id,
        objeto_servicio_id=obj_ajeno.id,
        fecha_inicio=_futuro(),
    )
    with pytest.raises(HTTPException) as exc:
        await services.crear_turno(db, usuario_cliente.id, data)
    assert exc.value.status_code == 403


# ------------------------------------------------------------ listar

@pytest.mark.asyncio
async def test_listar_turnos_cliente_vacio(db, usuario_cliente):
    turnos = await services.listar_turnos_cliente(db, usuario_cliente.id)
    assert turnos == []


@pytest.mark.asyncio
async def test_listar_turnos_cliente_con_datos(
    db, usuario_cliente, prestador_test, objeto_servicio_test
):
    for i in range(3):
        await services.crear_turno(
            db, usuario_cliente.id,
            TurnoCreate(
                prestador_id=prestador_test.id,
                objeto_servicio_id=objeto_servicio_test.id,
                fecha_inicio=_futuro(dias=i + 1),
            ),
        )
    await db.flush()

    turnos = await services.listar_turnos_cliente(db, usuario_cliente.id)
    assert len(turnos) == 3


# ------------------------------------------------------------ cambiar estado

@pytest.mark.asyncio
async def test_confirmar_turno_prestador(
    db, usuario_cliente, prestador_test, turno_test
):
    turno = await services.cambiar_estado_turno(
        db, turno_test.id, "confirmado",
        usuario_cliente.id, es_prestador=True,
    )
    assert turno.estado == EstadoTurno.CONFIRMADO


@pytest.mark.asyncio
async def test_cambiar_estado_transicion_invalida_409(
    db, usuario_cliente, turno_test
):
    with pytest.raises(HTTPException) as exc:
        await services.cambiar_estado_turno(
            db, turno_test.id, "completado",
            usuario_cliente.id, es_prestador=True,
        )
    assert exc.value.status_code == 409


# ------------------------------------------------------------ cancelar

@pytest.mark.asyncio
async def test_cancelar_turno_cliente(
    db, usuario_cliente, turno_test
):
    turno = await services.cancelar_turno(
        db, turno_test.id, usuario_cliente.id,
        es_prestador=False, motivo="No puedo ir",
    )
    assert turno.estado == EstadoTurno.CANCELADO
    assert turno.notas_cliente == "No puedo ir"


@pytest.mark.asyncio
async def test_cancelar_turno_ajeno_403(
    db, usuario_cliente, turno_test
):
    with pytest.raises(HTTPException) as exc:
        await services.cancelar_turno(
            db, turno_test.id, uuid4(),
            es_prestador=False,
        )
    assert exc.value.status_code == 403


# ------------------------------------------------------------ rechazar

@pytest.mark.asyncio
async def test_rechazar_turno_ok(
    db, prestador_test, turno_test
):
    turno = await services.rechazar_turno(
        db, turno_test.id, prestador_test.id, motivo="Sin cupo",
    )
    assert turno.estado == EstadoTurno.RECHAZADO
    assert turno.notas_prestador == "Sin cupo"


@pytest.mark.asyncio
async def test_rechazar_turno_ya_confirmado_409(
    db, usuario_cliente, prestador_test, turno_test
):
    await services.cambiar_estado_turno(
        db, turno_test.id, "confirmado",
        usuario_cliente.id, es_prestador=True,
    )
    await db.flush()

    with pytest.raises(HTTPException) as exc:
        await services.rechazar_turno(
            db, turno_test.id, prestador_test.id,
        )
    assert exc.value.status_code == 409


# ------------------------------------------------------------ actualizar

@pytest.mark.asyncio
async def test_actualizar_turno_pendiente_ok(
    db, usuario_cliente, turno_test
):
    upd = TurnoUpdate(motivo="Cambio de frenos")
    turno = await services.actualizar_turno(
        db, turno_test.id, usuario_cliente.id, upd,
    )
    assert turno.motivo == "Cambio de frenos"


@pytest.mark.asyncio
async def test_actualizar_turno_confirmado_409(
    db, usuario_cliente, turno_test
):
    await services.cambiar_estado_turno(
        db, turno_test.id, "confirmado",
        usuario_cliente.id, es_prestador=True,
    )
    await db.flush()

    with pytest.raises(HTTPException) as exc:
        await services.actualizar_turno(
            db, turno_test.id, usuario_cliente.id,
            TurnoUpdate(motivo="X"),
        )
    assert exc.value.status_code == 409


# ------------------------------------------------------------ workflow completo

@pytest.mark.asyncio
async def test_workflow_turno_completo(
    db, usuario_cliente, prestador_test, objeto_servicio_test
):
    """Ciclo: crear -> confirmar -> en_curso -> completado."""
    turno = await services.crear_turno(
        db, usuario_cliente.id,
        TurnoCreate(
            prestador_id=prestador_test.id,
            objeto_servicio_id=objeto_servicio_test.id,
            fecha_inicio=_futuro(),
        ),
    )
    await db.flush()

    turno = await services.cambiar_estado_turno(
        db, turno.id, "confirmado", usuario_cliente.id, es_prestador=True,
    )
    assert turno.estado == EstadoTurno.CONFIRMADO

    turno = await services.cambiar_estado_turno(
        db, turno.id, "en_curso", usuario_cliente.id, es_prestador=True,
    )
    assert turno.estado == EstadoTurno.EN_CURSO

    turno = await services.cambiar_estado_turno(
        db, turno.id, "completado", usuario_cliente.id, es_prestador=True,
    )
    assert turno.estado == EstadoTurno.COMPLETADO
