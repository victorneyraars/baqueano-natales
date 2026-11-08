"""multi-tenant: es_super_admin + admin_prestadores

Revision ID: m1n2o3p4q5r6
Revises: e8f9a0b1c2d3
Create Date: 2026-11-08
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision: str = 'm1n2o3p4q5r6'
down_revision: Union[str, None] = 'e8f9a0b1c2d3'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # 1. Agregar columna es_super_admin a usuarios
    op.add_column(
        'usuarios',
        sa.Column('es_super_admin', sa.Boolean(), nullable=False, server_default=sa.text('false'))
    )

    # 2. Crear tabla admin_prestadores (relación N:N)
    op.create_table(
        'admin_prestadores',
        sa.Column('admin_id', postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column('prestador_id', postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(['admin_id'], ['usuarios.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['prestador_id'], ['prestadores.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('admin_id', 'prestador_id'),
    )
    op.create_index('ix_admin_prestadores_prestador_id', 'admin_prestadores', ['prestador_id'])
    op.create_index('ix_admin_prestadores_admin_id', 'admin_prestadores', ['admin_id'])

    # 3. Promover a victorneyraars@gmail.com como super admin
    op.execute("""
        UPDATE usuarios
        SET es_super_admin = TRUE
        WHERE email = 'victorneyraars@gmail.com'
    """)


def downgrade() -> None:
    op.drop_index('ix_admin_prestadores_admin_id', table_name='admin_prestadores')
    op.drop_index('ix_admin_prestadores_prestador_id', table_name='admin_prestadores')
    op.drop_table('admin_prestadores')
    op.drop_column('usuarios', 'es_super_admin')
