"""Seed de datos base del modulo oficios."""
import logging

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.modules.oficios.models import MecanicaCategoriaServicio

logger = logging.getLogger(__name__)


CATEGORIAS_MECANICA = [
    {"nombre": "Mantenimiento", "slug": "mantenimiento", "icono": "build", "color_hex": "#16a34a", "orden": 1},
    {"nombre": "Frenos", "slug": "frenos", "icono": "directions_car", "color_hex": "#dc2626", "orden": 2},
    {"nombre": "Motor", "slug": "motor", "icono": "settings", "color_hex": "#7c3aed", "orden": 3},
    {"nombre": "Suspension y Direccion", "slug": "suspension-direccion", "icono": "linear_scale", "color_hex": "#f97316", "orden": 4},
    {"nombre": "Transmision", "slug": "transmision", "icono": "autorenew", "color_hex": "#0891b2", "orden": 5},
    {"nombre": "Electrico y Electronico", "slug": "electrico", "icono": "electrical_services", "color_hex": "#eab308", "orden": 6},
    {"nombre": "Aire Acondicionado", "slug": "aire-acondicionado", "icono": "ac_unit", "color_hex": "#0ea5e9", "orden": 7},
    {"nombre": "Neumaticos", "slug": "neumaticos", "icono": "tire_repair", "color_hex": "#1f2937", "orden": 8},
    {"nombre": "Escape", "slug": "escape", "icono": "air", "color_hex": "#64748b", "orden": 9},
    {"nombre": "Carroceria y Pintura", "slug": "carroceria", "icono": "format_paint", "color_hex": "#db2777", "orden": 10},
    {"nombre": "Diagnostico", "slug": "diagnostico", "icono": "search", "color_hex": "#4f46e5", "orden": 11},
]


async def seed_categorias_mecanica(db: AsyncSession) -> int:
    """Inserta las categorias base de mecanica si no existen.

    Idempotente: no falla si ya estan cargadas.
    Devuelve la cantidad de categorias insertadas.
    """
    creadas = 0
    for cat in CATEGORIAS_MECANICA:
        existente = (
            await db.execute(
                select(MecanicaCategoriaServicio).where(
                    MecanicaCategoriaServicio.slug == cat["slug"]
                )
            )
        ).scalar_one_or_none()
        if existente is not None:
            continue
        obj = MecanicaCategoriaServicio(**cat)
        db.add(obj)
        creadas += 1
    await db.flush()
    return creadas
