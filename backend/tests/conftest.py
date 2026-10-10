"""
Configuración compartida de pytest.

Estrategia:
- Si `TEST_DATABASE_URL` está en el entorno, se usa esa.
- Si no, se construye a partir de las variables POSTGRES_* (que están
  seteadas en el container), apuntando a la DB de test `baqueano_test`.
- Si no hay forma de armar la URL, los tests que piden `db` se saltan.

Notas sobre pytest-asyncio 0.25:
- `test_engine` y `_init_schema` son fixtures SÍNCRONOS (scope=session).
  `create_async_engine` no es awaitable, así que no necesitan ser async,
  y evitamos el ScopeMismatch entre fixtures async session-scoped y el
  event loop function-scoped.
- El CREATE TABLE inicial corre dentro de un `asyncio.run()` propio.
- `db` es async function-scoped: cada test tiene su propia sesión y loop.
"""
import asyncio
import os

# IMPORTANTE: antes de cualquier import de `app.core.db`
os.environ.setdefault(
    "DATABASE_URL",
    "postgresql://fake:fake@localhost:5432/fake_db",
)

import pytest
import pytest_asyncio
from sqlalchemy import text
from sqlalchemy.ext.asyncio import (
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)
from sqlalchemy.pool import NullPool

from app.core.db import Base


# =========================================================
# Construcción de la URL de test
# =========================================================
def _test_url() -> str | None:
    """URL de la DB de test (o None si no se puede armar)."""
    explicit = os.environ.get("TEST_DATABASE_URL")
    if explicit:
        return explicit

    user = os.environ.get("POSTGRES_USER")
    password = os.environ.get("POSTGRES_PASSWORD")
    host = os.environ.get("POSTGRES_HOST", "db")
    port = os.environ.get("POSTGRES_PORT", "5432")
    if user and password:
        return (
            f"postgresql+asyncpg://{user}:{password}"
            f"@{host}:{port}/baqueano_test"
        )
    return None


# =========================================================
# Fixtures (sync session-scoped)
# =========================================================
@pytest.fixture(scope="session")
def test_url() -> str:
    url = _test_url()
    if not url:
        pytest.skip(
            "No se pudo determinar la URL de test: "
            "se saltan los tests con DB"
        )
    return url


@pytest.fixture(scope="session")
def test_engine(test_url: str):
    """
    Engine async dedicado a los tests.

    Fixture SÍNCRONO: `create_async_engine` no es awaitable, así que no
    necesita un event loop. NullPool evita compartir conexiones entre
    loops distintos de cada test.
    """
    engine = create_async_engine(test_url, poolclass=NullPool)
    yield engine
    # No se hace dispose: NullPool + suite corta. El GC lo maneja.


@pytest.fixture(scope="session")
def _init_schema(test_engine):
    """
    Crea el esquema (todas las tablas) una sola vez por sesión de tests.

    NO es autouse: solo se ejecuta cuando un test pide el fixture `db`.
    Usa asyncio.run() para hacer el CREATE TABLE sin declarar un fixture
    async session-scoped (que dispararía ScopeMismatch en 0.25).
    """
    async def _crear():
        from app.modules.auth import models as _auth  # noqa: F401
        from app.modules.comercios import models as _comercios  # noqa: F401
        from app.modules.prestadores import models as _prestadores  # noqa: F401
        from app.modules.social import models as _social  # noqa: F401

        async with test_engine.begin() as conn:
            await conn.run_sync(Base.metadata.create_all)

    asyncio.run(_crear())
    yield


# =========================================================
# Sesión por test (async, function-scoped)
# =========================================================
@pytest_asyncio.fixture
async def db(test_engine, _init_schema) -> AsyncSession:
    """
    Sesión async limpia por test.

    TRUNCATE de las tablas del módulo social antes de cada test para
    garantizar aislamiento. CASCADE por las FK entre las 4 tablas.
    """
    session_maker = async_sessionmaker(
        test_engine,
        class_=AsyncSession,
        expire_on_commit=False,
        autoflush=False,
    )
    async with session_maker() as session:
        await session.execute(
            text(
                "TRUNCATE TABLE "
                "publicaciones_sociales, tokens_sociales, "
                "cuentas_sociales, config_social "
                "RESTART IDENTITY CASCADE"
            )
        )
        await session.commit()
        try:
            yield session
        finally:
            await session.rollback()