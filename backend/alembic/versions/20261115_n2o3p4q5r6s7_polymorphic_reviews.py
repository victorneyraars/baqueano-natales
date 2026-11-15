"""Add polymorphic fields to reviews for ecosystem-wide scalability.

Revision ID: n2o3p4q5r6s7
Revises: m1n2o3p4q5r6
Create Date: 2026-11-15
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import UUID

revision = 'n2o3p4q5r6s7'
down_revision = 'm1n2o3p4q5r6'
branch_labels = None
depends_on = None


def upgrade() -> None:
    # 1. Add entidad_tipo (default 'orden' for existing reviews)
    op.add_column(
        'reviews',
        sa.Column('entidad_tipo', sa.String(30), nullable=False, server_default='orden')
    )

    # 2. Add entidad_id (nullable to allow backfill)
    op.add_column(
        'reviews',
        sa.Column('entidad_id', UUID(as_uuid=True), nullable=True)
    )

    # 3. Backfill: for existing reviews, entidad_id = orden_id
    op.execute("UPDATE reviews SET entidad_id = orden_id WHERE entidad_id IS NULL")

    # 4. Make entidad_id NOT NULL (all rows now have it)
    op.alter_column('reviews', 'entidad_id', existing_type=UUID(as_uuid=True), nullable=False)

    # 5. Make orden_id nullable (polymorphic reviews may not be tied to an orden)
    op.alter_column('reviews', 'orden_id', existing_type=UUID(as_uuid=True), nullable=True)

    # 6. Drop old unique on orden_id (superseded by entidad-based unique)
    op.execute("ALTER TABLE reviews DROP CONSTRAINT IF EXISTS uq_review_orden")

    # 7. New unique: one review per (entidad_tipo, entidad_id, cliente_id)
    op.create_unique_constraint(
        'uq_review_entidad_cliente',
        'reviews',
        ['entidad_tipo', 'entidad_id', 'cliente_id'],
    )

    # 8. Index for fast lookups by entity
    op.create_index(
        'ix_reviews_entidad',
        'reviews',
        ['entidad_tipo', 'entidad_id'],
    )


def downgrade() -> None:
    op.drop_index('ix_reviews_entidad', table_name='reviews')
    op.drop_constraint('uq_review_entidad_cliente', 'reviews', type_='unique')
    op.create_unique_constraint('uq_review_orden', 'reviews', ['orden_id'])
    op.alter_column('reviews', 'orden_id', existing_type=UUID(as_uuid=True), nullable=False)
    op.alter_column('reviews', 'entidad_id', existing_type=UUID(as_uuid=True), nullable=True)
    op.drop_column('reviews', 'entidad_id')
    op.drop_column('reviews', 'entidad_tipo')
