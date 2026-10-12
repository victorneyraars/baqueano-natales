"""Interfaz abstracta de provider de notificaciones.

Cualquier provider nuevo (APNs directo, SMS, email) implementa esta ABC.
"""
from abc import ABC, abstractmethod
from dataclasses import dataclass


@dataclass
class SendResult:
    success: bool
    message_id: str | None = None
    error_code: str | None = None
    error_message: str | None = None


class NotificationProvider(ABC):
    @abstractmethod
    async def send(
        self,
        token: str,
        titulo: str,
        body: str,
        data: dict | None = None,
        analytics_label: str | None = None,
        prioridad: str = "high",
        ttl_hours: int = 24,
        collapse_key: str | None = None,
    ) -> SendResult:
        """Envia a un token individual."""
        ...

    @abstractmethod
    async def send_batch(
        self,
        tokens: list[str],
        titulo: str,
        body: str,
        data: dict | None = None,
        analytics_label: str | None = None,
        prioridad: str = "high",
        ttl_hours: int = 24,
        collapse_key: str | None = None,
    ) -> list[SendResult]:
        """Envia a N tokens. Devuelve un SendResult por token."""
        ...
