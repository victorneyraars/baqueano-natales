"""Endpoints de integración con APIs externas (Boostr).

BFF: oculta las API Keys del cliente.
Caché TTL 24h: evita re-consultas al mismo input.
Telemetría: persiste cada consulta en api_usage_events para analytics.
"""
import re
import time
from datetime import datetime, timezone
from typing import Optional

import httpx
from fastapi import APIRouter, HTTPException, Query
from cachetools import TTLCache

from app.core.config import settings
from app.core.db import DbSession
from app.modules.auth.deps import AdminUser
from app.modules.integrations.deps import AuthorizedIntegrations
from app.modules.integrations import telemetry

router = APIRouter(prefix="/integrations", tags=["integrations"])
BOOSTR_BASE_URL = "https://api.boostr.cl"

cache_rut: TTLCache = TTLCache(maxsize=1000, ttl=86400)
cache_patente: TTLCache = TTLCache(maxsize=1000, ttl=86400)

api_stats: dict = {
    "rut": {"api_calls": 0, "cached_hits": 0, "limit": 5, "remaining": 5,
            "reset_seconds": 0, "last_query_at": None, "credits_remaining": None},
    "patente": {"api_calls": 0, "cached_hits": 0, "limit": 5, "remaining": 5,
                "reset_seconds": 0, "last_query_at": None, "credits_remaining": None},
}


def _now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def _reset_seconds_now(api: str) -> int:
    s = api_stats[api]
    raw = s.get("reset_seconds") or 0
    last = s.get("last_query_at")
    if not last or raw <= 0:
        return 0
    try:
        elapsed = (datetime.now(timezone.utc) - datetime.fromisoformat(last)).total_seconds()
        return max(0, int(raw - elapsed))
    except Exception:
        return 0


def _update_stats_from_headers(api: str, res) -> None:
    s = api_stats[api]
    s["api_calls"] += 1
    s["limit"] = int(res.headers.get("ratelimit-limit", s["limit"]))
    s["remaining"] = int(res.headers.get("ratelimit-remaining", s["remaining"]))
    s["reset_seconds"] = int(res.headers.get("ratelimit-reset", 0))
    s["last_query_at"] = _now_iso()
    s["credits_remaining"] = res.headers.get("x-remaining-credits")


async def _log_and_commit(db, api: str, input_value: str, was_cached: bool,
                          duration_ms: int, error_message: str | None = None) -> None:
    s = api_stats[api]
    await telemetry.log_event(
        db=db, api=api, input_value=input_value, was_cached=was_cached,
        remaining=s["remaining"], api_limit=s["limit"],
        reset_seconds=s["reset_seconds"],
        duration_ms=duration_ms, error_message=error_message,
    )
    await db.commit()


@router.get("/rut/{rut}")
async def consultar_rut(rut: str, db: DbSession):
    started = time.monotonic()
    if rut in cache_rut:
        api_stats["rut"]["cached_hits"] += 1
        await _log_and_commit(db, "rut", rut, True, int((time.monotonic() - started) * 1000))
        return {"cached": True, "data": cache_rut[rut]}

    if not settings.BOOSTR_RUT_API_KEY:
        raise HTTPException(status_code=500, detail="Falta BOOSTR_RUT_API_KEY")

    url = f"{BOOSTR_BASE_URL}/rut/name/{rut}.json"
    headers = {"accept": "application/json", "X-API-KEY": settings.BOOSTR_RUT_API_KEY}

    async with httpx.AsyncClient(timeout=10.0) as client:
        res = await client.get(url, headers=headers)
        _update_stats_from_headers("rut", res)
        duration_ms = int((time.monotonic() - started) * 1000)
        try:
            data = res.json()
            if data.get("status") == "error":
                err = str(data.get("message", "Error en Boostr"))[:255]
                await _log_and_commit(db, "rut", rut, False, duration_ms, err)
                raise HTTPException(status_code=400, detail=err)
            cache_rut[rut] = data
            await _log_and_commit(db, "rut", rut, False, duration_ms)
            return {"cached": False, "data": data}
        except ValueError:
            err = f"Non-JSON: {res.text[:100]}"
            await _log_and_commit(db, "rut", rut, False, duration_ms, err)
            raise HTTPException(status_code=res.status_code, detail=f"Error Boostr: {res.text[:200]}")


_LETRAS_AUTO = "BCDFGHJKLMNPQRSTVWXYZ"
_PATRONES_AUTO = [
    re.compile(r"^[" + _LETRAS_AUTO + r"]{2}\d{4}$"),  # AB1234 (antiguo)
    re.compile(r"^[" + _LETRAS_AUTO + r"]{4}\d{2}$"),  # ABCD12 (2007-2026)
    re.compile(r"^[" + _LETRAS_AUTO + r"]{5}\d{1}$"),  # BBBBB0 (desde jul 2026)
]


