"""
Seed de datos iniciales del módulo prestadores.

Idempotente: se puede correr múltiples veces sin duplicar categorías.

Uso (dentro del contenedor):
    python -m app.modules.prestadores.seed
"""
import asyncio
import logging

from sqlalchemy import select

from app.core.db import AsyncSessionLocal
from app.modules.prestadores.models import CategoriaOficio

logger = logging.getLogger(__name__)


CATEGORIAS_BASE = [
    {
        "nombre": "Mecánica automotriz",
        "slug": "mecanica-automotriz",
        "descripcion": "Reparación y mantenimiento de vehículos",
        "icono": "build",
        "color_hex": "#1976D2",
        "orden": 10,
    },
    {
        "nombre": "Electricidad",
        "slug": "electricidad",
        "descripcion": "Instalaciones y reparaciones eléctricas",
        "icono": "electrical_services",
        "color_hex": "#FBC02D",
        "orden": 20,
    },
    {
        "nombre": "Gasfitería",
        "slug": "gasfiteria",
        "descripcion": "Instalaciones y reparaciones de agua y gas",
        "icono": "plumbing",
        "color_hex": "#0288D1",
        "orden": 30,
    },
    {
        "nombre": "Carpintería",
        "slug": "carpinteria",
        "descripcion": "Muebles, estructuras y trabajos en madera",
        "icono": "carpenter",
        "color_hex": "#8D6E63",
        "orden": 40,
    },
    {
        "nombre": "Albañilería",
        "slug": "albanileria",
        "descripcion": "Construcción y remodelación",
        "icono": "construction",
        "color_hex": "#757575",
        "orden": 50,
    },
    {
        "nombre": "Pintura",
        "slug": "pintura",
        "descripcion": "Pintura de interiores y exteriores",
        "icono": "format_paint",
        "color_hex": "#E53935",
        "orden": 60,
    },
    {
        "nombre": "Cerrajería",
        "slug": "cerrajeria",
        "descripcion": "Apertura, cambio y reparación de cerraduras",
        "icono": "vpn_key",
        "color_hex": "#455A64",
        "orden": 70,
    },
    {
        "nombre": "Jardinería",
        "slug": "jardineria",
        "descripcion": "Mantenimiento de jardines y áreas verdes",
        "icono": "yard",
        "color_hex": "#43A047",
        "orden": 80,
    },
    {
        "nombre": "Limpieza",
        "slug": "limpieza",
        "descripcion": "Servicios de aseo y limpieza",
        "icono": "cleaning_services",
        "color_hex": "#00ACC1",
        "orden": 90,
    },
    {
        "nombre": "Fletes y mudanzas",
        "slug": "fletes-y-mudanzas",
        "descripcion": "Transporte de carga y mudanzas",
        "icono": "local_shipping",
        "color_hex": "#6D4C41",
        "orden": 100,
    },
    {
        "nombre": "Otros oficios",
        "slug": "otros-oficios",
        "descripcion": "Otros servicios no listados",
        "icono": "handyman",
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
            stmt = select(CategoriaOficio).where(
                CategoriaOficio.slug == data["slug"]
            )
            cat = (await session.execute(stmt)).scalar_one_or_none()
            if cat is not None:
                existentes += 1
                continue
            session.add(CategoriaOficio(**data))
            creadas += 1
        await session.commit()

    logger.info(
        f"Seed categorías oficio: {creadas} creadas, {existentes} ya existían"
    )
    print(
        f"✅ Seed categorías oficio: {creadas} creadas, {existentes} ya existían"
    )


async def main() -> None:
    logging.basicConfig(level=logging.INFO)
    await seed_categorias()


if __name__ == "__main__":
    asyncio.run(main())