"""crear tabla documentos_firma (modulo documents)

Revision ID: e8f9a0b1c2d3
Revises: c7b6a5d4e3f2
Create Date: 2026-11-07 21:00:00.000000

"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa
import sqlalchemy.dialects.postgresql as pg

# revision identifiers, used by Alembic.
revision: str = 'e8f9a0b1c2d3'
down_revision: Union[str, None] = 'c7b6a5d4e3f2'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Crea la tabla documentos_firma para el modulo de firma digital."""
    op.create_table(
        'documentos_firma',
        sa.Column('id', pg.UUID(as_uuid=True), primary_key=True),
        sa.Column('token', sa.String(100), unique=True, nullable=False, index=True),
        sa.Column('tenant_id', pg.UUID(as_uuid=True), nullable=True, index=True),
        sa.Column('tipo', sa.String(50), nullable=False),
        sa.Column('payload', sa.JSON, nullable=False),
        sa.Column('estado', sa.String(20), nullable=False, server_default='pendiente'),
        sa.Column('firmado_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('ip_firma', sa.String(50), nullable=True),
        sa.Column('firma_base64', sa.Text, nullable=True),
    )


def downgrade() -> None:
    op.drop_table('documentos_firma')
