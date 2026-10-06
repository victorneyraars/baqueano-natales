"""
Implementación de AvatarStorage con filesystem local.
Los avatares se guardan en AVATAR_STORAGE_PATH (default: /app/media/avatars).
"""
import io
import logging
from pathlib import Path

import filetype
from PIL import Image

from app.core.config import settings
from app.shared.storage.base import (
    AvatarStorage,
    FileTooLargeError,
    InvalidFileTypeError,
    StorageError,
)

logger = logging.getLogger(__name__)


class LocalAvatarStorage(AvatarStorage):
    """Guardado de avatares en filesystem local."""

    def __init__(self, base_path: str | Path | None = None) -> None:
        """
        Inicializa el storage.

        Args:
            base_path: Directorio donde se guardan los avatares.
                       Default: settings.AVATAR_STORAGE_PATH
        """
        self.base_path = Path(base_path or settings.AVATAR_STORAGE_PATH)
        self.base_path.mkdir(parents=True, exist_ok=True)
        logger.info(f"LocalAvatarStorage inicializado en {self.base_path}")

    # ---------------------------------------------------------
    # Helpers privados
    # ---------------------------------------------------------
    def _avatar_path(self, user_id: str) -> Path:
        """Ruta completa del avatar de un usuario."""
        return self.base_path / f"{user_id}.jpg"

    def _validate_file(self, content: bytes) -> str:
        """
        Valida el archivo (tamaño + tipo real).

        Returns:
            El MIME type detectado.

        Raises:
            FileTooLargeError: si supera MAX_SIZE_BYTES.
            InvalidFileTypeError: si no es un tipo permitido.
        """
        # 1. Validar tamaño
        if len(content) > self.MAX_SIZE_BYTES:
            raise FileTooLargeError(
                f"Archivo excede el máximo permitido "
                f"({self.MAX_SIZE_BYTES // (1024 * 1024)} MB)"
            )

        # 2. Detectar tipo MIME real (leyendo bytes mágicos)
        kind = filetype.guess(content)
        if kind is None:
            raise InvalidFileTypeError("No se pudo detectar el tipo de archivo")

        mime = kind.mime
        if mime not in self.ALLOWED_MIME_TYPES:
            raise InvalidFileTypeError(
                f"Tipo '{mime}' no permitido. "
                f"Permitidos: {sorted(self.ALLOWED_MIME_TYPES)}"
            )

        return mime

    def _process_image(self, content: bytes) -> bytes:
        """
        Redimensiona y comprime la imagen.
        Convierte siempre a JPEG RGB para consistencia.

        Returns:
            Bytes de la imagen procesada (JPEG).
        """
        img = Image.open(io.BytesIO(content))

        # Convertir a RGB (por si es PNG con alpha, paleta, etc.)
        if img.mode != "RGB":
            img = img.convert("RGB")

        # Redimensionar manteniendo aspect ratio
        img.thumbnail(
            (self.MAX_DIMENSION, self.MAX_DIMENSION),
            Image.Resampling.LANCZOS,
        )

        # Guardar como JPEG en buffer
        output = io.BytesIO()
        img.save(
            output,
            format=self.OUTPUT_FORMAT,
            quality=self.OUTPUT_QUALITY,
            optimize=True,
        )
        return output.getvalue()

    # ---------------------------------------------------------
    # Interfaz pública
    # ---------------------------------------------------------
    async def save_avatar(self, user_id: str, content: bytes) -> str:
        """
        Guarda el avatar de un usuario.

        Flujo:
        1. Valida tamaño y tipo (MIME real).
        2. Procesa la imagen (resize + compress).
        3. Guarda en filesystem.
        4. Devuelve la URL pública.
        """
        # 1. Validar
        mime = self._validate_file(content)
        logger.info(f"Avatar recibido: usuario={user_id}, mime={mime}, "
                    f"tamaño={len(content)} bytes")

        # 2. Procesar
        try:
            processed = self._process_image(content)
        except Exception as e:
            raise StorageError(f"Error procesando imagen: {e}") from e

        # 3. Guardar
        path = self._avatar_path(user_id)
        try:
            path.write_bytes(processed)
            logger.info(f"Avatar guardado: {path} ({len(processed)} bytes)")
        except OSError as e:
            raise StorageError(f"Error escribiendo archivo: {e}") from e

        # 4. Devolver URL
        return self.get_avatar_url(user_id)

    async def delete_avatar(self, user_id: str) -> None:
        """Elimina el avatar del filesystem si existe."""
        path = self._avatar_path(user_id)
        if path.exists():
            try:
                path.unlink()
                logger.info(f"Avatar eliminado: {path}")
            except OSError as e:
                raise StorageError(f"Error eliminando archivo: {e}") from e

    def get_avatar_url(self, user_id: str) -> str:
        """
        Devuelve la URL pública del avatar.

        En local, expone /media/avatars/{user_id}.jpg (servido por nginx).
        """
        base_url = settings.PUBLIC_API_URL.rstrip("/")
        return f"{base_url}/media/avatars/{user_id}.jpg"
