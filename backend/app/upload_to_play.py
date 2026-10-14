#!/usr/bin/env python3
"""
Sube un AAB a Google Play Console y publica directamente.

Uso:
    python3 upload_to_play.py <path_aab> [track] [--draft]

Ejemplos:
    python3 upload_to_play.py /tmp/app.aab internal           # publica directo
    python3 upload_to_play.py /tmp/app.aab internal --draft   # deja en borrador
    python3 upload_to_play.py /tmp/app.aab production         # publica en prod
"""

import sys
from pathlib import Path
from google.oauth2 import service_account
from googleapiclient.discovery import build
from googleapiclient.http import MediaFileUpload
from googleapiclient.errors import HttpError

# --- Config ---
SERVICE_ACCOUNT_FILE = "/app/secrets/play-publisher.json"
PACKAGE_NAME = "cl.baqueanonatales"
SCOPES = ["https://www.googleapis.com/auth/androidpublisher"]

RELEASE_NOTES = "Nueva version de Baqueano Natales. Incluye mejoras internas."


def get_service():
    creds = service_account.Credentials.from_service_account_file(
        SERVICE_ACCOUNT_FILE, scopes=SCOPES
    )
    return build("androidpublisher", "v3", credentials=creds, cache_discovery=False)


def upload_aab(aab_path, track="internal", draft=False):
    if not Path(aab_path).is_file():
        print(f"ERROR: no existe {aab_path}")
        sys.exit(1)

    size_mb = Path(aab_path).stat().st_size / 1024 / 1024
    status = "draft" if draft else "completed"
    print(f"Subiendo: {aab_path} ({size_mb:.2f} MB) al track '{track}' (status={status})")

    service = get_service()

    # --- 1. Crear edit ---
    print("[1/4] Creando edit...")
    edit = service.edits().insert(body={}, packageName=PACKAGE_NAME).execute()
    edit_id = edit["id"]
    print(f"      edit_id = {edit_id}")

    try:
        # --- 2. Subir el AAB ---
        print("[2/4] Subiendo AAB (puede tardar 1-2 min)...")
        media = MediaFileUpload(aab_path, mimetype="application/octet-stream", resumable=True)
        bundle = service.edits().bundles().upload(
            editId=edit_id, packageName=PACKAGE_NAME, media_body=media
        ).execute()
        version_code = bundle["versionCode"]
        print(f"      versionCode = {version_code}")

        # --- 3. Crear release en el track ---
        print(f"[3/4] Creando release en track '{track}' (status={status})...")
        release_body = {
            "track": track,
            "releases": [
                {
                    "name": f"Build {version_code}",
                    "status": status,
                    "versionCodes": [str(version_code)],
                    "releaseNotes": [
                        {"language": "es-419", "text": RELEASE_NOTES}
                    ],
                }
            ],
        }
        release = service.edits().tracks().update(
            editId=edit_id, packageName=PACKAGE_NAME, track=track, body=release_body
        ).execute()
        print(f"      Release creada en estado '{status}'")

        # --- 4. Commit del edit ---
        print("[4/4] Confirmando edit (esto PUBLICa)...")
        service.edits().commit(editId=edit_id, packageName=PACKAGE_NAME).execute()

        print()
        if draft:
            print("✅ LISTO (draft)")
            print(f"   versionCode {version_code} en borrador en '{track}'")
            print("   Anda a Play Console y publicá manualmente.")
        else:
            print("✅ LISTO (publicado)")
            print(f"   versionCode {version_code} publicado en '{track}'")
            print("   Los testers reciben la actualización en 5-30 min.")

    except HttpError as e:
        msg = e.content.decode() if hasattr(e, "content") else str(e)
        print(f"\n❌ ERROR API: {msg[:800]}")
        sys.exit(1)
    except Exception as e:
        print(f"\n❌ ERROR: {type(e).__name__}: {e}")
        sys.exit(1)


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Uso: python3 upload_to_play.py <path_aab> [track] [--draft]")
        sys.exit(1)
    aab = sys.argv[1]
    track = "internal"
    draft = False
    for arg in sys.argv[2:]:
        if arg == "--draft":
            draft = True
        else:
            track = arg
    upload_aab(aab, track, draft)