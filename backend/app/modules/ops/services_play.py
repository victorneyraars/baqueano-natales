"""Cliente de Play Console API para el Ops Dashboard.

Lee el estado de los tracks (internal/alpha/beta/production) de las 2 apps
(client + admin) usando el mismo service account que ya usa el publisher.

Diseno:
- Async wrapper sobre google-api-python-client (que es sincrono) usando
  asyncio.to_thread para no bloquear el event loop.
- Cache TTL 30s (mas largo que GitHub porque Play cambia menos).
- Errores capturados: si falla una app, la otra sigue funcionando.
- La primera request puede tardar 1-3s (creacion del servicio + auth).
"""
from __future__ import annotations

import asyncio
import logging
from pathlib import Path

from google.oauth2 import service_account
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError

from app.core.config import settings
from app.modules.ops.schemas import (
    AppTracks,
    TrackVersion,
    TracksResponse,
)

logger = logging.getLogger(__name__)

SERVICE_ACCOUNT_FILE = "/app/secrets/play-publisher.json"
SCOPES = ["https://www.googleapis.com/auth/androidpublisher"]

# Cache simple (reusa el patron de services_github)
import time

class _TTLCache:
    def __init__(self, ttl_seconds: int = 30) -> None:
        self._ttl = ttl_seconds
        self._store: dict[str, tuple[float, object]] = {}

    def get(self, key: str) -> object | None:
        entry = self._store.get(key)
        if not entry:
            return None
        expires_at, value = entry
        if time.monotonic() > expires_at:
            del self._store[key]
            return None
        return value

    def set(self, key: str, value: object) -> None:
        self._store[key] = (time.monotonic() + self._ttl, value)


_cache = _TTLCache(ttl_seconds=30)


# ============================================================
# Helpers sincronos (corren en thread pool)
# ============================================================
def _get_service() -> object:
    """Crea el cliente de androidpublisher (sincrono)."""
    if not Path(SERVICE_ACCOUNT_FILE).is_file():
        raise FileNotFoundError(f"No existe {SERVICE_ACCOUNT_FILE}")

    creds = service_account.Credentials.from_service_account_file(
        SERVICE_ACCOUNT_FILE, scopes=SCOPES
    )
    return build("androidpublisher", "v3", credentials=creds, cache_discovery=False)


def _leer_tracks_sync(package_name: str) -> list[TrackVersion]:
    """Lee los tracks de una app (sincrono). Corre en thread pool."""
    service = _get_service()

    # Edit temporal para leer tracks (se descarta al final)
    edit = service.edits().insert(body={}, packageName=package_name).execute()
    edit_id = edit["id"]

    try:
        tracks_data = service.edits().tracks().list(
            editId=edit_id, packageName=package_name
        ).execute()

        tracks: list[TrackVersion] = []
        for track in tracks_data.get("tracks", []):
            track_name = track.get("track", "")
            # Cada track puede tener 0..N releases (beta, prod, etc.)
            # Tomamos la primera (mas reciente)
            releases = track.get("releases", [])
            if releases:
                rel = releases[0]
                # releaseNotes viene como lista de {language, text}
                notes = rel.get("releaseNotes", [])
                notes_text = ""
                for n in notes:
                    if n.get("language") == "es-419":
                        notes_text = n.get("text", "")
                        break
                if not notes_text and notes:
                    notes_text = notes[0].get("text", "")

                tracks.append(
                    TrackVersion(
                        track=track_name,
                        version_code=int(rel["versionCodes"][0]) if rel.get("versionCodes") else None,
                        version_name=rel.get("name"),
                        status=rel.get("status"),
                        release_name=rel.get("name"),
                        release_notes=notes_text or None,
                    )
                )
            else:
                tracks.append(TrackVersion(track=track_name))

        return tracks
    finally:
        # Limpiar el edit (no se commitea, no persiste cambios)
        try:
            service.edits().delete(editId=edit_id, packageName=package_name).execute()
        except Exception:
            pass


# ============================================================
# API publica
# ============================================================
async def _leer_app(package_name: str, app_label: str) -> AppTracks:
    """Wrapper async para leer una app con manejo de errores."""
    try:
        tracks = await asyncio.to_thread(_leer_tracks_sync, package_name)
        return AppTracks(
            package_name=package_name,
            app_label=app_label,
            tracks=tracks,
        )
    except FileNotFoundError as e:
        logger.error("ops.play.service_account_missing", extra={"error": str(e)})
        return AppTracks(
            package_name=package_name,
            app_label=app_label,
            error="Service account de Play no encontrado",
        )
    except HttpError as e:
        logger.error(
            "ops.play.http_error",
            extra={"package": package_name, "status": e.resp.status if hasattr(e, 'resp') else '?', "error": str(e)[:200]},
        )
        return AppTracks(
            package_name=package_name,
            app_label=app_label,
            error=f"Error Play API: HTTP {e.resp.status if hasattr(e, 'resp') else '?'}",
        )
    except Exception as e:
        logger.exception(
            "ops.play.unexpected_error",
            extra={"package": package_name, "error": str(e)},
        )
        return AppTracks(
            package_name=package_name,
            app_label=app_label,
            error=f"Error inesperado: {type(e).__name__}",
        )


async def listar_tracks() -> TracksResponse:
    """Lee los tracks de las 2 apps en paralelo."""
    cache_key = "tracks:all"
    cached = _cache.get(cache_key)
    if cached is not None:
        logger.debug("ops.play.cache_hit")
        return cached  # type: ignore[return-value]

    # En paralelo — pero Play API no es thread-safe en la primera llamada (crea auth)
    # Ejecutamos secuencial para evitar problemas
    client = await _leer_app(settings.PLAY_PACKAGE_CLIENT, "Baqueano Natales")
    admin = await _leer_app(settings.PLAY_PACKAGE_ADMIN, "Baqueano Admin")

    response = TracksResponse(client=client, admin=admin)
    _cache.set(cache_key, response)

    logger.info(
        "ops.play.tracks_loaded",
        extra={
            "client_tracks": len(client.tracks),
            "admin_tracks": len(admin.tracks),
            "client_error": client.error,
            "admin_error": admin.error,
        },
    )
    return response
