"""prestadores: perfil_negocio JSONB + campos GBP/JSON-LD

Revision ID: prestador_perfil_negocio_001
Revises: manual_rentacar_003
Create Date: 2026-10-29 04:30:00
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import JSONB

revision = "prestador_perfil_negocio_001"
down_revision = "manual_rentacar_003"
branch_labels = None
depends_on = None

def upgrade() -> None:
    op.add_column(
        "prestadores",
        sa.Column("razon_social", sa.String(200), nullable=True),
    )
    op.add_column(
        "prestadores",
        sa.Column("rut_empresa", sa.String(20), nullable=True),
    )
    op.add_column(
        "prestadores",
        sa.Column("gbp_place_id", sa.String(150), nullable=True),
    )
    op.add_column(
        "prestadores",
        sa.Column("gbp_maps_url", sa.String(500), nullable=True),
    )
    op.add_column(
        "prestadores",
        sa.Column("precio_desde", sa.Numeric(12, 2), nullable=True),
    )
    op.add_column(
        "prestadores",
        sa.Column("brand_kit_slug", sa.String(50), nullable=True),
    )
    op.add_column(
        "prestadores",
        sa.Column("perfil_negocio", JSONB, nullable=True),
    )

def downgrade() -> None:
    op.drop_column("prestadores", "perfil_negocio")
    op.drop_column("prestadores", "brand_kit_slug")
    op.drop_column("prestadores", "precio_desde")
    op.drop_column("prestadores", "gbp_maps_url")
    op.drop_column("prestadores", "gbp_place_id")
    op.drop_column("prestadores", "rut_empresa")
    op.drop_column("prestadores", "razon_social")