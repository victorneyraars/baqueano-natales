"""telemetria de APIs externas (api_usage_events)

Revision ID: f7e8d9c0b1a2
Revises: 96ba32d7100d
Create Date: 2026-10-22 02:00:00.000000
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = 'f7e8d9c0b1a2'
down_revision: Union[str, None] = '96ba32d7100d'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        'api_usage_events',
        sa.Column('id', sa.UUID(), nullable=False),
        sa.Column('api', sa.String(length=20), nullable=False),
        sa.Column('input_value', sa.String(length=50), nullable=False),
        sa.Column('was_cached', sa.Boolean(), nullable=False),
        sa.Column('remaining', sa.Integer(), nullable=True),
        sa.Column('api_limit', sa.Integer(), nullable=True),
        sa.Column('reset_seconds', sa.Integer(), nullable=True),
        sa.Column('duration_ms', sa.Integer(), nullable=True),
        sa.Column('error_message', sa.String(length=255), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index('ix_api_usage_events_api', 'api_usage_events', ['api'], unique=False)
    op.create_index('ix_api_usage_events_created_at', 'api_usage_events', ['created_at'], unique=False)


def downgrade() -> None:
    op.drop_index('ix_api_usage_events_created_at', table_name='api_usage_events')
    op.drop_index('ix_api_usage_events_api', table_name='api_usage_events')
    op.drop_table('api_usage_events')
