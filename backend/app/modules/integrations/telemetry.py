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

from sqlalchemy import func, or_, select
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
    q: str | None = None,
    remaining_min: int | None = None,
    remaining_max: int | None = None,
    duration_min: int | None = None,
    duration_max: int | None = None,
    has_error: bool | None = None,
    sort_by: str = "created_at",
    sort_order: str = "desc",
    limit: int = 50,
    offset: int = 0,
) -> tuple[list[ApiUsageEvent], int]:
    """Devuelve (eventos, total) con filtros avanzados y sorting dinamico.

    Busqueda de texto (q): ILIKE sobre input_value y error_message.
    Rangos: remaining y duration_ms son inclusivos [min, max].
    has_error: True = solo con error_message, False = solo exitosos, None = todos.
    """
    conditions = []
    if api is not None:
        conditions.append(ApiUsageEvent.api == api)
    if was_cached is not None:
        conditions.append(ApiUsageEvent.was_cached == was_cached)
    if date_from is not None:
        conditions.append(ApiUsageEvent.created_at >= date_from)
    if date_to is not None:
        conditions.append(ApiUsageEvent.created_at <= date_to)
    if q:
        safe = q.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")
        pattern = f"%{safe}%"
        conditions.append(
            or_(
                ApiUsageEvent.input_value.ilike(pattern, escape="\\"),
                ApiUsageEvent.error_message.ilike(pattern, escape="\\"),
            )
        )
    if remaining_min is not None:
        conditions.append(ApiUsageEvent.remaining >= remaining_min)
    if remaining_max is not None:
        conditions.append(ApiUsageEvent.remaining <= remaining_max)
    if duration_min is not None:
        conditions.append(ApiUsageEvent.duration_ms >= duration_min)
    if duration_max is not None:
        conditions.append(ApiUsageEvent.duration_ms <= duration_max)
    if has_error is True:
        conditions.append(ApiUsageEvent.error_message.is_not(None))
    elif has_error is False:
        conditions.append(ApiUsageEvent.error_message.is_(None))

    count_query = select(func.count(ApiUsageEvent.id))
    data_query = select(ApiUsageEvent)
    for cond in conditions:
        count_query = count_query.where(cond)
        data_query = data_query.where(cond)

    sort_cols = {
        "created_at": ApiUsageEvent.created_at,
        "duration_ms": ApiUsageEvent.duration_ms,
        "remaining": ApiUsageEvent.remaining,
    }
    sort_col = sort_cols.get(sort_by, ApiUsageEvent.created_at)
    if sort_order == "asc":
        data_query = data_query.order_by(sort_col.asc().nullslast())
    else:
        data_query = data_query.order_by(sort_col.desc().nullslast())

    total = (await db.execute(count_query)).scalar_one()
    data_query = data_query.limit(limit).offset(offset)
    result = await db.execute(data_query)
    return list(result.scalars().all()), total


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
