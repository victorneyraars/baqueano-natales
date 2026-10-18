"""
Configuración de la aplicación.
Lee variables del .env usando pydantic-settings.
"""
from functools import lru_cache
from typing import Literal

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Configuración central de la aplicación."""
    # ============================================================
    # Ops Dashboard - Quick Links
    # ============================================================
    PLAY_CONSOLE_DEV_ID: str = "5489050729101024675"
    PLAY_CONSOLE_APP_ID_CLIENT: str = ""
    PLAY_CONSOLE_APP_ID_ADMIN: str = "4973778958369099895"
    CLOUDFLARE_DASHBOARD_URL: str = "https://dash.cloudflare.com"
    RACKNERD_DASHBOARD_URL: str = "https://my.racknerd.com"


    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=True,
        extra="ignore",
    )

    # --- Ambiente ---
    ENVIRONMENT: Literal["development", "staging", "production"] = "development"
    DEBUG: bool = False
    LOG_LEVEL: str = "INFO"

    # --- Base de datos ---
    POSTGRES_USER: str = "baqueano_user"
    POSTGRES_PASSWORD: str = "changeme"
    POSTGRES_DB: str = "baqueano_natales"
    POSTGRES_HOST: str = "db"
    POSTGRES_PORT: int = 5432
    DATABASE_URL: str = ""

    # --- Backend ---
    BACKEND_HOST: str = "0.0.0.0"
    BACKEND_PORT: int = 8000
    SECRET_KEY: str = "changeme_insecure"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 10080

    # --- Cifrado de secretos (tokens sociales, integraciones) ---
    # Clave Fernet (32 bytes base64). Obligatoria en producción.
    # Generar con:
    #   python -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"
    TOKEN_ENCRYPTION_KEY: str = ""

    # --- Firebase ---
    FIREBASE_SERVICE_ACCOUNT_PATH: str = "/app/secrets/firebase-service-account.json"
    FIREBASE_PROJECT_ID: str = "baqueano-natales"
    FCM_ENABLED: bool = True

    # --- Google ---
    GOOGLE_CLIENT_ID: str = ""
    GOOGLE_CLIENT_SECRET: str = ""

    # --- WhatsApp ---
    WHATSAPP_API_URL: str = "https://graph.facebook.com/v20.0"
    WHATSAPP_PHONE_NUMBER_ID: str = ""
    WHATSAPP_ACCESS_TOKEN: str = ""
    WHATSAPP_VERIFY_TOKEN: str = ""
    WHATSAPP_TEMPLATE_NAME: str = "auth_code_es"

    # --- SMS ---
    SMS_PROVIDER: str = "twilio"
    TWILIO_ACCOUNT_SID: str = ""
    TWILIO_AUTH_TOKEN: str = ""
    TWILIO_FROM_NUMBER: str = ""

    # --- OTP ---
    OTP_EXPIRATION_MINUTES: int = 10
    OTP_MAX_ATTEMPTS: int = 5
    OTP_RATE_LIMIT_PER_HOUR: int = 3

    # --- Admin ---
    ADMIN_EMAILS: str = ""

    # --- Storage de avatares ---
    AVATAR_STORAGE_PATH: str = "/app/media/avatars"
    PUBLIC_API_URL: str = "https://api.baqueanonatales.com"
    PUBLIC_WEB_URL: str = "https://www.baqueanonatales.com"
    REVALIDATE_API_KEY: str = ""
    VERCEL_BYPASS_TOKEN: str = ""
    PUBLIC_MEDIA_URL: str = "https://dev-api.baqueanonatales.com"
    MAX_AVATAR_SIZE_BYTES: int = 5 * 1024 * 1024  # 5 MB

    # --- Storage de fotos de ordenes (M5 oficios) ---
    FOTO_STORAGE_PATH: str = "/app/media/ordenes"
    MAX_FOTO_SIZE_BYTES: int = 15 * 1024 * 1024  # 15 MB


    # --- Facebook / Meta (OAuth + Graph API) ---
    # App de Meta for Developers. El App ID es p?blico; el App Secret es
    # secreto (va en .env del server, nunca al repo).
    FACEBOOK_APP_ID: str = ""
    FACEBOOK_APP_SECRET: str = ""
    # Redirect URI registrado en Meta Console. Debe ser HTTPS y coincidir
    # EXACTAMENTE con el registrado en la app de Meta.
    FACEBOOK_OAUTH_REDIRECT_URI: str = (
        "https://dev-api.baqueanonatales.com"
        "/api/v1/admin/social/facebook/oauth/callback"
    )
    # Versi?n de Graph API. Se fija expl?citamente para no romper cuando Meta
    # deprecia versiones viejas.
    FACEBOOK_GRAPH_API_VERSION: str = "v26.0"
    # Permisos que pide el di?logo OAuth (comma-separated).
    FACEBOOK_OAUTH_SCOPES: str = (
        "pages_show_list,pages_read_engagement,pages_manage_posts"
    )

    # --- Google Business Profile (Etapa 8) ---
    # Feature flag: activa/desactiva la publicacion en GBP. Cuando se
    # apruebe la API de Google, cambiar a true.
    GOOGLE_BUSINESS_ENABLED: bool = False
    # Cuenta principal de GBP. Formato: "accounts/1234567890".
    GOOGLE_BUSINESS_ACCOUNT_NAME: str = ""
    # OAuth credentials para la API (distintas de GOOGLE_CLIENT_ID que es
    # para Sign-In).
    GOOGLE_BUSINESS_CLIENT_ID: str = ""
    GOOGLE_BUSINESS_CLIENT_SECRET: str = ""
    # Version de la API de GBP.
    GOOGLE_BUSINESS_API_VERSION: str = "v4"

    # --- Worker de publicaciones sociales (Etapa 3) ---
    # Scheduler in-process (APScheduler) que procesa la cola
    # publicaciones_sociales. Deshabilitar en tests o si corre un worker
    # externo.
    SOCIAL_WORKER_ENABLED: bool = True
    # Intervalo entre ciclos del worker (segundos). Cada ciclo procesa
    # las publicaciones con estado=PENDIENTE y proximo_intento_en <= now.
    SOCIAL_WORKER_INTERVAL_SEC: int = 30

    # ----------------------------------------------------------------
    # Worker de recordatorios (oficios)
    # ----------------------------------------------------------------
    RECORDATORIOS_WORKER_ENABLED: bool = True
    RECORDATORIOS_WORKER_INTERVAL_SEC: int = 3600  # 1 hora

    # ------------------------------------------------------------------
    # Ops Dashboard (integracion GitHub Actions + Play Console)
    # ------------------------------------------------------------------
    GITHUB_OPS_TOKEN: str = ""
    GITHUB_OPS_REPO: str = "victorneyraars/baqueano-natales"
    GITHUB_API_BASE: str = "https://api.github.com"
    GITHUB_OPS_CACHE_TTL_SEC: int = 20

    # Paquetes de las apps para Play Console
    PLAY_PACKAGE_CLIENT: str = "cl.baqueanonatales"
    PLAY_PACKAGE_ADMIN: str = "cl.baqueanonatales.admin"

    # Links de opt-in (internal testing) para compartir con testers
    PLAY_OPT_IN_CLIENT: str = "https://play.google.com/apps/internaltest/4701406488817338834"
    PLAY_OPT_IN_ADMIN: str = "https://play.google.com/apps/internaltest/4700564668101923540"

    @property
    def admin_emails_list(self) -> list[str]:
        """Lista de emails admin parseados."""
        if not self.ADMIN_EMAILS:
            return []
        return [e.strip().lower() for e in self.ADMIN_EMAILS.split(",") if e.strip()]

    @property
    def is_production(self) -> bool:
        return self.ENVIRONMENT == "production"

    @property
    def is_development(self) -> bool:
        return self.ENVIRONMENT == "development"


@lru_cache
def get_settings() -> Settings:
    """Retorna una instancia cacheada de Settings."""
    return Settings()


settings = get_settings()