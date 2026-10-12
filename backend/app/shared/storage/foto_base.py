"""Interfaz abstracta para almacenamiento de fotos de ordenes.

Mismo patron que AvatarStorage: ABC + impl local, con forward compat
para S3/R2 cambiando solo la implementacion.

Diferencia clave con avatares:
- Content-addressable: el nombre del archivo es el SHA-256 del contenido.
- Variantes: original (2048px), medium (1024px), thumb (256px).
- Blurhash calculado del thumb.
- Privacidad: NO se sirve por nginx, se sirve via endpoint autenticado.
"""
from abc import ABC, abstractmethod
from dataclasses import dataclass

# Reusar las excepciones del modulo base (una sola fuente de verdad).
# Si se duplican aca, `except StorageError` en los services no captura.
from app.shared.storage.base import (
    FileTooLargeError,
    InvalidFileTypeError,
    StorageError,
)

__all__ = [
    "FileTooLargeError",
    "FotoProcesada",
    "FotoStorage",
    "InvalidFileTypeError",
    "StorageError",
    "VarianteFoto",
]


@dataclass(frozen=True)
class VarianteFoto:
    """Metadata de una variante generada."""

    ancho: int
    alto: int
    tamano_bytes: int


@dataclass(frozen=True)
class FotoProcesada:
    """Resultado de procesar y guardar una foto."""

    hash_sha256: str
    storage_backend: str
    storage_key: str
    variantes: dict[str, str]
    variantes_meta: dict[str, VarianteFoto]
    ancho: int
    alto: int
    mime_type: str
    tamano_bytes: int
    blurhash: str | None
    metadata_extra: dict | None


class FotoStorage(ABC):
    """Interfaz para almacenamiento de fotos de ordenes."""

    MAX_SIZE_BYTES: int = 15 * 1024 * 1024  # 15 MB
    ALLOWED_MIME_TYPES: set[str] = {
        "image/jpeg",
        "image/png",
        "image/webp",
    }
    VARIANTES: tuple[str, ...] = ("original", "medium", "thumb")
    MAX_DIMENSION_ORIGINAL: int = 2048
    MAX_DIMENSION_MEDIUM: int = 1024
    MAX_DIMENSION_THUMB: int = 256
    OUTPUT_FORMAT: str = "JPEG"
    OUTPUT_QUALITY: int = 85

    @staticmethod
    def storage_key_para_hash(hash_hex: str) -> str:
        """Layout content-addressable: ordenes/ab/cd/<hash>."""
        return f"ordenes/{hash_hex[:2]}/{hash_hex[2:4]}/{hash_hex}"

    @abstractmethod
    async def save_foto(self, content: bytes) -> FotoProcesada:
        """Procesa y guarda una foto, devolviendo su metadata."""

    @abstractmethod
    async def read_variante(self, storage_key: str, variante: str) -> bytes:
        """Devuelve los bytes de una variante especifica."""

    @abstractmethod
    async def delete_foto(self, storage_key: str) -> None:
        """Elimina todas las variantes de una foto."""
