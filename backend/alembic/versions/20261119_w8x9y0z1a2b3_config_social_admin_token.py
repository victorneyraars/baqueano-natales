"""config_social: agregar facebook_admin_token y facebook_admin_token_updated_at

Revision ID: w8x9y0z1a2b3
Revises: v7w8x9y0z1a2
Create Date: 2026-11-19
"""
from alembic import op

revision = "w8x9y0z1a2b3"
down_revision = "v7w8x9y0z1a2"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute(
        """
        ALTER TABLE config_social
          ADD COLUMN IF NOT EXISTS facebook_admin_token text,
          ADD COLUMN IF NOT EXISTS facebook_admin_token_updated_at timestamp with time zone;
        """
    )


def downgrade() -> None:
    op.execute(
        """
        ALTER TABLE config_social
          DROP COLUMN IF EXISTS facebook_admin_token_updated_at,
          DROP COLUMN IF EXISTS facebook_admin_token;
        """
    )
