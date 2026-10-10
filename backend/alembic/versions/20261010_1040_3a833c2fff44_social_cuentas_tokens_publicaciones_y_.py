"""social: cuentas, tokens, publicaciones y config

Revision ID: 3a833c2fff44
Revises: fc76f6b9a9ef
Create Date: 2026-10-10 10:40:19.629978

Migración del módulo social. Crea 4 tablas:
- cuentas_sociales
- tokens_sociales
- publicaciones_sociales
- config_social

Notas:
- Los enums `propietario_tipo_social` y `red_social` son creados por
  `cuentas_sociales` (el primero en usarlos). Las tablas posteriores los
  reutilizan con `create_type=False` en los modelos, y Alembic los maneja
  correctamente acá.
- Se removió el bloque de ALTER sobre `usuarios` que Alembic detectó
  automáticamente (diferencias de server_default ajenas a este cambio).
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = '3a833c2fff44'
down_revision: Union[str, None] = 'fc76f6b9a9ef'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        'config_social',
        sa.Column('id', sa.UUID(), nullable=False),
        sa.Column('propietario_tipo', sa.Enum(
            'baqueano', 'prestador', 'comercio',
            name='propietario_tipo_social',
        ), nullable=True),
        sa.Column('propietario_id', sa.UUID(), nullable=True),
        sa.Column(
            'auto_publish', sa.Boolean(),
            server_default='false', nullable=False,
            comment='Interruptor maestro. Si false, no se publica nada automático.',
        ),
        sa.Column('destino', sa.Enum(
            'central', 'propio', 'ambos',
            name='destino_publicacion',
        ), server_default='ambos', nullable=False),
        sa.Column('publicar_en_facebook', sa.Boolean(),
                  server_default='true', nullable=False),
        sa.Column('publicar_en_instagram', sa.Boolean(),
                  server_default='false', nullable=False),
        sa.Column('publicar_en_google', sa.Boolean(),
                  server_default='false', nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True),
                  server_default=sa.text('now()'), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True),
                  server_default=sa.text('now()'), nullable=False),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('propietario_tipo', 'propietario_id',
                            name='uq_config_social_propietario'),
    )

    op.create_table(
        'cuentas_sociales',
        sa.Column('id', sa.UUID(), nullable=False),
        sa.Column('propietario_tipo', sa.Enum(
            'baqueano', 'prestador', 'comercio',
            name='propietario_tipo_social',
        ), nullable=False),
        sa.Column('propietario_id', sa.UUID(), nullable=True,
                  comment='NULL = cuenta central de Baqueano Natales'),
        sa.Column('red', sa.Enum(
            'facebook', 'instagram', 'google_business',
            name='red_social',
        ), nullable=False),
        sa.Column('external_id', sa.String(length=150), nullable=False,
                  comment='ID en la red (page_id de FB, ig_user_id, location_id de Google)'),
        sa.Column('external_name', sa.String(length=255), nullable=True,
                  comment='Nombre visible en la red (para mostrar en admin)'),
        sa.Column('cuenta_padre_id', sa.UUID(), nullable=True,
                  comment='IG -> cuenta de FB que lo contiene (mismo token)'),
        sa.Column('auto_publish', sa.Boolean(),
                  server_default='false', nullable=False,
                  comment='Si true, se publican automáticamente los eventos configurados'),
        sa.Column('metadata_extra', postgresql.JSONB(astext_type=sa.Text()),
                  nullable=True,
                  comment='Datos extra de la red (categoría, seguidores, etc.)'),
        sa.Column('created_at', sa.DateTime(timezone=True),
                  server_default=sa.text('now()'), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True),
                  server_default=sa.text('now()'), nullable=False),
        sa.Column('activo', sa.Boolean(),
                  server_default='true', nullable=False),
        sa.ForeignKeyConstraint(['cuenta_padre_id'], ['cuentas_sociales.id'],
                                ondelete='SET NULL'),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('red', 'external_id',
                            name='uq_cuenta_social_red_ext'),
    )
    op.create_index('ix_cuenta_social_propietario', 'cuentas_sociales',
                    ['propietario_tipo', 'propietario_id'], unique=False)
    op.create_index(op.f('ix_cuentas_sociales_red'), 'cuentas_sociales',
                    ['red'], unique=False)

    op.create_table(
        'publicaciones_sociales',
        sa.Column('id', sa.UUID(), nullable=False),
        sa.Column('cuenta_id', sa.UUID(), nullable=False),
        sa.Column('recurso_tipo', sa.String(length=50), nullable=False,
                  comment="Ej: 'prestador_servicio', 'comercio_producto'"),
        sa.Column('recurso_id', sa.UUID(), nullable=False,
                  comment='UUID del recurso (prestador, servicio, producto, ...)'),
        sa.Column('red', sa.Enum(
            'facebook', 'instagram', 'google_business',
            name='red_social',
        ), nullable=False),
        sa.Column('contenido', postgresql.JSONB(astext_type=sa.Text()),
                  nullable=False,
                  comment="{'message': str, 'image_urls': [str], 'link': str}"),
        sa.Column('estado', sa.Enum(
            'pendiente', 'publicando', 'publicado', 'fallado', 'agotado',
            name='estado_publicacion',
        ), server_default='pendiente', nullable=False),
        sa.Column('intentos', sa.Integer(),
                  server_default='0', nullable=False),
        sa.Column('proximo_intento_en', sa.DateTime(timezone=True),
                  nullable=True,
                  comment='NULL si aún no se programó. Worker la usa para reintentos.'),
        sa.Column('external_post_id', sa.String(length=255), nullable=True,
                  comment='ID del post en la red (para correlacionar)'),
        sa.Column('error_ultimo', sa.Text(), nullable=True,
                  comment='Último error. Se sobreescribe en cada reintento.'),
        sa.Column('created_at', sa.DateTime(timezone=True),
                  server_default=sa.text('now()'), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True),
                  server_default=sa.text('now()'), nullable=False),
        sa.ForeignKeyConstraint(['cuenta_id'], ['cuentas_sociales.id'],
                                ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index('ix_publicacion_social_cola', 'publicaciones_sociales',
                    ['estado', 'proximo_intento_en'], unique=False)
    op.create_index(op.f('ix_publicaciones_sociales_cuenta_id'),
                    'publicaciones_sociales', ['cuenta_id'], unique=False)
    op.create_index(op.f('ix_publicaciones_sociales_estado'),
                    'publicaciones_sociales', ['estado'], unique=False)

    op.create_table(
        'tokens_sociales',
        sa.Column('id', sa.UUID(), nullable=False),
        sa.Column('cuenta_id', sa.UUID(), nullable=False),
        sa.Column('access_token', sa.Text(), nullable=False,
                  comment="Cifrado con prefijo 'enc:'"),
        sa.Column('refresh_token', sa.Text(), nullable=True,
                  comment="Cifrado con prefijo 'enc:'"),
        sa.Column('token_type', sa.String(length=50),
                  server_default='Bearer', nullable=False),
        sa.Column('expires_at', sa.DateTime(timezone=True), nullable=True,
                  comment='NULL = no expira (tokens de página de FB pueden ser así)'),
        sa.Column('scope', sa.Text(), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True),
                  server_default=sa.text('now()'), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True),
                  server_default=sa.text('now()'), nullable=False),
        sa.ForeignKeyConstraint(['cuenta_id'], ['cuentas_sociales.id'],
                                ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index(op.f('ix_tokens_sociales_cuenta_id'), 'tokens_sociales',
                    ['cuenta_id'], unique=False)


def downgrade() -> None:
    op.drop_index(op.f('ix_tokens_sociales_cuenta_id'),
                  table_name='tokens_sociales')
    op.drop_table('tokens_sociales')

    op.drop_index(op.f('ix_publicaciones_sociales_estado'),
                  table_name='publicaciones_sociales')
    op.drop_index(op.f('ix_publicaciones_sociales_cuenta_id'),
                  table_name='publicaciones_sociales')
    op.drop_index('ix_publicacion_social_cola',
                  table_name='publicaciones_sociales')
    op.drop_table('publicaciones_sociales')

    op.drop_index(op.f('ix_cuentas_sociales_red'),
                  table_name='cuentas_sociales')
    op.drop_index('ix_cuenta_social_propietario',
                  table_name='cuentas_sociales')
    op.drop_table('cuentas_sociales')

    op.drop_table('config_social')