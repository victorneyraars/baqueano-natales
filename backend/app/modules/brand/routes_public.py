"""Endpoints públicos del brand kit (sin auth).

Sirven assets para consumidores externos:
- JSON-LD `logo` (Google, Schema.org)
- og-image / Open Graph (WhatsApp, Facebook, Twitter)
- cualquier cliente que necesite el logo del prestador

Cache largo (24h) porque el logo no cambia seguido.
"""
from fastapi import APIRouter, HTTPException, Query, status
from fastapi.responses import FileResponse

from . import services

router_public = APIRouter(
    prefix="/public/brand",
    tags=["brand-public"],
)

SIZES_LOGO = (512, 1024, 2048)
SIZES_SYMBOL = (512, 1024)


@router_public.get("/{slug}/logo.png")
async def get_logo_public(
    slug: str,
    size: int = Query(512, description="512, 1024 o 2048"),
):
    """Sirve el logo horizontal del brand kit sin auth."""
    if size not in SIZES_LOGO:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"size debe ser uno de {SIZES_LOGO}",
        )

    try:
        target = services.get_asset_path(
            slug, f"print/logo-{size}.png",
        )
    except FileNotFoundError:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Logo no encontrado: {slug}",
        )
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="path invalido",
        )

    return FileResponse(
        path=str(target),
        media_type="image/png",
        headers={
            "Cache-Control": "public, max-age=86400, immutable",
            "ETag": f"{slug}-logo-{size}",
        },
    )


@router_public.get("/{slug}/symbol.png")
async def get_symbol_public(
    slug: str,
    size: int = Query(512, description="512 o 1024"),
):
    """Sirve el simbolo cuadrado (V sola) sin auth."""
    if size not in SIZES_SYMBOL:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"size debe ser uno de {SIZES_SYMBOL}",
        )

    try:
        target = services.get_asset_path(
            slug, f"print/symbol-{size}.png",
        )
    except FileNotFoundError:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Simbolo no encontrado: {slug}",
        )
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="path invalido",
        )

    return FileResponse(
        path=str(target),
        media_type="image/png",
        headers={
            "Cache-Control": "public, max-age=86400, immutable",
            "ETag": f"{slug}-symbol-{size}",
        },
    )