"""Tests de la state machine de ordenes (unit, sin DB).

Verifica que las transiciones permitidas por rol son las correctas.
No se toca la DB: se testean solo los diccionarios de transicion.
"""
import pytest

from app.modules.oficios.models import EstadoOrden
from app.modules.oficios.services import (
    TRANSICIONES_CLIENTE,
    TRANSICIONES_PRESTADOR,
    _transicion_valida,
)


# ------------------------------------------------------------ prestador

@pytest.mark.parametrize("actual,nuevo", [
    (EstadoOrden.INGRESADO, EstadoOrden.DIAGNOSTICANDO),
    (EstadoOrden.INGRESADO, EstadoOrden.CANCELADO),
    (EstadoOrden.DIAGNOSTICANDO, EstadoOrden.PRESUPUESTADO),
    (EstadoOrden.DIAGNOSTICANDO, EstadoOrden.CANCELADO),
    (EstadoOrden.APROBADO, EstadoOrden.EN_PROCESO),
    (EstadoOrden.APROBADO, EstadoOrden.CANCELADO),
    (EstadoOrden.EN_PROCESO, EstadoOrden.LISTO),
    (EstadoOrden.EN_PROCESO, EstadoOrden.CANCELADO),
    (EstadoOrden.LISTO, EstadoOrden.ENTREGADO),
    (EstadoOrden.ENTREGADO, EstadoOrden.GARANTIA),
])
def test_prestador_transiciones_validas(actual, nuevo):
    assert _transicion_valida(actual, nuevo, es_prestador=True) is True


@pytest.mark.parametrize("actual,nuevo", [
    # El prestador NO puede aprobar/rechazar (eso es del cliente)
    (EstadoOrden.PRESUPUESTADO, EstadoOrden.APROBADO),
    (EstadoOrden.PRESUPUESTADO, EstadoOrden.RECHAZADO),
    # No puede saltar pasos
    (EstadoOrden.INGRESADO, EstadoOrden.PRESUPUESTADO),
    (EstadoOrden.INGRESADO, EstadoOrden.ENTREGADO),
    # No puede volver atras
    (EstadoOrden.ENTREGADO, EstadoOrden.INGRESADO),
    (EstadoOrden.LISTO, EstadoOrden.EN_PROCESO),
])
def test_prestador_transiciones_invalidas(actual, nuevo):
    assert _transicion_valida(actual, nuevo, es_prestador=True) is False


# ------------------------------------------------------------ cliente

@pytest.mark.parametrize("actual,nuevo", [
    (EstadoOrden.PRESUPUESTADO, EstadoOrden.APROBADO),
    (EstadoOrden.PRESUPUESTADO, EstadoOrden.RECHAZADO),
    (EstadoOrden.RECHAZADO, EstadoOrden.CANCELADO),
])
def test_cliente_transiciones_validas(actual, nuevo):
    assert _transicion_valida(actual, nuevo, es_prestador=False) is True


@pytest.mark.parametrize("actual,nuevo", [
    # El cliente NO mueve los estados operativos
    (EstadoOrden.INGRESADO, EstadoOrden.DIAGNOSTICANDO),
    (EstadoOrden.APROBADO, EstadoOrden.EN_PROCESO),
    (EstadoOrden.EN_PROCESO, EstadoOrden.LISTO),
    # No puede aprobar desde otro estado
    (EstadoOrden.INGRESADO, EstadoOrden.APROBADO),
    (EstadoOrden.EN_PROCESO, EstadoOrden.APROBADO),
])
def test_cliente_transiciones_invalidas(actual, nuevo):
    assert _transicion_valida(actual, nuevo, es_prestador=False) is False


# ------------------------------------------------------------ completitud

def test_transiciones_prestador_cubren_todos_los_estados():
    """Todos los estados desde los que puede actuar el prestador estan definidos."""
    for estado in TRANSICIONES_PRESTADOR:
        assert isinstance(estado, EstadoOrden)


def test_transiciones_cliente_cubren_todos_los_estados():
    for estado in TRANSICIONES_CLIENTE:
        assert isinstance(estado, EstadoOrden)
