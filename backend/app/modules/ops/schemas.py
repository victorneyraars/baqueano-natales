"""Schemas Pydantic del modulo ops (Ops Dashboard admin).

Fase 1: solo lectura (runs, tracks, health, links).
Fase 2+ agregara schemas de acciones (trigger, promote, audit).
"""
from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field


# ============================================================
# GitHub Actions
# ============================================================
class RunInfo(BaseModel):
    """Resumen de un workflow run de GitHub Actions."""

    id: int
    name: str = Field(description="Nombre del workflow (CI, Build, Release)")
    workflow_id: int
    event: str = Field(description="push, pull_request, workflow_dispatch, etc.")
    status: Literal["queued", "in_progress", "completed", "requested", "waiting", "pending"]
    conclusion: Literal[
        "success", "failure", "neutral", "cancelled", "skipped",
        "timed_out", "action_required", "stale", None,
    ] = None
    head_branch: str | None = None
    head_sha: str = ""
    run_number: int
    created_at: datetime
    updated_at: datetime
    html_url: str
    duration_seconds: int | None = Field(
        default=None,
        description="Segundos desde created_at hasta updated_at (si esta running o completed)",
    )


class StepInfo(BaseModel):
    """Un paso (step) dentro de un job."""

    name: str
    status: str
    conclusion: str | None = None
    number: int
    started_at: datetime | None = None
    completed_at: datetime | None = None


class JobInfo(BaseModel):
    """Un job dentro de un workflow run."""

    id: int
    name: str
    status: str
    conclusion: str | None = None
    started_at: datetime | None = None
    completed_at: datetime | None = None
    steps: list[StepInfo] = Field(default_factory=list)


class RunDetail(RunInfo):
    """Detalle completo de un run: jobs + steps."""

    jobs: list[JobInfo] = Field(default_factory=list)


class RunsResponse(BaseModel):
    """Lista paginada de runs."""

    total_count: int
    runs: list[RunInfo]


# ============================================================
# Play Console (tracks + versiones)
# ============================================================
class TrackVersion(BaseModel):
    """Version actual en un track de Play Store."""

    track: str = Field(description="internal, alpha, beta, production")
    version_code: int | None = None
    version_name: str | None = None
    status: str | None = Field(
        default=None,
        description="completed, draft, halted, inProgress",
    )
    release_name: str | None = None
    release_notes: str | None = None


class AppTracks(BaseModel):
    """Tracks de una app."""

    package_name: str
    app_label: str = Field(description="Nombre legible: 'Baqueano Natales' o 'Baqueano Admin'")
    tracks: list[TrackVersion] = Field(default_factory=list)
    error: str | None = Field(default=None, description="Error de la API si no se pudo leer")


class TracksResponse(BaseModel):
    """Tracks de las 2 apps (client + admin)."""

    client: AppTracks
    admin: AppTracks


# ============================================================
# Links de descarga (para compartir)
# ============================================================
class AppLinks(BaseModel):
    """Links de descarga de una app."""

    package_name: str
    app_label: str
    opt_in_url: str = Field(description="Link de opt-in para testers (internal testing)")
    play_store_url: str = Field(description="Link publico de Play Store")


class LinksResponse(BaseModel):
    """Links de descarga de las 2 apps."""

    client: AppLinks
    admin: AppLinks


# ============================================================
# Health consolidado
# ============================================================
class ComponentHealth(BaseModel):
    """Estado de un componente del sistema."""

    name: str
    status: Literal["ok", "degraded", "down"]
    detail: str | None = None


class SystemHealth(BaseModel):
    """Estado consolidado del sistema para el panel admin."""

    environment: str
    version: str
    timestamp: datetime
    components: list[ComponentHealth]

    # Ultimo release exitoso
    last_successful_release: RunInfo | None = None

    # Estadisticas rapidas
    total_runs_last_24h: int = 0
    failed_runs_last_24h: int = 0

    # Links de descarga (atajo)
    links: LinksResponse

# ============================================================
# Quick links (accesos rapidos a dashboards externos)
# ============================================================
class QuickLink(BaseModel):
    """Un link a un dashboard o herramienta externa."""

    id: str
    label: str
    description: str | None = None
    url: str
    icon: str = Field(description="Nombre semantico del icono")


class QuickLinkCategory(BaseModel):
    """Una categoria de links (ej. Play Console, GitHub)."""

    id: str
    label: str
    icon: str
    links: list[QuickLink]


class QuickLinksResponse(BaseModel):
    """Respuesta con todas las categorias y links."""

    categories: list[QuickLinkCategory]


# ============================================================
# Fase 2 - Release trigger (preview + confirm)
# ============================================================
class ReleasePreviewRequest(BaseModel):
    """Input para pedir el preview de un release."""

    version_name: str = Field(
        description="Version sin '+N', ej. '0.3.5'",
        pattern=r"^\d+\.\d+\.\d+$",
    )
    branch: str = Field(default="main", description="Branch a taggear")


class ValidationCheck(BaseModel):
    """Una validacion previa al release."""

    name: str
    status: Literal["ok", "warning", "error"]
    detail: str | None = None


class ReleasePreviewResponse(BaseModel):
    """Preview de lo que va a pasar si se ejecuta el release."""

    # Versiones calculadas
    current_version: str = Field(description="Ej. '0.3.4+7'")
    target_version: str = Field(description="Ej. '0.3.5+8'")
    target_tag: str = Field(description="Ej. 'v0.3.5'")
    next_version_code: int

    # Estado del branch objetivo
    head_sha: str
    head_commit_message: str
    head_commit_age_minutes: int | None = None

    # Validaciones
    validations: list[ValidationCheck]
    can_proceed: bool = Field(description="True si no hay validaciones en 'error'")

    # Estimaciones
    estimated_duration_min: int
    workflow_name: str = Field(description="Workflow que se va a disparar")

    # Preview token (firma lo que el usuario vio)
    preview_token: str
    expires_at: datetime


class ReleaseTriggerRequest(BaseModel):
    """Input para ejecutar el release (2c). Requiere el preview_token previo."""

    preview_token: str
    confirm: str = Field(description="Debe ser exactamente 'CONFIRMAR'")

class ReleaseTriggerResponse(BaseModel):
    """Respuesta del trigger de release."""

    tag: str = Field(description="Tag creado, ej. 'v0.3.5'")
    commit_sha: str = Field(description="SHA del commit taggeado")
    workflow_name: str
    estimated_duration_min: int
    github_url: str = Field(description="URL del repo para ver el workflow corriendo")
    audit_log_id: str = Field(description="ID del registro en ops_audit_log")
    message: str = Field(description="Mensaje de exito")