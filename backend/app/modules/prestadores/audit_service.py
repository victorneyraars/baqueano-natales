"""Audit log del prestador (append-only).

Registra acciones de Vásquez y sus colaboradores sobre recursos del
prestador (reservas, canales, colaboradores, vehículos).

Diseño:
- Best-effort: nunca rompe el endpoint principal si falla el log.
- Append-only: solo INSERT, nunca UPDATE/DELETE.
- Retención: 12 meses mínimo (compliance SII Chile).

Distinto de OpsAuditLog (que es para el Ops Dashboard interno).
"""
import logging
from uuid import UUID

from sqlalchemy.ext.asyncio import AsyncSession

from app.modules.auth.models import Usuario
from app.modules.prestadores.models import PrestadorAuditLog

logger = logging.getLogger(__name__)


async def log_audit(
    db: AsyncSession,
    prestador_id: UUID,
    user: Usuario | None,
    accion: str,
    entidad: str,
    entidad_id: str | None = None,
    metadata: dict | None = None,
    ip: str | None = None,
    user_agent: str | None = None,
) -> None:
    """Registra una acción en el audit log. Best-effort.

    Args:
        db: Sesión activa. NO se hace commit acá: el caller hace el commit
            junto con la mutación original (transacción atómica).
        prestador_id: UUID del prestador afectado.
        user: Usuario que ejecutó la acción. Si None, se usa "system".
        accion: "reserva_confirmada", "colaborador_invitado", etc.
        entidad: "reserva", "colaborador", "canal", "vehiculo".
        entidad_id: ID específico del recurso (string).
        metadata: Dict JSON con contexto (estado_anterior/nuevo, email, etc.).
        ip: IP del request (opcional).
        user_agent: User-Agent del request (opcional).

    No propaga excepción: si falla, se loguea con `logger.exception` y sigue.
    """
    try:
        entry = PrestadorAuditLog(
            prestador_id=prestador_id,
            user_id=user.id if user else None,
            user_email=(user.email if user and user.email else "system"),
            accion=accion,
            entidad=entidad,
            entidad_id=entidad_id,
            metadata_=metadata or {},
            ip=ip,
            user_agent=user_agent,
        )
        db.add(entry)
    except Exception as e:
        # No propagamos: el endpoint original debe seguir funcionando
        logger.exception(f"audit.log.error accion={accion} error={e}")
