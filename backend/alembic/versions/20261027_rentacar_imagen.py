"""rentacar: agregar imagen_url a vehiculos

Revision ID: manual_rentacar_003
Revises: manual_rentacar_002
Create Date: 2026-10-27 17:00:00
"""
from alembic import op
import sqlalchemy as sa

revision = 'manual_rentacar_003'
down_revision = 'manual_rentacar_002'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column('rentacar_vehiculos', sa.Column('imagen_url', sa.String(500), nullable=True))


def downgrade() -> None:
    op.drop_column('rentacar_vehiculos', 'imagen_url')
