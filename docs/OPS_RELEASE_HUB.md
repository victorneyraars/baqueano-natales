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


## 🚀 Fase 4: Auto-Actualización (In-App Updater)

El sistema ahora es capaz de detectar e instalar actualizaciones por sí solo.

### Arquitectura del Auto-Update
1.  **Backend (CI/CD)**: Cada vez que se compila un APK (flavor `clientDev`), el workflow `dev-build.yml` genera un archivo `version.json` público con la `latest_version`, `url`, `sha256` y `changelog`.
2.  **Servicio Flutter (`app_update_service.dart`)**:
    *   Consulta el `version.json` (con cache-buster).
    *   Compara la versión instalada (`package_info_plus`) con la del servidor.
    *   Si hay una nueva, muestra un diálogo con el changelog.
    *   Al aceptar, descarga el APK con `dio` y lanza el instalador nativo con `open_filex`.
    *   Usa `permission_handler` para solicitar automáticamente el permiso de "Instalar apps desconocidas" si es necesario.
3.  **Disparadores (Triggers)**:
    *   **Al abrir la app** (con un delay de 2s para estabilidad).
    *   **Botón manual** en el AppBar (ícono `system_update`).
    *   **Observer de ciclo de vida** (`WidgetsBindingObserver`): chequea al volver del segundo plano (mínimo 5 min de espera).

### Notas técnicas de la Fase 4
*   Se usó `permission_handler v12.0.3` en lugar de la v13 para mantener compatibilidad con `compileSdk = 36`.
*   Se capturó el `navigator.context` antes de los `await` para evitar warnings de `use_build_context_synchronously`.
*   Se agregó `github-token` al action `bundletool` para evitar el rate limit (403) de la API de GitHub.
