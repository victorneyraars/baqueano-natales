import httpx
from fastapi import APIRouter, HTTPException, status
from app.core.config import settings
from cachetools import TTLCache

router = APIRouter(prefix="/integrations", tags=["integrations"])
BOOSTR_BASE_URL = "https://api.boostr.cl"

cache_rut = TTLCache(maxsize=1000, ttl=86400)
cache_patente = TTLCache(maxsize=1000, ttl=86400)

api_stats = {
    "rut": {"api_calls": 0, "cached_hits": 0, "limit": 5, "remaining": 5, "reset_seconds": 0, "credits_remaining": None},
    "patente": {"api_calls": 0, "cached_hits": 0, "limit": 5, "remaining": 5, "reset_seconds": 0, "credits_remaining": None},
}


@router.get("/rut/{rut}", summary="Consultar RUT en Boostr")
async def consultar_rut(rut: str):
    if rut in cache_rut:
        api_stats["rut"]["cached_hits"] += 1
        return {"cached": True, "data": cache_rut[rut]}
    if not settings.BOOSTR_RUT_API_KEY:
        raise HTTPException(status_code=500, detail="Falta BOOSTR_RUT_API_KEY")
    url = f"{BOOSTR_BASE_URL}/rut/name/{rut}.json"
    headers = {"accept": "application/json", "X-API-KEY": settings.BOOSTR_RUT_API_KEY}
    async with httpx.AsyncClient(timeout=10.0) as client:
        res = await client.get(url, headers=headers)
        api_stats["rut"]["api_calls"] += 1
        api_stats["rut"]["limit"] = int(res.headers.get("ratelimit-limit", 5))
        api_stats["rut"]["remaining"] = int(res.headers.get("ratelimit-remaining", 5))
        api_stats["rut"]["reset_seconds"] = int(res.headers.get("ratelimit-reset", 0))
        api_stats["rut"]["credits_remaining"] = res.headers.get("x-remaining-credits")
        try:
            data = res.json()
            if data.get("status") == "error":
                raise HTTPException(status_code=400, detail=data.get("message", "Error en Boostr"))
            cache_rut[rut] = data
            return {"cached": False, "data": data}
        except ValueError:
            raise HTTPException(status_code=res.status_code, detail=f"Error Boostr: {res.text[:200]}")

@router.get("/patente/{patente}", summary="Consultar Patente en Boostr")
async def consultar_patente(patente: str):
    if patente in cache_patente:
        api_stats["patente"]["cached_hits"] += 1
        return {"cached": True, "data": cache_patente[patente]}
    if not settings.BOOSTR_PATENTE_API_KEY:
        raise HTTPException(status_code=500, detail="Falta BOOSTR_PATENTE_API_KEY")
    url = f"{BOOSTR_BASE_URL}/vehicle/{patente}.json"
    headers = {"accept": "application/json", "X-API-KEY": settings.BOOSTR_PATENTE_API_KEY}
    async with httpx.AsyncClient(timeout=10.0) as client:
        res = await client.get(url, headers=headers)
        api_stats["patente"]["api_calls"] += 1
        api_stats["patente"]["limit"] = int(res.headers.get("ratelimit-limit", 5))
        api_stats["patente"]["remaining"] = int(res.headers.get("ratelimit-remaining", 5))
        api_stats["patente"]["reset_seconds"] = int(res.headers.get("ratelimit-reset", 0))
        api_stats["patente"]["credits_remaining"] = res.headers.get("x-remaining-credits")
        try:
            data = res.json()
            if data.get("status") == "error":
                raise HTTPException(status_code=400, detail=data.get("message", "Error en Boostr"))
            cache_patente[patente] = data
            return {"cached": False, "data": data}
        except ValueError:
            raise HTTPException(status_code=res.status_code, detail=f"Error Boostr: {res.text[:200]}")

@router.get("/stats", summary="Obtener estadísticas de consumo de las APIs")
async def get_stats():
    """Devuelve el estado actual del rate limit y consumo de caché."""
    return api_stats
