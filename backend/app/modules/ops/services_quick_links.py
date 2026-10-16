# DEPLOY_TEST_2026-10-16 02:01:52

"""Quick links a dashboards externos (Play Console, GitHub, Cloudflare, etc.)."""
from app.core.config import settings
from app.modules.ops.schemas import QuickLink, QuickLinkCategory, QuickLinksResponse


def _base_play_console() -> str:
    return f"https://play.google.com/console/u/0/developers/{settings.PLAY_CONSOLE_DEV_ID}"


def _url_play_app(app_id: str, path: str) -> str:
    if not app_id:
        return f"{_base_play_console()}/app-list"
    return f"{_base_play_console()}/app/{app_id}/{path}"


def _play_links() -> list[QuickLink]:
    client_id = settings.PLAY_CONSOLE_APP_ID_CLIENT
    admin_id = settings.PLAY_CONSOLE_APP_ID_ADMIN
    return [
        QuickLink(
            id="play-testers-client",
            label="Testers - Baqueano Natales",
            description="Ver y gestionar la lista de testers del internal testing",
            url=_url_play_app(client_id, "tracks/internal-testing/tabs/testers"),
            icon="people",
        ),
        QuickLink(
            id="play-internal-client",
            label="Internal testing - Baqueano Natales",
            description="Releases en el track internal",
            url=_url_play_app(client_id, "tracks/internal-testing"),
            icon="rocket",
        ),
        QuickLink(
            id="play-testers-admin",
            label="Testers - Baqueano Admin",
            description="Ver y gestionar la lista de testers del internal testing",
            url=_url_play_app(admin_id, "tracks/internal-testing/tabs/testers"),
            icon="people",
        ),
        QuickLink(
            id="play-internal-admin",
            label="Internal testing - Baqueano Admin",
            description="Releases en el track internal",
            url=_url_play_app(admin_id, "tracks/internal-testing"),
            icon="rocket",
        ),
        QuickLink(
            id="play-store-client",
            label="Play Store - Baqueano Natales",
            description=f"Ficha publica ({settings.PLAY_PACKAGE_CLIENT})",
            url=f"https://play.google.com/store/apps/details?id={settings.PLAY_PACKAGE_CLIENT}",
            icon="shop",
        ),
        QuickLink(
            id="play-store-admin",
            label="Play Store - Baqueano Admin",
            description=f"Ficha publica ({settings.PLAY_PACKAGE_ADMIN})",
            url=f"https://play.google.com/store/apps/details?id={settings.PLAY_PACKAGE_ADMIN}",
            icon="shop",
        ),
        QuickLink(
            id="play-console",
            label="Play Console (general)",
            description="Panel principal de la consola",
            url=_base_play_console(),
            icon="dashboard",
        ),
    ]


def _github_links() -> list[QuickLink]:
    repo = settings.GITHUB_OPS_REPO
    return [
        QuickLink(
            id="github-repo",
            label="Repositorio",
            description=repo,
            url=f"https://github.com/{repo}",
            icon="git",
        ),
        QuickLink(
            id="github-actions",
            label="Actions (CI/CD)",
            description="Historial de workflow runs",
            url=f"https://github.com/{repo}/actions",
            icon="play",
        ),
        QuickLink(
            id="github-releases",
            label="Releases",
            description="Tags y releases publicados",
            url=f"https://github.com/{repo}/releases",
            icon="tag",
        ),
        QuickLink(
            id="github-issues",
            label="Issues",
            description="Issues abiertos del proyecto",
            url=f"https://github.com/{repo}/issues",
            icon="bug",
        ),
    ]


def _infra_links() -> list[QuickLink]:
    return [
        QuickLink(
            id="cloudflare",
            label="Cloudflare Dashboard",
            description="DNS, SSL, cache, workers",
            url=settings.CLOUDFLARE_DASHBOARD_URL,
            icon="cloud",
        ),
        QuickLink(
            id="racknerd",
            label="RackNerd Panel",
            description="Panel del VPS (server nuevo)",
            url=settings.RACKNERD_DASHBOARD_URL,
            icon="server",
        ),
        QuickLink(
            id="backend-prod-health",
            label="Backend prod (health)",
            description=settings.PUBLIC_API_URL,
            url=f"{settings.PUBLIC_API_URL}/health",
            icon="health",
        ),
        QuickLink(
            id="backend-dev-health",
            label="Backend dev (health)",
            description="https://api-dev.baqueanonatales.com",
            url="https://api-dev.baqueanonatales.com/health",
            icon="health",
        ),
    ]


def obtener_quick_links() -> QuickLinksResponse:
    """Retorna los quick links agrupados por categoria."""
    return QuickLinksResponse(
        categories=[
            QuickLinkCategory(id="play-console", label="Play Console", icon="shop", links=_play_links()),
            QuickLinkCategory(id="github", label="GitHub", icon="git", links=_github_links()),
            QuickLinkCategory(id="infra", label="Infraestructura", icon="cloud", links=_infra_links()),
        ],
    )
