# Ops Release Hub

## Arquitectura
App Admin -> Backend -> GitHub Actions -> VPS -> App Admin (Descarga In-App).

## Endpoints
- POST /api/v1/admin/ops/build-dev-apk
- GET /api/v1/admin/ops/latest-apk/{flavor}

## Flutter
- Dependencias: dio, path_provider, open_filex.
- Android: REQUEST_INSTALL_PACKAGES y FileProvider.

## SemVer
- feat: Sube Minor (0.4.0)
- fix: Sube Patch (0.3.5)
- breaking: Sube Major (1.0.0)

## Comandos Canonicos
gh workflow run dev-build.yml -f flavor=adminDev
curl -sS -I https://api-dev.baqueanonatales.com/apks/app-admindev.apk
