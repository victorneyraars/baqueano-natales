"""agregar servicio_id a turnos

Revision ID: a1b2c3d4e5f6
Revises: d2e3f4a5b6c7
Create Date: 2026-11-07 18:00:00.000000

"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa
import sqlalchemy.dialects.postgresql as pg

# revision identifiers, used by Alembic.
revision: str = 'a1b2c3d4e5f6'
down_revision: Union[str, None] = 'd2e3f4a5b6c7'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Agregar columna servicio_id a la tabla turnos
    op.add_column('turnos', sa.Column('servicio_id', pg.UUID(as_uuid=True), nullable=True))


def downgrade() -> None:
    op.drop_column('turnos', 'servicio_id')
