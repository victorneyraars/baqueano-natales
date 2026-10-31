"""add OTP verification fields to rentacar_reservas

Revision ID: b1c2d3e4f5a6
Revises: prestador_perfil_negocio_001
Create Date: 2026-10-31 04:30:00.000000

Agrega 5 campos para verificacion OTP de email:
- email_verificado (bool, default False)
- email_verificado_at (datetime nullable)
- otp_code (varchar 6 nullable)
- otp_expires_at (datetime nullable)
- otp_intentos (int default 0)

Tambien hace opcional telefono_cliente (Guest-First: maxima conversion).
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = 'b1c2d3e4f5a6'
down_revision: Union[str, None] = 'prestador_perfil_negocio_001'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        'rentacar_reservas',
        sa.Column(
            'email_verificado',
            sa.Boolean(),
            nullable=False,
            server_default=sa.text('false'),
        ),
    )
    op.add_column(
        'rentacar_reservas',
        sa.Column('email_verificado_at', sa.DateTime(timezone=True), nullable=True),
    )
    op.add_column(
        'rentacar_reservas',
        sa.Column('otp_code', sa.String(length=6), nullable=True),
    )
    op.add_column(
        'rentacar_reservas',
        sa.Column('otp_expires_at', sa.DateTime(timezone=True), nullable=True),
    )
    op.add_column(
        'rentacar_reservas',
        sa.Column(
            'otp_intentos',
            sa.Integer(),
            nullable=False,
            server_default=sa.text('0'),
        ),
    )
    op.alter_column(
        'rentacar_reservas',
        'telefono_cliente',
        existing_type=sa.String(length=20),
        nullable=True,
    )


def downgrade() -> None:
    op.alter_column(
        'rentacar_reservas',
        'telefono_cliente',
        existing_type=sa.String(length=20),
        nullable=False,
    )
    op.drop_column('rentacar_reservas', 'otp_intentos')
    op.drop_column('rentacar_reservas', 'otp_expires_at')
    op.drop_column('rentacar_reservas', 'otp_code')
    op.drop_column('rentacar_reservas', 'email_verificado_at')
    op.drop_column('rentacar_reservas', 'email_verificado')
