"""
Script CLI para promover usuarios existentes a admin.
Útil cuando ya hay usuarios y querés darles permisos sin recrearlos.

Uso:
    docker compose exec backend python -m app.modules.admin.seed \
        --email=user@example.com

    # O promover a todos los ADMIN_EMAILS del .env:
    docker compose exec backend python -m app.modules.admin.seed --sync-env
"""
import argparse
import asyncio
import logging
import sys

from sqlalchemy import select

from app.core.config import settings
from app.core.db import AsyncSessionLocal
from app.modules.auth.models import RolUsuario, Usuario

logging.basicConfig(
    level=logging.INFO,
    format="%(levelname)s: %(message)s",
)
logger = logging.getLogger(__name__)


async def promote_by_email(email: str) -> bool:
    """
    Promueve un usuario a admin por email.

    Returns:
        True si se promovió, False si no se encontró o ya era admin.
    """
    async with AsyncSessionLocal() as db:
        stmt = select(Usuario).where(Usuario.email == email.lower())
        result = await db.execute(stmt)
        user = result.scalar_one_or_none()

        if user is None:
            logger.warning(f"Usuario con email '{email}' no encontrado")
            return False

        if user.rol == RolUsuario.ADMIN:
            logger.info(f"Usuario '{email}' ya es admin")
            return False

        old_rol = user.rol.value
        user.rol = RolUsuario.ADMIN
        await db.commit()
        await db.refresh(user)

        logger.info(f"✓ Usuario promovido: {email}")
        logger.info(f"  id: {user.id}")
        logger.info(f"  rol: {old_rol} → admin")
        return True


async def sync_env_admins() -> int:
    """
    Promueve a todos los emails de ADMIN_EMAILS del .env.

    Returns:
        Cantidad de usuarios promovidos.
    """
    emails = settings.admin_emails_list
    if not emails:
        logger.warning("ADMIN_EMAILS está vacío en el .env")
        return 0

    logger.info(f"Sincronizando {len(emails)} emails de ADMIN_EMAILS...")

    promovidos = 0
    for email in emails:
        if await promote_by_email(email):
            promovidos += 1

    return promovidos


async def main():
    parser = argparse.ArgumentParser(
        description="Promover usuarios a admin",
    )
    parser.add_argument(
        "--email",
        type=str,
        help="Email del usuario a promover",
    )
    parser.add_argument(
        "--sync-env",
        action="store_true",
        help="Promover todos los emails de ADMIN_EMAILS",
    )

    args = parser.parse_args()

    if not args.email and not args.sync_env:
        parser.print_help()
        sys.exit(1)

    if args.sync_env:
        promovidos = await sync_env_admins()
        logger.info(f"Total promovidos: {promovidos}")
    else:
        success = await promote_by_email(args.email)
        if not success:
            sys.exit(1)


if __name__ == "__main__":
    asyncio.run(main())
