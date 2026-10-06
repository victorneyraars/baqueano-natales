"""
Interfaz abstracta para almacenamiento de archivos.
Permite cambiar la implementación (local → S3 → Firebase Storage) sin
modificar el código que la usa.
"""
from abc import ABC, abstractmethod


class StorageError(Exception):
    """Error genérico de almacenamiento."""

    pass


class FileTooLargeError(StorageError):
    """El archivo excede el tamaño máximo permitido."""

    pass


class InvalidFileTypeError(StorageError):
    """El tipo de archivo no está permitido."""

    pass


class AvatarStorage(ABC):
    """
    Interfaz para almacenamiento de avatares.

    Implementaciones posibles:
    - LocalAvatarStorage (filesystem local)
    - S3AvatarStorage (AWS S3, Backblaze B2, DigitalOcean Spaces)
    - FirebaseStorageAvatar (Firebase Storage)
    - CloudinaryAvatar (CDN de imágenes)
    """

    # Constantes compartidas
    MAX_SIZE_BYTES: int = 5 * 1024 * 1024  # 5 MB
    ALLOWED_MIME_TYPES: set[str] = {
        "image/jpeg",
        "image/png",
        "image/webp",
    }
    MAX_DIMENSION: int = 512  # px (lado máximo)
    OUTPUT_FORMAT: str = "JPEG"
    OUTPUT_QUALITY: int = 85

    @abstractmethod
    async def save_avatar(self, user_id: str, content: bytes) -> str:
        """
        Guarda un avatar y devuelve la URL/path para accederlo.

        Args:
            user_id: UUID del usuario (para nombrar el archivo).
            content: Bytes del archivo (ya validado).

        Returns:
            Ruta o URL para acceder al avatar.

        Raises:
            StorageError: si falla el guardado.
        """
        ...

    @abstractmethod
    async def delete_avatar(self, user_id: str) -> None:
        """
        Elimina el avatar de un usuario (si existe).

        Args:
            user_id: UUID del usuario.
        """
        ...

    @abstractmethod
    def get_avatar_url(self, user_id: str) -> str:
        """
        Devuelve la URL/path del avatar de un usuario.

        Args:
            user_id: UUID del usuario.

        Returns:
            URL o path del avatar.
        """
        ...
