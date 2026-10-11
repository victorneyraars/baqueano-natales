"""
Alembic environment configuration.
Lee la URL de la DB desde pydantic-settings y soporta async.
"""
import asyncio
from logging.config import fileConfig

from alembic import context
from sqlalchemy import pool
from sqlalchemy.engine import Connection
from sqlalchemy.ext.asyncio import async_engine_from_config

# Importar settings y modelos para autogenerate
from app.core.config import settings
from app.core.db import Base

# Importar TODOS los modelos para que Alembic los detecte
# (A medida que creamos módulos, se importan aquí)
from app.modules.auth import models as auth_models  # noqa: F401
from app.modules.comercios import models as comercios_models  # noqa: F401
from app.modules.prestadores import models as prestadores_models  # noqa: F401
from app.modules.social import models as social_models  # noqa: F401
from app.modules.oficios import models as oficios_models  # noqa: F401

# Alembic Config object
config = context.config

# Logging desde el archivo .ini
if config.config_file_name is not None:
    fileConfig(config.config_file_name)

# Metadata para autogenerate
target_metadata = Base.metadata


def _to_async_url(url: str) -> str:
    """Convierte postgresql:// a postgresql+asyncpg://"""
    if url.startswith("postgresql://"):
        return url.replace("postgresql://", "postgresql+asyncpg://", 1)
    return url


# Sobreescribir la URL con la del .env
config.set_main_option("sqlalchemy.url", _to_async_url(settings.DATABASE_URL))


def run_migrations_offline() -> None:
    """Run migrations in 'offline' mode."""
    url = config.get_main_option("sqlalchemy.url")
    context.configure(
        url=url,
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
        compare_type=True,
        compare_server_default=True,
    )

    with context.begin_transaction():
        context.run_migrations()


def do_run_migrations(connection: Connection) -> None:
    """Run migrations with the given connection."""
    context.configure(
        connection=connection,
        target_metadata=target_metadata,
        compare_type=True,
        compare_server_default=True,
    )

    with context.begin_transaction():
        context.run_migrations()


async def run_async_migrations() -> None:
    """Create an async engine and run migrations."""
    connectable = async_engine_from_config(
        config.get_section(config.config_ini_section, {}),
        prefix="sqlalchemy.",
        poolclass=pool.NullPool,
    )

    async with connectable.connect() as connection:
        await connection.run_sync(do_run_migrations)

    await connectable.dispose()


def run_migrations_online() -> None:
    """Run migrations in 'online' mode."""
    asyncio.run(run_async_migrations())


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()