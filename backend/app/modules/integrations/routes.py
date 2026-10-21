import httpx
from fastapi import APIRouter, HTTPException, status
from app.core.config import settings

router = APIRouter(prefix="/integrations", tags=["integrations"])
BOOSTR_BASE_URL = "https://api.boostr.cl"

@router.get("/rut/{rut}", summary="Consultar RUT en Boostr")
async def consultar_rut(rut: str):
    if not settings.BOOSTR_RUT_API_KEY:
        raise HTTPException(status_code=500, detail="Falta BOOSTR_RUT_API_KEY")
    url = f"{BOOSTR_BASE_URL}/rut/{rut}.json"
    headers = {"accept": "application/json", "X-API-KEY": settings.BOOSTR_RUT_API_KEY}
    async with httpx.AsyncClient(timeout=10.0) as client:
        res = await client.get(url, headers=headers)
        data = res.json()
        if data.get("status") == "error":
            raise HTTPException(status_code=400, detail=data.get("message"))
        return data

@router.get("/patente/{patente}", summary="Consultar Patente en Boostr")
async def consultar_patente(patente: str):
    if not settings.BOOSTR_PATENTE_API_KEY:
        raise HTTPException(status_code=500, detail="Falta BOOSTR_PATENTE_API_KEY")
    url = f"{BOOSTR_BASE_URL}/vehicle/{patente}.json"
    headers = {"accept": "application/json", "X-API-KEY": settings.BOOSTR_PATENTE_API_KEY}
    async with httpx.AsyncClient(timeout=10.0) as client:
        res = await client.get(url, headers=headers)
        data = res.json()
        if data.get("status") == "error":
            raise HTTPException(status_code=400, detail=data.get("message"))
        return data
