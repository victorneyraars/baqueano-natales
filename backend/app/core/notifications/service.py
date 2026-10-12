"""Servicio orquestador de notificaciones.

Pipeline: preferencias -> quiet hours -> tokens -> provider -> log.

Es el punto de entrada recomendado. Los providers se inyectan, lo que
permite agregar APNs/SMS/email sin cambiar este archivo.
"""
import logging
from datetime import datetime, time, timezone
from uuid import UUID
from zoneinfo import ZoneInfo

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.db import AsyncSessionLocal
from app.core.notifications.models import (
    EstadoNotificacion,
    FcmToken,
    NotificationLog,
    Plataforma,
    PreferenciaNotificacion,
    TipoNotificacion,
)
from app.core.notifications.providers.base import NotificationProvider, SendResult
from app.core.notifications.providers.fcm import FcmProvider
from app.modules.auth.models import Usuario

logger = logging.getLogger(__name__)


_TIPO_A_PREF = {
    TipoNotificacion.RECORDATORIO: "recordatorios",
    TipoNotificacion.PROMOCION: "promociones",
    TipoNotificacion.SISTEMA: "sistema",
    TipoNotificacion.CAMPANA: "confirmaciones",
}


class NotificationService:
    """Orquesta el envio de notificaciones."""

    def __init__(self, provider: NotificationProvider | None = None):
        self.provider = provider or FcmProvider()

    # ==================== API principal ====================

    async def enviar_a_usuario(
        self,
        db: AsyncSession,
        usuario_id: UUID,
        titulo: str,
        body: str,
        tipo: TipoNotificacion = TipoNotificacion.SISTEMA,
        data: dict | None = None,
        analytics_label: str | None = None,
        ignorar_preferencias: bool = False,
        ignorar_quiet_hours: bool = False,
    ) -> SendResult:
        """Envia una notificacion a un usuario con el pipeline completo.

        Args:
            db: Sesion. Si el caller tiene una transaccion abierta, este
                service hace flush + commit internamente (el caller no
                necesita commitear).
            usuario_id: Destinatario.
            tipo: Define que preferencia se chequea.
            ignorar_preferencias: Para notifs criticas (confirmaciones).
            ignorar_quiet_hours: Idem.

        Returns:
            SendResult con el primer resultado (o error).
        """
        # 1. Preferencias
        if not ignorar_preferencias:
            prefs = await self._get_or_create_prefs(db, usuario_id)
            if not self._tipo_habilitado(prefs, tipo):
                await self._log_skipped(db, usuario_id, titulo, body, tipo, "preferencia")
                await db.commit()
                return SendResult(success=False, error_code="PREFERENCE_DISABLED")

            if not ignorar_quiet_hours and self._en_quiet_hours(prefs):
                await self._log_skipped(db, usuario_id, titulo, body, tipo, "quiet_hours")
                await db.commit()
                return SendResult(success=False, error_code="QUIET_HOURS")

        # 2. Tokens activos
        tokens = await self._get_tokens_activos(db, usuario_id)
        if not tokens:
            await self._log_skipped(db, usuario_id, titulo, body, tipo, "sin_tokens")
            await db.commit()
            return SendResult(success=False, error_code="NO_TOKENS")

        # 3. Crear log PENDIENTE
        log = await self._crear_log(db, usuario_id, titulo, body, tipo, data, analytics_label)

        # 3b. Inyectar el notification_log_id en el payload del push.
        # La app Flutter lo usa para reportar la apertura (POST /notificaciones/{id}/abierta).
        payload = {**(data or {}), "notification_log_id": str(log.id)}

        # 4. Enviar via provider
        results = await self.provider.send_batch(
            tokens=[t.token for t in tokens],
            titulo=titulo,
            body=body,
            data=payload,
            analytics_label=analytics_label,
        )

        # 5. Actualizar log + limpieza de tokens invalidos
        await self._procesar_results(db, log, tokens, results)
        await db.commit()

        return results[0] if results else SendResult(
            success=False, error_code="NO_RESULTS"
        )

    # ==================== Compatibilidad legacy ====================

    async def enviar_legacy(
        self,
        usuario_id: UUID,
        titulo: str,
        body: str,
        data: dict | None = None,
        db: AsyncSession | None = None,
    ) -> bool:
        """Compatibilidad con push.py. NO chequea preferencias ni quiet hours.

        Usado por el worker de recordatorios y otros callers que necesitan
        el comportamiento "siempre envia".
        """
        async def _do(session: AsyncSession) -> bool:
            result = await self.enviar_a_usuario(
                db=session,
                usuario_id=usuario_id,
                titulo=titulo,
                body=body,
                tipo=TipoNotificacion.SISTEMA,
                data=data,
                ignorar_preferencias=True,
                ignorar_quiet_hours=True,
            )
            return result.success

        try:
            if db is None:
                async with AsyncSessionLocal() as session:
                    return await _do(session)
            return await _do(db)
        except Exception:
            logger.exception("Error en enviar_legacy user_id=%s", usuario_id)
            return False

    # ==================== Helpers internos ====================

    async def _get_or_create_prefs(
        self, db: AsyncSession, usuario_id: UUID
    ) -> PreferenciaNotificacion:
        stmt = select(PreferenciaNotificacion).where(
            PreferenciaNotificacion.usuario_id == usuario_id
        )
        prefs = (await db.execute(stmt)).scalar_one_or_none()
        if prefs is None:
            prefs = PreferenciaNotificacion(usuario_id=usuario_id)
            db.add(prefs)
            await db.flush()
        return prefs

    def _tipo_habilitado(
        self, prefs: PreferenciaNotificacion, tipo: TipoNotificacion
    ) -> bool:
        campo = _TIPO_A_PREF.get(tipo)
        if campo is None:
            return True
        return bool(getattr(prefs, campo, True))

    def _en_quiet_hours(self, prefs: PreferenciaNotificacion) -> bool:
        if not prefs.quiet_hours_enabled:
            return False
        if not prefs.quiet_hours_inicio or not prefs.quiet_hours_fin:
            return False
        try:
            tz = ZoneInfo(prefs.timezone or "America/Santiago")
        except Exception:
            tz = ZoneInfo("America/Santiago")
        ahora_local = datetime.now(tz).time()
        try:
            inicio = time.fromisoformat(prefs.quiet_hours_inicio)
            fin = time.fromisoformat(prefs.quiet_hours_fin)
        except ValueError:
            return False
        if inicio <= fin:
            return inicio <= ahora_local < fin
        # Wrap-around (ej: 22:00 -> 08:00)
        return ahora_local >= inicio or ahora_local < fin

    async def _get_tokens_activos(
        self, db: AsyncSession, usuario_id: UUID
    ) -> list[FcmToken]:
        """Devuelve tokens activos del usuario.

        Fallback: si no hay en `fcm_tokens`, busca en la columna legacy
        `Usuario.fcm_token` y lo inserta en la tabla nueva (auto-migracion).
        """
        stmt = select(FcmToken).where(
            FcmToken.usuario_id == usuario_id,
            FcmToken.activo.is_(True),
        )
        tokens = list((await db.execute(stmt)).scalars().all())
        if tokens:
            return tokens

        # Fallback legacy
        stmt_legacy = select(Usuario.fcm_token).where(
            Usuario.id == usuario_id,
            Usuario.fcm_token.isnot(None),
        )
        legacy = (await db.execute(stmt_legacy)).scalar_one_or_none()
        if not legacy:
            return []

        # Auto-migrar
        nuevo = FcmToken(
            usuario_id=usuario_id,
            token=legacy,
            plataforma=Plataforma.ANDROID,
        )
        db.add(nuevo)
        await db.flush()
        logger.info(
            "Token legacy migrado on-the-fly para user_id=%s", usuario_id
        )
        return [nuevo]

    async def _crear_log(
        self,
        db: AsyncSession,
        usuario_id: UUID | None,
        titulo: str,
        body: str,
        tipo: TipoNotificacion,
        data: dict | None,
        analytics_label: str | None,
    ) -> NotificationLog:
        log = NotificationLog(
            usuario_id=usuario_id,
            tipo=tipo,
            titulo=titulo,
            body=body,
            data=data,
            analytics_label=analytics_label,
            estado=EstadoNotificacion.PENDIENTE,
        )
        db.add(log)
        await db.flush()
        return log

    async def _log_skipped(
        self,
        db: AsyncSession,
        usuario_id: UUID,
        titulo: str,
        body: str,
        tipo: TipoNotificacion,
        razon: str,
    ) -> None:
        log = NotificationLog(
            usuario_id=usuario_id,
            tipo=tipo,
            titulo=titulo,
            body=body,
            estado=EstadoNotificacion.SKIPPED,
            error=f"skipped: {razon}",
        )
        db.add(log)
        await db.flush()

    async def _procesar_results(
        self,
        db: AsyncSession,
        log: NotificationLog,
        tokens: list[FcmToken],
        results: list[SendResult],
    ) -> None:
        if not results:
            log.estado = EstadoNotificacion.FALLIDA
            log.error = "no results"
            return

        exitos = sum(1 for r in results if r.success)
        if exitos > 0:
            log.estado = EstadoNotificacion.ENVIADA
            log.enviado_en = datetime.now(timezone.utc)
        else:
            log.estado = EstadoNotificacion.FALLIDA
            log.error = results[0].error_message or "all failed"

        for token_obj, result in zip(tokens, results):
            if not result.success and result.error_code in (
                "UNREGISTERED", "SENDER_ID_MISMATCH", "INVALID_ARGUMENT"
            ):
                token_obj.activo = False
                logger.info(
                    "Token marcado inactivo: %.20s... (code=%s)",
                    token_obj.token, result.error_code,
                )


# ==================== Singleton ====================

_service: NotificationService | None = None


def get_notification_service() -> NotificationService:
    """Devuelve el service singleton (lazy init)."""
    global _service
    if _service is None:
        _service = NotificationService()
    return _service
