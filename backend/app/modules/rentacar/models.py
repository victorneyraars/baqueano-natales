"""Modelos de base de datos para Rent a Car Vásquez.

3 tablas:
- RentacarConfig: configuración del prestador (pagos, depósito, categorías).
- RentacarVehiculo: flota en alquiler (con precio_dia y categoría configurable).
- RentacarReserva: reservas de vehículos.

Nota: NO confundir con oficios.Vehiculo (que es el vehículo de trabajo del
prestador de oficios). Aquí el vehículo es el PRODUCTO que se alquila.
"""
from datetime import datetime
from uuid import UUID, uuid4

from sqlalchemy import (
    Boolean,
    DateTime,
    ForeignKey,
    Integer,
    Numeric,
    String,
    func,
)
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.dialects.postgresql import UUID as PG_UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.db import Base
from app.core.mixins import TimestampMixin


class RentacarConfig(TimestampMixin, Base):
    __tablename__ = "rentacar_config"

    id: Mapped[UUID] = mapped_column(PG_UUID(as_uuid=True), primary_key=True, default=uuid4)
    prestador_id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("prestadores.id"), unique=True, index=True
    )
    metodos_pago: Mapped[dict] = mapped_column(JSONB, default=dict, nullable=False)
    deposito: Mapped[dict] = mapped_column(JSONB, default=dict, nullable=False)
    conductor_adicional: Mapped[dict] = mapped_column(JSONB, default=dict, nullable=False)
    categorias: Mapped[list] = mapped_column(JSONB, default=list, nullable=False)


class RentacarVehiculo(TimestampMixin, Base):
    __tablename__ = "rentacar_vehiculos"

    id: Mapped[UUID] = mapped_column(PG_UUID(as_uuid=True), primary_key=True, default=uuid4)
    prestador_id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("prestadores.id"), index=True
    )
    patente: Mapped[str] = mapped_column(String(10), unique=True, index=True)
    marca: Mapped[str] = mapped_column(String(50))
    modelo: Mapped[str] = mapped_column(String(50))
    anio: Mapped[int] = mapped_column(Integer)
    categoria: Mapped[str] = mapped_column(String(50))
    precio_dia: Mapped[float] = mapped_column(Numeric(10, 2))
    imagen_url: Mapped[str | None] = mapped_column(String(500), nullable=True)
    disponible: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)


class RentacarReserva(TimestampMixin, Base):
    __tablename__ = "rentacar_reservas"

    id: Mapped[UUID] = mapped_column(PG_UUID(as_uuid=True), primary_key=True, default=uuid4)
    vehiculo_id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("rentacar_vehiculos.id"), index=True
    )
    cliente_id: Mapped[UUID | None] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("usuarios.id"), nullable=True, index=True
    )
    nombre_cliente: Mapped[str | None] = mapped_column(String(150), nullable=True)
    email_cliente: Mapped[str | None] = mapped_column(String(255), nullable=True)
    telefono_cliente: Mapped[str | None] = mapped_column(String(20), nullable=True)
    fecha_inicio: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    fecha_fin: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    metodo_pago: Mapped[str] = mapped_column(String(50))
    precio_total: Mapped[float] = mapped_column(Numeric(10, 2))
    estado: Mapped[str] = mapped_column(String(20), default="pendiente", nullable=False)
    # Verificacion OTP de email (Guest-First)
    email_verificado: Mapped[bool] = mapped_column(
        Boolean, default=False, nullable=False
    )
    email_verificado_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    otp_code: Mapped[str | None] = mapped_column(String(6), nullable=True)
    otp_expires_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    otp_intentos: Mapped[int] = mapped_column(
        Integer, default=0, nullable=False
    )
