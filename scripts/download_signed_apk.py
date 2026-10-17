#!/usr/bin/env python3
"""
Descarga el APK universal firmado por Google Play para una versionCode dada.

Google genera los APKs firmados de forma ASÍNCRONA después de subir el AAB.
El downloadId puede aparecer en list() varios minutos antes de que el archivo
esté disponible para descargar. Por eso hacemos retry con backoff.
"""
import argparse
import io
import time
from google.oauth2 import service_account
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError
from googleapiclient.http import MediaIoBaseDownload

SCOPES = ['https://www.googleapis.com/auth/androidpublisher']


def list_universal_apk(service, package_name, version_code):
    """Devuelve el APK universal (o None si aún no está listado)."""
    response = service.generatedapks().list(
        packageName=package_name,
        versionCode=version_code,
    ).execute()
    for signing_key in response.get('generatedApks', []):
        if 'generatedUniversalApk' in signing_key:
            return signing_key['generatedUniversalApk']
    return None


def download_apk(service, package_name, version_code, download_id, output_path):
    """Descarga el APK. Lanza HttpError si Google devuelve error."""
    request = service.generatedapks().download(
        packageName=package_name,
        versionCode=version_code,
        downloadId=download_id,
    )
    fh = io.BytesIO()
    downloader = MediaIoBaseDownload(fh, request)
    done = False
    while not done:
        _, done = downloader.next_chunk()
    content = fh.getvalue()
    if not content:
        raise HttpError(
            resp=type('R', (), {'status': 204, 'reason': 'No Content'})(),
            content=b'',
        )
    with open(output_path, 'wb') as f:
        f.write(content)
    return len(content)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--json-key', required=True)
    parser.add_argument('--package-name', required=True)
    parser.add_argument('--version-code', required=True, type=int)
    parser.add_argument('--output', required=True)
    parser.add_argument('--max-retries', type=int, default=15)
    parser.add_argument('--delay', type=int, default=30, help='segundos entre reintentos')
    args = parser.parse_args()

    creds = service_account.Credentials.from_service_account_file(args.json_key, scopes=SCOPES)
    service = build('androidpublisher', 'v3', credentials=creds)

    print(f"🎯 Buscando APK firmado: {args.package_name} v{args.version_code}")
    print(f"   Reintentos: {args.max_retries} × {args.delay}s = {args.max_retries * args.delay // 60} min máx")

    for attempt in range(1, args.max_retries + 1):
        try:
            apk_info = list_universal_apk(service, args.package_name, args.version_code)

            if apk_info is None:
                print(f"   [{attempt}/{args.max_retries}] APK aún no listado. Esperando {args.delay}s...")
                time.sleep(args.delay)
                continue

            download_id = apk_info['downloadId']
            print(f"   [{attempt}/{args.max_retries}] APK listado. Intentando descargar...")
            try:
                size = download_apk(service, args.package_name, args.version_code, download_id, args.output)
                size_mb = size / (1024 * 1024)
                print(f"✅ APK guardado: {args.output} ({size_mb:.1f} MB)")
                return
            except HttpError as e:
                if e.resp.status == 204:
                    print(f"   [{attempt}/{args.max_retries}] HTTP 204 (Google aún procesando). Esperando {args.delay}s...")
                    time.sleep(args.delay)
                    continue
                raise
        except HttpError as e:
            if e.resp.status in [400, 404]:
                print(f"   [{attempt}/{args.max_retries}] HTTP {e.resp.status}. Esperando {args.delay}s...")
                time.sleep(args.delay)
                continue
            raise

    raise Exception(f"❌ No se pudo descargar el APK después de {args.max_retries} intentos ({args.max_retries * args.delay // 60} min)")


if __name__ == '__main__':
    main()
