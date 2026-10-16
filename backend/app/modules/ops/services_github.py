"""Cliente de GitHub Actions API para el Ops Dashboard.

Diseno:
- httpx.AsyncClient reutilizable (una instancia global).
- Cache en memoria con TTL configurable (default 20s) para reducir
  el consumo del rate limit de GitHub (5000 req/h con PAT).
- Manejo robusto de errores: nunca propaga excepciones al caller,
  siempre devuelve resultados tipados + campos `error`.
- Logging estructurado con el patron del proyecto.

Referencias API:
- List runs:     GET /repos/{owner}/{repo}/actions/runs
- Run detail:    GET /repos/{owner}/{repo}/actions/runs/{run_id}
- Run jobs:      GET /repos/{owner}/{repo}/actions/runs/{run_id}/jobs
"""
from __future__ import annotations

import logging
import time
from datetime import datetime
from typing import Any

import httpx

from app.core.config import settings
from app.modules.ops.schemas import (
    JobInfo,
    RunDetail,
    RunInfo,
    RunsResponse,
    StepInfo,
)

logger = logging.getLogger(__name__)


# ============================================================
# Cache en memoria (simple, por proceso)
# ============================================================
class _TTLCache:
    """Cache simple con TTL. Una entrada por clave."""

    def __init__(self, ttl_seconds: int) -> None:
        self._ttl = ttl_seconds
        self._store: dict[str, tuple[float, Any]] = {}

    def get(self, key: str) -> Any | None:
        entry = self._store.get(key)
        if not entry:
            return None
        expires_at, value = entry
        if time.monotonic() > expires_at:
            del self._store[key]
            return None
        return value

    def set(self, key: str, value: Any) -> None:
        self._store[key] = (time.monotonic() + self._ttl, value)

    def clear(self) -> None:
        self._store.clear()


_cache = _TTLCache(settings.GITHUB_OPS_CACHE_TTL_SEC)


# ============================================================
# HTTP client (global, lazy)
# ============================================================
_http_client: httpx.AsyncClient | None = None


def _get_http_client() -> httpx.AsyncClient:
    global _http_client
    if _http_client is None:
        _http_client = httpx.AsyncClient(
            base_url=settings.GITHUB_API_BASE,
            headers={
                "Authorization": f"Bearer {settings.GITHUB_OPS_TOKEN}",
                "Accept": "application/vnd.github+json",
                "X-GitHub-Api-Version": "2022-11-28",
                "User-Agent": "baqueano-ops-dashboard/1.0",
            },
            timeout=httpx.Timeout(10.0, connect=5.0),
        )
    return _http_client


async def close_http_client() -> None:
    """Cleanup al shutdown de la app (llamado desde lifespan)."""
    global _http_client
    if _http_client is not None:
        await _http_client.aclose()
        _http_client = None


# ============================================================
# Helpers
# ============================================================
def _parse_datetime(value: str | None) -> datetime | None:
    """Parsea un timestamp ISO 8601 de GitHub. Devuelve None si falla."""
    if not value:
        return None
    try:
        # GitHub usa formato "2026-10-14T12:00:00Z"
        return datetime.fromisoformat(value.replace("Z", "+00:00"))
    except (ValueError, TypeError):
        return None


def _compute_duration(created: str | None, updated: str | None) -> int | None:
    """Segundos entre created_at y updated_at."""
    c = _parse_datetime(created)
    u = _parse_datetime(updated)
    if not c or not u:
        return None
    return int((u - c).total_seconds())


def _run_info_from_api(data: dict[str, Any]) -> RunInfo:
    """Convierte la respuesta de GitHub al schema RunInfo."""
    return RunInfo(
        id=data["id"],
        name=data.get("name", ""),
        workflow_id=data.get("workflow_id", 0),
        event=data.get("event", ""),
        status=data.get("status", "unknown"),  # type: ignore[arg-type]
        conclusion=data.get("conclusion"),  # type: ignore[arg-type]
        head_branch=data.get("head_branch"),
        head_sha=data.get("head_sha", ""),
        run_number=data.get("run_number", 0),
        created_at=_parse_datetime(data.get("created_at")) or datetime.utcnow(),
        updated_at=_parse_datetime(data.get("updated_at")) or datetime.utcnow(),
        html_url=data.get("html_url", ""),
        duration_seconds=_compute_duration(
            data.get("created_at"), data.get("updated_at")
        ),
    )


