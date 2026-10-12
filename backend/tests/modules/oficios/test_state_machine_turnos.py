"""Tests de la state machine de turnos (unit, sin DB)."""
import pytest

from app.modules.oficios.models import EstadoTurno
from app.modules.oficios.services import (
    TRANSICIONES_TURNO_CLIENTE,
    TRANSICIONES_TURNO_PRESTADOR,
    _transicion_turno_valida,
)


# ------------------------------------------------------------ prestador

@pytest.mark.parametrize("actual,nuevo", [
    (EstadoTurno.PENDIENTE, EstadoTurno.CONFIRMADO),
    (EstadoTurno.PENDIENTE, EstadoTurno.RECHAZADO),
    (EstadoTurno.CONFIRMADO, EstadoTurno.EN_CURSO),
    (EstadoTurno.CONFIRMADO, EstadoTurno.CANCELADO),
    (EstadoTurno.CONFIRMADO, EstadoTurno.NO_ASISTIO),
    (EstadoTurno.EN_CURSO, EstadoTurno.COMPLETADO),
    (EstadoTurno.EN_CURSO, EstadoTurno.CANCELADO),
])
def test_prestador_validas(actual, nuevo):
    assert _transicion_turno_valida(actual, nuevo, es_prestador=True) is True


@pytest.mark.parametrize("actual,nuevo", [
    (EstadoTurno.PENDIENTE, EstadoTurno.EN_CURSO),
    (EstadoTurno.PENDIENTE, EstadoTurno.COMPLETADO),
    (EstadoTurno.COMPLETADO, EstadoTurno.PENDIENTE),
    (EstadoTurno.CANCELADO, EstadoTurno.CONFIRMADO),
    (EstadoTurno.RECHAZADO, EstadoTurno.CONFIRMADO),
])
def test_prestador_invalidas(actual, nuevo):
    assert _transicion_turno_valida(actual, nuevo, es_prestador=True) is False


# ------------------------------------------------------------ cliente

@pytest.mark.parametrize("actual,nuevo", [
    (EstadoTurno.PENDIENTE, EstadoTurno.CANCELADO),
    (EstadoTurno.CONFIRMADO, EstadoTurno.CANCELADO),
])
def test_cliente_validas(actual, nuevo):
    assert _transicion_turno_valida(actual, nuevo, es_prestador=False) is True


@pytest.mark.parametrize("actual,nuevo", [
    (EstadoTurno.PENDIENTE, EstadoTurno.CONFIRMADO),
    (EstadoTurno.PENDIENTE, EstadoTurno.RECHAZADO),
    (EstadoTurno.CONFIRMADO, EstadoTurno.EN_CURSO),
    (EstadoTurno.EN_CURSO, EstadoTurno.COMPLETADO),
])
def test_cliente_invalidas(actual, nuevo):
    assert _transicion_turno_valida(actual, nuevo, es_prestador=False) is False


def test_transiciones_prestador_cubren_estados():
    for estado in TRANSICIONES_TURNO_PRESTADOR:
        assert isinstance(estado, EstadoTurno)


def test_transiciones_cliente_cubren_estados():
    for estado in TRANSICIONES_TURNO_CLIENTE:
        assert isinstance(estado, EstadoTurno)
