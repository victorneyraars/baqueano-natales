"""Generacion y validacion de tokens JWT para acciones desde emails
y para invitaciones a colaboradores."""
from datetime import datetime, timedelta, timezone
import jwt
from app.core.config import settings


def generar_token_accion(reserva_id: str, accion: str) -> str:
    """Token firmado valido 7 dias."""
    payload = {
        "reserva_id": reserva_id,
        "accion": accion,
        "exp": datetime.utcnow() + timedelta(days=7),
        "iat": datetime.utcnow(),
    }
    return jwt.encode(payload, settings.SECRET_KEY, algorithm="HS256")


def validar_token_accion(token: str) -> dict:
    """Lanza jwt.InvalidTokenError si invalido/expirado."""
    return jwt.decode(token, settings.SECRET_KEY, algorithms=["HS256"])

# =========================================================
# Tokens para invitaciones a colaboradores
# =========================================================
def generar_token_invitacion(prestador_id: str, email: str) -> str:
    """Token firmado valido 7 dias para aceptar invitacion."""
    payload = {
        "tipo": "invitacion_colaborador",
        "prestador_id": prestador_id,
        "email": email.lower().strip(),
        "exp": datetime.now(timezone.utc) + timedelta(days=7),
        "iat": datetime.now(timezone.utc),
    }
    return jwt.encode(payload, settings.SECRET_KEY, algorithm="HS256")


def validar_token_invitacion(token: str) -> dict:
    """Lanza jwt.InvalidTokenError si invalido/expirado o si no es
    un token de invitacion."""
    payload = jwt.decode(token, settings.SECRET_KEY, algorithms=["HS256"])
    if payload.get("tipo") != "invitacion_colaborador":
        raise jwt.InvalidTokenError("Token no es de invitacion")
    return payload
