"""Endpoints HTTP del módulo analytics."""
import logging
from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.db import get_db
from app.modules.analytics import services
from app.modules.analytics.schemas import StatsRequest, StatsResponse
from app.modules.auth.deps import AdminUser, CurrentUser
from app.modules.prestadores.models import Prestador
from app.modules.prestadores.deps import PrestadorOwner

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/analytics", tags=["analytics"])

PROPERTY_ID = "562461404"
import os as _os
_os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = "/app/secrets/ga4-service-account.json"


@router.get(
    "/stats",
    response_model=StatsResponse,
    summary="Estadísticas Web Analytics (admin)",
    description="Devuelve stats de todos los sitios. Solo admins.",
)
async def get_stats(
    current_user: AdminUser,
    days: int = Query(default=7, ge=1, le=90),
    hostname: str | None = Query(default=None),
) -> StatsResponse:
    try:
        return await services.fetch_web_analytics(
            StatsRequest(days=days, hostname=hostname)
        )
    except RuntimeError as e:
        logger.error("Error CF: %s", e)
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=f"Cloudflare no disponible: {e}",
        )


@router.get(
    "/mi-prestador/stats",
    response_model=StatsResponse,
    summary="Estadísticas del prestador autenticado",
    description="Devuelve las stats del sitio del prestador. Filtra por hostname según su slug.",
)
async def get_my_stats(
    current_user: CurrentUser,
    db: AsyncSession = Depends(get_db),
    days: int = Query(default=7, ge=1, le=90),
) -> StatsResponse:
    # Buscar el prestador asociado al usuario
    result = await db.execute(
        select(Prestador).where(Prestador.usuario_id == current_user.id).order_by(Prestador.created_at.desc())
    )
    prestador = result.scalars().first()

    if not prestador:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No tenés un perfil de prestador asociado",
        )

    # Mapeo manual slug → hostname
    # Si el user tiene múltiples prestadores, priorizamos el que tiene hostname definido
    hostname_map = {
        "se-alquila-marido": "sealquilamarido.com",
    }

    # Buscar entre todos los prestadores del user el que tenga hostname
    if prestador and prestador.slug not in hostname_map:
        # Fallback: buscar cualquier prestador del user que tenga hostname
        all_prestadores = await db.execute(
            select(Prestador).where(Prestador.usuario_id == current_user.id)
        )
        for p in all_prestadores.scalars().all():
            if p.slug in hostname_map:
                prestador = p
                break

    hostname = hostname_map.get(prestador.slug) if prestador else None

    try:
        return await services.fetch_web_analytics(
            StatsRequest(days=days, hostname=hostname)
        )
    except RuntimeError as e:
        logger.error("Error CF: %s", e)
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=f"Cloudflare no disponible: {e}",
        )


# =========================================================
# Endpoints de Google Analytics 4 (para la app de Flutter)
# =========================================================

@router.get(
    "/metrics/summary",
    summary="Resumen de métricas de los últimos 30 días",
)
async def get_metrics_summary(
    user: CurrentUser,
    prestador: PrestadorOwner,
):
    try:
        from google.analytics.data_v1beta import BetaAnalyticsDataClient
        from google.analytics.data_v1beta.types import RunReportRequest, DateRange, Metric

        client = BetaAnalyticsDataClient()

        request = RunReportRequest(
            property=f"properties/{PROPERTY_ID}",
            date_ranges=[DateRange(start_date="30daysAgo", end_date="today")],
            metrics=[
                Metric(name="activeUsers"),
                Metric(name="screenPageViews"),
                Metric(name="sessions"),
            ],
        )

        response = client.run_report(request)

        if not response.rows:
            return {"usuarios_activos": 0, "paginas_vistas": 0, "sesiones": 0}

        row = response.rows[0]
        return {
            "usuarios_activos": int(row.metric_values[0].value),
            "paginas_vistas": int(row.metric_values[1].value),
            "sesiones": int(row.metric_values[2].value),
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error consultando GA4: {e}")


@router.get(
    "/metrics/daily",
    summary="Métricas diarias de los últimos 30 días",
)
async def get_metrics_daily(
    user: CurrentUser,
    prestador: PrestadorOwner,
):
    try:
        from google.analytics.data_v1beta import BetaAnalyticsDataClient
        from google.analytics.data_v1beta.types import RunReportRequest, DateRange, Metric, Dimension

        client = BetaAnalyticsDataClient()

        request = RunReportRequest(
            property=f"properties/{PROPERTY_ID}",
            date_ranges=[DateRange(start_date="30daysAgo", end_date="today")],
            dimensions=[Dimension(name="date")],
            metrics=[
                Metric(name="activeUsers"),
                Metric(name="screenPageViews"),
            ],
        )

        response = client.run_report(request)
        data = []
        for row in response.rows:
            fecha_str = row.dimension_values[0].value
            fecha_formateada = f"{fecha_str[:4]}-{fecha_str[4:6]}-{fecha_str[6:]}"
            data.append({
                "fecha": fecha_formateada,
                "usuarios": int(row.metric_values[0].value),
                "paginas_vistas": int(row.metric_values[1].value),
            })
        return {"data": data}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error consultando GA4: {e}")


@router.get(
    "/metrics/pages",
    summary="Top 10 páginas más visitadas",
)
async def get_top_pages(
    user: CurrentUser,
    prestador: PrestadorOwner,
):
    try:
        from google.analytics.data_v1beta import BetaAnalyticsDataClient
        from google.analytics.data_v1beta.types import RunReportRequest, DateRange, Metric, Dimension

        client = BetaAnalyticsDataClient()

        request = RunReportRequest(
            property=f"properties/{PROPERTY_ID}",
            date_ranges=[DateRange(start_date="30daysAgo", end_date="today")],
            dimensions=[Dimension(name="pagePath")],
            metrics=[Metric(name="screenPageViews")],
            limit=10,
        )

        response = client.run_report(request)
        data = []
        for row in response.rows:
            data.append({
                "pagina": row.dimension_values[0].value,
                "vistas": int(row.metric_values[0].value),
            })
        return {"data": data}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error consultando GA4: {e}")
