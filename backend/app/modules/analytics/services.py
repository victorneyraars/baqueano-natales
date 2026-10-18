"""Cliente GraphQL de Cloudflare Web Analytics."""
import logging
from datetime import date, timedelta
from typing import Any

import httpx

from app.core.config import settings
from app.modules.analytics.schemas import (
    StatsRequest, StatsResponse, TopItem, VisitaDia,
)

logger = logging.getLogger(__name__)

CF_GRAPHQL_URL = "https://api.cloudflare.com/client/v4/graphql"


def _get_cf_credentials() -> dict[str, str]:
    """Devuelve headers de autenticación para Cloudflare."""
    api_email = getattr(settings, "CLOUDFLARE_API_EMAIL", None) or ""
    api_key = getattr(settings, "CLOUDFLARE_API_KEY", None) or ""
    api_token = getattr(settings, "CLOUDFLARE_ANALYTICS_TOKEN", None) or ""

    if api_email and api_key:
        return {
            "X-Auth-Email": api_email,
            "X-Auth-Key": api_key,
            "Content-Type": "application/json",
        }
    if api_token:
        return {
            "Authorization": f"Bearer {api_token}",
            "Content-Type": "application/json",
        }
    raise RuntimeError(
        "Faltan credenciales: CLOUDFLARE_API_EMAIL+CLOUDFLARE_API_KEY o CLOUDFLARE_ANALYTICS_TOKEN"
    )


async def fetch_web_analytics(request: StatsRequest) -> StatsResponse:
    """Consulta Cloudflare Web Analytics vía GraphQL."""
    headers = _get_cf_credentials()
    account_id = getattr(settings, "CLOUDFLARE_ACCOUNT_ID", "")

    # Fechas ISO 8601
    # Until = HOY a las 00:00 UTC (excluye las horas parciales de hoy)
    # Esto evita datos incompletos y rate limiting
    # Clampear since a la fecha de lanzamiento del sitio (11 oct 2026)
    # Antes de esa fecha, no hay datos (devuelve 0 y rompe la agregación)
    LAUNCH_DATE = date(2026, 10, 11)
    since_date = date.today() - timedelta(days=request.days)
    if since_date < LAUNCH_DATE:
        since_date = LAUNCH_DATE

    since = since_date.strftime("%Y-%m-%dT00:00:00Z")
    until = date.today().strftime("%Y-%m-%dT23:59:59Z")

    # Filtro base (fechas + hostname opcional)
    filter_obj: dict[str, Any] = {
        "datetime_geq": since,
        "datetime_leq": until,
        "bot": 0,  # Excluir tráfico de bots (0 = no bots)
    }
    if request.hostname:
        filter_obj["requestHost"] = request.hostname

    # Query GraphQL — nombres correctos según introspección
    # Query simplificado: solo 2 subqueries (porDia + porPath)
    # Evita rate limiting de Cloudflare (5 subqueries era demasiado)
    query = """
    query GetWebAnalytics($accountTag: string!, $filter: AccountRumPageloadEventsAdaptiveGroupsFilter_InputObject!) {
      viewer {
        accounts(filter: { accountTag: $accountTag }) {
          porDia: rumPageloadEventsAdaptiveGroups(
            limit: 100,
            filter: $filter,
            orderBy: [date_ASC]
          ) {
            count
            dimensions { date }
          }
          porPath: rumPageloadEventsAdaptiveGroups(
            limit: 10,
            filter: $filter,
            orderBy: [count_DESC]
          ) {
            count
            dimensions { requestPath }
          }
        }
      }
    }
    """

    payload = {
        "query": query,
        "variables": {
            "accountTag": account_id,
            "filter": filter_obj,
        },
    }

    async with httpx.AsyncClient(timeout=30.0) as client:
        response = await client.post(CF_GRAPHQL_URL, json=payload, headers=headers)

    if response.status_code != 200:
        logger.error("CF GraphQL error: %s %s", response.status_code, response.text[:500])
        raise RuntimeError(f"Cloudflare GraphQL {response.status_code}: {response.text[:200]}")

    data = response.json()
    if data.get("errors"):
        logger.error("CF GraphQL errors: %s", data["errors"])
        raise RuntimeError(f"Cloudflare: {data['errors']}")

    accounts = data.get("data", {}).get("viewer", {}).get("accounts", [])
    if not accounts:
        return StatsResponse(
            period_days=request.days, hostname=request.hostname,
            total_visits=0, total_pageviews=0,
            by_day=[], top_countries=[], top_referrers=[], top_pages=[],
        )

    acc = accounts[0]

    # Por día
    by_day: list[VisitaDia] = []
    for row in acc.get("porDia", []):
        d = row["dimensions"]["date"]
        by_day.append(VisitaDia(
            date=date.fromisoformat(d),
            visits=row["count"],
            pageviews=row["count"],  # Pageloads = pageviews en Cloudflare RUM
        ))
    by_day.sort(key=lambda x: x.date)

    def _to_top(items: list[dict[str, Any]], key: str) -> list[TopItem]:
        return [
            TopItem(name=item["dimensions"].get(key) or "Desconocido", count=item["count"])
            for item in items
        ]

    total = sum(v.visits for v in by_day)

    # top_countries y top_referrers: temporalmente vacíos (rate limit)
    # TODO: agregar de vuelta cuando se optimice el query (con cache o batching)
    return StatsResponse(
        period_days=request.days,
        hostname=request.hostname,
        total_visits=total,
        total_pageviews=total,
        by_day=by_day,
        top_countries=[],
        top_referrers=[],
        top_pages=_to_top(acc.get("porPath", []), "requestPath"),
    )
