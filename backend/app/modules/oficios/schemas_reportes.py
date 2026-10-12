"""Schemas Pydantic de reportes del taller (M5.3)."""
from datetime import date, datetime

from pydantic import BaseModel, ConfigDict, Field


class ReporteKPIs(BaseModel):
    """KPIs del periodo."""

    total_ordenes: int = 0
    ordenes_por_estado: dict[str, int] = Field(default_factory=dict)
    ingresos_totales: float = 0.0
    ticket_promedio: float = 0.0
    tasa_aprobacion_items: float = 0.0
    duracion_promedio_dias: float | None = None


class ReporteSerieMes(BaseModel):
    """Un punto de la serie temporal (mes)."""

    mes: str = Field(..., description="YYYY-MM")
    ordenes: int = 0
    ingresos: float = 0.0


class ReporteTopServicio(BaseModel):
    """Un servicio del ranking (agrupado por descripcion)."""

    descripcion: str
    cantidad: int
    ingresos_totales: float


class ReporteTopCliente(BaseModel):
    """Un cliente del ranking por facturacion."""

    cliente_id: str
    cliente_nombre: str | None = None
    ordenes: int
    ingresos_totales: float


class ReportePrestador(BaseModel):
    """Reporte completo del taller en un periodo."""

    model_config = ConfigDict(from_attributes=True)

    prestador_id: str
    desde: date
    hasta: date
    generado_en: datetime
    kpis: ReporteKPIs
    serie_mensual: list[ReporteSerieMes] = Field(default_factory=list)
    top_servicios: list[ReporteTopServicio] = Field(default_factory=list)
    top_clientes: list[ReporteTopCliente] = Field(default_factory=list)
