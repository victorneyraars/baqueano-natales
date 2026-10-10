"""
Cifrado simétrico de secretos (tokens de redes sociales, integraciones).

Usa Fernet (AES-128 en CBC + HMAC-SHA256), el esquema recomendado por la
propia documentación de `cryptography`.

Diseño:
- La clave se lee de ``TOKEN_ENCRYPTION_KEY`` (variable de entorno).
- Los valores cifrados se guardan con prefijo ``enc:`` para distinguirlos
  de valores en claro (compatibilidad con datos previos).
- Si la clave no está configurada:
    * En ``ENVIRONMENT=production`` -> error explícito en el arranque
      (fallar temprano es mejor que guardar tokens en claro sin que nadie
      se entere).
    * En dev/staging -> warning en log, se guarda en claro. Esto permite
      desarrollar sin configurar todo, pero es INCORRECTO en producción.

Generar una clave::

    python -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"

Rotación de clave (futuro): ``rotar()`` permitirá migrar de una clave
vieja a una nueva sin perder datos. Se agregará cuando haga falta.
"""
import logging

from cryptography.fernet import Fernet, InvalidToken

from app.core.config import settings

logger = logging.getLogger(__name__)

_PREFIJO = "enc:"


# =========================================================
# Internos
# =========================================================
def _cargar_fernet() -> Fernet | None:
    """
    Carga la clave Fernet desde settings.

    Devuelve None si no hay clave configurada o si es inválida (con log
    del motivo). No levanta excepción: quien llama decide qué hacer.
    """
    clave = (settings.TOKEN_ENCRYPTION_KEY or "").strip()
    if not clave:
        return None
    try:
        return Fernet(clave.encode())
    except (ValueError, TypeError) as e:
        logger.error("TOKEN_ENCRYPTION_KEY inválida: %s", e)
        return None


# =========================================================
# API pública
# =========================================================
def cifrar(texto: str | None) -> str | None:
    """
    Cifra un secreto para guardar en DB.

    Devuelve el valor cifrado con prefijo ``enc:`` o el texto original si
    no hay clave configurada (con warning en el log).

    Nunca levanta excepción: si algo falla, devuelve el texto tal cual y
    deja un warning. Esto es intencional: el llamador no debería romperse
    por un problema de crypto.
    """
    if not texto:
        return texto
    f = _cargar_fernet()
    if f is None:
        logger.warning(
            "TOKEN_ENCRYPTION_KEY no configurada: el secreto se guarda SIN "
            "cifrar. En producción esto no debería pasar."
        )
        return texto
    return _PREFIJO + f.encrypt(texto.encode()).decode()


def descifrar(guardado: str | None) -> str | None:
    """
    Devuelve el secreto en claro.

    Acepta valores cifrados (prefijo ``enc:``) y valores en claro
    (compatibilidad con datos guardados antes de configurar la clave).

    Devuelve None si:
    - El valor parece cifrado pero falta la clave.
    - El valor parece cifrado pero la clave no lo puede descifrar
      (clave distinta a la que se usó para cifrar).

    Nunca levanta excepción.
    """
    if not guardado:
        return guardado
    if not guardado.startswith(_PREFIJO):
        # Estaba en claro. Se devuelve tal cual.
        return guardado
    f = _cargar_fernet()
    if f is None:
        logger.error(
            "Hay un secreto cifrado pero falta TOKEN_ENCRYPTION_KEY. "
            "No se puede descifrar."
        )
        return None
    try:
        return f.decrypt(guardado[len(_PREFIJO):].encode()).decode()
    except InvalidToken:
        logger.error(
            "No se pudo descifrar el secreto (clave equivocada o dato "
            "corrupto)."
        )
        return None


def validar_clave_configurada() -> None:
    """
    Verifica que la clave esté configurada.

    Se llama en el arranque de la app (lifespan). Si estamos en producción
    y no hay clave, se levanta RuntimeError para no arrancar con una
    configuración insegura.

    En dev/staging solo deja un warning: permite desarrollar sin configurar
    todo, a costa de guardar en claro (aceptable solo en no-producción).
    """
    if settings.TOKEN_ENCRYPTION_KEY:
        return
    mensaje = (
        "TOKEN_ENCRYPTION_KEY no configurada. Los secretos (tokens de "
        "redes sociales, integraciones) se guardarían SIN cifrar."
    )
    if settings.is_production:
        raise RuntimeError(mensaje + " Abortando en producción.")
    logger.warning(mensaje + " (solo aceptable en dev/staging).")