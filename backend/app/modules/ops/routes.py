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
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query, Request
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.db import get_db

from app.modules.ops import (
    services_audit,
    services_cleanup,
    services_github,
    services_health,
    services_links,
    services_play,
    services_quick_links,
    services_release,
)
from app.modules.ops.services_release import ReleaseTriggerError
from app.modules.ops.deps import AdminUser

# Alias para type hint de DB
DbSession = Annotated[AsyncSession, Depends(get_db)]
from app.modules.ops.schemas import (
    LinksResponse,
    ReleasePreviewRequest,
    ReleasePreviewResponse,
    ReleaseTriggerRequest,
    ReleaseTriggerResponse,
    QuickLinksResponse,
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

@router.get(
    "/quick-links",
    response_model=QuickLinksResponse,
    summary="Quick links a dashboards externos",
    description="Links directos a Play Console, GitHub, Cloudflare, RackNerd.",
)
async def obtener_quick_links_endpoint(admin: AdminUser) -> QuickLinksResponse:
    """Quick links agrupados por categoria."""
    return services_quick_links.obtener_quick_links()


# ============================================================
# Fase 2b - Release preview (dry-run)
# ============================================================
@router.post(
    "/release/preview",
    response_model=ReleasePreviewResponse,
    summary="Preview de un release (dry-run)",
    description=(
        "Valida que se pueda taggear (tag libre, versionCode mayor a Play, "
        "HEAD accesible, pubspec parseable) y devuelve un preview_token "
        "firmado (5 min de validez) para ejecutar el release despues."
    ),
)
async def preview_release(
    request: ReleasePreviewRequest,
    admin: AdminUser,
) -> ReleasePreviewResponse:
    """Genera un preview del release sin ejecutar nada."""
    return await services_release.generar_preview(request, admin.id)


# ============================================================
# Fase 2c - Release trigger (crea el tag y dispara el workflow)
# ============================================================
@router.post(
    "/release/trigger",
    response_model=ReleaseTriggerResponse,
    summary="Ejecutar un release (crea tag en GitHub)",
    description=(
        "Crea el tag en GitHub lo que dispara el workflow Release. "
        "Requiere el preview_token previo (firmado, 5 min de validez) + "
        "confirm='CONFIRMAR'. Rate limit: 1 release cada 10 min."
    ),
)
async def trigger_release(
    request: ReleaseTriggerRequest,
    admin: AdminUser,
    http_request: Request,
) -> ReleaseTriggerResponse:
    """Ejecuta el release: crea el tag en GitHub."""
    ip = http_request.client.host if http_request.client else None
    user_agent = http_request.headers.get("user-agent")
    try:
        return await services_release.ejecutar_release(
            request,
            admin.id,
            admin.email,
            ip_address=ip,
            user_agent=user_agent,
        )
    except ReleaseTriggerError as e:
        raise HTTPException(status_code=e.http_status, detail=e.message) from e

# ============================================================
# Cleanup de datos incompletos
# ============================================================

@router.get(
    "/cleanup/preview",
    summary="Preview del cleanup (dry-run)",
    description="Muestra qué registros con datos incompletos se detectarían, sin modificar nada.",
)
async def cleanup_preview(
    user: AdminUser,
    db: DbSession,
) -> dict:
    """Dry-run del cleanup. No modifica nada."""
    resultado = await services_cleanup.ejecutar_cleanup(db, dry_run=True)
    return resultado


@router.post(
    "/cleanup",
    summary="Ejecutar cleanup manualmente",
    description="Sanitiza registros verificados con datos incompletos. Solo admins.",
)
async def cleanup_run(
    user: AdminUser,
    db: DbSession,
) -> dict:
    """Ejecuta el cleanup real. Sanitiza prestadores, loguea comercios."""
    from datetime import datetime, timezone

    inicio = datetime.now(timezone.utc)
    resultado = await services_cleanup.ejecutar_cleanup(db, dry_run=False)
    await db.commit()

    fin = datetime.now(timezone.utc)
    duration_ms = int((fin - inicio).total_seconds() * 1000)

    await services_audit.registrar(
        db=db,
        user_id=user.id,
        user_email=user.email,
        action="cleanup.run",
        status="success",
        target="prestadores+comercios",
        result=resultado,
        duration_ms=duration_ms,
    )
    await db.commit()

    return resultado

# ============================================================
# Build Dev APK (dispara dev-build.yml desde la app)
# ============================================================
@router.post("/build-dev-apk")
async def build_dev_apk(
    current_user: AdminUser,
    flavor: str = Query(default="adminDev", pattern="^(clientDev|adminDev|both)$"),
):
    """Dispara el workflow dev-build.yml para generar un APK directo.

    - flavor=adminDev → compila la App Admin
    - flavor=clientDev → compila la App Cliente
    - flavor=both → compila ambas

    El APK queda disponible en:
    https://api-dev.baqueanonatales.com/apks/app-{flavor}.apk
    Listo en ~5-10 min.
    """
    import httpx
    from app.core.config import settings

    if not settings.GITHUB_OPS_TOKEN:
        raise HTTPException(
            status_code=500,
            detail="GITHUB_OPS_TOKEN no configurado en .env",
        )

    url = (
        f"{settings.GITHUB_API_BASE}/repos/{settings.GITHUB_OPS_REPO}"
        f"/actions/workflows/dev-build.yml/dispatches"
    )

    async with httpx.AsyncClient() as client:
        try:
            r = await client.post(
                url,
                headers={
                    "Authorization": f"Bearer {settings.GITHUB_OPS_TOKEN}",
                    "Accept": "application/vnd.github+json",
                },
                json={"ref": "main", "inputs": {"flavor": flavor}},
                timeout=15.0,
            )
        except httpx.HTTPError as e:
            raise HTTPException(status_code=502, detail=f"Error GitHub: {e}")

    if r.status_code not in (200, 204):
        raise HTTPException(
            status_code=502,
            detail=f"GitHub API {r.status_code}: {r.text[:300]}",
        )

    return {
        "status": "triggered",
        "flavor": flavor,
        "message": f"Build {flavor} disparado. Listo en ~5-10 min.",
        "workflow_url": (
            f"https://github.com/{settings.GITHUB_OPS_REPO}"
            f"/actions/workflows/dev-build.yml"
        ),
        "apk_url": (
            f"https://api-dev.baqueanonatales.com/apks/"
            f"app-{flavor.replace('Dev', '').lower()}.apk"
        ),
    }



import os
from pydantic import BaseModel
from fastapi import HTTPException

class ApkInfoResponse(BaseModel):
    version: str
    url: str
    sha256: str
    size_mb: float

@router.get("/latest-apk/{flavor}", response_model=ApkInfoResponse)
async def get_latest_apk(flavor: str):
    if flavor not in ["adminDev", "clientDev"]:
        raise HTTPException(status_code=400, detail="Flavor inválido")
        
    filename = "app-admindev.apk" if flavor == "adminDev" else "app-clientdev.apk"
    apk_path = f"/home/deploy/baqueano-natales/deploy/apks/{filename}"
    
    if not os.path.exists(apk_path):
        raise HTTPException(status_code=404, detail="APK no encontrado")
        
    sha = ""
    sha_path = apk_path + ".sha256"
    if os.path.exists(sha_path):
        with open(sha_path, "r") as f:
            sha = f.read().strip().split()[0]

    version = "0.4.0" # temporal hasta que el CI genere un metadata.json

    return ApkInfoResponse(
        version=version,
        url=f"https://api-dev.baqueanonatales.com/apks/{filename}",
        sha256=sha,
        size_mb=round(os.path.getsize(apk_path) / (1024 * 1024), 1)
    )
