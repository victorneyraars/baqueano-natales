"""Routers del modulo oficios (Hub Pattern)."""

from .public_routes import router_publico
from .admin_routes import router_admin_categorias
from .admin_routes import router_admin_repuestos
from .cliente_routes import router_propietario
from .cliente_routes import router_mis_ordenes_cliente
from .cliente_routes import router_turnos_cliente
from .cliente_routes import router_garantias_cliente
from .cliente_routes import router_recordatorios
from .prestador_routes import router_mis_ordenes
from .prestador_routes import router_prestador_utilidades
from .prestador_routes import router_turnos_prestador
from .prestador_routes import router_garantias_prestador
