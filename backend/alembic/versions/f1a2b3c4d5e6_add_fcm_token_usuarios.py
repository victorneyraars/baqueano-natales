"""add fcm_token to usuarios

Revision ID: f1a2b3c4d5e6
Revises: de89315a2610
Create Date: 2026-10-12

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = "f1a2b3c4d5e6"
down_revision: Union[str, None] = "de89315a2610"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "usuarios",
        sa.Column("fcm_token", sa.String(length=500), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("usuarios", "fcm_token")
