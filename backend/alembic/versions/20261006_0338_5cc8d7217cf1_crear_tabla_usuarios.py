"""crear tabla usuarios

Revision ID: 5cc8d7217cf1
Revises:
Create Date: 2026-10-06 03:38:58.860294

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


# revision identifiers, used by Alembic.
revision: str = '5cc8d7217cf1'
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # 1) Crear el tipo ENUM primero (con valores en minúscula, como el modelo)
    rol_usuario_enum = postgresql.ENUM(
        'cliente',
        'comercio',
        'prestador',
        'admin',
        name='rol_usuario',
        create_type=False,
    )
    rol_usuario_enum.create(op.get_bind(), checkfirst=True)

    # 2) Crear la tabla
    op.create_table(
        'usuarios',
        sa.Column('id', postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column('firebase_uid', sa.String(length=128), nullable=False),
        sa.Column('email', sa.String(length=255), nullable=True),
        sa.Column('phone', sa.String(length=20), nullable=True),
        sa.Column('nombre', sa.String(length=100), nullable=True),
        sa.Column('apellido', sa.String(length=100), nullable=True),
        sa.Column('avatar_url', sa.String(length=500), nullable=True),
        sa.Column(
            'rol',
            postgresql.ENUM(
                'cliente', 'comercio', 'prestador', 'admin',
                name='rol_usuario',
                create_type=False,
            ),
            nullable=False,
            server_default='cliente',
        ),
        sa.Column('verificado', sa.Boolean(), nullable=False, server_default=sa.text('false')),
        sa.Column('activo', sa.Boolean(), nullable=False, server_default=sa.text('true')),
        sa.Column('tiene_google', sa.Boolean(), nullable=False, server_default=sa.text('false')),
        sa.Column('tiene_whatsapp', sa.Boolean(), nullable=False, server_default=sa.text('false')),
        sa.Column('tiene_sms', sa.Boolean(), nullable=False, server_default=sa.text('false')),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.Column('ultimo_login', sa.DateTime(timezone=True), nullable=True),
        sa.PrimaryKeyConstraint('id'),
    )

    # 3) Índices
    op.create_index(op.f('ix_usuarios_email'), 'usuarios', ['email'], unique=True)
    op.create_index(op.f('ix_usuarios_firebase_uid'), 'usuarios', ['firebase_uid'], unique=True)
    op.create_index(op.f('ix_usuarios_phone'), 'usuarios', ['phone'], unique=True)
    op.create_index(op.f('ix_usuarios_rol'), 'usuarios', ['rol'], unique=False)


def downgrade() -> None:
    # 1) Índices
    op.drop_index(op.f('ix_usuarios_rol'), table_name='usuarios')
    op.drop_index(op.f('ix_usuarios_phone'), table_name='usuarios')
    op.drop_index(op.f('ix_usuarios_firebase_uid'), table_name='usuarios')
    op.drop_index(op.f('ix_usuarios_email'), table_name='usuarios')

    # 2) Tabla
    op.drop_table('usuarios')

    # 3) ENUM al final (después de la tabla que lo usa)
    rol_usuario_enum = postgresql.ENUM(
        'cliente', 'comercio', 'prestador', 'admin',
        name='rol_usuario',
    )
    rol_usuario_enum.drop(op.get_bind(), checkfirst=True)