def _validar_patente_auto(patente: str) -> str:
    """Normaliza y valida una patente de auto chileno.

    Devuelve la patente limpia (mayusculas, sin puntos/guiones/espacios)
    o lanza HTTPException(400) si el formato no corresponde a un auto.
    """
    p_limpia = (
        patente.strip().upper().replace(".", "").replace("-", "").replace(" ", "")
    )
    if len(p_limpia) != 6:
        raise HTTPException(
            status_code=400,
            detail=(
                "Patente invalida: debe tener 6 caracteres (sin puntos ni guiones)."
            ),
        )
    if not any(patron.match(p_limpia) for patron in _PATRONES_AUTO):
        raise HTTPException(
            status_code=400,
            detail=(
                "Patente invalida para auto. Formatos aceptados: "
                "AB1234 (antiguo), ABCD12 (2007-2026) o BBBBB0 (desde jul 2026). "
                "No se permiten vocales ni las letras M, N, N-tilde, Q."
            ),
        )
    return p_limpia


@router.get("/patente/{patente}")
async def consultar_patente(patente: str, db: DbSession):
    patente = _validar_patente_auto(patente)
    started = time.monotonic()
    if patente in cache_patente:
        api_stats["patente"]["cached_hits"] += 1
        await _log_and_commit(db, "patente", patente, True, int((time.monotonic() - started) * 1000))
        return {"cached": True, "data": cache_patente[patente]}

    if not settings.BOOSTR_PATENTE_API_KEY:
        raise HTTPException(status_code=500, detail="Falta BOOSTR_PATENTE_API_KEY")

    url = f"{BOOSTR_BASE_URL}/vehicle/{patente}.json"
    headers = {"accept": "application/json", "X-API-KEY": settings.BOOSTR_PATENTE_API_KEY}

    async with httpx.AsyncClient(timeout=10.0) as client:
        res = await client.get(url, headers=headers)
        _update_stats_from_headers("patente", res)
        duration_ms = int((time.monotonic() - started) * 1000)
        try:
            data = res.json()
            if data.get("status") == "error":
                err = str(data.get("message", "Error en Boostr"))[:255]
                await _log_and_commit(db, "patente", patente, False, duration_ms, err)
                raise HTTPException(status_code=400, detail=err)
            cache_patente[patente] = data
            await _log_and_commit(db, "patente", patente, False, duration_ms)
            return {"cached": False, "data": data}
        except ValueError:
            err = f"Non-JSON: {res.text[:100]}"
            await _log_and_commit(db, "patente", patente, False, duration_ms, err)
            raise HTTPException(status_code=res.status_code, detail=f"Error Boostr: {res.text[:200]}")


@router.get("/stats")
async def get_stats(_: AuthorizedIntegrations):
    return {
        "rut": {**api_stats["rut"], "reset_seconds_now": _reset_seconds_now("rut")},
        "patente": {**api_stats["patente"], "reset_seconds_now": _reset_seconds_now("patente")},
    }


@router.get("/stats/history")
async def get_stats_history(
    _: AuthorizedIntegrations,
    db: DbSession,
    api: Optional[str] = Query(None, pattern="^(rut|patente)$"),
    was_cached: Optional[bool] = Query(None),
    date_from: Optional[datetime] = Query(None),
    date_to: Optional[datetime] = Query(None),
    q: Optional[str] = Query(None, max_length=100),
    remaining_min: Optional[int] = Query(None, ge=0),
    remaining_max: Optional[int] = Query(None, ge=0),
    duration_min: Optional[int] = Query(None, ge=0),
    duration_max: Optional[int] = Query(None, ge=0),
    has_error: Optional[bool] = Query(None),
    sort_by: str = Query("created_at", pattern="^(created_at|duration_ms|remaining)$"),
    sort_order: str = Query("desc", pattern="^(asc|desc)$"),
    limit: int = Query(50, ge=1, le=500),
    offset: int = Query(0, ge=0),
):
    events, total = await telemetry.get_recent_events(
        db, api=api, was_cached=was_cached,
        date_from=date_from, date_to=date_to,
        q=q,
        remaining_min=remaining_min, remaining_max=remaining_max,
        duration_min=duration_min, duration_max=duration_max,
        has_error=has_error,
        sort_by=sort_by, sort_order=sort_order,
        limit=limit, offset=offset,
    )
    return {
        "items": [
            {
                "id": str(e.id),
                "api": e.api,
                "input_value": e.input_value,
                "was_cached": e.was_cached,
                "remaining": e.remaining,
                "api_limit": e.api_limit,
                "reset_seconds": e.reset_seconds,
                "duration_ms": e.duration_ms,
                "error_message": e.error_message,
                "created_at": e.created_at.isoformat() if e.created_at else None,
            }
            for e in events
        ],
        "total": total,
        "limit": limit,
        "offset": offset,
        "count": len(events),
        "has_more": (offset + len(events)) < total,
    }


@router.get("/stats/analytics")
async def get_stats_analytics(
    _: AuthorizedIntegrations,
    db: DbSession,
    days: int = Query(30, ge=1, le=365),
):
    return await telemetry.get_analytics(db, days=days)
