"""rentacar: cliente_id nullable + datos contacto invitado

Revision ID: manual_rentacar_002
Revises: manual_rentacar_001
Create Date: 2026-10-27 16:00:00
"""
from alembic import op
import sqlalchemy as sa

revision = 'manual_rentacar_002'
down_revision = 'manual_rentacar_001'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.alter_column(
        'rentacar_reservas', 'cliente_id',
        existing_type=sa.dialects.postgresql.UUID(as_uuid=True),
        nullable=True,
    )
    op.add_column('rentacar_reservas', sa.Column('nombre_cliente', sa.String(150), nullable=True))
    op.add_column('rentacar_reservas', sa.Column('email_cliente', sa.String(255), nullable=True))
    op.add_column('rentacar_reservas', sa.Column('telefono_cliente', sa.String(20), nullable=True))


def downgrade() -> None:
    op.drop_column('rentacar_reservas', 'telefono_cliente')
    op.drop_column('rentacar_reservas', 'email_cliente')
    op.drop_column('rentacar_reservas', 'nombre_cliente')
    op.alter_column(
        'rentacar_reservas', 'cliente_id',
        existing_type=sa.dialects.postgresql.UUID(as_uuid=True),
        nullable=False,
    )
