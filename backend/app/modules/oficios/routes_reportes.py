"""Endpoints HTTP de reportes del taller (M5.3).

Routers:
- GET /api/v1/mis-prestadores/{pid}/reportes        (JSON)
- GET /api/v1/mis-prestadores/{pid}/reportes.csv    (descarga CSV)
"""
import logging
from datetime import date
from uuid import UUID

from fastapi import APIRouter, HTTPException, Query, status
from fastapi.responses import Response
from sqlalchemy import select

from app.core.db import DbSession
from app.modules.auth.deps import CurrentUser
from app.modules.oficios import services_reportes
from app.modules.oficios.schemas_reportes import ReportePrestador
from app.modules.prestadores.models import Prestador

logger = logging.getLogger(__name__)


router_reportes_prestador = APIRouter(
    prefix="/mis-prestadores",
    tags=["oficios-reportes"],
)


# =========================================================
# Helper
# =========================================================
async def _validar_prestador_dueno(
    db, prestador_id: UUID, user,
) -> None:
    """Valida que el usuario sea dueno del prestador o admin."""
    prestador = (
        await db.execute(
            select(Prestador).where(Prestador.id == prestador_id)
        )
    ).scalar_one_or_none()
    if prestador is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Prestador no encontrado",
        )
    if user.rol != "admin" and prestador.usuario_id != user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="No tenes permiso sobre este prestador",
        )


# =========================================================
# GET /reportes
# =========================================================
@router_reportes_prestador.get(
    "/{prestador_id}/reportes",
    response_model=ReportePrestador,
    summary="Reporte del taller (JSON)",
    description=(
        "Metricas de industria: KPIs, serie mensual, top servicios y "
        "top clientes. Si no se pasa `desde`/`hasta`, usa los ultimos "
        "12 meses."
    ),
)
async def obtener_reporte(
    prestador_id: UUID,
    user: CurrentUser,
    db: DbSession,
    desde: date | None = Query(None, description="Fecha inicial (YYYY-MM-DD)"),
    hasta: date | None = Query(None, description="Fecha final (YYYY-MM-DD)"),
):
    await _validar_prestador_dueno(db, prestador_id, user)
    return await services_reportes.generar_reporte(
        db, prestador_id, desde=desde, hasta=hasta,
    )


# =========================================================
# GET /reportes.csv
# =========================================================
@router_reportes_prestador.get(
    "/{prestador_id}/reportes.csv",
    summary="Reporte del taller (CSV descargable)",
    response_class=Response,
    responses={
        200: {
            "content": {"text/csv": {}},
            "description": "Reporte en CSV plano (KPIs + bloques).",
        },
    },
)
async def descargar_reporte_csv(
    prestador_id: UUID,
    user: CurrentUser,
    db: DbSession,
    desde: date | None = Query(None, description="Fecha inicial (YYYY-MM-DD)"),
    hasta: date | None = Query(None, description="Fecha final (YYYY-MM-DD)"),
):
    await _validar_prestador_dueno(db, prestador_id, user)
    reporte = await services_reportes.generar_reporte(
        db, prestador_id, desde=desde, hasta=hasta,
    )
    csv = services_reportes.reporte_a_csv(reporte)
    filename = f"reporte-{reporte['desde']}_{reporte['hasta']}.csv"

    return Response(
        content=csv.encode("utf-8"),
        media_type="text/csv",
        headers={
            "Content-Disposition": f'attachment; filename="{filename}"',
        },
    )
