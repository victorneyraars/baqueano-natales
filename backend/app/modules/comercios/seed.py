"""
Seed de datos iniciales del módulo comercios.

Idempotente: se puede correr múltiples veces sin duplicar categorías.

Uso (dentro del contenedor):
    python -m app.modules.comercios.seed
"""
import asyncio
import logging

from sqlalchemy import select

from app.core.db import AsyncSessionLocal
from app.modules.comercios.models import CategoriaComercio

logger = logging.getLogger(__name__)


CATEGORIAS_BASE = [
    {
        "nombre": "Restaurante",
        "slug": "restaurante",
        "descripcion": "Comida preparada, almuerzos, cenas",
        "icono": "restaurant",
        "color_hex": "#E53935",
        "orden": 10,
    },
    {
        "nombre": "Café",
        "slug": "cafe",
        "descripcion": "Cafeterías y casas de té",
        "icono": "local_cafe",
        "color_hex": "#6D4C41",
        "orden": 20,
    },
    {
        "nombre": "Panadería",
        "slug": "panaderia",
        "descripcion": "Pan, pasteles, masas",
        "icono": "bakery_dining",
        "color_hex": "#FB8C00",
        "orden": 30,
    },
    {
        "nombre": "Minimarket",
        "slug": "minimarket",
        "descripcion": "Almacenes y minimarkets",
        "icono": "storefront",
        "color_hex": "#43A047",
        "orden": 40,
    },
    {
        "nombre": "Farmacia",
        "slug": "farmacia",
        "descripcion": "Farmacias y remedios",
        "icono": "local_pharmacy",
        "color_hex": "#00ACC1",
        "orden": 50,
    },
    {
        "nombre": "Ferretería",
        "slug": "ferreteria",
        "descripcion": "Ferreterías y materiales",
        "icono": "hardware",
        "color_hex": "#546E7A",
        "orden": 60,
    },
    {
        "nombre": "Servicios",
        "slug": "servicios",
        "descripcion": "Gasfitería, electricidad, oficios",
        "icono": "handyman",
        "color_hex": "#3949AB",
        "orden": 70,
    },
    {
        "nombre": "Belleza",
        "slug": "belleza",
        "descripcion": "Peluquerías, estética, spa",
        "icono": "spa",
        "color_hex": "#D81B60",
        "orden": 80,
    },
    {
        "nombre": "Otro",
        "slug": "otro",
        "descripcion": "Otros rubros no listados",
        "icono": "category",
        "color_hex": "#757575",
        "orden": 999,
    },
]


async def seed_categorias() -> None:
    """Crea las categorías base si no existen (idempotente)."""
    creadas = 0
    existentes = 0

    async with AsyncSessionLocal() as session:
        for data in CATEGORIAS_BASE:
            stmt = select(CategoriaComercio).where(
                CategoriaComercio.slug == data["slug"]
            )
            cat = (await session.execute(stmt)).scalar_one_or_none()
            if cat is not None:
                existentes += 1
                continue
            session.add(CategoriaComercio(**data))
            creadas += 1
        await session.commit()

    logger.info(
        f"Seed categorías: {creadas} creadas, {existentes} ya existían"
    )
    print(
        f"✅ Seed categorías: {creadas} creadas, {existentes} ya existían"
    )


async def main() -> None:
    logging.basicConfig(level=logging.INFO)
    await seed_categorias()


if __name__ == "__main__":
    asyncio.run(main())