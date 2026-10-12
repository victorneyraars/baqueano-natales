"""M5.1: drop unique constraint en orden_fotos

El constraint (storage_backend, hash_sha256) impedia subir la misma
imagen a dos ordenes distintas. El dedupe queda a nivel logico
(por orden) en el service.

Revision ID: a1b2c3d4e5f6
Revises: ee4752206777
Create Date: 2026-10-12 18:00:00

"""
from typing import Sequence, Union

from alembic import op


revision: str = "a1b2c3d4e5f6"
down_revision: Union[str, None] = "ee4752206777"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.drop_constraint(
        "uq_orden_foto_backend_hash", "orden_fotos", type_="unique"
    )


def downgrade() -> None:
    op.create_unique_constraint(
        "uq_orden_foto_backend_hash",
        "orden_fotos",
        ["storage_backend", "hash_sha256"],
    )
