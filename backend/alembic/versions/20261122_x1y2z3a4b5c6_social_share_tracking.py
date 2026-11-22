"""social share tracking

Revision ID: x1y2z3a4b5c6
Revises: w8x9y0z1a2b3
Create Date: 2026-11-22 14:00:00.000000
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision = "x1y2z3a4b5c6"
down_revision = "w8x9y0z1a2b3"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "social_share_tracking",
        sa.Column("id", postgresql.UUID(as_uuid=True), server_default=sa.text("gen_random_uuid()"), nullable=False),
        sa.Column("share_id", sa.String(length=64), nullable=False),
        sa.Column("publicacion_id", postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column("red", sa.String(length=32), server_default="facebook", nullable=False),
        sa.Column("grupo_nombre", sa.String(length=160), nullable=False),
        sa.Column("grupo_slug", sa.String(length=120), nullable=False),
        sa.Column("url_compartida", sa.Text(), nullable=False),
        sa.Column("estado_reportado", sa.String(length=32), server_default="pendiente_confirmacion", nullable=False),
        sa.Column("confirmado_en", sa.DateTime(timezone=True), nullable=True),
        sa.Column("visitas", sa.Integer(), server_default="0", nullable=False),
        sa.Column("clics_whatsapp", sa.Integer(), server_default="0", nullable=False),
        sa.Column("reservas_iniciadas", sa.Integer(), server_default="0", nullable=False),
        sa.Column("reservas_enviadas", sa.Integer(), server_default="0", nullable=False),
        sa.Column("ultima_interaccion_en", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_social_share_tracking_share_id", "social_share_tracking", ["share_id"], unique=True)
    op.create_index("ix_social_share_tracking_publicacion_id", "social_share_tracking", ["publicacion_id"], unique=False)
    op.create_index("ix_social_share_tracking_grupo_slug", "social_share_tracking", ["grupo_slug"], unique=False)


def downgrade() -> None:
    op.drop_index("ix_social_share_tracking_grupo_slug", table_name="social_share_tracking")
    op.drop_index("ix_social_share_tracking_publicacion_id", table_name="social_share_tracking")
    op.drop_index("ix_social_share_tracking_share_id", table_name="social_share_tracking")
    op.drop_table("social_share_tracking")
