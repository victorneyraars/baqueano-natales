"""Modelos del sistema de notificaciones.

Diseno multi-provider, multi-device, con analytics y preferencias.
"""
from datetime import datetime
from enum import Enum
from uuid import UUID, uuid4

from sqlalchemy import (
    Boolean, DateTime, Enum as SQLEnum, ForeignKey, String, Text, func,
)
from sqlalchemy.dialects.postgresql import JSONB, UUID as PG_UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.core.db import Base


class Plataforma(str, Enum):
    ANDROID = "android"
    IOS = "ios"
    WEB = "web"


class TipoNotificacion(str, Enum):
    RECORDATORIO = "recordatorio"
    PROMOCION = "promocion"
    SISTEMA = "sistema"
    CAMPANA = "campana"


class CanalNotificacion(str, Enum):
    FCM = "fcm"
    IN_APP = "in_app"


class EstadoNotificacion(str, Enum):
    PENDIENTE = "pendiente"
    ENVIADA = "enviada"
    ENTREGADA = "entregada"
    IMPRESA = "impresa"
    ABIERTA = "abierta"
    FALLIDA = "fallida"
    SKIPPED = "skipped"


class FcmToken(Base):
    """Token FCM de un dispositivo. Multi-device: un user puede tener N."""
    __tablename__ = "fcm_tokens"

    id: Mapped[UUID] = mapped_column(PG_UUID(as_uuid=True), primary_key=True, default=uuid4)
    usuario_id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("usuarios.id", ondelete="CASCADE"),
        index=True, nullable=False,
    )
    token: Mapped[str] = mapped_column(String(500), unique=True, index=True, nullable=False)
    device_id: Mapped[str | None] = mapped_column(String(128), index=True, nullable=True)
    plataforma: Mapped[Plataforma] = mapped_column(
        SQLEnum(Plataforma, name="plataforma_fcm",
                values_callable=lambda x: [e.value for e in x]),
        nullable=False, default=Plataforma.ANDROID,
    )
    app_version: Mapped[str | None] = mapped_column(String(50), nullable=True)
    activo: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True, index=True)
    creado_en: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now(),
    )
    actualizado_en: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False,
        server_default=func.now(), onupdate=func.now(),
    )
    ultimo_uso: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)


class PreferenciaNotificacion(Base):
    """Preferencias por tipo + quiet hours. One-to-one con Usuario."""
    __tablename__ = "preferencias_notificacion"

    id: Mapped[UUID] = mapped_column(PG_UUID(as_uuid=True), primary_key=True, default=uuid4)
    usuario_id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("usuarios.id", ondelete="CASCADE"),
        unique=True, index=True, nullable=False,
    )
    recordatorios: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    promociones: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    confirmaciones: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    sistema: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)

    quiet_hours_enabled: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    quiet_hours_inicio: Mapped[str | None] = mapped_column(String(5), nullable=True)
    quiet_hours_fin: Mapped[str | None] = mapped_column(String(5), nullable=True)
    timezone: Mapped[str] = mapped_column(String(50), nullable=False, default="America/Santiago")

    creado_en: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now(),
    )
    actualizado_en: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False,
        server_default=func.now(), onupdate=func.now(),
    )


class NotificationLog(Base):
    """Historial + analytics. Cada envio tiene una fila por token."""
    __tablename__ = "notification_logs"

    id: Mapped[UUID] = mapped_column(PG_UUID(as_uuid=True), primary_key=True, default=uuid4)
    usuario_id: Mapped[UUID | None] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("usuarios.id", ondelete="SET NULL"),
        index=True, nullable=True,
    )
    tipo: Mapped[TipoNotificacion] = mapped_column(
        SQLEnum(TipoNotificacion, name="tipo_notificacion",
                values_callable=lambda x: [e.value for e in x]),
        nullable=False, index=True,
    )
    canal: Mapped[CanalNotificacion] = mapped_column(
        SQLEnum(CanalNotificacion, name="canal_notificacion",
                values_callable=lambda x: [e.value for e in x]),
        nullable=False, default=CanalNotificacion.FCM,
    )
    titulo: Mapped[str] = mapped_column(String(200), nullable=False)
    body: Mapped[str] = mapped_column(Text, nullable=False)
    data: Mapped[dict | None] = mapped_column(JSONB, nullable=True)
    analytics_label: Mapped[str | None] = mapped_column(String(50), nullable=True, index=True)
    estado: Mapped[EstadoNotificacion] = mapped_column(
        SQLEnum(EstadoNotificacion, name="estado_notificacion",
                values_callable=lambda x: [e.value for e in x]),
        nullable=False, default=EstadoNotificacion.PENDIENTE, index=True,
    )
    error: Mapped[str | None] = mapped_column(Text, nullable=True)
    token_id: Mapped[UUID | None] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("fcm_tokens.id", ondelete="SET NULL"), nullable=True,
    )
    creado_en: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now(), index=True,
    )
    enviado_en: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    abierto_en: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
