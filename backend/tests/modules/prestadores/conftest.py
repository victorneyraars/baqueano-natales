"""Fixtures del modulo prestadores.

Reusa fixtures de oficios (usuario_cliente, prestador_test,
vehiculo_test, etc.). Los importamos explicitamente porque pytest
registra los fixtures por nombre en el namespace del conftest.
"""

# noqa: F401 (imports sin uso directo: los usa pytest)
from tests.modules.oficios.conftest import (  # noqa: F401
    categoria_mecanica,
    categoria_oficio,
    objeto_servicio_test,
    prestador_test,
    turno_test,
    usuario_cliente,
    vehiculo_test,
)
