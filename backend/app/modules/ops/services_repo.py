"""Servicio de escritura sobre el repo (GitHub API).

Bump de pubspec.yaml via commits atomicos:
- Lee el HEAD actual + tree + contenido del archivo.
- Modifica el contenido.
- Crea blob + tree + commit + update ref en orden.
- Si algo falla, no se toca nada (no hay estado intermedio).

Patron recomendado por GitHub:
https://docs.github.com/en/rest/git/commits
"""
from __future__ import annotations

import base64
import logging
import re
from typing import Any

import httpx

from app.core.config import settings
from app.modules.ops.services_github import _get_http_client

logger = logging.getLogger(__name__)

PUBSPEC_PATH = "flutter/pubspec.yaml"


class RepoWriteError(Exception):
    """Fallo al escribir en el repo. User-friendly."""

    def __init__(self, message: str, *, http_status: int = 502):
        super().__init__(message)
        self.message = message
        self.http_status = http_status


# ============================================================
# Parseo
# ============================================================
def _parse_version(content: str) -> tuple[str, int] | None:
    m = re.search(r"^version:\s*(\d+\.\d+\.\d+)\+(\d+)\s*$", content, re.MULTILINE)
    if not m:
        return None
    return m.group(1), int(m.group(2))


def _replace_version(content: str, version_name: str, version_code: int) -> str:
    nueva = f"version: {version_name}+{version_code}"
    return re.sub(
        r"^version:\s*\d+\.\d+\.\d+\+\d+\s*$",
        nueva,
        content,
        count=1,
        flags=re.MULTILINE,
    )


# ============================================================
# Bump atomico
# ============================================================
async def bump_pubspec_and_push(
    *,
    version_name: str,
    version_code: int,
    branch: str = "main",
    user_email: str | None = None,
) -> dict[str, Any]:
    """Actualiza pubspec.yaml y pushea a GitHub. Devuelve {commit_sha, ...}.

    Raises:
        RepoWriteError: si falla cualquier paso del flujo atomico.
    """
    repo = settings.GITHUB_OPS_REPO
    client = _get_http_client()

    try:
        # -------- 1. HEAD actual del branch --------
        r = await client.get(f"/repos/{repo}/git/ref/heads/{branch}")
        if r.status_code != 200:
            raise RepoWriteError(
                f"No se pudo leer HEAD de {branch}: HTTP {r.status_code}",
            )
        head_sha = r.json()["object"]["sha"]
        logger.info("ops.repo.head_read", extra={"sha": head_sha, "branch": branch})

        # -------- 2. Commit para obtener tree_sha --------
        r = await client.get(f"/repos/{repo}/git/commits/{head_sha}")
        r.raise_for_status()
        base_tree_sha = r.json()["tree"]["sha"]

        # -------- 3. Contenido actual del pubspec --------
        r = await client.get(
            f"/repos/{repo}/contents/{PUBSPEC_PATH}",
            params={"ref": branch},
        )
        r.raise_for_status()
        file_data = r.json()
        current_content = base64.b64decode(file_data["content"]).decode("utf-8")

        # -------- 4. Parsear + modificar --------
        parsed = _parse_version(current_content)
        if parsed is None:
            raise RepoWriteError("No se pudo parsear 'version: X.Y.Z+N' en pubspec")
        current_name, current_code = parsed

        if current_name == version_name and current_code == version_code:
            logger.info("ops.repo.pubspec_already_at_target")
            return {
                "commit_sha": head_sha,
                "no_change": True,
                "current_version": f"{current_name}+{current_code}",
            }

        new_content = _replace_version(current_content, version_name, version_code)
        if new_content == current_content:
            raise RepoWriteError("El reemplazo de version no cambio el contenido")

        # -------- 5. Blob del nuevo pubspec --------
        r = await client.post(
            f"/repos/{repo}/git/blobs",
            json={
                "content": base64.b64encode(new_content.encode("utf-8")).decode("ascii"),
                "encoding": "base64",
            },
        )
        r.raise_for_status()
        blob_sha = r.json()["sha"]

        # -------- 6. Tree con el archivo reemplazado --------
        r = await client.post(
            f"/repos/{repo}/git/trees",
            json={
                "base_tree": base_tree_sha,
                "tree": [
                    {
                        "path": PUBSPEC_PATH,
                        "mode": "100644",
                        "type": "blob",
                        "sha": blob_sha,
                    }
                ],
            },
        )
        r.raise_for_status()
        new_tree_sha = r.json()["sha"]

        # -------- 7. Commit --------
        author_email = user_email or "ops-dashboard@baqueanonatales.com"
        commit_message = (
            f"chore(release): bump version a {version_name}+{version_code}\n\n"
            f"Creado desde el Ops Dashboard por {author_email}.\n"
            f"Anterior: {current_name}+{current_code}"
        )
        r = await client.post(
            f"/repos/{repo}/git/commits",
            json={
                "message": commit_message,
                "tree": new_tree_sha,
                "parents": [head_sha],
            },
        )
        r.raise_for_status()
        new_commit_sha = r.json()["sha"]

        # -------- 8. Update ref (force: false = no sobrescribe si cambio) --------
        r = await client.patch(
            f"/repos/{repo}/git/refs/heads/{branch}",
            json={
                "sha": new_commit_sha,
                "force": False,
            },
        )
        if r.status_code == 422:
            raise RepoWriteError(
                f"Race condition: alguien pusheo a {branch} entre medio. "
                f"Reintentar el preview.",
                http_status=409,
            )
        r.raise_for_status()

        logger.info(
            "ops.repo.pubspec_bumped",
            extra={
                "old_sha": head_sha,
                "new_sha": new_commit_sha,
                "from": f"{current_name}+{current_code}",
                "to": f"{version_name}+{version_code}",
            },
        )

        return {
            "commit_sha": new_commit_sha,
            "parent_sha": head_sha,
            "no_change": False,
            "current_version": f"{current_name}+{current_code}",
            "target_version": f"{version_name}+{version_code}",
        }

    except RepoWriteError:
        raise
    except httpx.HTTPStatusError as e:
        logger.error(
            "ops.repo.http_error",
            extra={
                "status": e.response.status_code,
                "body": e.response.text[:300],
            },
        )
        raise RepoWriteError(
            f"Fallo al escribir en GitHub: HTTP {e.response.status_code}",
        ) from e
    except Exception as e:
        logger.exception("ops.repo.unexpected", extra={"error": str(e)})
        raise RepoWriteError(f"Error inesperado: {type(e).__name__}") from e
