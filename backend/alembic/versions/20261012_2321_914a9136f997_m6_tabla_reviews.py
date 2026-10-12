"""M6: tabla reviews

Revision ID: 914a9136f997
Revises: a1b2c3d4e5f6
Create Date: 2026-10-12 23:21:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = "914a9136f997"
down_revision: Union[str, None] = "a1b2c3d4e5f6"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "reviews",
        sa.Column("id", sa.UUID(), nullable=False),
        sa.Column("prestador_id", sa.UUID(), nullable=False),
        sa.Column("cliente_id", sa.UUID(), nullable=False),
        sa.Column(
            "orden_id",
            sa.UUID(),
            nullable=False,
            comment="Una sola review por orden (UNIQUE)",
        ),
        sa.Column(
            "rating",
            sa.Integer(),
            nullable=False,
            comment="1 a 5 estrellas",
        ),
        sa.Column("comentario", sa.Text(), nullable=True),
        sa.Column("respuesta_prestador", sa.Text(), nullable=True),
        sa.Column(
            "respuesta_en",
            sa.DateTime(timezone=True),
            nullable=True,
        ),
        sa.Column("created_at", sa.DateTime(timezone=True),
                  server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True),
                  server_default=sa.text("now()"), nullable=False),
        sa.Column("activo", sa.Boolean(), server_default="true",
                  nullable=False),
        sa.CheckConstraint(
            "rating >= 1 AND rating <= 5",
            name="ck_review_rating",
        ),
        sa.ForeignKeyConstraint(
            ["cliente_id"], ["usuarios.id"], ondelete="RESTRICT"
        ),
        sa.ForeignKeyConstraint(
            ["orden_id"], ["ordenes_trabajo.id"], ondelete="CASCADE"
        ),
        sa.ForeignKeyConstraint(
            ["prestador_id"], ["prestadores.id"], ondelete="CASCADE"
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("orden_id", name="uq_review_orden"),
    )
    op.create_index(
        op.f("ix_reviews_cliente_id"),
        "reviews",
        ["cliente_id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_reviews_orden_id"),
        "reviews",
        ["orden_id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_reviews_prestador_id"),
        "reviews",
        ["prestador_id"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index(op.f("ix_reviews_prestador_id"), table_name="reviews")
    op.drop_index(op.f("ix_reviews_orden_id"), table_name="reviews")
    op.drop_index(op.f("ix_reviews_cliente_id"), table_name="reviews")
    op.drop_table("reviews")
