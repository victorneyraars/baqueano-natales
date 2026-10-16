"""Servicio del release preview (Fase 2b).

Valida que se pueda taggear + calcula versiones + firma el preview token.
La ejecucion real (trigger) es Fase 2c.
"""
from __future__ import annotations

import logging
import re
from datetime import datetime, timezone
from uuid import UUID

from app.core.config import settings
from app.modules.ops import services_github, services_repo
from app.modules.ops.schemas import (
    ReleasePreviewRequest,
    ReleasePreviewResponse,
    ValidationCheck,
)
from app.modules.ops.services_preview_token import crear_preview_token

logger = logging.getLogger(__name__)


# Duracion estimada del workflow Release (client + admin secuenciales).
# Basado en la observacion real: ~12 min + ~12 min = ~24 min.
ESTIMATED_RELEASE_DURATION_MIN = 25
RELEASE_WORKFLOW_NAME = "Release"


# ============================================================
# Parseo de pubspec.yaml
# ============================================================
def _parse_version_from_pubspec(content: str) -> tuple[str, int] | None:
    """Parsea el campo `version: 0.3.4+7` de pubspec.yaml.

    Returns:
        (version_name, version_code) o None si no se puede parsear.
    """
    m = re.search(r"^version:\s*(\d+\.\d+\.\d+)\+(\d+)\s*$", content, re.MULTILINE)
    if not m:
        return None
    return m.group(1), int(m.group(2))


# ============================================================
# Preview
# ============================================================
async def generar_preview(
    request: ReleasePreviewRequest,
    user_id: UUID,
) -> ReleasePreviewResponse:
    """Genera el preview del release: versiones + validaciones + token."""
    validations: list[ValidationCheck] = []

    # -------- 1. Leer pubspec actual --------
    pubspec = await services_github.get_file_content("flutter/pubspec.yaml", ref=request.branch)
    if pubspec is None:
        validations.append(ValidationCheck(
            name="pubspec.yaml accesible",
            status="error",
            detail=f"No se pudo leer flutter/pubspec.yaml en {request.branch}",
        ))
        current_version = "0.0.0+0"
        current_code = 0
    else:
        parsed = _parse_version_from_pubspec(pubspec)
        if parsed is None:
            validations.append(ValidationCheck(
                name="pubspec.yaml parseable",
                status="error",
                detail="No se encontro 'version: X.Y.Z+N' en pubspec.yaml",
            ))
            current_version = "0.0.0+0"
            current_code = 0
        else:
            current_name, current_code = parsed
            current_version = f"{current_name}+{current_code}"
            validations.append(ValidationCheck(
                name="pubspec.yaml parseable",
                status="ok",
                detail=f"Version actual: {current_version}",
            ))

    # -------- 2. Calcular target --------
    # version_name viene del request. next_version_code = current_code + 1.
    target_version = f"{request.version_name}+{current_code + 1}"
    target_tag = f"v{request.version_name}"
    next_version_code = current_code + 1

    # -------- 3. Validar que el tag no exista --------
    if await services_github.tag_exists(target_tag):
        validations.append(ValidationCheck(
            name="tag libre",
            status="error",
            detail=f"El tag {target_tag} ya existe. Elegir otro version_name.",
        ))
    else:
        validations.append(ValidationCheck(
            name="tag libre",
            status="ok",
            detail=f"Tag {target_tag} disponible",
        ))

    # -------- 4. VersionCode vs Play Console --------
    # Comparar con el ultimo versionCode publicado en internal.
    # Si Play tiene uno mas alto que current_code+1, hay conflicto.
    try:
        from app.modules.ops import services_play
        tracks = await services_play.listar_tracks()
        play_codes: list[int] = []
        for app_tracks in (tracks.client, tracks.admin):
            for t in app_tracks.tracks:
                if t.version_code is not None:
                    play_codes.append(t.version_code)
        max_play_code = max(play_codes) if play_codes else 0
        if next_version_code <= max_play_code:
            validations.append(ValidationCheck(
                name="versionCode mayor a Play",
                status="error",
                detail=(
                    f"El versionCode calculado ({next_version_code}) es <= "
                    f"al maximo en Play ({max_play_code}). "
                    f"Actualizar pubspec.yaml primero."
                ),
            ))
        else:
            validations.append(ValidationCheck(
                name="versionCode mayor a Play",
                status="ok",
                detail=f"{next_version_code} > max en Play ({max_play_code})",
            ))
    except Exception as e:
        logger.warning("ops.release.play_check_failed", extra={"error": str(e)})
        validations.append(ValidationCheck(
            name="versionCode mayor a Play",
            status="warning",
            detail=f"No se pudo verificar contra Play: {type(e).__name__}",
        ))

    # -------- 5. HEAD del branch --------
    head_info = await services_github.get_head_commit(request.branch)
    if head_info is None:
        validations.append(ValidationCheck(
            name="HEAD accesible",
            status="error",
            detail=f"No se pudo leer el HEAD de {request.branch}",
        ))
        head_sha = ""
        head_msg = ""
        head_age = None
    else:
        head_sha = head_info["sha"]
        head_msg = head_info["message"]
        head_age = _minutes_since(head_info.get("date"))
        validations.append(ValidationCheck(
            name="HEAD accesible",
            status="ok",
            detail=f"{head_sha[:7]} — {head_msg[:60]}",
        ))

    # -------- 6. Compilar respuesta --------
    can_proceed = all(v.status != "error" for v in validations)

    # Preview token (aunque haya errores, para que la UI lo muestre).
    token, expires_at = crear_preview_token(
        version_name=request.version_name,
        target_tag=target_tag,
        next_version_code=next_version_code,
        head_sha=head_sha,
        branch=request.branch,
        user_id=str(user_id),
    )

    logger.info(
        "ops.release.preview_generated",
        extra={
            "user_id": str(user_id),
            "target_tag": target_tag,
            "next_version_code": next_version_code,
            "can_proceed": can_proceed,
            "num_errors": sum(1 for v in validations if v.status == "error"),
        },
    )

    return ReleasePreviewResponse(
        current_version=current_version,
        target_version=target_version,
        target_tag=target_tag,
        next_version_code=next_version_code,
        head_sha=head_sha,
        head_commit_message=head_msg,
        head_commit_age_minutes=head_age,
        validations=validations,
        can_proceed=can_proceed,
        estimated_duration_min=ESTIMATED_RELEASE_DURATION_MIN,
        workflow_name=RELEASE_WORKFLOW_NAME,
        preview_token=token,
        expires_at=expires_at,
    )


