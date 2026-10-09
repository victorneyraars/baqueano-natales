"""
Utilidades para generar slugs únicos.

Un slug es la versión URL-safe de un texto: minúsculas, sin acentos,
sin caracteres especiales, palabras separadas por guiones.

Ejemplo:
    "Café Central Ñuñoa" → "cafe-central-nunoa"

Uso típico:
    from app.shared.utils.slug import generar_slug_unico

    slug = await generar_slug_unico(
        db,
        texto="Mi Comercio",
        modelo=Comercio,
    )
"""
import re
import unicodedata
from typing import Any, Type, TypeVar
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

# TypeVar genérico — no necesita bound porque trabajamos con el contrato
# implícito: el modelo debe tener `id` y un campo slug. Usar `Any` como
# bound evita importar `Base` (que dispara la creación del engine al
# cargar `app.core.db`).
T = TypeVar("T", bound=Any)


def slugify(texto: str) -> str:
    """
    Convierte un texto en slug URL-safe.

    - Minúsculas
    - Sin acentos ni caracteres Unicode combinantes
    - Reemplaza cualquier cosa no alfanumérica por guiones
    - Colapsa guiones múltiples
    - Quita guiones del inicio y del final

    Si el resultado queda vacío, devuelve "sin-nombre".
    """
    # Normalizar: separar letras de sus acentos
    normalizado = unicodedata.normalize("NFKD", texto)
    # Quitar marcas combinantes (acentos)
    sin_acentos = "".join(c for c in normalizado if not unicodedata.combining(c))
    # Reemplazar todo lo no alfanumérico por guiones
    slug = re.sub(r"[^a-zA-Z0-9]+", "-", sin_acentos)
    # Colapsar guiones múltiples y quitar extremos
    slug = re.sub(r"-+", "-", slug).strip("-").lower()
    return slug or "sin-nombre"


async def generar_slug_unico(
    db: AsyncSession,
    texto: str,
    modelo: Type[T],
    *,
    campo_slug: str = "slug",
    excluir_id: UUID | None = None,
    max_intentos: int = 1000,
) -> str:
    """
    Genera un slug único a partir del texto.

    Si el slug base ya existe en la tabla, agrega sufijo -2, -3, ...
    hasta encontrar uno libre.

    Args:
        db: sesión async de SQLAlchemy.
        texto: texto del cual derivar el slug (ej: nombre).
        modelo: clase del modelo SQLAlchemy (ej: Comercio). Solo necesita
                tener un campo `id` y un campo de slug.
        campo_slug: nombre del campo slug en el modelo. Default "slug".
        excluir_id: si se está editando, ID a excluir de la búsqueda.
        max_intentos: límite de seguridad.

    Returns:
        Slug único, listo para insertar.

    Raises:
        RuntimeError: si después de `max_intentos` no encuentra uno libre.
    """
    base = slugify(texto)
    campo = getattr(modelo, campo_slug)
    slug = base
    contador = 2

    while contador < max_intentos:
        stmt = select(modelo.id).where(campo == slug)
        if excluir_id is not None:
            stmt = stmt.where(modelo.id != excluir_id)
        existe = (await db.execute(stmt)).scalar_one_or_none()
        if existe is None:
            return slug
        slug = f"{base}-{contador}"
        contador += 1

    raise RuntimeError(
        f"No se pudo generar slug único para '{texto}' "
        f"después de {max_intentos} intentos"
    )