"""
Conexión a base de datos con SQLAlchemy 2.0 async.
Provee el engine, la sesión y la dependencia get_db() para FastAPI.
"""
from collections.abc import AsyncGenerator
from typing import Annotated

from fastapi import Depends
from sqlalchemy.ext.asyncio import (
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)
from sqlalchemy.orm import DeclarativeBase

from app.core.config import settings


class Base(DeclarativeBase):
    """Clase base para todos los modelos SQLAlchemy."""

    pass


# ---------------------------------------------------------
# Engine async
# ---------------------------------------------------------
# Convertir la URL sync a async (postgresql:// → postgresql+asyncpg://)
def _to_async_url(url: str) -> str:
    if url.startswith("postgresql://"):
        return url.replace("postgresql://", "postgresql+asyncpg://", 1)
    return url


async_url = _to_async_url(settings.DATABASE_URL)

engine = create_async_engine(
    async_url,
    echo=settings.DEBUG,
    pool_size=10,
    max_overflow=20,
    pool_pre_ping=True,
    pool_recycle=3600,
)

# Session maker async
AsyncSessionLocal = async_sessionmaker(
    bind=engine,
    class_=AsyncSession,
    expire_on_commit=False,
    autoflush=False,
)


# ---------------------------------------------------------
# Dependencia para FastAPI
# ---------------------------------------------------------
async def get_db() -> AsyncGenerator[AsyncSession, None]:
    """
    Dependencia de FastAPI que provee una sesión de DB.
    Se encarga de commit/rollback y cierre automático.

    Uso:
        @router.get("/algo")
        async def endpoint(db: DbSession):
            ...
    """
    async with AsyncSessionLocal() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise
        finally:
            await session.close()


# Tipo anotado para usar en endpoints
DbSession = Annotated[AsyncSession, Depends(get_db)]
