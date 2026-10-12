"""Storage abstracto del proyecto (avatares + fotos)."""
from app.shared.storage.base import (
    AvatarStorage,
    FileTooLargeError,
    InvalidFileTypeError,
    StorageError,
)
from app.shared.storage.foto_base import (
    FotoProcesada,
    FotoStorage,
    VarianteFoto,
)
from app.shared.storage.foto_local import LocalFotoStorage
from app.shared.storage.local import LocalAvatarStorage

__all__ = [
    "AvatarStorage",
    "FileTooLargeError",
    "FotoProcesada",
    "FotoStorage",
    "InvalidFileTypeError",
    "LocalAvatarStorage",
    "LocalFotoStorage",
    "StorageError",
    "VarianteFoto",
]
