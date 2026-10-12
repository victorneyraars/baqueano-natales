"""add rate_limit_config

Revision ID: b9c0d1e2f3a4
Revises: a8b9c0d1e2f3
Create Date: 2026-10-12

Rate limiting por tipo de notificacion (anti-fatiga del usuario).
"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "b9c0d1e2f3a4"
down_revision: Union[str, None] = "a8b9c0d1e2f3"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "rate_limit_config",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("tipo", sa.String(20), nullable=False, unique=True),
        sa.Column("max_por_hora", sa.Integer(), nullable=True),
        sa.Column("max_por_dia", sa.Integer(), nullable=True),
        sa.Column("max_por_semana", sa.Integer(), nullable=True),
        sa.Column("min_intervalo_seg", sa.Integer(), nullable=True),
        sa.Column("strict", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
    )
    op.create_index("ix_rate_limit_config_tipo", "rate_limit_config", ["tipo"])

    # Seed con defaults sensatos
    op.execute("""
        INSERT INTO rate_limit_config (id, tipo, max_por_hora, max_por_dia, max_por_semana, min_intervalo_seg, strict)
        VALUES
            (gen_random_uuid(), 'sistema',       NULL, NULL, NULL, NULL, false),
            (gen_random_uuid(), 'confirmaciones', NULL, NULL, NULL, NULL, false),
            (gen_random_uuid(), 'recordatorio',   2,    3,    7,    3600, false),
            (gen_random_uuid(), 'promocion',      1,    1,    2,    NULL, false),
            (gen_random_uuid(), 'campana',        1,    1,    3,    NULL, false)
    """)


def downgrade() -> None:
    op.drop_table("rate_limit_config")
