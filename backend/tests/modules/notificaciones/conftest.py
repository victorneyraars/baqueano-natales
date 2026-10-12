"""Fixtures especificas del modulo notificaciones."""
from uuid import uuid4

import pytest_asyncio

from app.modules.auth.models import RolUsuario, Usuario


@pytest_asyncio.fixture
async def usuario_cliente(db):
    """Usuario con rol CLIENTE."""
    user = Usuario(
        firebase_uid=f"test_{uuid4().hex[:12]}",
        email=f"test_{uuid4().hex[:8]}@test.com",
        nombre="Test",
        apellido="Cliente",
        rol=RolUsuario.CLIENTE,
        activo=True,
    )
    db.add(user)
    await db.flush()
    return user
