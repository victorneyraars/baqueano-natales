"""Links de descarga de las apps (para compartir con testers).

Simple: no llama a ninguna API. Los links vienen de config.py.
"""
from app.core.config import settings
from app.modules.ops.schemas import AppLinks, LinksResponse


def obtener_links() -> LinksResponse:
    """Retorna los links de descarga de las 2 apps."""
    return LinksResponse(
        client=AppLinks(
            package_name=settings.PLAY_PACKAGE_CLIENT,
            app_label="Baqueano Natales",
            opt_in_url=settings.PLAY_OPT_IN_CLIENT,
            play_store_url=f"https://play.google.com/store/apps/details?id={settings.PLAY_PACKAGE_CLIENT}",
        ),
        admin=AppLinks(
            package_name=settings.PLAY_PACKAGE_ADMIN,
            app_label="Baqueano Admin",
            opt_in_url=settings.PLAY_OPT_IN_ADMIN,
            play_store_url=f"https://play.google.com/store/apps/details?id={settings.PLAY_PACKAGE_ADMIN}",
        ),
    )
