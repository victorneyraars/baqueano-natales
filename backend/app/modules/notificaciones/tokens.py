"""Generacion y validacion de tokens JWT para acciones desde emails."""
from datetime import datetime, timedelta
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
