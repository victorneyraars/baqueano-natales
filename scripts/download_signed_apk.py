#!/usr/bin/env python3
"""
Descarga el APK universal firmado por Google Play para una versionCode dada.
Utiliza la Google Play Developer API de forma robusta (con reintentos).
"""
import argparse
import io
import time
from google.oauth2 import service_account
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError
from googleapiclient.http import MediaIoBaseDownload

SCOPES = ['https://www.googleapis.com/auth/androidpublisher']

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--json-key', required=True)
    parser.add_argument('--package-name', required=True)
    parser.add_argument('--version-code', required=True, type=int)
    parser.add_argument('--output', required=True)
    args = parser.parse_args()

    # Autenticación
    creds = service_account.Credentials.from_service_account_file(args.json_key, scopes=SCOPES)
    service = build('androidpublisher', 'v3', credentials=creds)

    print(f"Buscando APK firmado para {args.package_name} (versionCode: {args.version_code})...")
    
    # Google Play puede tardar en generar el APK. Reintentamos hasta 15 veces (2.5 minutos)
    max_retries = 15
    delay = 10
    apk_info = None

    for i in range(max_retries):
        try:
            response = service.generatedapks().list(
                packageName=args.package_name,
                versionCode=args.version_code
            ).execute()
            
            # Buscamos el APK universal (el que sirve para todos los dispositivos)
            for signing_key in response.get('generatedApks', []):
                if 'generatedUniversalApk' in signing_key:
                    apk_info = signing_key['generatedUniversalApk']
                    break
            
            if apk_info:
                print("✅ APK universal encontrado.")
                break
        except HttpError as e:
            if e.resp.status not in [400, 404]:
                raise e
        
        print(f"   APK aún no generado. Reintento {i+1}/{max_retries} en {delay}s...")
        time.sleep(delay)

    if not apk_info:
        raise Exception("❌ Error: Google no generó el APK a tiempo.")

    # Descarga del APK (usando MediaIoBaseDownload — forma canónica Google)
    download_id = apk_info['downloadId']
    print(f"Descargando APK (downloadId: {download_id})...")
    
    request = service.generatedapks().download(
        packageName=args.package_name,
        versionCode=args.version_code,
        downloadId=download_id
    )
    
    fh = io.BytesIO()
    downloader = MediaIoBaseDownload(fh, request)
    done = False
    while not done:
        status, done = downloader.next_chunk()
        if status:
            print(f"   Progreso: {int(status.progress() * 100)}%")
    
    content = fh.getvalue()
    with open(args.output, 'wb') as f:
        f.write(content)
    
    size_mb = len(content) / (1024 * 1024)
    print(f"✅ APK guardado en {args.output} ({size_mb:.1f} MB)")

if __name__ == '__main__':
    main()
