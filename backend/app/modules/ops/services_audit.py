"""Servicio de auditoria del modulo ops.

Registra acciones del Ops Dashboard en `ops_audit_log`.

Diseno best-effort: si falla el insert, loguea y devuelve None. El
audit NO debe romper la accion real que se esta registrando.

Sanitizacion:
- Elimina campos sensibles (token, password, secret, etc.).
- Trunca strings largos para evitar DoS por payload inflado.
"""
from __future__ import annotations

import logging
from typing import Any
from uuid import UUID

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.db import AsyncSessionLocal
from app.modules.ops.models import OpsAuditLog

logger = logging.getLogger(__name__)


# Campos que NUNCA se persisten (se reemplazan por "***").
_SENSITIVE_FIELDS = frozenset({
    "token", "password", "secret", "authorization",
    "pat", "api_key", "access_token", "refresh_token",
})

# Limites de tamano.
_MAX_STRING_LEN = 1000
_MAX_ERROR_LEN = 2000
_MAX_USER_AGENT_LEN = 500


def _sanitizar(data: dict[str, Any] | None) -> dict[str, Any] | None:
    """Elimina campos sensibles y limita tamanos. No muta el input."""
    if not data:
        return None
    out: dict[str, Any] = {}
    for k, v in data.items():
        k_lower = k.lower()
        if any(s in k_lower for s in _SENSITIVE_FIELDS):
            out[k] = "***"
        elif isinstance(v, str) and len(v) > _MAX_STRING_LEN:
            out[k] = v[:_MAX_STRING_LEN] + "...(truncated)"
        else:
            out[k] = v
    return out


def _truncar(s: str | None, max_len: int) -> str | None:
    if s is None:
        return None
    if len(s) > max_len:
        return s[:max_len] + "...(truncated)"
    return s


async def registrar(
    db: AsyncSession | None = None,
    *,
    user_id: UUID | None = None,
    user_email: str | None = None,
    action: str,
    status: str,
    target: str | None = None,
    payload: dict[str, Any] | None = None,
    result: dict[str, Any] | None = None,
    error_message: str | None = None,
    duration_ms: int | None = None,
    ip_address: str | None = None,
    user_agent: str | None = None,
) -> OpsAuditLog | None:
    """Registra una accion en el audit log. Best-effort.

    Args:
        db: sesion existente. Si es None, abre una propia y commitea.
            Usar None desde BackgroundTasks (post-request).
        action: ej. "release.trigger", "release.preview".
        status: "pending" | "success" | "error" | "rejected" | "cancelled".

    Returns:
        La fila creada, o None si fallo (nunca propaga excepcion).
    """
    try:
        entry = OpsAuditLog(
            user_id=user_id,
            user_email=user_email,
            action=action,
            status=status,
            target=target,
            payload=_sanitizar(payload),
            result=_sanitizar(result),
            error_message=_truncar(error_message, _MAX_ERROR_LEN),
            duration_ms=duration_ms,
            ip_address=ip_address,
            user_agent=_truncar(user_agent, _MAX_USER_AGENT_LEN),
        )

        if db is not None:
            db.add(entry)
            await db.flush()
            return entry
        async with AsyncSessionLocal() as session:
            session.add(entry)
            await session.commit()
            await session.refresh(entry)
            return entry

    except Exception as e:
        logger.exception(
            "ops.audit.error",
            extra={"action": action, "error": str(e)},
        )
        return None