"""add notifications system (fcm_tokens, preferencias, notification_logs)

Revision ID: a8b9c0d1e2f3
Revises: f1a2b3c4d5e6
Create Date: 2026-10-12

Crea el sistema de notificaciones nivel industria:
- fcm_tokens: multi-device, con limpieza automatica de tokens invalidos.
- preferencias_notificacion: opt-in/out por tipo + quiet hours.
- notification_logs: historial + analytics.

Backfill: copia usuarios.fcm_token (columna legacy) a fcm_tokens.
La columna legacy NO se borra (rollback seguro, se deprecara despues).
"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "a8b9c0d1e2f3"
down_revision: Union[str, None] = "f1a2b3c4d5e6"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # ============ 1. Enums ============
    plataforma = postgresql.ENUM(
        "android", "ios", "web", name="plataforma_fcm", create_type=False,
    )
    tipo = postgresql.ENUM(
        "recordatorio", "promocion", "sistema", "campana",
        name="tipo_notificacion", create_type=False,
    )
    canal = postgresql.ENUM(
        "fcm", "in_app", name="canal_notificacion", create_type=False,
    )
    estado = postgresql.ENUM(
        "pendiente", "enviada", "entregada", "impresa", "abierta",
        "fallida", "skipped",
        name="estado_notificacion", create_type=False,
    )

    plataforma.create(op.get_bind(), checkfirst=True)
    tipo.create(op.get_bind(), checkfirst=True)
    canal.create(op.get_bind(), checkfirst=True)
    estado.create(op.get_bind(), checkfirst=True)

    # ============ 2. fcm_tokens ============
    op.create_table(
        "fcm_tokens",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column(
            "usuario_id", postgresql.UUID(as_uuid=True),
            sa.ForeignKey("usuarios.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("token", sa.String(500), nullable=False, unique=True),
        sa.Column("device_id", sa.String(128), nullable=True),
        sa.Column("plataforma", plataforma, nullable=False, server_default="android"),
        sa.Column("app_version", sa.String(50), nullable=True),
        sa.Column("activo", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column("creado_en", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.Column("actualizado_en", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.Column("ultimo_uso", sa.DateTime(timezone=True), nullable=True),
    )
    op.create_index("ix_fcm_tokens_usuario_id", "fcm_tokens", ["usuario_id"])
    op.create_index("ix_fcm_tokens_token", "fcm_tokens", ["token"])
    op.create_index("ix_fcm_tokens_device_id", "fcm_tokens", ["device_id"])
    op.create_index("ix_fcm_tokens_activo", "fcm_tokens", ["activo"])

    # ============ 3. preferencias_notificacion ============
    op.create_table(
        "preferencias_notificacion",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column(
            "usuario_id", postgresql.UUID(as_uuid=True),
            sa.ForeignKey("usuarios.id", ondelete="CASCADE"),
            nullable=False, unique=True,
        ),
        sa.Column("recordatorios", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column("promociones", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("confirmaciones", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column("sistema", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column("quiet_hours_enabled", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("quiet_hours_inicio", sa.String(5), nullable=True),
        sa.Column("quiet_hours_fin", sa.String(5), nullable=True),
        sa.Column("timezone", sa.String(50), nullable=False, server_default="America/Santiago"),
        sa.Column("creado_en", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.Column("actualizado_en", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
    )
    op.create_index(
        "ix_preferencias_notificacion_usuario_id",
        "preferencias_notificacion", ["usuario_id"],
    )

    # ============ 4. notification_logs ============
    op.create_table(
        "notification_logs",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column(
            "usuario_id", postgresql.UUID(as_uuid=True),
            sa.ForeignKey("usuarios.id", ondelete="SET NULL"),
            nullable=True,
        ),
        sa.Column("tipo", tipo, nullable=False),
        sa.Column("canal", canal, nullable=False, server_default="fcm"),
        sa.Column("titulo", sa.String(200), nullable=False),
        sa.Column("body", sa.Text(), nullable=False),
        sa.Column("data", postgresql.JSONB(), nullable=True),
        sa.Column("analytics_label", sa.String(50), nullable=True),
        sa.Column("estado", estado, nullable=False, server_default="pendiente"),
        sa.Column("error", sa.Text(), nullable=True),
        sa.Column(
            "token_id", postgresql.UUID(as_uuid=True),
            sa.ForeignKey("fcm_tokens.id", ondelete="SET NULL"),
            nullable=True,
        ),
        sa.Column("creado_en", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.Column("enviado_en", sa.DateTime(timezone=True), nullable=True),
        sa.Column("abierto_en", sa.DateTime(timezone=True), nullable=True),
    )
    op.create_index("ix_notification_logs_usuario_id", "notification_logs", ["usuario_id"])
    op.create_index("ix_notification_logs_tipo", "notification_logs", ["tipo"])
    op.create_index("ix_notification_logs_estado", "notification_logs", ["estado"])
    op.create_index("ix_notification_logs_analytics_label", "notification_logs", ["analytics_label"])
    op.create_index("ix_notification_logs_creado_en", "notification_logs", ["creado_en"])

    # ============ 5. Backfill: usuarios.fcm_token -> fcm_tokens ============
    op.execute("""
        INSERT INTO fcm_tokens (id, usuario_id, token, plataforma, activo)
        SELECT gen_random_uuid(), id, fcm_token, 'android', true
        FROM usuarios
        WHERE fcm_token IS NOT NULL
        ON CONFLICT (token) DO NOTHING
    """)


def downgrade() -> None:
    op.drop_table("notification_logs")
    op.drop_table("preferencias_notificacion")
    op.drop_table("fcm_tokens")

    op.execute("DROP TYPE IF EXISTS estado_notificacion")
    op.execute("DROP TYPE IF EXISTS canal_notificacion")
    op.execute("DROP TYPE IF EXISTS tipo_notificacion")
    op.execute("DROP TYPE IF EXISTS plataforma_fcm")
