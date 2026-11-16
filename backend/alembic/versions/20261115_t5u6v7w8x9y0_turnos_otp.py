"""turnos: agregar campos para solicitud publica via landing

Revision ID: t5u6v7w8x9y0
Revises: n2o3p4q5r6s7
Create Date: 2026-11-15
"""

from alembic import op
import sqlalchemy as sa

revision = "t5u6v7w8x9y0"
down_revision = "n2o3p4q5r6s7"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("turnos", sa.Column("otp_code", sa.String(10), nullable=True))
    op.add_column("turnos", sa.Column("email_verificado", sa.Boolean(), nullable=False, server_default="false"))
    op.add_column("turnos", sa.Column("email_cliente", sa.String(255), nullable=True))
    op.add_column("turnos", sa.Column("nombre_cliente", sa.String(255), nullable=True))
    op.add_column("turnos", sa.Column("telefono_cliente", sa.String(50), nullable=True))
    op.create_index("ix_turnos_otp_code", "turnos", ["otp_code"])


def downgrade() -> None:
    op.drop_index("ix_turnos_otp_code", "turnos")
    op.drop_column("turnos", "telefono_cliente")
    op.drop_column("turnos", "nombre_cliente")
    op.drop_column("turnos", "email_cliente")
    op.drop_column("turnos", "email_verificado")
    op.drop_column("turnos", "otp_code")
