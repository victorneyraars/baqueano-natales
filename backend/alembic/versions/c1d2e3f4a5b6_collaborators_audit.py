"""collaborators + prestador audit log

Revision ID: c1d2e3f4a5b6
Revises: b1c2d3e4f5a6
Create Date: 2026-10-31 04:30:00.000000

Agrega:
- prestadores.colaboradores JSONB (default [])
- tabla prestadores_audit_log (append-only, 12 meses retencion)
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


revision: str = 'c1d2e3f4a5b6'
down_revision: Union[str, None] = 'b1c2d3e4f5a6'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # 1) Colaboradores del prestador (JSONB array)
    op.add_column(
        'prestadores',
        sa.Column(
            'colaboradores',
            postgresql.JSONB(astext_type=sa.Text()),
            nullable=False,
            server_default=sa.text("'[]'::jsonb"),
        ),
    )

    # 2) Audit log append-only
    op.create_table(
        'prestadores_audit_log',
        sa.Column('id', sa.UUID(), nullable=False),
        sa.Column('prestador_id', sa.UUID(), nullable=False),
        sa.Column('user_id', sa.UUID(), nullable=True),
        sa.Column('user_email', sa.String(length=255), nullable=False),
        sa.Column('accion', sa.String(length=50), nullable=False),
        sa.Column('entidad', sa.String(length=50), nullable=False),
        sa.Column('entidad_id', sa.String(length=100), nullable=True),
        sa.Column(
            'metadata',
            postgresql.JSONB(astext_type=sa.Text()),
            nullable=False,
            server_default=sa.text("'{}'::jsonb"),
        ),
        sa.Column('ip', sa.String(length=45), nullable=True),
        sa.Column('user_agent', sa.String(length=500), nullable=True),
        sa.Column(
            'created_at',
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(
            ['prestador_id'], ['prestadores.id'], ondelete='CASCADE',
        ),
        sa.ForeignKeyConstraint(
            ['user_id'], ['usuarios.id'], ondelete='SET NULL',
        ),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index(
        'ix_audit_prestador_created',
        'prestadores_audit_log',
        ['prestador_id', 'created_at'],
    )
    op.create_index(
        'ix_audit_accion_created',
        'prestadores_audit_log',
        ['accion', 'created_at'],
    )
    op.create_index(
        'ix_audit_user_id',
        'prestadores_audit_log',
        ['user_id'],
    )


def downgrade() -> None:
    op.drop_index('ix_audit_user_id', table_name='prestadores_audit_log')
    op.drop_index('ix_audit_accion_created', table_name='prestadores_audit_log')
    op.drop_index(
        'ix_audit_prestador_created', table_name='prestadores_audit_log',
    )
    op.drop_table('prestadores_audit_log')
    op.drop_column('prestadores', 'colaboradores')