def _minutes_since(iso_date: str | None) -> int | None:
    """Devuelve minutos desde el timestamp ISO. None si no se puede parsear."""
    if not iso_date:
        return None
    try:
        dt = datetime.fromisoformat(iso_date.replace("Z", "+00:00"))
        delta = datetime.now(timezone.utc) - dt
        return max(0, int(delta.total_seconds() / 60))
    except (ValueError, TypeError):
        return None

# ============================================================
# Fase 2c - Trigger real del release
# ============================================================
RATE_LIMIT_MINUTES = 10  # 1 release cada 10 min por user


class ReleaseTriggerError(Exception):
    """Error de validacion del trigger. El mensaje es user-friendly."""

    def __init__(self, message: str, *, http_status: int = 400):
        super().__init__(message)
        self.message = message
        self.http_status = http_status


async def ejecutar_release(
    request,
    user_id: UUID,
    user_email: str | None,
    *,
    ip_address: str | None = None,
    user_agent: str | None = None,
    db=None,
) -> "ReleaseTriggerResponse":
    """Ejecuta el trigger de release con los 4 safety rails.

    Raises:
        ReleaseTriggerError: si falla alguna validacion.
    """
    import time
    from app.modules.ops import services_audit
    from app.modules.ops.services_preview_token import (
        PreviewTokenError,
        validar_preview_token,
    )

    t0 = time.monotonic()

    # ---------- Safety rail #1: confirm exacto ----------
    if request.confirm != "CONFIRMAR":
        raise ReleaseTriggerError(
            "Confirmacion incorrecta. Debe enviar {'confirm': 'CONFIRMAR'}.",
            http_status=400,
        )

    # ---------- Safety rail #2: preview_token valido ----------
    try:
        payload = validar_preview_token(
            request.preview_token,
            expected_user_id=str(user_id),
        )
    except PreviewTokenError as e:
        raise ReleaseTriggerError(
            f"Preview token invalido: {e}",
            http_status=400,
        ) from e

    version_name = payload["version_name"]
    target_tag = payload["target_tag"]
    next_version_code = int(payload["next_version_code"])
    expected_sha = payload["head_sha"]
    branch = payload["branch"]

    # ---------- Safety rail #3: HEAD no cambio ----------
    head_info = await services_github.get_head_commit(branch)
    if head_info is None:
        raise ReleaseTriggerError(
            f"No se pudo leer el HEAD de {branch}.",
            http_status=502,
        )
    current_sha = head_info["sha"]
    if current_sha != expected_sha:
        raise ReleaseTriggerError(
            (
                f"El HEAD de {branch} cambio desde el preview. "
                f"Esperado: {expected_sha[:7]}, actual: {current_sha[:7]}. "
                f"Genera un preview nuevo."
            ),
            http_status=409,
        )

    # ---------- Safety rail #4: rate limit ----------
    ultimo = await services_audit.ultima_accion_exitosa(
        action="release.trigger",
        user_id=user_id,
        ventana_minutos=RATE_LIMIT_MINUTES,
    )
    if ultimo is not None:
        delta = _minutes_since(ultimo.isoformat() if hasattr(ultimo, 'isoformat') else str(ultimo))
        if delta is not None and delta < RATE_LIMIT_MINUTES:
            raise ReleaseTriggerError(
                f"Rate limit: espera {RATE_LIMIT_MINUTES} min entre releases. "
                f"Ultimo hace {delta} min.",
                http_status=429,
            )

    # ---------- Todas las validaciones OK, ejecutar ----------
    logger.info(
        "ops.release.trigger_start",
        extra={
            "user_id": str(user_id),
            "target_tag": target_tag,
            "sha": current_sha,
        },
    )

    # 5. Bump pubspec.yaml + push (para que el workflow use la version nueva)
    try:
        bump_result = await services_repo.bump_pubspec_and_push(
            version_name=version_name,
            version_code=next_version_code,
            branch=branch,
            user_email=user_email,
        )
    except services_repo.RepoWriteError as e:
        duration_ms = int((time.monotonic() - t0) * 1000)
        await services_audit.registrar(
            db,
            user_id=user_id,
            user_email=user_email,
            action="release.trigger",
            status="error",
            target=target_tag,
            payload={
                "version_name": version_name,
                "next_version_code": next_version_code,
                "head_sha": current_sha,
                "branch": branch,
            },
            error_message=f"Fallo al bumpear pubspec: {e.message}",
            duration_ms=duration_ms,
            ip_address=ip_address,
            user_agent=user_agent,
        )
        raise ReleaseTriggerError(
            f"No se pudo actualizar pubspec.yaml: {e.message}",
            http_status=e.http_status,
        ) from e

    bumped_sha = bump_result["commit_sha"]
    logger.info(
        "ops.release.pubspec_bumped",
        extra={
            "old_sha": current_sha,
            "new_sha": bumped_sha,
            "no_change": bump_result.get("no_change", False),
        },
    )

    # 6. Crear tag en GitHub (sobre el NUEVO commit con pubspec actualizado)
    tag_result = await services_github.create_tag(
        tag_name=target_tag,
        sha=bumped_sha,
        message=f"Release {target_tag} desde Ops Dashboard",
    )

    duration_ms = int((time.monotonic() - t0) * 1000)

    if tag_result is None:
        # Error al crear el tag
        await services_audit.registrar(
            db,
            user_id=user_id,
            user_email=user_email,
            action="release.trigger",
            status="error",
            target=target_tag,
            payload={
                "version_name": version_name,
                "next_version_code": next_version_code,
                "head_sha": current_sha,
                "branch": branch,
            },
            error_message="Fallo al crear tag en GitHub",
            duration_ms=duration_ms,
            ip_address=ip_address,
            user_agent=user_agent,
        )
        raise ReleaseTriggerError(
            f"No se pudo crear el tag {target_tag} en GitHub. Revisar logs.",
            http_status=502,
        )

    # 6. Audit log: exito
    audit_entry = await services_audit.registrar(
        db,
        user_id=user_id,
        user_email=user_email,
        action="release.trigger",
        status="success",
        target=target_tag,
        payload={
            "version_name": version_name,
            "next_version_code": next_version_code,
            "head_sha_preview": current_sha,
            "head_sha_post_bump": bumped_sha,
            "branch": branch,
            "no_change": bump_result.get("no_change", False),
        },
        result={"tag_ref": tag_result.get("ref", "")},
        duration_ms=duration_ms,
        ip_address=ip_address,
        user_agent=user_agent,
    )

    logger.info(
        "ops.release.trigger_success",
        extra={
            "user_id": str(user_id),
            "target_tag": target_tag,
            "duration_ms": duration_ms,
        },
    )

    # 7. Respuesta
    from app.modules.ops.schemas import ReleaseTriggerResponse

    return ReleaseTriggerResponse(
        tag=target_tag,
        commit_sha=bumped_sha,
        workflow_name=RELEASE_WORKFLOW_NAME,
        estimated_duration_min=ESTIMATED_RELEASE_DURATION_MIN,
        github_url=f"https://github.com/{settings.GITHUB_OPS_REPO}/actions",
        audit_log_id=str(audit_entry.id) if audit_entry else "",
        message=(
            f"Tag {target_tag} creado. Workflow Release corriendo en GitHub. "
            f"Duracion estimada: ~{ESTIMATED_RELEASE_DURATION_MIN} min."
        ),
    )