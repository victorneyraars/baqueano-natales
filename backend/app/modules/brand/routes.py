"""Endpoints públicos del brand kit."""
import mimetypes
from fastapi import APIRouter, HTTPException, Response, status
from fastapi.responses import FileResponse
from app.modules.social.deps import CurrentUser
from . import services

router_propietario = APIRouter(prefix="/mis-brand", tags=["brand-propietario"])

@router_propietario.get("/available")
async def list_available(_user: CurrentUser):
    return {"slugs": services.list_available()}

@router_propietario.get("/{slug}/assets/list")
async def list_assets(slug: str, _user: CurrentUser):
    """Lista todos los assets agrupados por categoria.

    Devuelve path, name, category, size_bytes, content_type y dimensions
    (para PNGs). El frontend usa esto para preview + descarga individual.
    """
    try:
        return services.list_assets(slug)
    except FileNotFoundError:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Brand kit no encontrado: {slug}",
        )


@router_propietario.get("/{slug}/assets/file/{path:path}")
async def get_asset_file(
    slug: str,
    path: str,
    _user: CurrentUser,
):
    """Descarga un asset individual con Content-Type correcto.

    Sanitiza path traversal y valida que el archivo este dentro del
    brand kit del slug.
    """
    try:
        target = services.get_asset_path(slug, path)
    except FileNotFoundError:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Asset no encontrado: {path}",
        )
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e),
        )

    content_type, _ = mimetypes.guess_type(str(target))
    return FileResponse(
        path=str(target),
        media_type=content_type or "application/octet-stream",
        filename=target.name,
    )


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