"""turnos: agregar otp_expires_at, otp_intentos, email_verificado_at

Revision ID: u6v7w8x9y0a
Revises: t5u6v7w8x9y0
Create Date: 2026-11-15
"""

from alembic import op
import sqlalchemy as sa

revision = "u6v7w8x9y0a"
down_revision = "t5u6v7w8x9y0"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("turnos", sa.Column("otp_expires_at", sa.DateTime(timezone=True), nullable=True))
    op.add_column("turnos", sa.Column("otp_intentos", sa.Integer(), nullable=False, server_default=sa.text("0")))
    op.add_column("turnos", sa.Column("email_verificado_at", sa.DateTime(timezone=True), nullable=True))


def downgrade() -> None:
    op.drop_column("turnos", "email_verificado_at")
    op.drop_column("turnos", "otp_intentos")
    op.drop_column("turnos", "otp_expires_at")
