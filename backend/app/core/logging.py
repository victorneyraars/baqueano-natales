"""
Configuración de logging estructurado en JSON.
Útil para journald y agregadores de logs.
"""
import logging
import sys

from pythonjsonlogger import jsonlogger

from app.core.config import settings


def setup_logging() -> None:
    """Configura el logger raíz para emitir JSON a stdout."""
    root = logging.getLogger()

    # Evitar duplicar handlers si se llama más de una vez
    if root.handlers:
        return

    root.setLevel(settings.LOG_LEVEL.upper())

    handler = logging.StreamHandler(sys.stdout)
    formatter = jsonlogger.JsonFormatter(
        "%(asctime)s %(levelname)s %(name)s %(message)s",
        timestamp=True,
    )
    handler.setFormatter(formatter)
    root.addHandler(handler)

    # Bajar verbosidad de uvicorn
    logging.getLogger("uvicorn.access").setLevel(logging.WARNING)
    logging.getLogger("uvicorn.error").setLevel(logging.INFO)
