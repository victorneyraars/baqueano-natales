"""agregar campos_extra a prestador_servicios

Revision ID: y2z3a4b5c6d7
Revises: x1y2z3a4b5c6
Create Date: 2026-11-25 19:55:00.000000
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision = "y2z3a4b5c6d7"
down_revision = "x1y2z3a4b5c6"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "prestador_servicios",
        sa.Column(
            "campos_extra",
            postgresql.JSONB(astext_type=sa.Text()),
            nullable=False,
            server_default=sa.text("'[]'::jsonb"),
            comment="Campos dinámicos clave/valor editables desde la app",
        ),
    )


def downgrade() -> None:
    op.drop_column("prestador_servicios", "campos_extra")
