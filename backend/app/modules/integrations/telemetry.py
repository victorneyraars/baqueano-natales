"""Funciones puras de telemetría para las consultas a Boostr.

Responsabilidades:
- log_event: persiste cada consulta (API o caché) en api_usage_events.
- get_recent_events: historial paginado con filtros opcionales.
- get_analytics: agregados SQL para capacity planning (últimos N días).

Diseño: funciones puras (reciben db como parámetro) para facilitar tests
unitarios y ser consumidas por cualquier endpoint futuro sin acoplamiento.
"""
from datetime import datetime, timedelta, timezone
from uuid import UUID

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.modules.integrations.models import ApiUsageEvent


async def log_event(
    db: AsyncSession,
    api: str,
    input_value: str,
    was_cached: bool,
    remaining: int | None = None,
    api_limit: int | None = None,
    reset_seconds: int | None = None,
    duration_ms: int | None = None,
    error_message: str | None = None,
) -> ApiUsageEvent:
    """Persiste un evento de consulta. Llamado en RUT/Patente post-respuesta."""
    event = ApiUsageEvent(
        api=api,
        input_value=input_value,
        was_cached=was_cached,
        remaining=remaining,
        api_limit=api_limit,
        reset_seconds=reset_seconds,
        duration_ms=duration_ms,
        error_message=error_message,
    )
    db.add(event)
    await db.flush()
    return event


async def get_recent_events(
    db: AsyncSession,
    api: str | None = None,
    was_cached: bool | None = None,
    date_from: datetime | None = None,
    date_to: datetime | None = None,
    limit: int = 50,
    offset: int = 0,
) -> tuple[list[ApiUsageEvent], int]:
    """Devuelve (eventos, total) del historial paginado con filtros opcionales."""
    from sqlalchemy import func as sql_func

    conditions = []
    if api is not None:
        conditions.append(ApiUsageEvent.api == api)
    if was_cached is not None:
        conditions.append(ApiUsageEvent.was_cached == was_cached)
    if date_from is not None:
        conditions.append(ApiUsageEvent.created_at >= date_from)
    if date_to is not None:
        conditions.append(ApiUsageEvent.created_at <= date_to)

    count_query = select(sql_func.count(ApiUsageEvent.id))
    data_query = select(ApiUsageEvent)
    for cond in conditions:
        count_query = count_query.where(cond)
        data_query = data_query.where(cond)

    total = (await db.execute(count_query)).scalar_one()
    data_query = data_query.order_by(ApiUsageEvent.created_at.desc()).limit(limit).offset(offset)
    result = await db.execute(data_query)
    events = list(result.scalars().all())
    return events, total


async def get_analytics(db: AsyncSession, days: int = 30) -> dict:
    """Calcula agregados para capacity planning en los últimos N días."""
    cutoff = datetime.now(timezone.utc) - timedelta(days=days)

    # Total por API y por origen (caché vs API)
    total_query = select(
        ApiUsageEvent.api,
        ApiUsageEvent.was_cached,
        func.count(ApiUsageEvent.id).label("count"),
    ).where(ApiUsageEvent.created_at >= cutoff).group_by(
        ApiUsageEvent.api, ApiUsageEvent.was_cached
    )
    total_rows = (await db.execute(total_query)).all()

    # remaining mínimo registrado (para detectar "estás al 10% de la cuota")
    min_remaining_query = select(
        ApiUsageEvent.api,
        func.min(ApiUsageEvent.remaining).label("min_remaining"),
    ).where(
        ApiUsageEvent.created_at >= cutoff,
        ApiUsageEvent.remaining.is_not(None),
    ).group_by(ApiUsageEvent.api)
    min_rows = (await db.execute(min_remaining_query)).all()

    # Desglose diario (para proyectar consumo mensual)
    daily_query = select(
        ApiUsageEvent.api,
        func.date_trunc("day", ApiUsageEvent.created_at).label("day"),
        func.count(ApiUsageEvent.id).label("count"),
    ).where(ApiUsageEvent.created_at >= cutoff).group_by(
        ApiUsageEvent.api, "day"
    ).order_by("day")
    daily_rows = (await db.execute(daily_query)).all()

    # Hora pico (agrupando por hora del día)
    hour_query = select(
        func.extract("hour", ApiUsageEvent.created_at).label("hour"),
        func.count(ApiUsageEvent.id).label("count"),
    ).where(ApiUsageEvent.created_at >= cutoff).group_by("hour").order_by(
        func.count(ApiUsageEvent.id).desc()
    ).limit(1)
    hour_row = (await db.execute(hour_query)).first()

    # Construir respuesta agrupada por API
    analytics: dict = {
        "period_days": days,
        "cutoff": cutoff.isoformat(),
        "by_api": {},
        "daily": [],
        "peak_hour": None,
    }
    for api in ("rut", "patente"):
        api_total = next((r.count for r in total_rows if r.api == api and not r.was_cached), 0)
        api_cached = next((r.count for r in total_rows if r.api == api and r.was_cached), 0)
        total = api_total + api_cached
        analytics["by_api"][api] = {
            "total": total,
            "api_calls": api_total,
            "cached_hits": api_cached,
            "cache_ratio_pct": round((api_cached / total * 100), 1) if total > 0 else 0.0,
            "min_remaining": next((r.min_remaining for r in min_rows if r.api == api), None),
        }
    for row in daily_rows:
        analytics["daily"].append({
            "day": row.day.isoformat() if row.day else None,
            "api": row.api,
            "count": row.count,
        })
    if hour_row:
        analytics["peak_hour"] = {"hour": int(hour_row.hour), "count": hour_row.count}
    return analytics
