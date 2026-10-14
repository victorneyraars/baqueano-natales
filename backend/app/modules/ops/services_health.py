"""Estado consolidado del sistema para el Ops Dashboard.

Combina datos de varios sources en una sola respuesta:
- Health del backend (rápido, siempre disponible)
- Último release exitoso (GitHub)
- Runs fallidos en las últimas 24h (GitHub)
- Links de descarga (config)

Diseño: este service NUNCA falla completo. Si GitHub está caído, devuelve
health + links (los esenciales) y marca el componente como degraded.
"""
from __future__ import annotations

import logging
from datetime import datetime, timedelta, timezone

from app.core.config import settings
from app.modules.ops.schemas import (
    ComponentHealth,
    RunInfo,
    SystemHealth,
)
from app.modules.ops.services_github import (
    listar_runs,
    obtener_ultimo_run_exitoso,
)
from app.modules.ops.services_links import obtener_links

logger = logging.getLogger(__name__)


def _check_backend() -> ComponentHealth:
    """Health del backend — siempre OK si llegamos a este código."""
    return ComponentHealth(
        name="Backend",
        status="ok",
        detail=f"{settings.ENVIRONMENT}",
    )


def _count_runs_last_24h(runs: list[RunInfo]) -> tuple[int, int]:
    """Cuenta total y fallidos en las últimas 24h."""
    cutoff = datetime.now(timezone.utc) - timedelta(hours=24)
    total = 0
    failed = 0
    for run in runs:
        created = run.created_at
        # Normalizar timezone
        if created.tzinfo is None:
            created = created.replace(tzinfo=timezone.utc)
        if created >= cutoff:
            total += 1
            if run.conclusion == "failure":
                failed += 1
    return total, failed


async def obtener_health() -> SystemHealth:
    """Construye el SystemHealth consolidado.

    Estrategia:
    1. Traer runs (10 últimos).
    2. Traer último release exitoso.
    3. Traer links (local, siempre OK).
    4. Combinar.
    """
    # Runs (para stats)
    runs_response = await listar_runs(limit=10)
    total_24h, failed_24h = _count_runs_last_24h(runs_response.runs)

    # Último release exitoso
    last_release = await obtener_ultimo_run_exitoso(workflow_name="Release")

    # Links
    links = obtener_links()

    # Componentes
    components: list[ComponentHealth] = [_check_backend()]

    # Estado de GitHub según el último listado
    if runs_response.total_count > 0:
        components.append(ComponentHealth(
            name="GitHub Actions",
            status="ok",
            detail=f"{runs_response.total_count} runs totales",
        ))
    else:
        components.append(ComponentHealth(
            name="GitHub Actions",
            status="degraded",
            detail="Sin runs o API no disponible",
        ))

    if failed_24h > 0:
        components.append(ComponentHealth(
            name="CI/CD últimas 24h",
            status="degraded",
            detail=f"{failed_24h} runs fallidos de {total_24h}",
        ))
    else:
        components.append(ComponentHealth(
            name="CI/CD últimas 24h",
            status="ok",
            detail=f"{total_24h} runs, 0 fallidos",
        ))

    return SystemHealth(
        environment=settings.ENVIRONMENT,
        version="0.3.3",  # TODO: leer de un archivo version.txt o similar
        timestamp=datetime.now(timezone.utc),
        components=components,
        last_successful_release=last_release,
        total_runs_last_24h=total_24h,
        failed_runs_last_24h=failed_24h,
        links=links,
    )
