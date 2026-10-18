#!/usr/bin/env python3
"""
Registra un SHA-1 en Firebase para las apps Android de Baqueano Natales.
Idempotente: si el SHA-1 ya está registrado, no falla.
"""
import argparse
import os
import sys

from google.oauth2 import service_account
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError

SCOPES = ['https://www.googleapis.com/auth/cloud-platform']
FIREBASE_PROJECT_ID = 'baqueano-natales-prod'
PACKAGE_NAMES = {
    'clientDev': 'cl.baqueanonatales.dev',
    'adminDev': 'cl.baqueanonatales.admin.dev',
}


def get_firebase_service(json_key_path: str):
    creds = service_account.Credentials.from_service_account_file(json_key_path, scopes=SCOPES)
    return build('firebase', 'v1beta1', credentials=creds)


def register_sha1(service, package_name: str, sha1: str):
    apps = service.projects().androidApps().list(parent=f'projects/{FIREBASE_PROJECT_ID}').execute()
    app_id = None
    for app in apps.get('apps', []):
        if app.get('packageName') == package_name:
            app_id = app.get('appId')
            break

    if not app_id:
        raise ValueError(f'App con package {package_name} no encontrada en Firebase')

    parent = f'projects/{FIREBASE_PROJECT_ID}/androidApps/{app_id}'

    existing = service.projects().androidApps().sha().list(parent=parent).execute()
    for cert in existing.get('certificates', []):
        if cert.get('shaHash', '').upper() == sha1.upper():
            print(f'   SHA-1 ya registrado para {package_name}')
            return False

    body = {'shaHash': sha1, 'certType': 'SHA_1'}
    service.projects().androidApps().sha().create(parent=parent, body=body).execute()
    print(f'✅ SHA-1 registrado para {package_name}: {sha1}')
    return True


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--firebase-sa', required=True, help='Path al JSON del service account')
    parser.add_argument('--sha1', required=True, help='SHA-1 en formato con dos puntos o hex')
    parser.add_argument('--flavor', required=True, choices=['clientDev', 'adminDev', 'both'])
    args = parser.parse_args()

    sha1 = args.sha1
    # Normalizar: si viene sin dos puntos, no hace falta formatear. Firebase lo acepta así.
    print(f'🎯 SHA-1 a registrar: {sha1}')

    service = get_firebase_service(args.firebase_sa)

    flavors = ['clientDev', 'adminDev'] if args.flavor == 'both' else [args.flavor]
    for flavor in flavors:
        package_name = PACKAGE_NAMES[flavor]
        try:
            register_sha1(service, package_name, sha1)
        except HttpError as e:
            if e.resp.status == 409:
                print(f'   SHA-1 ya existe para {package_name}')
            else:
                raise


if __name__ == '__main__':
    main()