# ============================================================
# API publica del service
# ============================================================
async def listar_runs(
    limit: int = 10,
    branch: str | None = None,
) -> RunsResponse:
    """Lista los ultimos N workflow runs del repo.

    Args:
        limit: maximo de runs a devolver (1-50).
        branch: filtrar por branch (opcional).

    Returns:
        RunsResponse con la lista. En caso de error, retorna una lista vacia
        y loguea el error (no propaga excepcion).
    """
    limit = max(1, min(limit, 50))
    cache_key = f"runs:{limit}:{branch or 'all'}"

    cached = _cache.get(cache_key)
    if cached is not None:
        logger.debug("ops.github.cache_hit", extra={"key": cache_key})
        return cached

    if not settings.GITHUB_OPS_TOKEN:
        logger.warning("ops.github.no_token")
        return RunsResponse(total_count=0, runs=[])

    try:
        client = _get_http_client()
        params: dict[str, Any] = {"per_page": limit}
        if branch:
            params["branch"] = branch

        r = await client.get(
            f"/repos/{settings.GITHUB_OPS_REPO}/actions/runs",
            params=params,
        )
        r.raise_for_status()
        data = r.json()

        runs = [_run_info_from_api(run) for run in data.get("workflow_runs", [])]
        response = RunsResponse(
            total_count=data.get("total_count", len(runs)),
            runs=runs,
        )
        _cache.set(cache_key, response)
        logger.info(
            "ops.github.runs_listed",
            extra={"count": len(runs), "total": response.total_count},
        )
        return response

    except httpx.HTTPStatusError as e:
        logger.error(
            "ops.github.http_error",
            extra={"status": e.response.status_code, "body": e.response.text[:200]},
        )
        return RunsResponse(total_count=0, runs=[])
    except httpx.RequestError as e:
        logger.error("ops.github.request_error", extra={"error": str(e)})
        return RunsResponse(total_count=0, runs=[])
    except Exception as e:
        logger.exception("ops.github.unexpected_error", extra={"error": str(e)})
        return RunsResponse(total_count=0, runs=[])


async def obtener_detalle_run(run_id: int) -> RunDetail | None:
    """Obtiene el detalle de un run con sus jobs + steps.

    Returns:
        RunDetail o None si el run no existe o hay error.
    """
    cache_key = f"run_detail:{run_id}"

    cached = _cache.get(cache_key)
    if cached is not None:
        return cached

    try:
        client = _get_http_client()

        # 1. Run detail
        r = await client.get(
            f"/repos/{settings.GITHUB_OPS_REPO}/actions/runs/{run_id}"
        )
        r.raise_for_status()
        run_data = r.json()

        # 2. Jobs + steps
        r_jobs = await client.get(
            f"/repos/{settings.GITHUB_OPS_REPO}/actions/runs/{run_id}/jobs"
        )
        r_jobs.raise_for_status()
        jobs_data = r_jobs.json()

        jobs: list[JobInfo] = []
        for job in jobs_data.get("jobs", []):
            steps = [
                StepInfo(
                    name=step.get("name", ""),
                    status=step.get("status", ""),
                    conclusion=step.get("conclusion"),
                    number=step.get("number", 0),
                    started_at=_parse_datetime(step.get("started_at")),
                    completed_at=_parse_datetime(step.get("completed_at")),
                )
                for step in job.get("steps", [])
            ]
            jobs.append(
                JobInfo(
                    id=job.get("id", 0),
                    name=job.get("name", ""),
                    status=job.get("status", ""),
                    conclusion=job.get("conclusion"),
                    started_at=_parse_datetime(job.get("started_at")),
                    completed_at=_parse_datetime(job.get("completed_at")),
                    steps=steps,
                )
            )

        base = _run_info_from_api(run_data)
        detail = RunDetail(**base.model_dump(), jobs=jobs)
        _cache.set(cache_key, detail)
        logger.info(
            "ops.github.run_detail_loaded",
            extra={"run_id": run_id, "jobs": len(jobs)},
        )
        return detail

    except httpx.HTTPStatusError as e:
        if e.response.status_code == 404:
            logger.warning("ops.github.run_not_found", extra={"run_id": run_id})
        else:
            logger.error(
                "ops.github.detail_http_error",
                extra={"run_id": run_id, "status": e.response.status_code},
            )
        return None
    except httpx.RequestError as e:
        logger.error(
            "ops.github.detail_request_error",
            extra={"run_id": run_id, "error": str(e)},
        )
        return None
    except Exception as e:
        logger.exception(
            "ops.github.detail_unexpected_error",
            extra={"run_id": run_id, "error": str(e)},
        )
        return None


