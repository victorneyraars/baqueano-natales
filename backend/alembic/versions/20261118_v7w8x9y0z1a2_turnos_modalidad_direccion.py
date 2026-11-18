"""turnos: agregar modalidad, direccion_atencion y metadata_extra

Revision ID: v7w8x9y0z1a2
Revises: u6v7w8x9y0a
Create Date: 2026-11-18
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision = "v7w8x9y0z1a2"
down_revision = "u6v7w8x9y0a"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "turnos",
        sa.Column("modalidad", sa.String(length=30), nullable=False, server_default="domicilio"),
    )
    op.add_column(
        "turnos",
        sa.Column("direccion_atencion", sa.String(length=500), nullable=True),
    )
    op.add_column(
        "turnos",
        sa.Column("metadata_extra", postgresql.JSONB(astext_type=sa.Text()), nullable=True),
    )
    op.create_index("ix_turnos_modalidad", "turnos", ["modalidad"], unique=False)


def downgrade() -> None:
    op.drop_index("ix_turnos_modalidad", table_name="turnos")
    op.drop_column("turnos", "metadata_extra")
    op.drop_column("turnos", "direccion_atencion")
    op.drop_column("turnos", "modalidad")
