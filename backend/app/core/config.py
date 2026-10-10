"""
Configuración de la aplicación.
Lee variables del .env usando pydantic-settings.
"""
from functools import lru_cache
from typing import Literal

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Configuración central de la aplicación."""

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
    MAX_AVATAR_SIZE_BYTES: int = 5 * 1024 * 1024  # 5 MB


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