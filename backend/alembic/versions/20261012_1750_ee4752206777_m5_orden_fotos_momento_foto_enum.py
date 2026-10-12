"""M5: orden_fotos + momento_foto enum

Revision ID: ee4752206777
Revises: b9c0d1e2f3a4
Create Date: 2026-10-12 17:50:40.311767

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = "ee4752206777"
down_revision: Union[str, None] = "b9c0d1e2f3a4"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "orden_fotos",
        sa.Column("id", sa.UUID(), nullable=False),
        sa.Column("orden_id", sa.UUID(), nullable=False),
        sa.Column(
            "item_id",
            sa.UUID(),
            nullable=True,
            comment="Item del presupuesto al que se asocia (opcional)",
        ),
        sa.Column(
            "momento",
            sa.Enum(
                "ingreso",
                "diagnostico",
                "en_proceso",
                "entrega",
                "reclamo",
                "otro",
                name="momento_foto",
            ),
            server_default="otro",
            nullable=False,
        ),
        sa.Column("subido_por_id", sa.UUID(), nullable=False),
        sa.Column(
            "subido_por_rol",
            sa.String(length=20),
            nullable=False,
            comment="Snapshot del rol al subir: cliente|prestador|admin",
        ),
        sa.Column(
            "hash_sha256",
            sa.String(length=64),
            nullable=False,
            comment="SHA-256 hex del contenido original",
        ),
        sa.Column(
            "storage_backend",
            sa.String(length=20),
            server_default="local",
            nullable=False,
            comment="local|s3|r2|...",
        ),
        sa.Column(
            "storage_key",
            sa.String(length=500),
            nullable=False,
            comment="Prefijo de las variantes: ordenes/ab/cd/<hash>",
        ),
        sa.Column(
            "variantes",
            postgresql.JSONB(astext_type=sa.Text()),
            nullable=False,
            comment='{"original": "...", "medium": "...", "thumb": "..."}',
        ),
        sa.Column("mime_type", sa.String(length=50), nullable=False),
        sa.Column("tamano_bytes", sa.Integer(), nullable=False),
        sa.Column("ancho", sa.Integer(), nullable=False),
        sa.Column("alto", sa.Integer(), nullable=False),
        sa.Column("blurhash", sa.String(length=100), nullable=True),
        sa.Column("descripcion", sa.String(length=255), nullable=True),
        sa.Column(
            "fecha_captura",
            sa.DateTime(timezone=True),
            nullable=True,
            comment="Fecha EXIF de captura (si esta disponible)",
        ),
        sa.Column(
            "metadata_extra",
            postgresql.JSONB(astext_type=sa.Text()),
            nullable=True,
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column("activo", sa.Boolean(), server_default="true", nullable=False),
        sa.ForeignKeyConstraint(
            ["item_id"], ["orden_items.id"], ondelete="SET NULL"
        ),
        sa.ForeignKeyConstraint(
            ["orden_id"], ["ordenes_trabajo.id"], ondelete="CASCADE"
        ),
        sa.ForeignKeyConstraint(
            ["subido_por_id"], ["usuarios.id"], ondelete="RESTRICT"
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "storage_backend",
            "hash_sha256",
            name="uq_orden_foto_backend_hash",
        ),
    )
    op.create_index(
        "ix_orden_fotos_hash_backend",
        "orden_fotos",
        ["hash_sha256", "storage_backend"],
        unique=False,
    )
    op.create_index(
        op.f("ix_orden_fotos_hash_sha256"),
        "orden_fotos",
        ["hash_sha256"],
        unique=False,
    )
    op.create_index(
        op.f("ix_orden_fotos_item_id"),
        "orden_fotos",
        ["item_id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_orden_fotos_momento"),
        "orden_fotos",
        ["momento"],
        unique=False,
    )
    op.create_index(
        op.f("ix_orden_fotos_orden_id"),
        "orden_fotos",
        ["orden_id"],
        unique=False,
    )
    op.create_index(
        "ix_orden_fotos_orden_momento",
        "orden_fotos",
        ["orden_id", "momento"],
        unique=False,
    )
    op.create_index(
        op.f("ix_orden_fotos_subido_por_id"),
        "orden_fotos",
        ["subido_por_id"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index(
        op.f("ix_orden_fotos_subido_por_id"), table_name="orden_fotos"
    )
    op.drop_index("ix_orden_fotos_orden_momento", table_name="orden_fotos")
    op.drop_index(op.f("ix_orden_fotos_orden_id"), table_name="orden_fotos")
    op.drop_index(op.f("ix_orden_fotos_momento"), table_name="orden_fotos")
    op.drop_index(op.f("ix_orden_fotos_item_id"), table_name="orden_fotos")
    op.drop_index(
        op.f("ix_orden_fotos_hash_sha256"), table_name="orden_fotos"
    )
    op.drop_index("ix_orden_fotos_hash_backend", table_name="orden_fotos")
    op.drop_table("orden_fotos")
    sa.Enum(name="momento_foto").drop(op.get_bind(), checkfirst=True)
