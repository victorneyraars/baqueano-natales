"""
Inicialización del Firebase Admin SDK.
Provee autenticación con Google y envío de notificaciones FCM.
"""
import logging
from pathlib import Path

import firebase_admin
from firebase_admin import auth, credentials

from app.core.config import settings

logger = logging.getLogger(__name__)

_firebase_app: firebase_admin.App | None = None


def init_firebase() -> firebase_admin.App:
    """
    Inicializa Firebase Admin SDK.
    Idempotente: si ya está inicializado, devuelve la misma instancia.

    Returns:
        App de Firebase inicializada.

    Raises:
        FileNotFoundError: si el service account no existe.
        ValueError: si el JSON es inválido.
    """
    global _firebase_app

    if _firebase_app is not None:
        return _firebase_app

    # Verificar que el archivo exista
    sa_path = Path(settings.FIREBASE_SERVICE_ACCOUNT_PATH)
    if not sa_path.exists():
        raise FileNotFoundError(
            f"Service account de Firebase no encontrado en: {sa_path}"
        )

    logger.info(f"Inicializando Firebase Admin SDK con {sa_path}")
    cred = credentials.Certificate(str(sa_path))

    _firebase_app = firebase_admin.initialize_app(
        cred,
        {"projectId": settings.FIREBASE_PROJECT_ID},
    )

    logger.info(f"Firebase Admin SDK inicializado (project: {settings.FIREBASE_PROJECT_ID})")
    return _firebase_app


def get_firebase_app() -> firebase_admin.App:
    """Retorna la app de Firebase (la inicializa si hace falta)."""
    return init_firebase()


def verify_id_token(id_token: str) -> dict:
    """
    Verifica un ID token de Firebase y devuelve el payload decodificado.

    Args:
        id_token: JWT emitido por Firebase Auth.

    Returns:
        Payload del token (dict con uid, email, etc.).

    Raises:
        firebase_admin.auth.InvalidIdTokenError: si el token es inválido.
        firebase_admin.auth.ExpiredIdTokenError: si el token expiró.
    """
    get_firebase_app()  # Asegurar inicialización
    return auth.verify_id_token(id_token)
