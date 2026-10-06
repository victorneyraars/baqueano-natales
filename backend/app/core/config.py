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

    @property
    def admin_emails_list(self) -> list[str]:
        """Lista de emails admin parseados."""
        if not self.ADMIN_EMAILS:
            return []
        return [e.strip().lower() for e in self.ADMIN_EMAILS.split(",") if e.strip()]

    @property
    def is_production(self) -> bool:
        return self.ENVIRONMENT == "production"


@lru_cache
def get_settings() -> Settings:
    """Retorna una instancia cacheada de Settings."""
    return Settings()


settings = get_settings()
