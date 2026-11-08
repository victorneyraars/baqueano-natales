
import uuid
from datetime import datetime
from sqlalchemy import String, DateTime, JSON, Text
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.dialects.postgresql import UUID
from app.core.db import Base
from app.core.mixins import TimestampMixin

class DocumentoFirma(TimestampMixin, Base):
    __tablename__ = "documentos_firma"
    
    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    token: Mapped[str] = mapped_column(String(100), unique=True, index=True)
    tenant_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=True, index=True)
    tipo: Mapped[str] = mapped_column(String(50)) # ej. "contrato_rentacar", "orden_oficio"
    payload: Mapped[dict] = mapped_column(JSON) # Datos del contrato
    estado: Mapped[str] = mapped_column(String(20), default="pendiente")
    
    firmado_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=True)
    ip_firma: Mapped[str] = mapped_column(String(50), nullable=True)
    firma_base64: Mapped[str] = mapped_column(Text, nullable=True)
