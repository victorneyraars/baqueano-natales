"""Implementacion local (filesystem) de FotoStorage.

Layout: {FOTO_STORAGE_PATH}/ordenes/{hash[:2]}/{hash[2:4]}/{hash}/
  - original.jpg
  - medium.jpg
  - thumb.jpg
"""
import hashlib
import io
import logging
from pathlib import Path

import blurhash
import filetype
from PIL import Image, ImageOps

from app.core.config import settings
from app.shared.storage.foto_base import (
    FileTooLargeError,
    FotoProcesada,
    FotoStorage,
    InvalidFileTypeError,
    StorageError,
    VarianteFoto,
)

logger = logging.getLogger(__name__)


class LocalFotoStorage(FotoStorage):
    """Guardado de fotos en filesystem local."""

    def __init__(self, base_path: str | Path | None = None) -> None:
        self.base_path = Path(base_path or settings.FOTO_STORAGE_PATH)
        self.base_path.mkdir(parents=True, exist_ok=True)
        logger.info(f"LocalFotoStorage inicializado en {self.base_path}")

    # ---------------------------------------------------------------
    # Helpers
    # ---------------------------------------------------------------
    def _carpeta(self, storage_key: str) -> Path:
        return self.base_path / storage_key

    def _validar(self, content: bytes) -> str:
        """Valida tamano + MIME por magic bytes. Devuelve el MIME."""
        if len(content) > self.MAX_SIZE_BYTES:
            raise FileTooLargeError(
                f"Archivo excede el maximo permitido "
                f"({self.MAX_SIZE_BYTES // (1024 * 1024)} MB)"
            )

        kind = filetype.guess(content)
        if kind is None:
            raise InvalidFileTypeError(
                "No se pudo detectar el tipo de archivo"
            )

        mime = kind.mime
        if mime not in self.ALLOWED_MIME_TYPES:
            raise InvalidFileTypeError(
                f"Tipo '{mime}' no permitido. "
                f"Permitidos: {sorted(self.ALLOWED_MIME_TYPES)}"
            )

        return mime

    def _procesar_variantes(
        self, content: bytes,
    ) -> tuple[dict[str, bytes], dict[str, tuple[int, int]]]:
        """Abre la imagen, aplica EXIF orientation, borra EXIF, genera 3 variantes.

        Returns:
            (variantes_bytes, variantes_meta_wh)
        """
        img = Image.open(io.BytesIO(content))

        # Aplicar orientacion EXIF y luego quitar metadatos
        img = ImageOps.exif_transpose(img) or img

        # JPEG no soporta alpha ni paletas
        if img.mode != "RGB":
            img = img.convert("RGB")

        variantes_bytes: dict[str, bytes] = {}
        variantes_wh: dict[str, tuple[int, int]] = {}

        for nombre, max_dim in (
            ("original", self.MAX_DIMENSION_ORIGINAL),
            ("medium", self.MAX_DIMENSION_MEDIUM),
            ("thumb", self.MAX_DIMENSION_THUMB),
        ):
            copia = img.copy()
            copia.thumbnail(
                (max_dim, max_dim), Image.Resampling.LANCZOS,
            )
            buf = io.BytesIO()
            copia.save(
                buf,
                format=self.OUTPUT_FORMAT,
                quality=self.OUTPUT_QUALITY,
                optimize=True,
            )
            variantes_bytes[nombre] = buf.getvalue()
            variantes_wh[nombre] = copia.size

        return variantes_bytes, variantes_wh

    # ---------------------------------------------------------------
    # Interfaz publica
    # ---------------------------------------------------------------
    async def save_foto(self, content: bytes) -> FotoProcesada:
        mime = self._validar(content)
        hash_hex = hashlib.sha256(content).hexdigest()
        storage_key = self.storage_key_para_hash(hash_hex)
        carpeta = self._carpeta(storage_key)

        logger.info(
            f"Foto recibida: hash={hash_hex[:12]} mime={mime} "
            f"tamano={len(content)} bytes"
        )

        try:
            variantes_bytes, variantes_wh = self._procesar_variantes(content)
        except Exception as e:
            raise StorageError(f"Error procesando imagen: {e}") from e

        # Blurhash del thumb
        try:
            thumb_img = Image.open(io.BytesIO(variantes_bytes["thumb"]))
            blur = blurhash.encode(
                thumb_img, x_components=4, y_components=3,
            )
        except Exception as e:
            logger.warning(f"No se pudo calcular blurhash: {e}")
            blur = None

        # Escribir a disco
        try:
            carpeta.mkdir(parents=True, exist_ok=True)
            for nombre, data in variantes_bytes.items():
                (carpeta / f"{nombre}.jpg").write_bytes(data)
        except OSError as e:
            raise StorageError(f"Error escribiendo archivos: {e}") from e

        variantes_path = {
            nombre: f"{storage_key}/{nombre}.jpg"
            for nombre in variantes_bytes
        }

        return FotoProcesada(
            hash_sha256=hash_hex,
            storage_backend="local",
            storage_key=storage_key,
            variantes=variantes_path,
            variantes_meta={
                nombre: VarianteFoto(
                    ancho=w,
                    alto=h,
                    tamano_bytes=len(variantes_bytes[nombre]),
                )
                for nombre, (w, h) in variantes_wh.items()
            },
            ancho=variantes_wh["original"][0],
            alto=variantes_wh["original"][1],
            mime_type=mime,
            tamano_bytes=len(content),
            blurhash=blur,
            metadata_extra=None,
        )

    async def read_variante(self, storage_key: str, variante: str) -> bytes:
        if variante not in self.VARIANTES:
            raise StorageError(f"Variante '{variante}' no valida")
        path = self._carpeta(storage_key) / f"{variante}.jpg"
        if not path.exists():
            raise StorageError(
                f"No existe variante '{variante}' para {storage_key}"
            )
        try:
            return path.read_bytes()
        except OSError as e:
            raise StorageError(f"Error leyendo archivo: {e}") from e

    async def delete_foto(self, storage_key: str) -> None:
        carpeta = self._carpeta(storage_key)
        if not carpeta.exists():
            return
        try:
            for f in carpeta.iterdir():
                if f.is_file():
                    f.unlink()
            carpeta.rmdir()
            logger.info(f"Foto eliminada: {storage_key}")
        except OSError as e:
            logger.warning(f"Error borrando {carpeta}: {e}")
