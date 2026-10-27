"""add rentacar tables (manual)

Revision ID: manual_rentacar_001
Revises: f7e8d9c0b1a2
Create Date: 2026-10-27 12:00:00

Nota: creada manualmente porque autogenerate detectó schema drift en
tablas pre-existentes (media_assets, social_posts, configuraciones)
que NO deben tocarse en esta migración.
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision = 'manual_rentacar_001'
down_revision = 'f7e8d9c0b1a2'
branch_labels = None
depends_on = None


def upgrade() -> None:
    # 1. rentacar_config
    op.create_table(
        'rentacar_config',
        sa.Column('id', postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column('prestador_id', postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column('metodos_pago', postgresql.JSONB(astext_type=sa.Text()), nullable=False),
        sa.Column('deposito', postgresql.JSONB(astext_type=sa.Text()), nullable=False),
        sa.Column('conductor_adicional', postgresql.JSONB(astext_type=sa.Text()), nullable=False),
        sa.Column('categorias', postgresql.JSONB(astext_type=sa.Text()), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.ForeignKeyConstraint(['prestador_id'], ['prestadores.id']),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('prestador_id'),
    )
    op.create_index('ix_rentacar_config_prestador_id', 'rentacar_config', ['prestador_id'])

    # 2. rentacar_vehiculos
    op.create_table(
        'rentacar_vehiculos',
        sa.Column('id', postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column('prestador_id', postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column('patente', sa.String(10), nullable=False),
        sa.Column('marca', sa.String(50), nullable=False),
        sa.Column('modelo', sa.String(50), nullable=False),
        sa.Column('anio', sa.Integer(), nullable=False),
        sa.Column('categoria', sa.String(50), nullable=False),
        sa.Column('precio_dia', sa.Numeric(10, 2), nullable=False),
        sa.Column('disponible', sa.Boolean(), nullable=False, server_default=sa.text('true')),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.ForeignKeyConstraint(['prestador_id'], ['prestadores.id']),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('patente'),
    )
    op.create_index('ix_rentacar_vehiculos_patente', 'rentacar_vehiculos', ['patente'])
    op.create_index('ix_rentacar_vehiculos_prestador_id', 'rentacar_vehiculos', ['prestador_id'])

    # 3. rentacar_reservas
    op.create_table(
        'rentacar_reservas',
        sa.Column('id', postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column('vehiculo_id', postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column('cliente_id', postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column('fecha_inicio', sa.DateTime(timezone=True), nullable=False),
        sa.Column('fecha_fin', sa.DateTime(timezone=True), nullable=False),
        sa.Column('metodo_pago', sa.String(50), nullable=False),
        sa.Column('precio_total', sa.Numeric(10, 2), nullable=False),
        sa.Column('estado', sa.String(20), nullable=False, server_default='pendiente'),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.ForeignKeyConstraint(['vehiculo_id'], ['rentacar_vehiculos.id']),
        sa.ForeignKeyConstraint(['cliente_id'], ['usuarios.id']),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index('ix_rentacar_reservas_vehiculo_id', 'rentacar_reservas', ['vehiculo_id'])
    op.create_index('ix_rentacar_reservas_cliente_id', 'rentacar_reservas', ['cliente_id'])


def downgrade() -> None:
    op.drop_table('rentacar_reservas')
    op.drop_table('rentacar_vehiculos')
    op.drop_table('rentacar_config')
