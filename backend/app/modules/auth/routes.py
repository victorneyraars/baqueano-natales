"""
Endpoints HTTP de autenticación.
"""
import logging

from fastapi import APIRouter, HTTPException, status
from pydantic import BaseModel, Field

from app.core.db import DbSession
from app.core.security import create_access_token
from app.modules.auth.deps import CurrentUser
from app.modules.auth.schemas import UsuarioResponse
from app.modules.auth.services import get_or_create_user_from_firebase

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/auth", tags=["auth"])


# ---------------------------------------------------------
# Schemas de entrada/salida específicos de este router
# ---------------------------------------------------------
class GoogleLoginRequest(BaseModel):
    """Payload del login con Google."""

    id_token: str = Field(
        ...,
        description="ID token JWT emitido por Firebase Auth (Google Sign-In)",
        min_length=100,
    )


class TokenResponse(BaseModel):
    """Respuesta del login exitoso."""

    access_token: str
    token_type: str = "bearer"
    user: UsuarioResponse


# ---------------------------------------------------------
# Endpoints
# ---------------------------------------------------------
@router.post(
    "/google",
    response_model=TokenResponse,
    status_code=status.HTTP_200_OK,
    summary="Login con Google",
    description=(
        "Recibe un ID token de Firebase Auth (obtenido en la app móvil "
        "con Google Sign-In) y devuelve un JWT propio del backend."
    ),
)
async def login_google(
    payload: GoogleLoginRequest,
    db: DbSession,
) -> TokenResponse:
    """
    Login con Google.

    Flujo:
    1. Recibe `id_token` de Firebase Auth.
    2. Verifica el token con Firebase Admin SDK.
    3. Crea o actualiza el usuario en la DB.
    4. Genera un JWT propio del backend.
    5. Devuelve el JWT + datos del usuario.
    """
    try:
        user = await get_or_create_user_from_firebase(db, payload.id_token)
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=str(e),
        )

    # Generar JWT propio
    access_token = create_access_token(
        subject=str(user.id),
        extra_claims={
            "rol": user.rol.value,
            "email": user.email,
        },
    )

    logger.info(f"Login exitoso: usuario {user.id} (rol: {user.rol.value})")

    return TokenResponse(
        access_token=access_token,
        token_type="bearer",
        user=UsuarioResponse.model_validate(user),
    )


@router.get(
    "/me",
    response_model=UsuarioResponse,
    summary="Datos del usuario actual",
    description="Devuelve los datos del usuario autenticado (requiere JWT).",
)
async def get_me(user: CurrentUser) -> UsuarioResponse:
    """Devuelve el usuario actual."""
    return UsuarioResponse.model_validate(user)