async def obtener_ultimo_run_exitoso(workflow_name: str = "Release") -> RunInfo | None:
    """Retorna el ultimo run exitoso de un workflow especifico.

    Util para saber 'el ultimo release exitoso' sin traer todo el historial.
    """
    cache_key = f"last_success:{workflow_name}"
    cached = _cache.get(cache_key)
    if cached is not None:
        return cached if cached != "none" else None

    try:
        client = _get_http_client()
        r = await client.get(
            f"/repos/{settings.GITHUB_OPS_REPO}/actions/runs",
            params={
                "per_page": 10,
                "status": "completed",
            },
        )
        r.raise_for_status()
        data = r.json()

        for run in data.get("workflow_runs", []):
            if (
                run.get("name") == workflow_name
                and run.get("conclusion") == "success"
            ):
                info = _run_info_from_api(run)
                _cache.set(cache_key, info)
                return info

        _cache.set(cache_key, "none")
        return None

    except Exception as e:
        logger.error("ops.github.last_success_error", extra={"error": str(e)})
        return None


# ============================================================
# Fase 2 - Funciones de lectura para el release preview
# ============================================================
async def get_ref(ref: str) -> dict[str, Any] | None:
    """Lee un ref (tag o branch). Devuelve {ref, object: {sha, type}} o None."""
    try:
        client = _get_http_client()
        r = await client.get(f"/repos/{settings.GITHUB_OPS_REPO}/git/ref/{ref}")
        if r.status_code == 404:
            return None
        r.raise_for_status()
        return r.json()
    except httpx.HTTPStatusError as e:
        if e.response.status_code == 404:
            return None
        logger.error("ops.github.get_ref_error", extra={"ref": ref, "status": e.response.status_code})
        return None
    except Exception as e:
        logger.error("ops.github.get_ref_unexpected", extra={"ref": ref, "error": str(e)})
        return None


async def tag_exists(tag_name: str) -> bool:
    """True si el tag ya existe en el repo."""
    ref = await get_ref(f"tags/{tag_name}")
    return ref is not None


async def get_head_commit(branch: str = "main") -> dict[str, Any] | None:
    """Devuelve {sha, message, date} del ultimo commit del branch."""
    try:
        client = _get_http_client()
        r = await client.get(
            f"/repos/{settings.GITHUB_OPS_REPO}/commits/{branch}",
            params={"per_page": 1},
        )
        r.raise_for_status()
        data = r.json()
        commit = data.get("commit", {})
        return {
            "sha": data.get("sha", ""),
            "message": commit.get("message", "").split("\n")[0][:200],
            "date": commit.get("committer", {}).get("date"),
        }
    except Exception as e:
        logger.error("ops.github.get_head_error", extra={"branch": branch, "error": str(e)})
        return None


async def get_file_content(path: str, ref: str = "main") -> str | None:
    """Lee un archivo del repo. Devuelve el contenido (decodificado) o None."""
    import base64
    try:
        client = _get_http_client()
        r = await client.get(
            f"/repos/{settings.GITHUB_OPS_REPO}/contents/{path}",
            params={"ref": ref},
        )
        if r.status_code == 404:
            return None
        r.raise_for_status()
        data = r.json()
        if data.get("encoding") == "base64":
            content = base64.b64decode(data["content"]).decode("utf-8")
            return content
        return None
    except Exception as e:
        logger.error("ops.github.get_file_error", extra={"path": path, "error": str(e)})
        return None

# ============================================================
# Fase 2c - Funciones de escritura para el release trigger
# ============================================================
async def create_tag(
    tag_name: str,
    sha: str,
    message: str = "",
) -> dict[str, Any] | None:
    """Crea un tag ligero apuntando a un commit.

    Dispara workflows si el tag matchea el filtro (ej. v*).
    Devuelve la respuesta de GitHub ({ref, object: {sha, type}}) o None.
    """
    try:
        client = _get_http_client()
        r = await client.post(
            f"/repos/{settings.GITHUB_OPS_REPO}/git/refs",
            json={
                "ref": f"refs/tags/{tag_name}",
                "sha": sha,
            },
        )
        if r.status_code == 422:
            # Ya existe (race condition o validacion fallida)
            logger.warning(
                "ops.github.create_tag_conflict",
                extra={"tag": tag_name, "status": 422, "body": r.text[:300]},
            )
            return None
        r.raise_for_status()
        data = r.json()
        logger.info(
            "ops.github.tag_created",
            extra={"tag": tag_name, "sha": sha},
        )
        return data
    except httpx.HTTPStatusError as e:
        logger.error(
            "ops.github.create_tag_http_error",
            extra={
                "tag": tag_name,
                "status": e.response.status_code,
                "body": e.response.text[:300],
            },
        )
        return None
    except Exception as e:
        logger.exception(
            "ops.github.create_tag_unexpected",
            extra={"tag": tag_name, "error": str(e)},
        )
        return None