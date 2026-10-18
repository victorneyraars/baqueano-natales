"""
Webhook para revalidar páginas de la web pública en Vercel (ISR).
"""
import httpx
from fastapi import APIRouter, BackgroundTasks, HTTPException, Header
from app.core.config import settings

router = APIRouter(prefix="/ops", tags=["ops"])

async def _trigger_vercel_revalidation(paths: list[str]):
    """Dispara la revalidación en Vercel para las rutas dadas."""
    vercel_url = settings.PUBLIC_WEB_URL
    bypass_token = settings.VERCEL_BYPASS_TOKEN
    if not vercel_url or not bypass_token:
        return

    async with httpx.AsyncClient() as client:
        for path in paths:
            url = f"{vercel_url.rstrip('/')}{path}"
            headers = {"x-prerender-revalidate": bypass_token}
            try:
                await client.head(url, headers=headers, timeout=10.0)
            except Exception as e:
                print(f"Error revalidando {path}: {e}")

@router.post("/webhooks/revalidate")
async def revalidate_webhook(
    payload: dict,
    background_tasks: BackgroundTasks,
    x_api_key: str = Header(None),
):
    """Endpoint para que la app notifique cambios.
    Ejemplo: {"paths": ["/prestadores", "/prestadores/taller-mecanico-del-sur"]}
    """
    if x_api_key != settings.REVALIDATE_API_KEY:
        raise HTTPException(status_code=403, detail="Invalid API Key")

    paths = payload.get("paths", [])
    if not paths:
        raise HTTPException(status_code=400, detail="No paths provided")

    background_tasks.add_task(_trigger_vercel_revalidation, paths)
    return {"status": "revalidation_scheduled", "paths": paths}
