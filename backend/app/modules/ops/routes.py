"""Endpoints admin del Ops Dashboard (solo lectura — Fase 1).

Todos requieren rol `admin`. Los endpoints están diseñados para ser
consumidos desde la app admin Flutter.

Endpoints:
- GET /admin/ops/health          -> Estado consolidado del sistema
- GET /admin/ops/runs            -> Lista de runs (con filtros)
- GET /admin/ops/runs/{run_id}   -> Detalle de un run (jobs + steps)
- GET /admin/ops/tracks          -> Versiones por track (client + admin)
- GET /admin/ops/links           -> Links de descarga (opt-in + Play Store)

No hay endpoints de escritura en Fase 1. Ver README.md para el roadmap.
"""
from fastapi import APIRouter, HTTPException, Query

from app.modules.ops import (
    services_github,
    services_health,
    services_links,
    services_play,
)
from app.modules.ops.deps import AdminUser
from app.modules.ops.schemas import (
    LinksResponse,
    RunDetail,
    RunsResponse,
    SystemHealth,
    TracksResponse,
)

router = APIRouter(
    prefix="/admin/ops",
    tags=["admin-ops"],
)


@router.get(
    "/health",
    response_model=SystemHealth,
    summary="Estado consolidado del sistema",
    description="Combina health del backend + último release + stats 24h + links.",
)
async def obtener_health(admin: AdminUser) -> SystemHealth:
    """Estado consolidado del sistema."""
    return await services_health.obtener_health()


@router.get(
    "/runs",
    response_model=RunsResponse,
    summary="Lista los últimos runs de workflows",
    description="Retorna los últimos N workflow runs del repo.",
)
async def listar_runs(
    admin: AdminUser,
    limit: int = Query(10, ge=1, le=50, description="Cantidad (1-50)"),
    branch: str | None = Query(None, description="Filtrar por branch"),
) -> RunsResponse:
    """Lista los últimos workflow runs."""
    return await services_github.listar_runs(limit=limit, branch=branch)


@router.get(
    "/runs/{run_id}",
    response_model=RunDetail,
    summary="Detalle de un run (jobs + steps)",
    description="Retorna el detalle completo de un run con jobs y steps.",
)
async def obtener_run(
    run_id: int,
    admin: AdminUser,
) -> RunDetail:
    """Detalle de un run específico."""
    detail = await services_github.obtener_detalle_run(run_id)
    if detail is None:
        raise HTTPException(status_code=404, detail=f"Run {run_id} no encontrado")
    return detail


@router.get(
    "/tracks",
    response_model=TracksResponse,
    summary="Versiones actuales por track (Play Console)",
    description="Lee los tracks internal/alpha/beta/production de las 2 apps.",
)
async def listar_tracks(admin: AdminUser) -> TracksResponse:
    """Versiones por track de las 2 apps."""
    return await services_play.listar_tracks()


@router.get(
    "/links",
    response_model=LinksResponse,
    summary="Links de descarga para compartir",
    description="Links de opt-in (internal testing) + Play Store público.",
)
async def obtener_links(admin: AdminUser) -> LinksResponse:
    """Links de descarga de las 2 apps."""
    return services_links.obtener_links()
