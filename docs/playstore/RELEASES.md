# Baqueano Natales - Historial de releases

## Play Store - App oficial

| Track | URL |
|---|---|
| Internal testing | https://play.google.com/apps/internaltest/4701406488817338834 |
| Play Console | https://play.google.com/console/u/0/developers/5489050729101024675 |

## Versiones publicadas

### Build 2 (0.2.0) - 2026-10-14

- **versionCode**: 2
- **Estado**: Disponible para verificadores internos
- **Track**: internal
- **Cambios**: Registro del SHA-1 del app signing key de Google en Firebase. Google Sign-In funcional end-to-end en release.
- **Publicado vía**: API Play Publisher (upload_to_play.py)

### Build 1 (0.1.0) - 2026-10-13

- **versionCode**: 1
- **Estado**: Reemplazada por Build 2
- **Track**: internal
- **Cambios**: Versión inicial del MVP. Login con Google (fallaba en release sin SHA-1 de Google).
- **Publicado vía**: Play Console web (manual)

## Versionado

Formato: `MAJOR.MINOR.PATCH+BUILD` en `flutter/pubspec.yaml`

- **MAJOR**: cambios incompatibles.
- **MINOR**: nuevas features.
- **PATCH**: bugfixes.
- **BUILD**: siempre incrementa (versionCode de Android, no se puede repetir).

Cada versión nueva debe incrementar `BUILD` (obligatorio) y opcionalmente `MAJOR.MINOR.PATCH`.

## Cómo publicar una nueva versión

    # 1. Bump version en pubspec.yaml (ej: 0.2.0+2 -> 0.3.0+3)
    # 2. Build
    flutter build appbundle --flavor clientProd --release -t lib/main_client.dart --dart-define-from-file=dart_defines/client_prod.json

    # 3. Subir al server
    scp flutter/build/app/outputs/bundle/clientProdRelease/app-clientProd-release.aab deploy@104.129.59.151:/tmp/app-vX.aab

    # 4. Publicar
    ssh deploy@104.129.59.151 "docker cp /tmp/app-vX.aab baqueano_backend_prod:/tmp/app-vX.aab"
    ssh deploy@104.129.59.151 "docker exec baqueano_backend_prod python3 /app/upload_to_play.py /tmp/app-vX.aab internal"

## Apps pendientes de crear en Play Console

- **Baqueano Admin** (`cl.baqueanonatales.admin`) - Internal testing permanente
  - Requiere: crear la app en Play Console, subir `adminProd` AAB, activar Play App Signing, registrar SHA-1 en Firebase.