# CI/CD - Baqueano Natales

Pipeline de integracion continua y deploy automatico via GitHub Actions.

## Vision general

| Workflow | Disparador | Que hace | Duracion |
|---|---|---|---|
| **CI** | Push a main + PRs | `flutter analyze` + format check + tests | ~2 min |
| **Build** | PRs a main + tags v* | Compila AAB client + admin **sin firmar** | ~11 min |
| **Release** | Solo tags v* | Firma + sube a Play Store (internal) | ~25 min |

**Estrategia**: CI rapido en cada cambio. Release completo solo con tags.

## Como publicar una nueva version

### 1. Bump version en pubspec.yaml

    version: 0.3.1+4 -> 0.4.0+5

**Regla**: el `+N` (versionCode) siempre incrementa. No se puede repetir en Play Store.

### 2. Commit + push

    git add flutter/pubspec.yaml
    git commit -m "chore: bump version a 0.4.0+5"
    git push origin main

### 3. Crear y pushear tag

    git tag v0.4.0
    git push origin v0.4.0

**Esto es todo.** Los workflows se encargan del resto:
- `Build`: valida que compile
- `Release`: firma con keystore real + sube a Play Store

### 4. Monitorear

    ssh deploy@104.129.59.151 "gh run list --repo victorneyraars/baqueano-natales --limit 5"

    # O en vivo:
    ssh deploy@104.129.59.151 "gh run watch <run-id> --repo victorneyraars/baqueano-natales"

O en el navegador: https://github.com/victorneyraars/baqueano-natales/actions

## Arquitectura de workflows

### `ci.yml` — Feedback rapido

    push a main     -> analyze + format check + tests
    PR a main       -> idem

- **`concurrency`**: cancela runs anteriores del mismo branch (ahorra minutos)
- **Sin compilar**: solo valida codigo (rapido, ~2 min)
- **Tests**: se ejecutan solo si existen en `test/` (se omiten si no hay)

### `build.yml` — Validacion de compilacion

    PR a main       -> compila client + admin sin firmar (matrix paralelo)
    tag v*          -> idem (validacion previa al release)

- **Matrix strategy**: client y admin se compilan en paralelo
- **Sin keystore**: AAB sin firmar (solo valida que compile)
- **Artefactos**: sube los AAB sin firmar por 7 dias

### `release.yml` — Publicacion real

    tag v*          -> firma + sube a Play Store

- **Secuencial**: primero client, luego admin (para no saturar Play Store)
- **Keystore**: se restaura desde `ANDROID_KEYSTORE_BASE64` (secret)
- **Cleanup**: borra el keystore del runner despues del job (`if: always()`)
- **Track**: internal testing

## Secrets configurados

Todos en: https://github.com/victorneyraars/baqueano-natales/settings/secrets/actions

| Secret | Contenido | Uso |
|---|---|---|
| `ANDROID_KEYSTORE_BASE64` | Base64 del `baqueano-release.jks` | Firmar AABs |
| `ANDROID_STORE_PASSWORD` | Password del keystore | idem |
| `ANDROID_KEY_PASSWORD` | Misma password (PKCS12) | idem |
| `ANDROID_KEY_ALIAS` | `baqueano-release` | idem |
| `GOOGLE_SERVICE_ACCOUNT_JSON` | JSON del service account Play Publisher | Upload a Play Store |

## Flujo end-to-end

    Developer (Windows)                  GitHub Actions              Play Store
    ------------------                   ---------------             -----------
    1. Editar codigo
    2. Bump version en pubspec
    3. git push origin main        --> CI (analyze + test)
                                     -> success

    4. git tag v0.4.0
    5. git push origin v0.4.0     --> Build (sin firmar)
                                     Release:
                                       - Restaurar keystore
                                       - Firmar AAB
                                       - Upload         --> internal track

## Troubleshooting

### El release falla en "Subir a Play Store"

**Causa**: versionCode duplicado (ya existe en Play Store).

**Fix**: bump `+N` en pubspec.yaml (incrementar en 1).

### El release falla en "Restaurar keystore"

**Causa**: `ANDROID_KEYSTORE_BASE64` mal formado (saltos de linea, encoding).

**Fix**: re-cargar el secret. Ver docs/ACCESOS_SERVER.md.

### El build falla con NPE en `signAdminProdReleaseBundle`

**Causa**: `build.gradle.kts` intenta firmar sin keystore disponible.

**Fix aplicado**: `signingConfigs.create("release")` y `buildTypes.release` estan
gateados por `if (keystorePropertiesFile.exists())`. Sin keystore → AAB sin firmar.

### Rate limit de GitHub Actions

**Free tier**: 2000 min/mes para repos privados. Para repos publicos es gratis.

**Baqueano**: repo publico → sin limite. Los workflows pueden correr sin costo.

## Mejoras futuras

- [ ] Tests automatizados en Flutter (`flutter test`)
- [ ] Notificaciones Slack/email cuando falla un release
- [ ] Environments de GitHub (staging, production)
- [ ] Branch protection en main (requiere CI verde)
- [ ] Codecov para cobertura de tests
- [ ] Deploy a dev automatico en merge a `develop` (requiere branch strategy)

## Referencias

- `docs/ACCESOS_SERVER.md` — inventario de accesos y credenciales
- `docs/SERVER_CHEATSHEET.md` — comandos rapidos del server
- `docs/PLAYSTORE_RELEASES.md` (o `docs/playstore/RELEASES.md`) — historial de releases