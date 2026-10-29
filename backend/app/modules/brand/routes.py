"""Endpoints públicos del brand kit."""
from fastapi import APIRouter, HTTPException, Response, status
from app.modules.social.deps import CurrentUser
from . import services

router_propietario = APIRouter(prefix="/mis-brand", tags=["brand-propietario"])

@router_propietario.get("/available")
async def list_available(_user: CurrentUser):
    return {"slugs": services.list_available()}

@router_propietario.get("/{slug}/assets")
async def download_kit(slug: str, _user: CurrentUser):
    try:
        zip_bytes, filename = services.build_zip(slug)
    except FileNotFoundError:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Brand kit no encontrado: {slug}",
        )

    return Response(
        content=zip_bytes,
        media_type="application/zip",
        headers={
            "Content-Disposition": f"attachment; filename={filename}",
            "Content-Length": str(len(zip_bytes)),
        },
    )