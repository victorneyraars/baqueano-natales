# Baqueano Natales — Contexto Completo del Proyecto

> **Última actualización:** 2026-10-13
> **Propósito:** Documento maestro que resume el estado completo del proyecto para retomar el trabajo en cualquier momento sin perder contexto.

> **Ver también:**
> - `docs/OPERATIVA_DEV.md` — metodología de trabajo, patrones canónicos de comandos, reglas por dominio, workflow dual-repo y reglas de oro.
> - `docs/SERVER_CHEATSHEET.md` — comandos rápidos, credenciales, gotchas del server.

---

## 📋 Changelog reciente

### 2026-10-16 (cont. 46) - Fase 2e del modulo ops: auto-bump + VS Code Remote SSH

**Auto-bump de pubspec.yaml + adopcion de Remote SSH. El release trigger queda 100% funcional end-to-end.**

**Fase 2e - Auto-bump de pubspec.yaml (backend):**

Resuelve el gap critico del flujo: el workflow Release lee la version de `pubspec.yaml`, no del tag. Sin auto-bump, el tag decia `v0.3.5` pero la app publicada tenia la version vieja.

**Nuevo servicio `services_repo.py`:**

- `bump_pubspec_and_push(version_name, version_code, branch, user_email)`:
  - Lee HEAD + tree + contenido de pubspec via GitHub API.
  - Crea blob + tree + commit + update ref en 7 requests atomicos.
  - `force=false` -> si alguien pusheo entre medio, tira 409 (race-safe).
  - `RepoWriteError` con `http_status` para errores user-friendly.

**Modificado `services_release.py` (`ejecutar_release`):**

- Antes de crear el tag, llama a `bump_pubspec_and_push`.
- El tag se crea sobre el **NUEVO commit** (post-bump).
- Audit log con **ambos SHAs**: `head_sha_preview` + `head_sha_post_bump`.
- Si el bump falla, se registra en audit y se aborta sin taggear.

**Test end-to-end verificado:**

- Preview `v9.9.10` -> `target_version=9.9.10+8`.
- Trigger -> commit nuevo `3a92c14` (bump a 9.9.10+8) + tag `v9.9.10` sobre el nuevo commit.
- Audit log con trazabilidad completa (`8211818 -> 3a92c14`).
- Cleanup completo: workflow cancelado, tag borrado, main revertido.

**Impacto real:**

Desde la app admin, publicar `0.3.5` genera commit con pubspec `0.3.5+8` + tag `v0.3.5` **sincronizados**. El workflow usa la version correcta.

**VS Code Remote SSH adoptado:**

- Herramienta nueva para editar backend sin heredocs + PowerShell.
- `Ctrl+S` edita directo en el server.
- Documentado en `docs/DEV_ENVIRONMENT.md` (seccion nueva).
- Regla de oro actualizada: Backend -> ventana SSH, Flutter -> ventana Windows.

**Bug encontrado y fixeado:**

- El commit `18e7857` quedo **incompleto** (solo `services_repo.py`).
- Causa: `git reset --hard` durante el cleanup del test revirtio `services_release.py`.
- Fix: commit `ab26ab8` re-aplico los cambios.
- Leccion: `git reset --hard` es peligroso con cambios sin commitear. Verificar con `git stash` antes de correrlo.

**Commits:**

- `18e7857` feat(ops): auto-bump de pubspec.yaml antes de taggear (Fase 2e)
- `ab26ab8` fix(ops): re-aplicar auto-bump en services_release.py

**Estado del modulo ops (Fase 2 COMPLETA + extendida):**

- 2a: audit log.
- 2b: preview endpoint.
- 2c: trigger endpoint (4 safety rails).
- 2d: frontend completo.
- 2e: auto-bump pubspec + push atomico.

**Fase 3 (roadmap):** live streaming (SSE) sobre audit log + webhooks GitHub.

**Deuda tecnica documentada:**

- Migracion de PAT a GitHub App (sub-fase 2f).
- Considerar flow de "revert commit" en lugar de `--force push` cuando haya equipo trabajando en paralelo.

### 2026-10-16 (cont. 45) - Fase 2d del modulo ops + FASE 2 COMPLETA

**Frontend del release trigger + prueba end-to-end en emulador. El feature es 100% usable.**

**Que se entrego (2d):**

- **Models Dart** (`ops_models.dart`):
  - `ValidationStatus` enum (ok/warning/error).
  - `ValidationCheck` (name, status, detail).
  - `ReleasePreview` (versiones + validaciones + preview_token + expires_at).
  - `ReleaseTrigger` (tag, sha, workflow, github_url, audit_log_id, message).
  - Getters: `errorCount`, `warningCount`.

- **Repository** (`ops_repository.dart`):
  - `releasePreview(versionName, branch)` -> POST `/release/preview`.
  - `releaseTrigger(previewToken)` -> POST `/release/trigger` (con `confirm: 'CONFIRMAR'` automatico).

- **Providers** (`ops_providers.dart`):
  - `ReleasePreviewParams` (inmutable, family param).
  - `opsReleasePreviewProvider` (family).

- **Pantalla** (`ops_release_screen.dart`, ~450 lineas):
  - Form con validacion de version_name (X.Y.Z).
  - Boton "Generar preview" -> muestra el preview.
  - Preview card con: versiones (actual -> nueva), tag, versionCode, workflow, duracion, commit a taggear.
  - Validaciones con iconos verde/naranja/rojo.
  - Boton "Publicar release" (disabled si can_proceed=false).
  - Modal de confirmacion con input `CONFIRMAR` (habilitado solo si matchea exacto).
  - Trigger -> resultado con tag, sha, github_url + boton "Ver workflow en GitHub".

- **Wire**:
  - Ruta `/admin/ops/release` en `app_router.dart`.
  - Boton `rocket_launch` en el AppBar del Ops Dashboard.

**Verificado end-to-end en emulador Android 14:**

- Pantalla carga correctamente.
- Form valida inputs invalidos.
- Preview de `0.3.5`: current `0.3.4+7` -> target `0.3.5+8`, tag `v0.3.5`, 4 validaciones OK, boton "Publicar release" habilitado (verde).
- Preview de `0.3.4`: detecta "tag duplicado" en rojo, boton deshabilitado (gris).
- `flutter analyze`: No issues found! (3.5s).

**Estado del modulo ops (Fase 2 COMPLETA):**

- **Fase 1 (read-only):** health + runs + tracks + links + quick-links.
- **Fase 2 (acciones):**
  - 2a: audit log (tabla `ops_audit_log`).
  - 2b: preview endpoint (dry-run).
  - 2c: trigger endpoint (crea tag + dispara workflow + 4 safety rails).
  - 2d: frontend completo.
- **Fase 3 (roadmap):** live streaming (SSE) sobre audit log + webhooks GitHub.

**Commits:**

- `d789561` feat(ops): Fase 2d - pantalla de release trigger en Flutter (frontend)

**Deuda tecnica documentada:**

- Migracion de PAT a GitHub App (sub-fase 2e).
- Documentar procedimiento "Remote SSH + git apply" en lugar de heredoc + string replace.

**Lecciones de la sesion (sobre los errores de edicion):**

- El patron heredoc `@'...'@` + `.Replace()` es fragil: CRLF vs LF, escapado de strings, regex.
- Mejor patron: VS Code Remote SSH o git apply (patches).
- Ver seccion nueva en `docs/DEV_ENVIRONMENT.md` (proxima).

### 2026-10-16 (cont. 44) - Fase 2b + 2c del modulo ops (release trigger)

**Preview + trigger de releases desde el Ops Dashboard. 4 safety rails. Auditado.**

**Fase 2b - Preview (dry-run):**

- `POST /admin/ops/release/preview` con `{version_name, branch}`.
- Valida: pubspec parseable, tag libre, versionCode > max en Play, HEAD accesible.
- Calcula: current_version, target_version, next_version_code, target_tag.
- Devuelve `preview_token` (JWT firmado, TTL 5 min, nonce, issuer).
- Si falla alguna validacion -> `can_proceed=false` + detalle por check.
- Endpoint: 400/422/401 en casos de input invalido o sin auth.

**Fase 2c - Trigger real:**

- `POST /admin/ops/release/trigger` con `{preview_token, confirm}`.
- **4 safety rails**:
  1. `confirm == "CONFIRMAR"` exacto.
  2. `preview_token` firmado (valida firma + issuer + user + TTL).
  3. `head_sha` no cambio entre preview y trigger.
  4. Rate limit: 1 release por user cada 10 min.
- Crea el tag en GitHub (`POST /git/refs`) -> dispara workflow Release.
- Registra en `ops_audit_log` (action=release.trigger, status=success/error).
- Devuelve: tag, commit_sha, workflow_name, github_url, audit_log_id, message.

**Test end-to-end (dev) verificado:**

- Sin confirm -> 400.
- Preview token falso -> 400 (`Invalid crypto padding`).
- Preview v9.9.9 -> can_proceed=true, target=9.9.9+8.
- Trigger real -> tag v9.9.9 creado en GitHub + workflow Release disparado + audit log registrado (861ms).
- Re-trigger inmediato -> 429 rate limit.
- Cleanup: tag + workflow cancelado.

**Token de GitHub verificado:**

- OAuth scopes: `admin:public_key, gist, read:org, repo`.
- Permisos: push=True, admin=True, pull=True.
- PAT fine-grained con escritura OK.

**Lecciones tecnicas:**

- **PyJWT, no python-jose**: el proyecto usa `pyjwt==2.10.1`. El `ALGORITHM` esta en `settings.ALGORITHM`, no como constante top-level.
- **Patron del heredoc anidado**: `docker exec python3 << 'PYEOF'` dentro de un script bash es fragil. Mejor escribir el `.py` en el host + `docker cp` + `docker exec -e PYTHONPATH=/app python3 /tmp/x.py`.
- **Cleanup de tag**: el `gh api DELETE` via SSH desde el server hacia GitHub funciona si se corre desde Windows/PowerShell, no desde dentro del script bash remoto (SSH anidado falla con host key verification).

**Commits:**

- `d7772d5` feat(ops): Fase 2b - endpoint release/preview (dry-run)
- `094960f` feat(ops): Fase 2c - release trigger (crea tag + dispara workflow)

**Pendiente siguiente (Fase 2 continuacion):**

- **2d**: frontend Flutter (boton + modal preview + confirmacion + historial).
- **2e**: migracion de PAT a GitHub App (fase separada).

**Fase 3 (roadmap):**

- Live streaming en la app movil (SSE sobre ops_audit_log + webhooks GitHub). Base ya lista.

### 2026-10-16 (cont. 43) - Fase 2a del modulo ops: audit log

**Primera sub-fase de la Fase 2 (trigger de releases desde la app). Base para auditoria + live streaming (Fase 3).**

**Que se entrego:**

- **Tabla `ops_audit_log`** (append-only):
  - Quien: `user_id` (FK SET NULL), `user_email` (snapshot).
  - Que: `action` (`release.trigger`, etc.), `target` (tag/track).
  - Resultado: `status` (`pending|success|error|rejected|cancelled`), `error_message`.
  - Detalle: `payload` (JSONB, sanitizado), `result` (JSONB), `duration_ms`.
  - Contexto: `ip_address`, `user_agent`.
  - Indexes: `action`, `created_at`, `status`, `user_id`.

- **Servicio `services_audit.py`** con `registrar()`:
  - **Best-effort**: nunca propaga excepcion, devuelve `None` si falla.
  - **Sanitizacion automatica**: campos con `token|password|secret|authorization|pat|api_key|access_token|refresh_token` -> `"***"`.
  - **Truncado**: payload strings 1KB, error 2KB, user_agent 500B.
  - Soporta `db=None` (abre sesion propia, util para `BackgroundTasks` post-request).

**Migracion Alembic `96ba32d7100d`:**

- Aplicada en **dev** y **prod**.
- Limpiada a mano (Alembic autogenerate traia ~30 cambios espurios en `usuarios`, `fcm_tokens`, `notification_logs`, `preferencias_notificacion`, `rate_limit_config`, `orden_fotos`).
- `env.py` actualizado con `from app.modules.ops import models`.

**Test end-to-end (dev):**

- Insercion + lectura OK.
- Sanitizacion OK: `{"token": "SHOULD_BE_SANITIZED"}` -> `{"token": "***"}`.
- Best-effort OK: email de 500 chars -> `None`, sin propagar excepcion.

**Bug encontrado (patron conocido):**

`backend-prod` no tiene el volumen `./backend/app` montado (imagen autocontenida). Requiere rebuild despues de cambios en `backend/app/`. `backend-dev` si lo tiene. Es la misma asimetria que encontramos con quick-links.

**Leccion operativa:**

- **Dev**: `./backend/app` montado -> cambios en Python requieren restart (no rebuild) + a veces ni eso (hot reload no siempre dispara).
- **Prod**: imagen autocontenida -> SIEMPRE rebuild + restart.

**Lecciones tecnicas:**

- `docker exec python3 script.py` falla con `ModuleNotFoundError: app` — el `-w /app` NO es suficiente, hay que usar `-e PYTHONPATH=/app`.
- El patron "import de todos los modelos antes de AsyncSessionLocal" en scripts standalone es OBLIGATORIO (gotcha 4.3 del OPERATIVA_DEV).

**Commits:**

- `ae79e46` feat(ops): Fase 2a - tabla ops_audit_log + servicio de auditoria

**Pendiente siguiente (Fase 2 continuacion):**

- **2b**: endpoint `POST /admin/ops/release/preview` (dry-run).
- **2c**: endpoint `POST /admin/ops/release` (trigger real, requiere `{"confirm": "CONFIRMAR"}` + rate limit 10 min + validaciones).
- **2d**: frontend (boton + modal + historial).

**Decision de diseno pendiente (confirmada):**

- PAT fine-grained primero, migrar a GitHub App en fase separada (2e).
- Preview obligatorio antes de trigger.
- Audit solo de acciones que cambian estado (preview NO se audita -> mantiene log limpio).

### 2026-10-16 (cont. 42) - Scripts de deploy validados end-to-end

**deploy-dev.sh y deploy-prod.sh probados y funcionando.**

**Tests ejecutados:**

1. **deploy-dev.sh** con marker de test:
   - Marker commiteado en `services_quick_links.py`.
   - Script corrido: pull + build + recreate + healthcheck.
   - Resultado: `DEPLOY OK`. Container recreado correctamente.

2. **deploy-prod.sh** con cancelacion:
   - Input "no" al prompt.
   - Resultado: `Cancelado.` + exit 1. Prod NO se toco. ✅

**Bug encontrado y resuelto:**

El healthcheck original tenia 5s de timeout y fallaba con `502`. Uvicorn tarda ~15s en arrancar (imports + DB + workers). Los scripts ahora hacen retry cada 3s hasta 60s.

**Comportamiento correcto del script (idempotente):**

- **Si hay codigo nuevo**: `Recreated` + `Started` → recarga el codigo.
- **Si no hay cambios**: `Running` → no toca el container.

**Commits:**

- `b959ef4` fix(scripts): retry en healthcheck hasta 60s
- `0c07385` chore(ops): deploy test marker (2026-10-16 02:01:52) — temporal
- `b2de665` chore(ops): limpiar marker de test de deploy

**Estado:**

- Regla "siempre rebuild+restart despues de git pull en el server" ahora esta automatizada.
- El bug del backend desactualizado (que encontramos con quick-links) queda prevenido para el futuro.

**Uso diario:**

    # Dev
    ssh deploy@104.129.59.151 "bash ~/baqueano-natales/scripts/deploy-dev.sh"

    # Prod (pide escribir CONFIRMAR)
    ssh deploy@104.129.59.151 "bash ~/baqueano-natales/scripts/deploy-prod.sh"

### 2026-10-16 (cont. 41) - Release v0.3.4 publicado en Play Store

**Release v0.3.4 firmado, subido y publicado en Play Store internal testing.**

**Contenido del release:**

- Ops Dashboard (Fase 1 read-only) completo.
- Quick Links: 15 accesos directos a Play Console, GitHub, Infraestructura.
- Config VS Code a nivel industria + lints estrictos.
- Optimizaciones Windows (Defender exclusiones + limpieza disco).

**Pipeline CI/CD:**

- **Release CLIENT a Play Store**: `11m47s` (build + firma + upload).
- **Release ADMIN a Play Store**: `11m29s` (build + firma + upload).
- **Total: ~23 min** (secuencial para no saturar Play Store API).
- Run ID: `38829519703`.

**Version:**

- `pubspec.yaml`: `0.3.4+7` (versionCode 7).
- Ambas apps (client + admin) publicadas como versionCode 7.

**Prevencion de bug (nuevo bloque):**

Encontrado y resuelto: el backend dev no tenia el modulo `ops` deployado — el codigo estaba en GitHub pero el proceso uvicorn llevaba 25h corriendo la version vieja.

**Fix aplicado:**

- `scripts/deploy-dev.sh` (nuevo): pull + build + up -d + healthcheck.
- `scripts/deploy-prod.sh` (nuevo): igual pero pide escribir "CONFIRMAR".
- Seccion "Flujo canonico de deploy backend" en `SERVER_CHEATSHEET.md`.
- Regla nueva: despues de cada `git pull` en el server, SIEMPRE rebuild + restart.

**Commits del bloque:**

- `08f2fb1` feat(ops): quick links a dashboards externos (backend)
- `3e2b9f5` feat(ops): quick links a dashboards externos (Play Console, GitHub, Infra)
- `2cb6c88` docs(contexto): changelog quick links del Ops Dashboard (cont. 40)
- `b327e63` chore(release): bump version a 0.3.4+7 (tag v0.3.4)
- `12af481` feat(scripts): deploy-dev.sh y deploy-prod.sh para automatizar backend
- `9a39a5d` docs(cheatsheet): flujo canonico de deploy backend

**Estado:**

- App admin con Ops Dashboard + Quick Links disponible en Play Store internal (versionCode 7).
- Backend prod/dev healthy con el nuevo endpoint `/admin/ops/quick-links`.

**Proximo paso:**

- Probar los scripts de deploy-dev.sh y deploy-prod.sh end-to-end.
- Sesion dedicada: rotacion de secretos expuestos (SECRET_KEY, TOKEN_ENCRYPTION_KEY, Facebook app secret).
- Fase 2 del modulo ops: trigger de releases desde la app.

### 2026-10-15 (cont. 40) - Quick links a dashboards externos (Ops Dashboard)

**El Ops Dashboard ahora tiene "Accesos directos": 15 links a Play Console, GitHub e Infraestructura. Escalable desde el backend.**

**Backend:**

- `schemas.py`: nuevos modelos `QuickLink`, `QuickLinkCategory`, `QuickLinksResponse`.
- `services_quick_links.py` (nuevo): construye los links desde settings.
- `routes.py`: nuevo endpoint `GET /admin/ops/quick-links`.
- `config.py`: 5 settings nuevos (`PLAY_CONSOLE_DEV_ID`, `PLAY_CONSOLE_APP_ID_CLIENT`, `PLAY_CONSOLE_APP_ID_ADMIN`, `CLOUDFLARE_DASHBOARD_URL`, `RACKNERD_DASHBOARD_URL`).

**Frontend:**

- `ops_models.dart`: modelos espejo (`QuickLink`, `QuickLinkCategory`, `QuickLinksResponse`).
- `ops_repository.dart`: metodo `quickLinks()`.
- `ops_providers.dart`: `opsQuickLinksProvider`.
- `ops_estado_screen.dart`: card `_QuickLinksCard` con iconos semanticos + tiles clickeables.

**Categorias (15 links):**

- **Play Console** (7): testers client, internal client, testers admin, internal admin, Play Store client, Play Store admin, console general.
- **GitHub** (4): repo, actions, releases, issues.
- **Infraestructura** (4): cloudflare, racknerd, health prod, health dev.

**Escalabilidad:**

Agregar un link nuevo = solo editar `services_quick_links.py` (backend). El frontend renderiza generico segun la respuesta del backend. **Cero cambios en Flutter.**

**Bug encontrado y resuelto (importante):**

El backend dev no tenia el modulo `ops` deployado — el codigo estaba en GitHub pero el proceso de uvicorn llevaba 25h corriendo con la version anterior. El hot reload no se disparo.

**Causa:** `git pull` en el server trae el codigo nuevo al disco, pero no reinicia el proceso de uvicorn. Aunque `./backend/app` este montado como volumen, uvicorn no recarga sin `--reload` explicito o reinicio del container.

**Solucion aplicada:**

    ssh deploy@104.129.59.151 "cd ~/baqueano-natales && \
      git pull --rebase origin main && \
      docker compose -f docker-compose.yml -f docker-compose.dev.yml build backend-dev && \
      docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d backend-dev"

**Regla nueva:** despues de cada `git pull` en el server, SIEMPRE rebuild + restart del backend correspondiente. El nombre del servicio en dev es `backend-dev` (no `backend`).

**Commits:**

- `08f2fb1` feat(ops): quick links a dashboards externos (backend)
- `3e2b9f5` feat(ops): quick links a dashboards externos (Play Console, GitHub, Infra)

**Pendiente siguiente:**

- Scripts `scripts/deploy-dev.sh` + `scripts/deploy-prod.sh` para automatizar rebuild+restart (evita el error humano).
- Documentar el flujo canonico de deploy en `SERVER_CHEATSHEET.md`.
- Tag `v0.3.4` para publicar.

### 2026-10-15 (cont. 39) - Entorno de desarrollo a nivel industria + Ops Dashboard verificado

**Setup de VS Code + lints + optimizaciones de Windows. Flutter analyze paso de 10-266s a 4.87s.**

**Bloque 4 completo (Ops Dashboard):**

- Bloque 4a, 4b, 4c: domain models + repository + providers + pantalla responsive + wire al home admin.
- Auto-refresh 30s pausado en background, pull-to-refresh, vista error con retry.
- `ResponsiveLayout` creado en `core/widgets/` (no existia).
- Commit `3e12f74`.

**Config VS Code a nivel industria:**

- `.vscode/extensions.json` (11 extensiones: Dart, Flutter, ErrorLens, GitLens, spell-checker ES, snippets).
- `.vscode/settings.json` (format on save, organize imports, file nesting, ruler 100, spell-checker ES, terminal scrollback 10000).
- `.vscode/launch.json` (4 configs de debug por flavor).
- `.vscode/tasks.json` (7 tasks: analyze, pub get, clean, test, build APK, build AAB).
- `.gitignore`: bloque de excepciones para versionar `.vscode/` + soporte `*.local.json`.
- `docs/VSCODE_SETUP.md` (guia del setup).
- Commits `12560bf` + `34f0a57`.

**Lints estrictos (`flutter/analysis_options.yaml`):**

- Reglas de bajo ruido/alto valor (prefer_const, prefer_final, avoid_print, siempre tipos de retorno).
- Se dejaron FUERA: `prefer_relative_imports`, `directives_ordering`, `sort_constructors_first` (churn sin valor).
- `dart fix --apply`: 26 fixes en 9 archivos.
- `flutter analyze`: `No issues found!` (522 issues → 0 tras ajustar reglas).

**Optimizaciones del sistema (Windows):**

- **Windows Defender exclusiones aplicadas** (9 rutas + 11 procesos).
  - Impacto medido: `flutter analyze` paso de 10-266s a **4.87s**.
  - MsMpEng habia acumulado 2400s de CPU en una sesion (40 min de CPU quemados).
- **Limpieza de disco C:** liberados **20.8 GB**:
  - Downloads: 6.74 GB (instaladores ya usados).
  - Mitchell OnDemand → D:\Mitchell OnDemand\: 4.09 GB.
  - VirtualBox VM Win10_ATorch borrada: 12.2 GB.
  - C: paso de 33.4 GB → 54.2 GB libres (14% → 22.8%).

**Documentacion nueva:**

- `docs/DEV_ENVIRONMENT.md`: hardware, software, reglas de uso, exclusiones Defender, optimizaciones VS Code, troubleshooting, changelog del doc.

**Regla de oro actualizada:**

- **VS Code para Flutter, MobaXterm para SSH al server.** Nunca usar la terminal de MobaXterm para Flutter (hereda variables MSYS que rompen `flutter analyze` con "Unable to determine engine version").

**Commits de la sesion (8):**

- `3b7b48a` feat(ops): modelos de dominio del Ops Dashboard (Fase 1 read-only)
- `12560bf` chore(vscode): configuracion de workspace Flutter + lints estrictos
- `1a25b48` feat(ops): repository + providers del Ops Dashboard (Bloque 4b)
- `3e12f74` feat(ops): pantalla Ops Dashboard + wire al admin (Bloque 4c)
- `34f0a57` chore(vscode): agregar scrollback 10000 a la terminal integrada
- `47a7f8c` docs(contexto): changelog Bloque 4 - Ops Dashboard Flutter (Fase 1 completa)
- (este commit) docs(dev): entorno de desarrollo + optimizaciones Windows

**Pendientes para proxima sesion:**

- Probar la pantalla Ops Dashboard en emulador o device real (el AVD `Pixel6_API34_Play` puede necesitar recrearse).
- Tag `v0.3.4` para publicar en Play internal (CI/CD toma el tag y publica en ~25 min).
- Fase 2 del modulo ops: trigger de releases desde la app + migrar a GitHub App.

### 2026-10-15 (cont. 38) - Bloque 4: Ops Dashboard Flutter (Fase 1 completa)

**La app admin ya tiene el Ops Dashboard end-to-end: 5 endpoints consumidos, pantalla responsive, wire al home.**

**Entregables:**

- **Bloque 4a (domain models)** — `flutter/lib/features/ops_admin/domain/ops_models.dart` (543 lineas)
  - 11 tipos: `RunInfo`, `StepInfo`, `JobInfo`, `RunDetail`, `RunsResponse`, `TrackVersion`, `AppTracks`, `TracksResponse`, `AppLinks`, `LinksResponse`, `ComponentHealth`, `SystemHealth`
  - 3 enums con `fromRaw` defensivo (fallback `unknown`): `WorkflowRunStatus`, `WorkflowRunConclusion`, `ComponentStatus`
  - Getters de UI: `RunInfo.duracionHumana`, `TrackVersion.trackLabel`, `SystemHealth.allOk`
  - Parsing tolerante a nulls/campos faltantes (helpers `_asInt`, `_asString`, `_asDateTime`, `_asListOfMap`, `_asMap`)

- **Bloque 4b (data)** — `flutter/lib/features/ops_admin/data/`
  - `ops_repository.dart` (5 metodos: health, runs, runDetail, tracks, links)
  - `ops_providers.dart` (`opsRepositoryProvider` + 5 FutureProviders, `opsRunsProvider` family con `RunsParams` inmutable)

- **Bloque 4c (presentation + wire)** — `flutter/lib/features/ops_admin/presentation/screens/ops_estado_screen.dart` (~630 lineas)
  - Header con estado consolidado (ok/atencion + stats 24h)
  - Componentes del sistema (iconos por status: ok/degraded/down/unknown)
  - Ultimo release exitoso (nombre, run number, duracion)
  - Lista de ultimos 10 runs con icono por conclusion
  - Links de descarga (chips opt-in + Play Store con `url_launcher`)
  - Auto-refresh cada 30s con `Timer` (pausado en background via `WidgetsBindingObserver`)
  - Pull-to-refresh manual + vista error con retry
  - Responsive: phone 1 col / tablet 2 cols (Row + Expanded)
  - `core/widgets/responsive_layout.dart` creado (no existia) — regla 11 canonica
  - `app_router.dart`: import + GoRoute `/admin/ops`
  - `admin_home_screen.dart`: card Ops Dashboard (icon `monitor_heart`) antes de Usuarios

**Config VS Code a nivel industria (bonus):**

- `.vscode/extensions.json` — 11 extensiones recomendadas (Dart, Flutter, ErrorLens, GitLens, spell-checker ES, snippets)
- `.vscode/settings.json` — format on save, organize imports, file nesting, ruler 100, spell-checker ES, terminal scrollback 10000, terminal PowerShell
- `.vscode/launch.json` — 4 configs de debug (clientDev, clientProd, adminDev, adminProd)
- `.vscode/tasks.json` — 7 tasks (analyze, analyze --fatal-infos, pub get, clean, test, build APK, build AAB)
- `.gitignore` — bloque de excepciones para versionar `.vscode/` + soporte `*.local.json`
- `docs/VSCODE_SETUP.md` — guia completa del setup

**Lints estrictos (`analysis_options.yaml`):**

- Reglas de bajo ruido/alto valor: `prefer_const`, `prefer_final`, `avoid_print`, `prefer_single_quotes`, `always_declare_return_types`, `use_super_parameters`, `avoid_dynamic_calls`
- Se dejaron FUERA del lint: `prefer_relative_imports`, `directives_ordering`, `sort_constructors_first` (churn sin valor en un proyecto maduro)
- `dart fix --apply`: 26 fixes automaticos en 9 archivos (prefer_const_constructors, unnecessary_lambdas)
- `flutter analyze`: `No issues found!`

**Regla de oro actualizada para la sesion:**

- **VS Code para Flutter, MobaXterm para SSH al server.** Nunca usar la terminal de MobaXterm para Flutter (mete variables MSYS que rompen `flutter analyze` con "Unable to determine engine version").

**Commits:**

- `3b7b48a` feat(ops): modelos de dominio del Ops Dashboard (Fase 1 read-only)
- `12560bf` chore(vscode): configuracion de workspace Flutter + lints estrictos
- `1a25b48` feat(ops): repository + providers del Ops Dashboard (Bloque 4b)
- `3e12f74` feat(ops): pantalla Ops Dashboard + wire al admin (Bloque 4c)
- `34f0a57` chore(vscode): agregar scrollback 10000 a la terminal integrada

**Estado del Ops Dashboard:**

- **Fase 1 (read-only): COMPLETA end-to-end.**
- Backend: 5 endpoints admin OK (health, runs, runDetail, tracks, links).
- Frontend: pantalla completa + wire + auto-refresh.
- **Pendiente Fase 2** (del roadmap del modulo ops): trigger de releases desde la app (crea tag), migrar a GitHub App, tabla `ops_audit_log`.

**Proximo paso sugerido:**

- Probar la pantalla end-to-end en emulador admin (`flutter run --flavor adminDev -t lib/main_admin.dart --dart-define-from-file=dart_defines/admin_dev.json`).
- Tag `v0.3.4` para publicar la nueva version (CI/CD toma el tag y publica en Play internal).

### 2026-10-14 (cont. 37) - CI/CD con GitHub Actions

**Pipeline completo de integracion + deploy. Publicar una version es `git tag vX.Y.Z` + push.**

**Implementacion (3 workflows):**

- **`ci.yml`** — Push a main + PRs: `flutter analyze` + format check + tests. ~2 min.
- **`build.yml`** — PRs + tags v*: compila AAB client + admin sin firmar (matrix paralelo). ~11 min.
- **`release.yml`** — Solo tags v*: restaura keystore del secret + firma + sube a Play Store (internal). ~25 min (2 jobs secuenciales).

**Primer release exitoso:**

- Tag `v0.3.1` pusheado.
- Release CLIENT: ✅ 12m51s.
- Release ADMIN: ✅ 12m18s.
- Ambas versiones subidas a Play Store internal testing.

**Secrets cargados via `gh` CLI del server (sin instalar nada local):**

- `ANDROID_KEYSTORE_BASE64` (3752 chars)
- `ANDROID_STORE_PASSWORD` + `ANDROID_KEY_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `GOOGLE_SERVICE_ACCOUNT_JSON` (2385 chars)

Cargados con un script Python via `gh secret set <NAME>` (stdin para los largos).

**Pulido del bloque:**

- `build.gradle.kts`: `signingConfigs.create("release")` y `buildTypes.release` gateados por `keystorePropertiesFile.exists()`. Sin keystore → AAB sin firmar (fix del NPE en `build.yml`).
- `ci.yml` / `build.yml` / `release.yml`: `ubuntu-latest` → `ubuntu-24.04`, `actions/checkout@v4` → `@v5`, `actions/setup-java@v4` → `@v5`.
- `release.yml`: `track: internal` → `tracks: internal` (formato nuevo de `r0adkll/upload-google-play`).
- `docs/CICD.md`: guia completa del pipeline.

**Flujo canonico para publicar:**

    # 1. Bump version en pubspec.yaml (el +N siempre incrementa)
    # 2. git push origin main
    # 3. git tag vX.Y.Z && git push origin vX.Y.Z
    # 4. Los workflows se encargan del resto

**Commits:**

- `730993d` ci: agregar workflows de GitHub Actions (CI + Build + Release)
- `7d16f1c` chore(release): fix workflow + bump version a 0.3.1+4
- `75ecbe8` ci: pulir workflows + fix gradle signing + docs CICD

**Deuda menor:**

- Actualizar `flutter test` cuando existan tests (hoy no hay).
- Notificaciones Slack/email al fallar un release.

**Pendientes globales:**

- Rotacion de secretos expuestos.
- Ops Dashboard en la app admin (Fase 1 read-only, ~2-3 h).
### 2026-10-14 (cont. 36) - Bloque C: git server <-> GitHub <-> Windows alineados

**Los 3 entornos sincronizados en el mismo commit. Working tree limpio en todos.**

**Problema resuelto:**

El server llevaba 15+ commits atras (`6a1a03c`) con cambios locales sin commitear que quedaron de los bloques anteriores (Bluetooth setup, legal pages, Play Publisher API). Riesgo de perder trabajo + conflictos al pushear desde Windows.

**Solucion aplicada:**

1. **`.gitignore` reforzado** (server + repo): agregados `backend/secrets/` y `deploy/legal/`.
   - **CRITICO**: `play-publisher.json` (JSON key del service account) NO estaba ignorado -> riesgo de commit accidental. Ahora sí.

2. **Backup pre-sync**: copia de los 4 archivos a `/tmp/pre-sync-backup-20261014/` en el server.

3. **Stash + pull + pop**: los cambios locales se guardaron con `git stash`, se hizo `git pull --rebase` (15 commits), y se aplicó el stash de vuelta.

4. **Commit consolidado** (`6d9b396`):
   - `.gitignore`: agregados backend/secrets/ + deploy/legal/
   - `docker-compose.yml`: bind mount ./deploy/legal:/usr/share/nginx/legal:ro
   - `deploy/nginx/conf.d/api.conf`: location /legal/ (privacidad, terminos, eliminacion)
   - `backend/requirements.txt`: google-api-python-client, google-auth, google-auth-httplib2

5. **Pull en Windows**: fast-forward, sin conflictos.

**Estado final (verificado):**

    Windows:  6d9b396 (HEAD)
    Server:   6d9b396 (HEAD)
    GitHub:   6d9b396 (origin/main)
    Working tree: limpio en ambos lados.

**Commits relevantes del dia:**

- `6d9b396` infra: proteger secrets + bind mount legal + libs google-play-api
- `05e75ef` feat(play-api): admin publicado (v3) + script multi-package
- `94d20bb` feat(flutter): icono morado especifico para flavors admin
- `6466e0f` docs(brand): brand kit para Baqueano Admin
- `5a33223` docs(cheatsheet): corregir path del script upload_to_play.py
- `be7b1ff` docs: cierre Bloque 6 - app publicada en Play Store

**Pendiente global:**

- Rotacion de secretos expuestos (SECRET_KEY, TOKEN_ENCRYPTION_KEY, PAT legacy, Facebook app secret).
- CI/CD con GitHub Actions.
- Features de producto (mapa, delivery, carta QR, recompensas).
### 2026-10-14 (cont. 35) - Bloque 7: Baqueano Admin publicado en Play Store

**Ambas apps publicadas: cliente + admin. Dupla completa operativa.**

**Estado de Baqueano Admin:**

| Componente | Estado |
|---|---|
| App en Play Console | `Baqueano Admin` (ID: `4973778958369099895`) |
| Package | `cl.baqueanonatales.admin` |
| Icono | Morado (#5A3D8A -> #1A0F2E), 5 densidades × 2 variantes |
| Feature graphic | Morado con logo + tagline |
| 4 screenshots | Mockups de gestion (panel, verificaciones, reportes, redes) |
| Categoria | **Negocios** (no Estilo de vida) |
| Formularios Play | Todos completos |
| Play App Signing | Activado, SHA-1 de Google: `29:C9:2D:46:E1:4A:FF:AA:C0:26:4C:A0:5C:58:C3:CA:32:6C:10:BB` |
| Firebase | SHA-1 admin registrado en `cl.baqueanonatales.admin` |
| AAB | versionCode=3 (0.3.0), publicado via API |
| Track | Internal testing |

**Cambios al script de upload:**

`upload_to_play.py` ahora **detecta automaticamente el package** segun el nombre del AAB:
- Si el archivo contiene "admin" en el nombre -> `cl.baqueanonatales.admin`
- Si no -> `cl.baqueanonatales`

Comandos canonicos sin cambios:

    ssh deploy@104.129.59.151 "docker exec baqueano_backend_prod python3 /app/app/upload_to_play.py /tmp/app-admin-v3.aab internal"
    ssh deploy@104.129.59.151 "docker exec baqueano_backend_prod python3 /app/app/upload_to_play.py /tmp/app-client-vX.aab internal"

**Permisos del service account:**

El service account `play-publisher@baqueano-natales-prod.iam.gserviceaccount.com` fue
actualizado para tener **Admin total sobre TODAS las apps** de Studio Digital 360
(en vez de solo Baqueano Natales). Esto cubre la app admin + futuras apps.

**Gotcha aprendido:**

Al invitar un service account a Play Console, los permisos son **por app**.
Cuando se crea una nueva app (ej: admin), hay que editar el acceso del service
account y marcar la nueva app (o "Todas las apps"). El cambio tarda 5-30 min
en propagarse a la API.

**Deuda pendiente:**

- [ ] Probar Baqueano Admin en celular real (login end-to-end).
- [ ] Backup del JSON de service account admin a gestor (mismo JSON ya respaldado).
- [ ] Sincronizar git del server con GitHub (server tiene commits locales).
- [ ] Rotar secretos expuestos (SECRET_KEY, TOKEN_ENCRYPTION_KEY, PAT legacy).
- [ ] CI/CD con GitHub Actions.
### 2026-10-14 (cont. 34) - BLOQUE 6 COMPLETO: App publicada en Play Store

**Baqueano Natales está publicada, funciona end-to-end, y todo el pipeline de releases es automatizable.**

**Estado final del Bloque 6:**

| Componente | Estado |
|---|---|
| Keystore de release | `D:\dev\baqueano-keys\baqueano-release.jks` (fuera del repo) |
| AABs firmados | clientProd 58.24 MB, adminProd 58.18 MB |
| Ficha de Play Store | Completa (ícono, feature graphic, 4 screenshots, descripciones, categoría, contacto, privacy policy) |
| Formularios Play | Data safety, Content rating, Público objetivo, Acceso, Anuncios, etc. |
| Play App Signing | Activado, SHA-1 de Google: `D1:29:F6:FE:96:1B:C3:D5:F5:01:74:47:53:07:2D:CE:B3:7D:79:7B` |
| Firebase | SHA-1 de Google registrado, `google-services.json` actualizado |
| App en Play Store | **Build 2 (versionCode=2) disponible para verificadores internos** |
| Google Sign-In | **Funciona end-to-end en celular real** |
| Pipeline de uploads | API Play Publisher funcional (script `upload_to_play.py`) |
| Compatibilidad | 19,277 dispositivos Android |

**Service account Play Publisher:**

- Email: `play-publisher@baqueano-natales-prod.iam.gserviceaccount.com`
- JSON key: `/home/deploy/baqueano-natales/backend/secrets/play-publisher.json` (chmod 600)
- Permisos: Admin total sobre `Baqueano Natales`
- API: `androidpublisher.googleapis.com` habilitada

**Flujo de releases automatizado:**

    # Build
    flutter build appbundle --flavor clientProd --release -t lib/main_client.dart --dart-define-from-file=dart_defines/client_prod.json

    # Upload al server
    scp flutter/build/app/outputs/bundle/clientProdRelease/app-clientProd-release.aab deploy@104.129.59.151:/tmp/app-vX.aab

    # Publicar
    ssh deploy@104.129.59.151 "docker cp /tmp/app-vX.aab baqueano_backend_prod:/tmp/app-vX.aab"
    ssh deploy@104.129.59.151 "docker exec baqueano_backend_prod python3 /app/upload_to_play.py /tmp/app-vX.aab internal"

**Commits del bloque (7):**

- `87f8a55` docs: Firebase CLI + permisos admin
- `05215d1` feat(flutter): 4 flavors
- `b6ccd4b` feat(flutter): release signing + AABs
- `3ff77b4` docs(cheatsheet): gotchas Bloque 6
- `db9a53e` docs(play-console): cuenta Studio Digital 360
- `595ca07` docs(brand): icono + SVG + README
- `850f7dd` feat(legal): paginas legales + nginx /legal/
- `25ee37f` feat(play-api): script upload
- `93198a7` chore(flutter): google-services.json + version bump

**Deuda pendiente del Bloque 6:**

- [ ] Subir **adminProd** a Play Store (crear app "Baqueano Admin" — mismo flujo).
- [ ] Rebuild backend en server para persistir `upload_to_play.py` (via Dockerfile).
- [ ] Copiar el service account JSON a gestor del owner (backup).
- [ ] Rotar el service account key cada 6-12 meses.

**Pendientes del proyecto (fuera de Bloque 6):**

- Rotación de secretos expuestos (SECRET_KEY, TOKEN_ENCRYPTION_KEY, etc.).
- Revocar PATs legacy.
- CI/CD con GitHub Actions.
- Fase 4/5 completas del roadmap.
### 2026-10-14 (cont. 33) - Play Publisher API (upload automatizado de AABs)

**Pipeline completo de publicacion desde el server. Se acabo el upload manual por browser.**

**Implementacion:**

- **Service account GCP**: `play-publisher@baqueano-natales-prod.iam.gserviceaccount.com`
- **Permisos**: Admin total en Play Console sobre `Baqueano Natales`.
- **JSON key**: `/home/deploy/baqueano-natales/backend/secrets/play-publisher.json` (chmod 600, gitignored).
- **API habilitada**: `androidpublisher.googleapis.com` en proyecto `baqueano-natales-prod`.
- **Libs instaladas**: `google-api-python-client==2.149.0`, `google-auth==2.36.0`, `google-auth-httplib2==0.2.0` (agregadas a requirements.txt).
- **Script**: `backend/app/upload_to_play.py` (~120 lineas).

**Primer uso exitoso:**

- `clientProd` AAB v2 (versionCode=2) subido via API.
- Release publicada directo en internal testing (status=completed).
- Firebase SHA-1 de Google registrado → Google Sign-In funciona en release.

**Comandos canonicos (todo desde el server):**

    scp flutter/build/app/outputs/bundle/clientProdRelease/app-clientProd-release.aab deploy@104.129.59.151:/tmp/app-vX.aab
    ssh deploy@104.129.59.151 "docker cp /tmp/app-vX.aab baqueano_backend_prod:/tmp/app-vX.aab"
    ssh deploy@104.129.59.151 "docker exec baqueano_backend_prod python3 /app/upload_to_play.py /tmp/app-vX.aab internal"

**Para adminProd (proximo):**

- Crear app "Baqueano Admin" en Play Console (mismo service account, mismos permisos).
- Mismo script, cambiar `PACKAGE_NAME` a `cl.baqueanonatales.admin` (o parametrizar).
- Subir el AAB `app-adminProd-release.aab`.

**Gotchas aprendidos:**

- El endpoint `edits.tracks().update()` permite **1 sola release completed** por track. La nueva reemplaza la anterior automaticamente.
- La API `androidpublisher` tarda 2-5 min en propagar despues de habilitarla.
- `backend/app/` **no esta montado** en el container → usar `docker cp` para el script + rebuild para persistir.

**Commits:**
- (pendiente) `feat(play-api): script de upload de AABs a Play Console desde el server`
### 2026-10-13 (cont. 32) - Bloque 6: AAB release (clientProd + adminProd)

**Release signing real. Los 2 AABs de producción construidos y firmados con keystore propio.**

**Implementacion:**
- Keystore de release: `D:\dev\baqueano-keys\baqueano-release.jks` (fuera del repo, RSA 2048, validez ~27 años).
- `flutter/android/key.properties` (gitignored) con las credenciales.
- `build.gradle.kts` refactorizado: `signingConfigs.create("release")` lee de `key.properties`. Si el archivo no existe (CI sin keystore), la config release queda sin firmar (fail-loud).
- Backup del gradle original: `build.gradle.kts.bak`.

**AABs construidos:**
- `clientProd`: 58.24 MB, 15.5 min (primer build con clean + daemon off).
- `adminProd`:  58.18 MB,  8.6 min (incremental, reusa cache).

**Comandos canonicos:**

    flutter build appbundle --flavor clientProd --release -t lib/main_client.dart --dart-define-from-file=dart_defines/client_prod.json
    flutter build appbundle --flavor adminProd  --release -t lib/main_admin.dart  --dart-define-from-file=dart_defines/admin_prod.json

**Plan Play Store (decision de enfoques):**
- `cl.baqueanonatales` (clientProd) -> track **Production** (eventual, público).
- `cl.baqueanonatales.admin` (adminProd) -> track **Internal testing** (permanente, evita penalización por "repetitive content").

**Deuda nueva:**
- Backup del keystore + password: en gestor del owner (pendiente confirmar).
- Subir los AABs a Play Console (proximo bloque manual).
- Fase 5 de Play Store (keystore + Play App Signing + metadata) queda en curso.
### 2026-10-13 (cont. 31) - Flutter flavors completos (4 variantes)

**Ciclo de release desbloqueado: la app puede apuntar a prod o dev segun el flavor.**

**Implementacion:**

- **4 flavors** en `flutter/android/app/build.gradle.kts` (dimension `app`):
  - `clientDev`  -> `cl.baqueanonatales.dev`       -> "Baqueano DEV"
  - `clientProd` -> `cl.baqueanonatales`           -> "Baqueano Natales"
  - `adminDev`   -> `cl.baqueanonatales.admin.dev` -> "Baqueano Admin DEV"
  - `adminProd`  -> `cl.baqueanonatales.admin`     -> "Baqueano Admin"

- **AppConfig refactorizado**: ya no hardcodea URL ni environment. Los lee de
  `String.fromEnvironment('API_URL')` y `String.fromEnvironment('ENVIRONMENT')`
  (inyectados por `--dart-define-from-file`). Fallback: derivar de `environment`.

- **`dart_defines/*.json`**: 4 archivos (uno por variante) con `API_URL`,
  `ENVIRONMENT`, `APP_TYPE`.

- **`main_client.dart` / `main_admin.dart`**: sin hardcodear env. Solo
  `AppConfig.init(type: ...)`.

- **Firebase** (via CLI en el server):
  - 2 apps nuevas creadas: `cl.baqueanonatales.dev` + `cl.baqueanonatales.admin.dev`.
  - SHA-1 y SHA-256 de debug agregados a las 2 apps nuevas (Management API).
  - `google-services.json` regenerado con los 4 clients + reemplazado en el repo.

**Comandos canonicos:**

    flutter run --flavor clientDev  -t lib/main_client.dart --dart-define-from-file=dart_defines/client_dev.json
    flutter run --flavor clientProd -t lib/main_client.dart --dart-define-from-file=dart_defines/client_prod.json
    flutter run --flavor adminDev   -t lib/main_admin.dart  --dart-define-from-file=dart_defines/admin_dev.json
    flutter run --flavor adminProd  -t lib/main_admin.dart  --dart-define-from-file=dart_defines/admin_prod.json

**Validacion end-to-end:**

- 4 APKs debug construidos OK.
- `aapt dump badging` confirma `package` y `label` correctos en cada uno.
- `flutter analyze: No issues found!`

**Commits:**
- `87f8a55` docs: documentar Firebase CLI + permisos admin desde el server
- `05215d1` feat(flutter): 4 flavors (client/admin x dev/prod) + dart-define-from-file

**Deuda nueva documentada:**
- Disco `D:` quedo con solo ~5.6 GB libres. Antes del Bloque 6 (AAB release)
  hay que liberar ~10 GB (borrar APKs debug, limpiar caches de Gradle).


### 2026-10-13 (cont. 30) - Infraestructura dual (prod + dev) en el server nuevo

**El server nuevo pasa de un backend unico a dos entornos aislados. Server legacy respaldado.**

**Bloque 1 - Decisiones estrategicas:**
- Topologia: 1 server, 2 containers backend (prod + dev), 1 Postgres con 3 DBs fisicas, usuarios Postgres con minimo privilegio por DB.
- Subdominios normalizados: `api.baqueanonatales.com` (prod) + `api-dev.baqueanonatales.com` (dev). `dev-api.` deprecated con redirect 301 por 30 dias.
- Server legacy (`161.118.240.229`): plan de retiro en 4 fases (freeze -> snapshot -> 90 dias de gracia -> apagado -> destruccion).
- Staging: descartado por ahora (dev + prod alcanzan para el MVP).

**Bloque 2 - Snapshot del server legacy (completado):**
- Snapshot completo: `snapshot-legacy-2026-10-13.tar.gz` (51 MB, 9 archivos, checksums SHA-256 verificados en Windows).
- Contenido: codigo legacy + config nginx/systemd + secretos cifrados (GPG) + DB dump + 8 backups historicos + metadata.
- Excluidos: venv, SDKs Flutter/Kotlin, caches (reproducibles).
- Frase GPG guardada en gestor del owner (nombre: "GPG backup phrase - superapp-natales legacy").
- Hallazgos: 47 tablas, git remote con PAT expuesto (cuenta `sandraalvaradoclp`), `.github_token` adicional, `firebase-service-account.json` legacy.

**Bloque 3 - Infraestructura dual (completado):**

- **3.1 Preparacion (sin downtime):**
  - Backup fresco pre-rename + pre-swap de `baqueano_natales` (3 snapshots en `~/backups/`).
  - `.env.prod` y `.env.dev` creados (copia del `.env` + 8 variables cambiadas).
  - `docker-compose.yml` refactorizado a base (solo `db` + `nginx`).
  - `docker-compose.prod.yml` (backend-prod, container `baqueano_backend_prod`).
  - `docker-compose.dev.yml` (backend-dev, container `baqueano_backend_dev`).
  - `deploy/nginx/conf.d.new/`: `api.conf`, `api-dev.conf`, `dev-api.conf` (redirect 301).
  - `deploy/nginx/nginx.conf`: upstream `baqueano_backend` -> `backend-prod:8000`.
  - `deploy/nginx/conf.d/default.conf`: quitado bloque `/media/` (nginx ya no monta volumen).
  - 11 scripts en `scripts/`: `prod-up/down/restart/logs`, `dev-*`, `all-up/down`, `status`.

- **3.2 Usuarios Postgres + DBs:**
  - 3 usuarios nuevos con `NOSUPERUSER NOCREATEDB NOCREATEROLE`: `baqueano_prod_user`, `baqueano_dev_user`, `baqueano_test_user`.
  - Password rotado para `baqueano_user` (bootstrap superuser) — aplicado en el swap.
  - DB `baqueano_natales` renombrada a `baqueano_natales_prod`.
  - DB `baqueano_test` renombrada a `baqueano_natales_test`.
  - DB `baqueano_natales_dev` creada vacia.
  - `REVOKE CONNECT FROM PUBLIC` en cada DB nueva + `GRANT CONNECT` solo al usuario respectivo (aislamiento verificado).
  - Passwords guardadas en gestor del owner. NO versionadas.

- **3.3 Swap (2 min de downtime):**
  - `baqueano_backend` viejo parado.
  - DB renombrada + owner + grants + rotacion password + `.env` base actualizado.
  - Fix de permisos de volumenes nuevos (`chown 1000:1000` en `media_data_prod` y `media_data_dev`).
  - Stack completo recreado con `docker compose -f ... -f prod -f dev up -d --build`.
  - 4 containers healthy: `baqueano_db`, `baqueano_nginx`, `baqueano_backend_prod`, `baqueano_backend_dev`.
  - Migraciones Alembic aplicadas en dev (29 migraciones, version `914a9136f997 (head)`).
  - Tablas: 29 en prod, 29 en dev (schemas sincronizados).
  - Confs nginx activados (movidos de `conf.d.new/` a `conf.d/`).

- **3.4 DNS cutover:**
  - `api.baqueanonatales.com` A record actualizado: `161.118.240.229` -> `104.129.59.151`.
  - Marcado como **proxied** en Cloudflare (critico: el Origin Cert solo es valido via Cloudflare Edge).
  - Purge no aplicable (no habia nada cacheado).
  - `api-dev.baqueanonatales.com` creado y proxied.

**Verificacion end-to-end (post-swap):**
- `https://api.baqueanonatales.com/health` -> `environment=production`.
- `https://api-dev.baqueanonatales.com/health` -> `environment=development`.
- `https://dev-api.baqueanonatales.com/health` -> 301 a `api-dev`.
- `/api/v1/prestadores` en prod -> data real (`taller-mecanico-del-sur`).
- `/api/v1/prestadores` en dev -> `items: []` (DB vacia).
- Aislamiento Postgres: `prod_user` no puede conectar a `baqueano_natales_dev`.

**Bloque 9.B - Documentacion (parcial):**
- `SERVER_CHEATSHEET.md`: agregadas 3 secciones (Workflow dual-entorno, 5 gotchas nuevos, rotacion de secretos pendiente).

**Hallazgos / aprendizajes nuevos:**
- `docker compose config` imprime TODOS los secretos sin filtrado.
- Permisos de volumenes Docker nuevos: owner `root:root`, requiere `chown 1000:1000`.
- `docker exec` + `< /dev/null` + `docker cp` es el patron canonico para `pg_dump`.
- `docker compose exec -T` bloquea el resto del script en `bash -s` multi-linea.
- Cloudflare Origin Certificate SOLO valida via Cloudflare Edge (proxied=true). Sin proxy, los clientes ven cert invalido.

**Deuda pendiente (documentada, no bloqueante):**
- **Rotacion de secretos (`SECRET_KEY`, `TOKEN_ENCRYPTION_KEY`, `FACEBOOK_APP_SECRET`)** — bloque final, se hace todo junto.
- **Revocar 2 PATs legacy** (remote de `superapp-natales` + `~/.github_token`) — bloque final.
- **Archivar repo `sandraalvaradoclp/superapp-natales`** — bloque final.
- Portar script de backup del legacy al server nuevo (rclone a B2 separado por entorno).
- Implementar flavors Flutter (client-dev/prod, admin-dev/prod).
- Keystore de release + subir a Play Store (internal testing).
- CI/CD con GitHub Actions.

**Commits:**
- `119eefb` infra: infraestructura dual (prod + dev) para el server
- `6a1a03c` infra: activar confs de nginx (api + api-dev + redirect dev-api)

**Estado de la suite backend:** 402 tests verdes (sin cambios de codigo de aplicacion).
**Estado del server:** 4 containers healthy, health publico OK en ambos entornos.


### 2026-10-13 (cont. 29) - Cosmeticos de notificaciones (D) + label por flavor

**Deuda cosmetica de notificaciones cerrada.**

- **Fix del label (bug real)**: `AndroidManifest.xml` tenia `android:label="Baqueano Natales"` hardcodeado. Los `resValue("string", "app_name", ...)` de los flavors client/admin se ignoraban -> el admin decia "baqueano_natales" en el launcher. Fix: `android:label="@string/app_name"` (respeta el `resValue` de cada flavor).
  - Client -> "Baqueano Natales".
  - Admin -> "Baqueano Admin".
- **Icono monocromatico** (`res/drawable/ic_notification.xml`): campana vectorial blanca (Material Design notifications). FCM lo tinta automaticamente segun el theme del sistema.
- **Wire**: `AndroidManifest.xml` -> `meta-data default_notification_icon -> @drawable/ic_notification` (lo usa FCM para el push en background).
- **fcm_service.dart**: icono del canal + banner local (`flutter_local_notifications`) -> `@drawable/ic_notification`. Antes usaba `@mipmap/ic_launcher` (cuadrado de launcher).
- **Validado visualmente**: banner en foreground con campana blanca, launcher dice "Baqueano Natales".

**Deuda pendiente:**
- **C (push FCM en device fisico)** sin validar. Con emulador + Play Store funciona end-to-end. Falta celular real con USB debugging.
- **M5** modulo oficios: fotos + reportes ya cerrados en M5.1 y M5.3. Falta notificaciones in-app especificas en la M5 (revisar si ya cubierto por M5.2).
- **M6** (Reviews): cerrado backend + frontend + tests + smoke e2e.

### 2026-10-13 (cont. 28) - Smoke test end-to-end del MVP de mecanica

**MVP de mecanica cerrado end-to-end. Todos los flujos criticos verificados.**

- **Onboarding del prestador** (flujo completo verificado):
  1. Cliente crea prestador desde el empty state nuevo de `MisOficios` -> `POST /mis-prestadores` (201).
  2. Envia a revision -> `POST /mis-prestadores/{id}/enviar-revision` (200).
  3. Admin verifica -> `POST /admin/prestadores/{id}/verificar` (200).
  4. Estado final: `verificado`, `verificado=true`, `verificado_en` + `verificado_por_id` seteados.
- **Empty state mejorado** de `MisOficiosScreen` (commit 43bb658):
  - Icono circular grande + titulo "Ofrece tus servicios".
  - 3 pasos numerados (crea perfil, carga servicios, envia a revision).
  - CTA grande "Crear mi primer perfil".
- **Flujos del MVP verificados de punta a punta** (sesiones previas + esta):
  - Cliente descubre talleres (`/prestadores` + categorias).
  - Cliente reserva turno (M3).
  - Cliente aprueba/rechaza presupuesto por item (M2).
  - Prestador ejecuta + entrega -> garantia automatica (M4).
  - Prestador sube fotos content-addressable (M5.1).
  - Cliente recibe notifs in-app en cada cambio (M5.2).
  - Prestador ve reportes + descarga CSV (M5.3).
  - Cliente califica -> prestador responde (M6).
- **Estado del MVP de mecanica: FUNCIONAL.** Todos los bloques backend + frontend + tests verdes.
- **Suite backend: 402 passed, 0 warnings.**

**Deuda documentada (no bloqueante):**
- Push FCM real (hoy el worker marca `enviado=True` y loguea, pero no verifica entrega en device fisico).
- Admin flavor con CRUD de ordenes globales (no existe endpoint).
- Cosmetica de notifs (`android:label`, `ic_notification` monocromatico).

### 2026-10-12 (cont. 27) - M6 reviews/calificaciones (frontend) + smoke test e2e

**Modulo reviews cerrado end-to-end (backend + frontend).**

- **Frontend**:
  - Modelo `Review` + `ReviewItem` + `ReviewListResponse`.
  - `OficiosRepository`: `crearReview`, `obtenerMiReview`.
  - `PrestadorRepository`: `listarReviewsPublicas`, `responderReview`.
  - `miReviewProvider` + `reviewsPrestadorProvider` (family).
  - Pantallas/widgets:
    - `CrearReviewScreen`: estrellas 1-5 + comentario (max 2000).
    - `ReviewSeccion`: card en detalle de orden con 3 estados (sin review -> CTA / con review -> estrellas + comentario + respuesta).
    - `ReviewList`: widget publico reusable para el detalle del prestador.
    - `ReviewsPrestadorScreen`: panel del dueno con lista + boton "Responder" (una sola vez, via dialog).
  - Wire: card en `detalle_mi_orden`, seccion Resenas en `detalle_prestador`, boton en AppBar de `detalle_mi_prestador` (3er icono), 2 rutas nuevas.
- **Bug critico detectado y arreglado en el proceso** (Riverpod family): `_desde`/`_hasta` con `DateTime.now()` como getter disparaban fetch infinito (cada build = DateTime distinto -> params distintos -> re-fetch). Fix: campos `late DateTime` + recalculo explicito en `initState` y `onChanged`. **Regla general: params de provider family deben ser inmutables y deterministas.** Ya documentado de M5.3, reaplicado.
- **Bug de `pytest_plugins`** en conftest anidado: pytest 8+ exige que este SOLO en el conftest raiz, y el plugin del conftest raiz + descubrimiento automatico del conftest de oficios da "plugin already registered". Fix: conftest anidado con **imports explicitos** de los fixtures (no `pytest_plugins`).
- **Smoke test end-to-end validado**:
  - Cliente califica (`POST /mis-ordenes/{id}/review` -> 201).
  - Prestador ve resenas (`GET /prestadores/{slug}/reviews` -> 200).
  - Prestador responde (`POST /mis-prestadores/{pid}/reviews/{rid}/respuesta` -> 200).

**Estado del MVP de mecanica:**
- Backend + frontend de oficios M1-M5: COMPLETO.
- Reviews (M6): backend + frontend COMPLETO.
- Pendiente MVP: onboarding de prestadores + smoke test final del flujo completo.

**Suite backend: 402 passed (tras M6). Flutter analyze: limpio.**

### 2026-10-12 (cont. 26) - M5.3 reportes del taller (frontend) - **M5 COMPLETO**

**Modulo oficios M5 cerrado al 100% (backend + frontend + tests).**

- **Frontend**:
  - Modelo `ReportePrestador` + 4 sub-modelos (`ReporteKPIs`, `ReporteSerieMes`, `ReporteTopServicio`, `ReporteTopCliente`).
  - `OficiosRepository`: 2 metodos nuevos (`obtenerReporte` JSON, `descargarReporteCsv` bytes).
  - Provider family `reportePrestadorProvider` con params inmutables (prestadorId + desde + hasta).
  - Pantalla `ReportesTallerScreen`:
    - Selector de rango: chips 30d / 90d / 12m.
    - KPIs en cards 2x2 (icono + label + valor).
    - Chart de barras con `CustomPaint` (sin `fl_chart`).
    - Top 10 servicios + Top 10 clientes.
    - Boton de descarga CSV (share sheet via `share_plus` + `path_provider`).
  - Wire: boton `bar_chart_outlined` en AppBar de `detalle_mi_prestador`.
  - Ruta nueva: `/mis-prestadores/:id/reportes`.
- **Bug critico detectado en el smoke test (y arreglado)**: `_desde`/`_hasta` se calculaban con getters llamando `DateTime.now()` en cada build -> Riverpod family veia params distintos (microsegundos) -> fetch infinito. Fix: guardar como campos de estado (`late DateTime`) y recalcular solo en `initState` / `onChanged` del preset. **Aprendizaje general para Riverpod family: los params deben ser inmutables y deterministas.**
- **Validado end-to-end** en emulador:
  - KPIs correctos: 2 ordenes, $87.000, ticket $87.000, tasa 100%, duracion 2.0 d.
  - Chart de barras con 1 barra (oct).
  - Top 3 servicios + Top 1 cliente.
  - Cambio de chips: refetch correcto, sin loop.
- **Flutter analyze: No issues found!**

**Estado del modulo oficios (M5):**
- M5.1 (fotos): backend + frontend + tests OK
- M5.2 (notifs in-app): backend + frontend + tests OK
- M5.3 (reportes): backend + frontend + tests OK
- **M5 COMPLETO.**

**Backlog del proyecto (fuera de M5):**
- Cosmeticos de notifs (`android:label`, `ic_notification` monocromatico, card -> detalle).
- Rotar secretos expuestos (pendiente desde oct-08).
- M6 hipotetico: chat cliente-prestador, pagos, etc.

### 2026-10-12 (cont. 25) - M5.3 reportes del taller (backend completo)

**Ultimo slice de M5 backend. Metricas de industria basadas en Jobber / ServiceTitan / TallerPro.**

- **Nuevos modulos**:
  - `schemas_reportes.py`: ReportePrestador + ReporteKPIs + ReporteSerieMes + ReporteTopServicio + ReporteTopCliente.
  - `services_reportes.py`: SQL agregado directo (GROUP BY + func.sum/count/avg) sin vistas materializadas (optimizar cuando haya volumen real >10k ordenes/taller).
  - `routes_reportes.py`: 2 endpoints.
- **Metricas** (KPIs + rankings):
  - KPIs: total_ordenes, ordenes_por_estado, ingresos_totales (solo ENTREGADO), ticket_promedio, tasa_aprobacion_items, duracion_promedio_dias (ingreso -> entrega_real).
  - Serie mensual (12 meses): ordenes + ingresos por mes (YYYY-MM).
  - Top 10 servicios: agrupado por `descripcion` del item, ordenado por cantidad.
  - Top 10 clientes: agrupado por `cliente_id`, con nombre resuelto en 1 query IN.
- **Endpoints**:
  - `GET /api/v1/mis-prestadores/{pid}/reportes` (JSON).
  - `GET /api/v1/mis-prestadores/{pid}/reportes.csv` (descarga con `Content-Disposition`).
  - Filtros `desde` / `hasta` (defaults a ultimos 12 meses).
  - Ownership: 403 si no eres dueno del prestador (o admin).
- **6 tests HTTP** (`test_routes_reportes.py`): reporte con datos, reporte vacio, filtro de fechas, CSV con headers, ownership (403), prestador inexistente (404).
- **Smoke test manual**: reporte del Taller Mecanico del Sur -> 2 ordenes, $87.000 ingresos, ticket $87.000, tasa 100%, duracion 1.96 dias. CSV completo.
- **Suite total: 396 passed, 0 warnings.**

**Pendiente de M5:**
- **M5.3 frontend Flutter**: pantalla de reportes del taller (graficos + descarga CSV). Es la ultima pieza del modulo oficios M5.

### 2026-10-12 (cont. 24) - M5.2 tests HTTP del wire de notificaciones in-app

**Deuda de tests de M5.2 cerrada.**

- **5 tests nuevos** (`tests/modules/oficios/test_notificaciones_in_app.py`) que validan los 3 flujos wire:
  - `crear_orden` -> notif IN_APP al cliente con `data.tipo=orden` + `orden_id` + `estado`.
  - `cambiar_estado` (prestador) -> notif al cliente con `estado_anterior` + `estado`.
  - `cambiar_estado` (cliente, rechazar) -> notif al prestador dueno.
  - `aprobar_presupuesto` -> notif al prestador con `total_aprobado`.
  - `enviar_in_app()` funciona sin tokens FCM activos (canal=IN_APP).
- **Decision de diseno del test**: llaman a los services directamente (no HTTP) porque el wire esta en el service y asi evitamos la cadena HTTP completa. Los tests HTTP ya existen para los endpoints en si.
- **Transiciones validas del cliente** (descubierto en el proceso): solo `presupuestado -> aprobado|rechazado` y `rechazado -> cancelado`. El test usa `rechazado` porque es la transicion "del cliente" que dispara notif al prestador.
- **Suite total: 390 passed, 0 warnings.**

**Estado del modulo oficios (M5):**
- M5.1 (fotos): backend + frontend OK
- M5.2 (notifs in-app): backend + frontend + tests OK
- M5.3 (reportes taller): pendiente

### 2026-10-12 (cont. 23) - M5.2 notificaciones in-app en cambios de estado

**Slice M5.2 cerrado end-to-end (backend + frontend).**

- **Backend** (`app/core/notifications/service.py`):
  - `enviar_in_app()`: pipeline completo (preferencias + quiet hours + rate limit) pero **sin tokens FCM**. El log queda `estado=ENVIADA` directo con `canal=IN_APP`.
  - `_log_skipped()` ahora acepta `canal` (default FCM, retrocompatible).
- **Wire** en `oficios/services.py` con helper `_notificar_orden()` (best-effort, try/except que nunca rompe el flujo):
  - `crear_orden` -> notifica al cliente.
  - `cambiar_estado` -> notifica al "otro lado" (si cambio prestador -> cliente; si cambio cliente -> prestador dueno).
  - `aprobar_presupuesto` -> notifica al prestador con el resultado.
- **Payload del deep link**: `data = {"tipo": "orden", "orden_id": str(uuid), "estado": "..."}` para que el frontend navegue.
- **Frontend** (`mis_notificaciones_screen.dart`):
  - Helper `_resolverRuta()` que mapea `data.tipo` + id a la ruta GoRouter.
  - Soporta `orden` / `turno` / `recordatorio`. Sin tipo conocido -> solo marca como leida + SnackBar.
  - Tap navega con `GoRouter.of(context).push()` (apila, preserva el back).
- **`FcmService._resolverRuta()`** ya mapeaba `case 'campana'` con `orden_id` -> `/mis-ordenes/{id}` desde la sesion anterior, sin cambios.
- **Validado end-to-end** en emulador:
  - Crear orden real via SQL -> notif in-app "Nueva orden OT-2026-0002".
  - `cambiar_estado` a `diagnosticando` -> notif "Orden OT-2026-0002: diagnosticando".
  - Tap en la campanita del Home -> aparecen las 2 notifs con badge `campana`.
  - Tap en cualquiera -> navega al detalle de la orden (badge baja a 0).
  - Tap en notif de recordatorio (`sistema`) -> NO navega, solo marca leida + SnackBar.
- **Suite total: 385 passed, 0 warnings.**
- **Tests HTTP del backend de M5.2**: pendiente (solo smoke manual por SQL). Deuda: agregar tests que validen que `crear_orden` / `cambiar_estado` / `aprobar_presupuesto` generan un log con `canal=IN_APP`.

**Estado del modulo oficios (M5):**
- M5.1 (fotos): backend + frontend OK
- M5.2 (notifs in-app en cambio de estado): backend + frontend OK
- M5.3 (reportes taller): pendiente

### 2026-10-12 (cont. 22) - M5.1 fotos frontend (Flutter)

**Slice M5.1 cerrado end-to-end (backend + frontend).**

- **Modelo `OrdenFoto`** (Dart) + `MomentoFoto` enum (ingreso/diagnostico/en_proceso/entrega/reclamo/otro) + `FotoVariante`.
- **`AuthedImage`** (`core/network/authed_image_provider.dart`): `ImageProvider` custom que usa `DioClient` singleton para bajar bytes con `Authorization: Bearer` automatico. **Reusable en cualquier feature** que necesite servir imagenes privadas.
- **Repository**: 5 metodos nuevos (`subirFoto`, `subirFotoPrestador`, `listarFotosDeMiOrden`, `listarFotosDeOrdenPrestador`, `eliminarFotoDeMiOrden`, `eliminarFotoDeOrdenPrestador`). Multipart con `FormData` + `MultipartFile.fromBytes`.
- **Providers**: `fotosDeMiOrdenProvider` + `fotosDeOrdenPrestadorProvider` (family con params inmutables).
- **Widgets reusables**:
  - `FotoThumb`: thumbnail con `AuthedImage`, variante configurable (`thumb`/`medium`/`original`), placeholder, `onTap` + `onLongPress`.
  - `GaleriaFotos`: grid reusable con `maxFotos`, `onVerTodas`, `onFotoTap`.
- **Pantalla `GaleriaFotosScreen`**:
  - FAB upload con `image_picker` (camara/galeria + momento).
  - Filtro por momento (bottom sheet + badge en el icono).
  - Long-press para eliminar (dialogo de confirmacion).
  - Visor fullscreen con `PageView` + `InteractiveViewer` (pinch zoom 1-5x) + boton delete en AppBar.
- **Wire**: boton de fotos en AppBars de `detalle_mi_orden_screen` y `detalle_orden_taller_screen`. 2 rutas nuevas en `app_router.dart`.
- **Dep**: `image_picker ^1.1.2`.
- **Validado end-to-end en emulador Android 14**:
  - Upload PNG/JPEG desde camara y galeria -> 201 + grid actualiza.
  - `AuthedImage` -> GET con JWT a `/api/v1/ordenes/fotos/{id}/archivo/thumb` -> 200.
  - Filtro `?momento=` -> 200.
  - DELETE -> 204 + grid refresca.
- **Bugs encontrados y arreglados en el camino**:
  1. `FotoThumb` con `width/height: null` colapsaba a 0x0 en grid -> default `double.infinity`.
  2. Visor usaba variante `thumb` (256px borroso) -> ahora `original` (2048px).
  3. `BoxFit.cover` recortaba la imagen -> `contain` en visor.
  4. Long-press competia en gesture arena con `onTap` del `FotoThumb` -> ambos en el mismo widget.
- **Gotcha del emulador**: el AVD genera una escena sintetica de baja resolucion para la camara -> la foto se ve borrosa pero es la fuente, no el pipeline. Probar con device fisico o subir imagen desde la galeria (drag&drop de un PNG/JPG a la ventana del emulador).

**Estado del modulo oficios (M5):**
- M5.1 (fotos): backend + frontend OK
- M5.2 (notifs in-app en cambio de estado): pendiente
- M5.3 (reportes taller): pendiente
### 2026-10-12 (cont. 21) - M5.1 fotos de ordenes (backend completo)

**Primer slice de M5 del modulo oficios: fotos con estandares de industria.**

- **Modelo `OrdenFoto`** content-addressable (SHA-256 del contenido):
  - 3 variantes server-side: `original` (2048px), `medium` (1024px), `thumb` (256px).
  - `blurhash` (placeholder visual en cliente).
  - `storage_backend` + `storage_key` (forward compat S3/R2 sin migrar).
  - `subido_por_id` + `subido_por_rol` (snapshot).
  - `item_id` opcional (foto asociada a un item del presupuesto).
  - `fecha_captura` (EXIF) + `metadata_extra` JSONB.
  - Soft delete + GC futuro.
- **Storage abstracto** `FotoStorage` (ABC) + `LocalFotoStorage`:
  - Mismo patron que `AvatarStorage`.
  - Reusa las excepciones de `base.py` (evita duplicacion que rompia el `except`).
  - EXIF stripping + orientation transpose.
  - MIME por magic bytes (`filetype`), no por extension.
  - MAX_SIZE: 15 MB. Formatos: JPEG, PNG, WebP.
- **Service** (`services_fotos.py`):
  - `subir_foto`: valida ownership + rate limit + procesa + dedup logico por hash (misma orden) + inserta + registra en historial.
  - Rate limit: 30/h por orden + 100/h por usuario (SQL directo, sin slowapi).
  - `listar_fotos`, `obtener_foto_para_servir`, `leer_variante`, `eliminar_foto`.
- **Endpoints** (5):
  - `POST /api/v1/mis-ordenes/{oid}/fotos` (cliente)
  - `GET  /api/v1/mis-ordenes/{oid}/fotos?momento=...` (cliente)
  - `DELETE /api/v1/mis-ordenes/{oid}/fotos/{fid}` (cliente)
  - `POST/GET/DELETE /api/v1/mis-prestadores/{pid}/ordenes/{oid}/fotos` (prestador)
  - `GET /api/v1/ordenes/fotos/{fid}/archivo/{variante}` (autenticado, valida ownership)
  - **NO se sirve por nginx** (privacidad): todo pasa por endpoint autenticado.
- **Migraciones**: `ee4752206777` (tabla + enum `momento_foto`) + `a1b2c3d4e5f6` (drop unique constraint redundante que impedia subir la misma foto a 2 ordenes).
- **Fix critico `env.py`**: faltaba import de `app.core.notifications.models` -> Alembic queria dropear `fcm_tokens`, `notification_logs`, `preferencias_notificacion`, `rate_limit_config` en cada autogenerate. Ahora importa.
- **12 tests HTTP** (`test_routes_fotos.py`):
  - Upload png/jpeg OK, MIME invalido, momento invalido, sin archivo.
  - Dedup por hash (mismo contenido -> mismo row).
  - Listar con/sin filtro por momento.
  - Servir variante thumb (verifica magic bytes JPEG) + variante invalida + foto inexistente.
  - Tercero no sube a orden ajena (403).
- **Bug real detectado por tests**: dos definiciones de `StorageError` (en `base.py` y `foto_base.py`) -> el `except StorageError` no capturaba. Fix: `foto_base.py` reusa de `base.py`.
- **Suite total: 385 passed, 0 warnings.**

**Pendiente de M5:**
- M5.1 frontend Flutter: galeria + upload (`image_picker`).
- M5.2: notificaciones in-app en cambio de estado (reusar `NotificationService` con `canal=in_app`).
- M5.3: reportes del taller.

**Gotchas nuevos documentados:**
- `$py | ssh "cat > /tmp/file.py"` en PowerShell 5.1 **no es confiable** para contenido > 1 KB (se trunca silenciosamente). **Fix: base64**. Documentado en OPERATIVA_DEV 3.7.
- Alembic autogenerate: si un modulo nuevo no esta importado en `env.py`, va a querer dropear sus tablas. **Siempre verificar que no aparezca `Detected removed` antes de aplicar**.



### 2026-10-12 (cont. 20) - Cierre WIP deep linking: dedup FCM + back button

**Los 3 bugs del WIP de deep linking resueltos + 4 gotchas nuevos.**

- **Back button en deep link** (`main_client.dart`): `router.go(pending)` reemplazaba el stack -> no habia flecha atras. Cambiado a `router.push(pending)` (apila, preserva el back).
- **Dedup FCM con 3 capas** (`fcm_service.dart`):
  - **Capa 1**: `_procesadosEnSesion` como **`static final Set<String>`** (sobrevive hot restart, comparte estado entre instancias de FcmService).
  - **Capa 2**: check + add **sincrono** (`_registrarEnSesionSync`) sin `await` intermedio para eliminar el race entre `onMessageOpenedApp` y `getInitialMessage`.
  - **Capa 3**: persistencia en `SecureStorageService` (nuevos metodos `saveFcmTap`/`getFcmTap`) con ventana de 30s. Cubre **hot restart** (el plugin nativo cachea `getInitialMessage` y Dart pierde su estado).
  - **Key canonica**: `log:<notification_log_id>` (identifica univocamente cada envio y esta disponible en los 3 paths). Fallback a `messageId` y luego a `tipo|sentTimeMs`.
- **Bug real**: el callback de `flutter_local_notifications` (`onDidReceiveNotificationResponse`) llamaba directo a `_reportarAperturaPorId` sin pasar por el dedup. Ahora todos los paths (banner local + `onMessageOpenedApp` + `getInitialMessage`) convergen a `_yaProcesado('log:<uuid>')`. **El doble POST /abierta era 2 paths distintos, no 2 eventos del mismo path.**
- **Validado end-to-end** en emulador Android 14 (cold start):
  - `[FCM] dedup in-session: log:cae07c80-...` -> 2do path bloqueado.
  - `[Dio] POST .../abierta` -> **1 sola** (antes: 2).
  - `[DeepLink] navegando a: /mis-notificaciones` -> 1 sola.
  - Flecha atras visible en `/mis-notificaciones`.
  - Badge baja de 8 -> 6 despues del tap.
- **Reset de notifs en la DB**: todas estaban en `abierta` tras el smoke anterior -> UPDATE a `enviada` + `abierto_en = NULL` para volver al estado base.
- **Gotchas nuevos documentados** (cheatsheet #24-27):
  1. `<<'SQL'` heredoc dentro de `bash -s` se come stdin de `docker compose exec -T` -> `syntax error at or near "SQL"`. Usar `-c "..."` o llamadas SSH separadas.
  2. `docker compose exec -T` consume stdin cuando se usa dentro de `bash -s` multi-linea -> el resto del script no se ejecuta. Fix: separar en llamadas SSH distintas.
  3. En Windows, `< /dev/null` en el contenido de un here-string enviado por `bash -s` **se pierde** (PowerShell no lo interpreta). Usar comandos de una linea por SSH.
  4. Hot reload NO recicla los listeners de FCM (`onMessageOpenedApp` queda registrado con el closure viejo). Hot restart tampoco recicla el plugin nativo de `flutter_local_notifications` -> requiere **cold start** (`q` + `flutter run`) para estado limpio.

### 2026-10-12 (cont. 3) - M4 frontend verificado end-to-end + fix crítico ObjetoServicio

**Smoke test visual de M4 + bug encontrado en producción.**

- **Bug crítico encontrado y arreglado** (`3a5941b`):
  - `routes.py` usaba `ObjetoServicio` en `_validar_objeto_del_usuario` sin
    importarlo -> los 3 endpoints de recordatorios (GET x2 + POST) fallaban
    con `NameError`.
  - Fix: agregar `ObjetoServicio` al import de `models`.
  - **No lo detectaron los 272 tests** porque no hay tests HTTP que ejerciten
    `routes._validar_objeto_del_usuario`. Deuda: agregar tests de integración.

- **Smoke test M4 verificado visualmente en emulador Android 14**:
  - `MisRecordatoriosScreen` carga correctamente (GET sin filtro y con
    `incluir_enviados=true`).
  - Crear recordatorio desde el FAB -> 201 -> aparece en la lista con
    SnackBar "Recordatorio creado".
  - Badge "Enviado 12/10/2026" se muestra en el recordatorio procesado por
    el worker APScheduler -> **worker M4 end-to-end funcionando** (no solo
    loguea: persiste `enviado=True` + `fecha_envio`).
  - `GarantiaCard` renderiza perfecto en el detalle de la orden entregada
    (tipo, vigencia, duración, cobertura, condiciones).
  - `DetalleMiOrdenScreen` con 3 items + totales ($87.000) + timeline de
    8 eventos, todo OK.

- **Seed de smoke test en DB de producción** (para retomar):
  - ObjetoServicio `74ae2fcb-4e9d-42b1-a04f-6d92f34a3af7` (alias
    "Auto de prueba smoke M4").
  - Vehiculo `b408e708-5a27-4812-bdd2-e5e4fd74e23a` (patente SMOKE01).
  - Orden `494b063f-99fc-424c-a6df-87689fcc0c45` / `OT-2026-9999` en
    estado `entregado` (3 items + 8 eventos de historial + garantía).
  - 2 recordatorios (uno ya procesado por el worker, uno nuevo de prueba).

- **Gotcha nuevo documentado**: `docker compose restart backend` es más
  confiable que `docker compose up -d backend` cuando el hash del container
  no cambia (el `up -d` muestra "Running" en vez de "Recreated" y no recarga
  el código). El `touch app/main.py` **tampoco** disparó hot reload de
  uvicorn en este caso.

- **Estado final del módulo oficios**:
  - M1, M2, M3: completas (backend + frontend + tests)
  - M4: **backend + frontend + worker, todos verificados end-to-end**
  - M5: fotos + notificaciones in-app + reportes
  - **Deuda pendiente de M4**: push FCM real (hoy el worker marca
    `enviado=True` y loguea, pero no manda push al usuario).

### 2026-10-12 (cont. 19) - Deep linking + badge + filtro (WIP, cierre de sesion)

**Deep linking desde notifs funcionando end-to-end + 2 mejoras UX. Pendiente: deduplicacion de taps en hot restart.**

- **Deep linking** (commits `ded9c5e` + `7ca5e60`):
  - Backend: `service.py` agrega `"tipo": tipo.value` al payload del push.
  - Flutter: `FcmService._resolverRuta()` mapea tipo + data a ruta GoRouter.
  - `main_client.dart` escucha `pendingNavigationProvider` y navega
    post-auth (con guard para no disparar antes de que el JWT este listo).
  - `pendingNavigationProvider` (Riverpod 3 `NotifierProvider`) para la
    ruta pendiente. Migrado desde `StateProvider` (deprecado en v3).
  - **Validado end-to-end** (log confirmado):
    `[DeepLink] navegando a: /mis-vehiculos/74ae2fcb-.../recordatorios`

- **Badge de no leidas en el Home**: card "Mis notificaciones" pasa a
  `ConsumerWidget`. Badge numerico con count de estados
  `{'enviada', 'entregada', 'impresa'}` (excluye `skipped` y `fallida`).

- **Filtro "Solo no leidas"** en la lista (`FilterChip` en la AppBar).
  La pantalla pasa de `ConsumerWidget` a `ConsumerStatefulWidget`.

- **Suite backend: 373 passed, 0 warnings.**

- **Pendiente para proxima sesion (WIP)**:
  1. Deduplicar taps por `messageId` en `fcm_service.dart`.
  2. Reset de notifs en la DB (todas quedaron en `abierta` tras las pruebas).
  3. Re-test del deep link end-to-end sin hot restart.
  4. Commit de esos fixes.
### 2026-10-12 (cont. 18) - Rate Limiting / Frequency Capping (S8) - sistema 8/8 features

**Feature #8 de la industria. Sistema de notificaciones: 8/8 features nivel industria.**

- **Tabla `rate_limit_config`** (migracion `b9c0d1e2f3a4`):
  - Limites configurables por tipo: `max_por_hora`, `max_por_dia`,
    `max_por_semana`, `min_intervalo_seg`, `strict`.
  - 5 configs seedeadas:
    - `sistema` / `confirmaciones`: sin limite (criticos).
    - `recordatorio`: 2/h, 3/d, 7/sem, min 1h.
    - `promocion`: 1/h, 1/d, 2/sem.
    - `campana`: 1/h, 1/d, 3/sem.

- **Logica en `NotificationService._check_rate_limit()`**:
  - Se ejecuta ANTES de crear el log (despues de preferencias + quiet hours).
  - Si excede: registra `SKIPPED` con `razon=rate_limit:X`.
  - Tipos criticos (`sistema`, `campana`) bypassan el limite salvo `strict=True`.
  - Los logs `SKIPPED` NO cuentan para el conteo (solo los enviados).

- **2 endpoints admin**:
  - `GET  /api/v1/admin/notificaciones/rate-limits`.
  - `PATCH /api/v1/admin/notificaciones/rate-limits/{tipo}`.

- **9 tests nuevos** (7 de logica + 2 de endpoints).
- **Suite total: 373 passed, 0 warnings.**

- **Sistema de notificaciones 8/8 features**:
  1. Multi-device + limpieza automatica OK
  2. Prioridad + TTL + collapse_key OK
  3. Analytics end-to-end (enviada -> entregada -> abierta) OK
  4. Preferencias por tipo + quiet hours OK
  5. Panel admin (composer + historial + stats) OK
  6. Centro de notificaciones del usuario OK
  7. **Frequency capping / rate limiting OK**
  8. Arquitectura extensible (ABC provider) OK

### 2026-10-12 (cont. 17) - Centro de notificaciones del usuario (S7) - sistema 100% end-to-end

**Sistema de notificaciones nivel industria: 100% completo (backend + admin + usuario).**

- **S7 - Centro de notificaciones del usuario** (commits `f60a745` + `ca46767`):
  - `MisNotificacionesScreen`: lista con marcar-abierta al tocar + SnackBar de feedback.
  - `PreferenciasNotificacionScreen`: toggles por tipo + quiet hours con timepicker.
  - Modelo `PreferenciaNotificacion` + 4 metodos nuevos en el repository
    (misNotificaciones, marcarAbierta, misPreferencias, actualizarPreferencias).
  - 2 rutas nuevas: `/mis-notificaciones` + `/mis-notificaciones/preferencias`.
  - Card "Mis notificaciones" en el Home del cliente.
- **Fix de UX** (`ca46767`): el SnackBar no se veia porque el `context`
  original quedaba unmounted post `ref.invalidate()`. Fix: capturar el
  `ScaffoldMessenger` antes del await.
- **Fix del emulador** (sesion):
  - 5 adb zombies acumulados -> matar todo + adb start-server.
  - `-gpu host` con Intel UHD 630 -> warnings visuales.
    `-gpu swiftshader_indirect` es mas estable.

- **Estado final del sistema de notificaciones (100% end-to-end)**:
  - S1 (modelo multi-device) OK
  - S2 (refactor push batch + limpieza tokens) OK
  - S3 (tracking entrega/apertura) OK
  - S4 (preferencias + quiet hours) OK
  - S5 (panel admin backend) OK
  - S6 (panel admin Flutter) OK
  - S7 (centro de notificaciones del usuario) OK
  - Analytics end-to-end OK
  - Banner en foreground OK

- **Suite total: 364 tests verdes, 0 warnings.**

- **Backlog (no bloqueante)**:
  - Card -> detalle de notificacion (pantalla con body completo + data JSON).
  - Filtro "solo no leidas" en la AppBar.
  - Badge de no leidas en la Home.
  - `android:label` de la notif (mostrar "Baqueano Natales").
  - Icono monocromatico de notificacion (`ic_notification` vectorial).
  - M5 del modulo oficios: fotos + reportes.

### 2026-10-12 (cont. 16) - Panel admin Flutter (S6) - sistema de notificaciones 100% completo

**Sistema de notificaciones nivel industria: 100% completo (backend + frontend + admin panel).**

- **Panel admin Flutter** (commit `d1b5fd2`):
  - `lib/features/notificaciones/` nueva:
    - `domain/`: `NotificacionAdmin`, `Segmento` (+ `TipoSegmento`), `StatsNotificacion`.
    - `data/`: `NotificacionesRepository` (enviar + listar + stats) + providers Riverpod.
    - `presentation/screens/`:
      - `admin_notificaciones_composer_screen.dart`: envio a segmentos con resultado en dialogo.
      - `admin_notificaciones_historial_screen.dart`: filtros tipo/estado + cards coloreadas.
      - `admin_notificaciones_stats_screen.dart`: dashboard (metricas + por estado/tipo + top 5).
  - 3 rutas nuevas: `/admin/notificaciones{,/historial,/stats}`.
  - 3 cards nuevas en AdminHome.
- **Migraciones UI necesarias**:
  - `RadioGroup` en vez de `groupValue`/`onChanged` (deprecado en Flutter 3.32+).
  - `use_null_aware_elements` (Dart 3.8+): `'key': ?value` en vez de `if (v != null) 'key': v`.
  - `flutter_local_notifications v22`: `initialize({settings: ...})` + `show({id:, ..., notificationDetails: ...})`.

- **Validado end-to-end en emulador (flavor admin)**:
  - Composer: `POST /enviar` -> 200 + dialogo con Total/Enviados/Fallidos/Skipped.
  - Historial: multiples GETs con filtros tipo/estado -> todos 200.
  - Stats: `GET /stats` -> 200.

- **Gotcha nuevo (fix del emulador)**:
  - 5 procesos `adb` zombies acumulados de sesiones anteriores causaban
    timeouts y glitches. Fix: matar todo (emulator + qemu + adb),
    limpiar locks, `adb start-server`.
  - GPU `host` con Intel UHD 630 causa `Unable to match the desired
    swap behavior`. Fix: `-gpu swiftshader_indirect` (mas lento pero
    estable visualmente).

- **Estado final del sistema de notificaciones (100%)**:
  - S1 (modelo multi-device) OK
  - S2 (refactor push batch + limpieza tokens) OK
  - S3 (tracking entrega/apertura) OK
  - S4 (preferencias + quiet hours) OK
  - S5 (panel admin backend) OK
  - S6 (panel admin Flutter) OK
  - Analytics end-to-end OK (backend + Flutter)
  - Banner en foreground OK

- **Suite total: 364 tests verdes, 0 warnings.**

- **Pendiente para sesion futura**:
  - S7: centro de notificaciones Flutter (vista del usuario: lista + preferencias).
  - Deuda cosmetica: `android:label` de la notif + icono monocromatico.
  - M5 modulo oficios: fotos + reportes.

### 2026-10-12 (cont. 15) - Banner en foreground + sistema de notificaciones 100%

**Sistema de notificaciones COMPLETO end-to-end (S1-S5 + analytics + foreground banner).**

- **Banner en foreground** (commit `ebdfb90`):
  - `flutter_local_notifications ^22.3.2` agregado.
  - `coreLibraryDesugaring` habilitado en `build.gradle.kts` + dep
    `desugar_jdk_libs:2.1.4` (requerido por el plugin).
  - `FcmService` muestra el banner a mano desde `onMessage` (Android por
    default NO muestra notifs con la app en foreground).
  - `onDidReceiveNotificationResponse` reporta la apertura al backend.
  - Canal Android `baqueano_default` (matchea el meta-data del manifest).

- **API v22 de flutter_local_notifications**:
  - `initialize({settings: ...})` (named param, no positional).
  - `show({id:, title:, body:, notificationDetails:, payload:})`
    (todos named).
  - Gotcha documentado en CHEATSHEET #22.

- **Validado end-to-end**:
  - Push llegado al emulador con la app en foreground.
  - Banner visible con titulo + body.
  - Tap -> `[FCM] tap (background)` + `[FCM] tap (terminated)`.
  - POST `/notificaciones/{id}/abierta` -> 200.
  - DB: `estado=abierta, abierto_en=2026-10-12 13:42:59`.

- **Deuda cosmetica menor (backlog)**:
  - El titulo de la notif muestra `baqueano_natales` en vez de
    `Baqueano Natales`. Fix en `AndroidManifest` (`android:label`).
  - Icono cuadrado en vez de icono monocromatico. Fix con
    `ic_notification` vectorial.

- **Estado del sistema de notificaciones**:
  - S1 (modelo multi-device) OK
  - S2 (refactor push batch) OK
  - S3 (tracking entrega/apertura) OK
  - S4 (preferencias + quiet hours) OK
  - S5 (panel admin backend) OK
  - Analytics end-to-end OK (backend + Flutter)
  - Banner en foreground OK
  - S6 (panel admin Flutter) PENDIENTE
  - S7 (notificaciones in-app Flutter) PENDIENTE

- **Suite total: 364 passed, 0 warnings.**

### 2026-10-12 (cont. 14) - Pipeline de analytics cerrado end-to-end

**El ciclo enviada -> entregada -> abierta funciona completo (backend + Flutter).**

- **Backend** (commit `d3452a9`):
  - `NotificationService.enviar_a_usuario()` inyecta el `notification_log_id`
    en el payload del push FCM.
  - La app Flutter lo recibe en `message.data["notification_log_id"]`.
- **Flutter** (commit `db4a324`):
  - `FcmService` reporta la apertura al tocar la notificacion
    (`onMessageOpenedApp` para background + `getInitialMessage` para terminated).
  - POST a `/api/v1/notificaciones/{id}/abierta` (best-effort, no rompe el flujo).

- **Validado end-to-end**:
  - Worker dispara push con `notification_log_id: 98a11412-...`.
  - App Flutter lo recibe (`[FCM] foreground: ... notification_log_id: ...`).
  - `marcar_abierta` persiste: `estado=abierta, abierto_en=2026-10-12 13:15:26`.
  - Confirmado con `CHECK: estado=abierta abierto_en=...` en la DB.

- **Suite total: 364 passed, 0 warnings.**

### 2026-10-12 (cont. 13) - Panel admin de notificaciones (S5) - backend completo

**Backend del sistema de notificaciones 100% completo. Solo queda Flutter.**

- **S5 - Panel admin backend** (commit `7e81e6f`):
  - `POST /api/v1/admin/notificaciones/enviar` - envio masivo con segmentos:
    `{"tipo": "todos"}` | `{"tipo": "rol", "valor": "cliente"}` |
    `{"tipo": "usuarios", "valor": [uuid, ...]}`.
  - `GET /api/v1/admin/notificaciones` - historial con filtros
    (tipo, estado, desde, hasta) + paginacion.
  - `GET /api/v1/admin/notificaciones/stats` - dashboard con:
    total/enviadas/entregadas/abiertas/fallidas/skipped,
    delivery_rate, open_rate, por estado, por tipo, top 5.
  - El envio masivo **respeta preferencias del usuario y quiet hours**
    (los broadcasts no spamean a quien hizo opt-out).

- **Fixes de la sesion**:
  - `Field` import en `schemas.py` (crash al arrancar).
  - `conftest.py` TRUNCATE: agregadas `notification_logs`, `fcm_tokens`,
    `preferencias_notificacion` (aislamiento entre tests).

- **Suite total: 364 passed, 0 warnings** (351 + 13 nuevos).

- **Estado del sistema de notificaciones**:
  - S1 (modelo multi-device) OK
  - S2 (refactor push batch) OK
  - S3 (tracking entrega/apertura) OK
  - S4 (preferencias + quiet hours) OK
  - S5 (panel admin backend) OK
  - S6 (panel admin Flutter) PENDIENTE
  - S7 (notificaciones in-app Flutter) PENDIENTE
  - Flutter: centro de notificaciones + pantalla de preferencias PENDIENTE

- **Pendiente para sesion futura**:
  - Flutter: las 3 pantallas admin del panel (composer + historial + stats).
  - Flutter: centro de notificaciones del usuario + pantalla de preferencias.
  - Flutter: reporte de apertura al tocar notificacion push.

### 2026-10-12 (cont. 12) - Notificaciones: preferencias + tracking (S3+S4)

**Backend del sistema de notificaciones: 100% completo.**

- **S4 - Preferencias del usuario** (commit `644feae`):
  - `GET /api/v1/usuarios/me/preferencias-notificacion` (crea defaults).
  - `PUT /api/v1/usuarios/me/preferencias-notificacion` (parcial).
  - Schemas: `PreferenciaNotificacionResponse` + `PreferenciaNotificacionUpdate`.
  - Validacion de `quiet_hours_*` con regex `HH:MM`.
  - 7 tests.
- **S3 - Tracking de entrega/apertura** (misma commit):
  - Modulo nuevo `app/modules/notificaciones/`.
  - `GET /api/v1/notificaciones` (historial del usuario).
  - `POST /api/v1/notificaciones/{id}/recibida` (device confirma entrega).
  - `POST /api/v1/notificaciones/{id}/abierta` (idempotente).
  - Ownership validado (404 si notif ajena).
  - `ORDER BY creado_en DESC, id DESC` (tie-breaker estable).
  - 7 tests.
- **Fix de deuda** (commit `38840d5`): mocks de `test_push_service.py`
  actualizados al wrapper (los mocks viejos apuntaban a `app.core.push.messaging.send`,
  ahora viven en `app.core.notifications.providers.fcm`).

- **Suite total: 351 passed, 0 warnings** (337 + 14 nuevos).

- **Roadmap pendiente del sistema**:
  - S5-S6: panel admin (composer + historial + stats).
  - S7: notificaciones in-app (centro de notificaciones en la app Flutter).
  - Flutter: pantalla de preferencias (usa el endpoint ya listo).
  - Flutter: reporte de apertura desde el tap de la notificacion.

### 2026-10-12 (cont. 11) - Sistema de notificaciones nivel industria

**Base arquitectonica completa para FCM + futuros providers (APNs/SMS/email).**

- **Modulo nuevo** `app/core/notifications/` (commit `944d989`):
  - `models.py`: `FcmToken` (multi-device + limpieza automatica),
    `PreferenciaNotificacion` (opt-in/out por tipo + quiet hours),
    `NotificationLog` (historial + analytics).
  - `providers/base.py`: ABC `NotificationProvider` + `SendResult`.
  - `providers/fcm.py`: `FcmProvider` con `send` y `send_batch`
    (`send_each_for_multicast`), prioridad, TTL, collapse_key,
    analytics_label.
  - `service.py`: `NotificationService` con pipeline completo
    (preferencias -> quiet hours -> tokens -> provider -> log).
    Auto-migracion on-the-fly de tokens legacy.
    Limpieza automatica de tokens `UNREGISTERED`.
  - `push.py` refactorizado como **thin wrapper** -> worker no cambio.

- **Migracion `a8b9c0d1e2f3`**: 3 tablas + 4 enums + backfill de
  `usuarios.fcm_token` -> `fcm_tokens` (1 token migrado en prod).

- **Validado end-to-end**: `STATS: pushes: 1` + `LOG: estado=enviada`
  + notificacion recibida por el listener Flutter.

- **Roadmap pendiente**:
  - S3: analytics (tracking de apertura desde Flutter -> backend).
  - S4: endpoints de preferencias + UI Flutter.
  - S5-S6: panel admin (composer + historial + stats).
  - S7: notificaciones in-app (centro de notificaciones en la app).

### 2026-10-12 (cont. 10) - FCM frontend Flutter + validacion end-to-end

**FCM completo: backend + frontend, validado con push real en emulador.**

- **Slice Flutter (commit `861702b`)**:
  - `firebase_messaging: ^15.1.5` en `pubspec.yaml`.
  - `AndroidManifest.xml`: permiso `POST_NOTIFICATIONS` + meta-data del canal
    default `baqueano_default`.
  - `lib/core/fcm/fcm_service.dart`: servicio transversal con
    `inicializar()` (listeners foreground + background) y
    `solicitarPermisoYObtenerToken()`.
  - `lib/core/fcm/fcm_providers.dart`: provider Riverpod del servicio.
  - `auth_repository.registrarFcmToken()`: POST al backend.
  - `auth_notifier._registrarFcmAsync()`: fire-and-forget post-login y en
    restoreSession.
  - `main_client.dart`: inicializa FCM al arranque (listeners).

- **Validacion end-to-end en emulador Pixel6_API34_Play**:
  - Login Google OK -> token FCM obtenido -> POST `/usuarios/me/fcm-token`
    -> 200.
  - Worker de recordatorios disparado manualmente -> `pushes: 1`.
  - **Notificacion recibida por el listener Flutter:**
    `[FCM] foreground: title=Recordatorio de mantenimiento data={...}`

- **Herramienta nueva: AVD `Pixel6_API34_Play`**:
  - Imagen `system-images;android-34;google_apis_playstore;x86_64`.
  - **Necesario para FCM** (sin Play Store, FCM no funciona).
  - Arrancar con: `emulator -avd Pixel6_API34_Play -no-snapshot-load -gpu host`.
  - Gotcha: requiere **~5 GB libres en D:** para arrancar (el error
    `hasSufficientDiskSpace` bloquea el boot).

- **Aprendizajes**:
  - El SDK Manager CLI (`android sdk install`) tiene un bug en la version
    nueva: no descarga nada silenciosamente. **Usar Android Studio GUI**
    (SDK Manager -> SDK Platforms -> Show package details -> Google Play
    Intel x86_64 Atom System Image).
  - Los scripts ad-hoc con `AsyncSessionLocal` en un proceso Python nuevo
    necesitan importar TODOS los modelos relacionados (gotcha 4.3). El
    worker de produccion corre dentro del lifespan de FastAPI y ya los
    tiene cargados, pero un `python -c` ad-hoc falla con
    `InvalidRequestError: Mapper[...] failed to locate a name 'Prestador'`.
  - Los pushes a una app en **foreground** NO muestran banner del sistema;
    el listener `onMessage` los captura. Para banner en foreground se
    necesita `flutter_local_notifications` (nice-to-have futuro).

- **Suite backend: 337 tests verdes, 0 warnings.**
- **M4 (garantias + recordatorios + worker + FCM) cerrado 100%.**

### 2026-10-12 (cont. 9) - Backend de FCM (push notifications) completo

**Worker de recordatorios ahora manda push real. Cierra M4 al 100% (backend).**

- **Slice 1 (commit `770fbae`)** - Registro de token:
  - Columna `usuarios.fcm_token VARCHAR(500) NULL` (modelo single-device).
  - Migracion `f1a2b3c4d5e6`.
  - Endpoint `POST /api/v1/usuarios/me/fcm-token` con schema `FcmTokenUpdate`.
  - 4 tests HTTP: ok, sobreescribe, token > 500 chars (422), sin auth (401).
- **Slice 2 (commit `40af0bf`)** - Servicio de push:
  - `app/core/push.py` transversal con `enviar_push(token, ...)` y
    `enviar_push_a_usuario(user_id, ..., db=None)`.
  - El SDK de FCM (sincrono) se corre con `asyncio.to_thread` para no
    bloquear el event loop.
  - **Nunca propaga excepciones** (best-effort): devuelve True/False.
  - `FCM_ENABLED` en `Settings` para desactivar globalmente (tests, fallback).
  - 7 tests unitarios con mock de `messaging.send`.
- **Slice 3 (misma commit `40af0bf`)** - Wire en worker:
  - `worker.py` reemplaza el `# TODO M5` por `_enviar_push_recordatorio`.
  - Stats del worker ahora incluye counter `pushes`.
  - El push se manda **despues** de marcar el recordatorio como enviado
    (la marca es la fuente de verdad; si el push falla, no se re-dispara).
  - 2 tests de integracion: push ok → stats.pushes=1; push falla →
    recordatorio igual marcado enviado, stats.errores=0.

- **Cleanup de warnings** (commit `83cab05`):
  - `pytest.ini`: `cache_dir = /tmp/.pytest_cache` (elimina los 2
    PytestCacheWarning por permisos en Docker).
  - `logging.py`: migrado a `from pythonjsonlogger.json import JsonFormatter`
    con try/except para v2 (elimina el DeprecationWarning).
  - **Suite: 0 warnings.**

- **Suite total: 337 tests verdes** (328 + 7 push service + 2 worker push).
- **Pendiente de FCM:** frontend Flutter (`firebase_messaging`, permiso
  POST_NOTIFICATIONS, registrar token post-login). Proxima sesion.
- **Como deshabilitar FCM en produccion:** `FCM_ENABLED=false` en `.env` +
  recrear el container.

### 2026-10-12 (cont. 8) - Auditoria cross-modulo del patron MissingGreenlet

**El bug MissingGreenlet no era solo de oficios: 7 endpoints mas en 3 modulos.**

- **Auditoria cross-modulo** (commit `6800704`):
  - El patron `await services.crear_*/actualizar_*` seguido de
    `Model.model_validate(obj)` sin `await db.refresh(obj)` apareció en:
    - `comercios/routes.py`: `crear_comercio`, `crear_categoria` (2)
    - `prestadores/routes.py`: `crear_prestador`, `crear_categoria` (2)
    - `social/routes.py`: `crear_cuenta`, `actualizar_cuenta`,
      `actualizar_config` (3)
  - Los mas criticos: `actualizar_cuenta` y `actualizar_config` (UPDATE,
    no zafan con RETURNING).
  - Fix: `await db.refresh(obj)` defensivo en los 7. Es no-op si el
    objeto ya esta cargado, asi que no rompe nada.
- **Regla global documentada** en OPERATIVA_DEV.md 4.2: aplica a TODOS
  los modulos del proyecto.
- **Total endpoints con refresh post-service:** 14 (oficios) + 7 (otros) = **21**.
- **Suite total: 324 tests verdes** (sin cambios — el refresh es no-op
  donde no hacia falta).

### 2026-10-12 (cont. 7) - Cobertura HTTP completa de M1-M4 + cierre de sesion

**4to y ultimo archivo de tests HTTP de oficios. Cobertura M1-M4 al 100%.**

- **Test file nuevo** `backend/tests/modules/oficios/test_routes_garantias.py`
  (commit `fc2d48f`): 6 tests HTTP.
  - GET cliente (con/sin garantia).
  - **Test de integracion del wire** `cambiar_estado -> generar_garantia_automatica`
    al pasar a ENTREGADO (nada mas cubria este wire end-to-end).
  - GET/POST prestador.
  - Ownership (cliente y prestador ajenos).
- **Sin bugs nuevos** — garantias ya validaba ownership correctamente.

**Suite total del proyecto: 324 tests verdes** (era 272 al inicio de la sesion).

**Estado final de tests HTTP por modulo:**
| Modulo | Archivo | Tests |
|---|---|---|
| Recordatorios | test_routes_recordatorios.py | 5 |
| Vehiculos | test_routes_vehiculos.py | 10 |
| Ordenes | test_routes_ordenes.py | 18 |
| Turnos | test_routes_turnos.py | 13 |
| Garantias | test_routes_garantias.py | 6 |
| **Total oficios** | | **52** |

**Bugs reales encontrados en la sesion (4):**
1. `NameError: ObjetoServicio` (3 endpoints de recordatorios) - 3a5941b
2. `MissingGreenlet` en actualizar_vehiculo - 58f94a1
3. **Bug de seguridad**: 6 endpoints de ordenes sin validar owner - 238bfb8
4. `MissingGreenlet` en 4 endpoints de turnos + 10 endpoints mas con el
   mismo riesgo (auditoria) - ba1d185

**Cobertura HTTP de M1-M4 del modulo oficios: CERRADA.**
- M5 (fotos + notificaciones + reportes) queda pendiente, con su propia
  tanda de tests HTTP al cerrarse.

**Proximos pasos:**
1. Push FCM real en worker de recordatorios (hoy solo loguea).
2. M5: fotos + notificaciones in-app + reportes.

### 2026-10-12 (cont. 6) - Tests HTTP de turnos + auditoria MissingGreenlet

**3er archivo de tests HTTP de oficios. Bug real + auditoria defensiva.**

- **Test file nuevo** `backend/tests/modules/oficios/test_routes_turnos.py`
  (commit `99830a8`): 13 tests HTTP.
  - State machine (pendiente -> confirmado valido, pendiente -> completado
    invalido 409).
  - Editar/cancelar por cliente.
  - Agenda del taller.
  - Cambiar estado/rechazar por prestador.
  - Ownership en 4 endpoints.
- **Bug real** `MissingGreenlet` en 4 endpoints de turnos (commit `ba1d185`):
  - `PATCH /mis-turnos/{id}`, `POST /mis-turnos/{id}/cancelar`,
    `POST /mis-prestadores/{pid}/turnos/{id}/estado`,
    `POST /mis-prestadores/{pid}/turnos/{id}/rechazar`.
  - Causa: el service hacia `db.flush()` y despues el route handler hacia
    `TurnoResponse.model_validate(turno)` sin `await db.refresh(turno)`.
    Post-flush, `turno.updated_at` dispara IO lazy -> MissingGreenlet.
  - **Impacto en produccion**: 500 en cualquier edicion/cancelacion de turno.
- **Auditoria del patron** (misma commit): 10 endpoints mas tenian el mismo
  riesgo. Agregado `await db.refresh(obj)` en:
  - `crear_categoria_mecanica`, `actualizar_categoria_mecanica`
  - `crear_repuesto`, `actualizar_repuesto`
  - `agregar_item`, `actualizar_item`
  - `crear_turno`
  - `actualizar_garantia`, `crear_garantia`
  - `crear_recordatorio`
- **Patron seguro confirmado:** los endpoints de ordenes que ya usan
  `orden = await services.obtener_orden(db, orden.id)` despues de cada
  mutacion estan bien (porque `obtener_orden` usa `selectinload` +
  `populate_existing`).

- **Suite total: 318 tests verdes** (305 + 13).
- **3 archivos de tests HTTP agregados hoy**, **4 bugs reales encontrados**:
  1. `NameError: ObjetoServicio` (recordatorios) - 3a5941b
  2. `MissingGreenlet` en actualizar_vehiculo - 58f94a1
  3. Bug de seguridad: 6 endpoints de ordenes sin validar owner - 238bfb8
  4. `MissingGreenlet` en 4 endpoints de turnos + 10 endpoints mas con el
     mismo riesgo - ba1d185

### 2026-10-12 (cont. 5) - BUG DE SEGURIDAD en endpoints de ordenes + tests HTTP

**Hallazgo critico: bug de autorizacion en 6 endpoints de ordenes.**

- **Test file nuevo** `backend/tests/modules/oficios/test_routes_ordenes.py`
  (commit `fa0df3d`):
  - 18 tests HTTP: state machine (transiciones validas/invalidas), aprobacion
    total/parcial/rechazo, historial, ownership en los 6 endpoints del router
    de prestador.
- **Bug CRITICO de autorizacion** (commit `238bfb8`):
  - Los 6 endpoints de `/mis-prestadores/{pid}/ordenes` (detalle, actualizar,
    agregar_item, editar_item, eliminar_item, cambiar_estado) validaban que
    `orden.prestador_id == prestador_id` pero **NO que el usuario fuera dueno
    del prestador**.
  - Cualquier usuario autenticado podia cambiar el estado de cualquier orden
    conociendo los IDs (cambiar a entregado, agregar items, etc).
  - Fix: llamar `_validar_prestador_del_usuario` (que ya existia) al inicio
    de los 6 endpoints. Devuelve 403 si no es dueno ni admin.
  - **Impacto en produccion**: alto. Bug de seguridad real.
- **Test file nuevo** `backend/tests/modules/oficios/test_routes_vehiculos.py`
  (commit `dbeb062`): 10 tests HTTP.
- **Bug real** `MissingGreenlet` en `actualizar_vehiculo` (commit `58f94a1`):
  - `services.actualizar_vehiculo` hacia `db.flush()` y despues
    `_vehiculo_a_response(obj, veh)`, que accede a `obj.updated_at`. Post-flush
    el objeto queda expirado -> acceso lazy dispara IO sincronico ->
    `MissingGreenlet`.
  - Fix: `await db.refresh(obj)` + `await db.refresh(veh)` antes de serializar.
  - **Impacto en produccion**: PATCH /mis-vehiculos fallaba con 500.

- **Suite total: 305 tests verdes** (272 + 5 + 10 + 18).
- **Leccion**: los smoke tests visuales NO detectan bugs de autorizacion ni
  errores de serializacion. Los tests HTTP los detectaron en el primer intento.
  Los 3 archivos de tests HTTP agregados hoy encontraron **3 bugs reales**
  (2 de produccion + 1 de seguridad).

- **Aprendizajes operativos**:
  - Bloque `$py | ssh python3 -` con contenido largo puede fallar
    silenciosamente. Verificar SIEMPRE con `grep -c`. Ya documentado en
    OPERATIVA_DEV.md 3.7.
  - Los tests HTTP con `ASGITransport` requieren override de `get_db`
    ademas de `get_current_user`. Ya documentado en OPERATIVA_DEV.md 4.3.
  - **Nuevo**: en oficios, `ObjetoServicio` es base y `Vehiculo` extiende.
    Los services que devuelven "vehiculo completo" esperan ambos. Usar
    fixture `vehiculo_test` (crea ambos), no `objeto_servicio_test`.
  - **Nuevo**: SQLAlchemy post-flush deja objetos expirados. Antes de
    serializar con acceso a `updated_at`/`created_at`, hacer
    `await db.refresh(obj)` o usar `populate_existing`.

### 2026-10-12 (cont. 4) - Tests HTTP de oficios + suite 277 + aprendizajes

**Paso B: cerrado el gap que dejo pasar el bug ObjetoServicio.**

- **Test file nuevo** `backend/tests/modules/oficios/test_routes_recordatorios.py`
  (commit `368b11e`):
  - 5 tests HTTP que ejercitan los endpoints de recordatorios (GET vacio,
    GET con enviados, POST km, POST validacion, POST objeto ajeno).
  - Override de `get_current_user` Y `get_db` para compartir la sesion async
    del fixture (sin esto: `RuntimeError: Event loop is closed`).
  - **Hubieran detectado el bug `3a5941b`** al primer request.
- **Suite total: 277 tests verdes** (272 previos + 5 nuevos).
- **Aprendizajes de la sesion**:
  - Los tests HTTP con `ASGITransport` requieren override de `get_db`
    ademas de `get_current_user`. Documentado en `OPERATIVA_DEV.md` 4.3.
  - El patron `$py | ssh python3 -` con bloques largos puede fallar
    **silenciosamente** (el archivo no cambia y no hay error). Verificar
    SIEMPRE con `grep -c`. Documentado en `OPERATIVA_DEV.md` 3.7.
  - `docker compose up -d backend` no recrea el container si el hash no
    cambio -> usar `restart`. Documentado en `SERVER_CHEATSHEET.md` 16.
  - `touch app/main.py` no siempre dispara hot reload de uvicorn.
    Documentado en `SERVER_CHEATSHEET.md` 17.
  - Editar archivos con acentos/emojis: **NO** usar Python via stdin en
    Windows (rompe encoding). Usar `[System.IO.File]::WriteAllText` a un
    temporal. Documentado en `SERVER_CHEATSHEET.md` 18.

### 2026-10-11 (cont.) - Etapa 9b: Publicar afiches SVG end-to-end
- Backend completo para generar PNG + publicar afiches en redes:
  - svg_service.svg_a_png() via cairosvg (libs de sistema: libcairo2, libpango)
  - services.publicar_afiche() + _guardar_png() en /app/media/promociones/
  - Endpoints nuevos: POST /generar-png (image/png) y POST /publicar (201)
  - Nginx dev-api.conf: location /media/ (Meta descarga PNG por HTTPS)
  - Dockerfile: agregadas libcairo2-dev, libpango1.0-dev, libgdk-pixbuf (builder + runtime)
  - cairosvg==2.7.1 en requirements
- Frontend Flutter:
  - 3 botones en el editor: Descargar / Compartir / Publicar en redes
  - Modal de publicacion: checkboxes por red + caption editable
  - Deps: path_provider + share_plus
- Smoke test end-to-end en produccion:
  - Generar afiche -> PNG accesible por HTTPS publico
  - POST /publicar -> 201 -> worker publico en Facebook
- RESUELTO (2026-10-11): share_plus upgraded a 13.3.1 (ver changelog arriba).

### 2026-10-12 (cont. 2) - M4 worker de recordatorios (APScheduler) + M4 backend 100%

**M4 backend completo: garantias + recordatorios + worker automatico.**

- **Worker in-process** (`oficios/worker.py`) con APScheduler (mismo patron
  que el social worker):
  - Revisa la tabla `recordatorios` cada 1 hora (configurable).
  - Evalua condiciones:
    - **KM**: compara `Vehiculo.kilometraje_actual` >= `km_umbral` (solo vehiculos).
    - **FECHA**: compara `date.today()` >= `fecha`.
    - **EVENTO**: siempre se envia (el evento lo dispara el sistema).
  - Marca enviados los que cumplen; deja pendientes los que no.
  - Nunca crashea el scheduler: cada error se loggea y aisla.
- **2 settings nuevas** en `config.py`:
  - `RECORDATORIOS_WORKER_ENABLED: bool = True`
  - `RECORDATORIOS_WORKER_INTERVAL_SEC: int = 3600`
- **Wire en `main.py` lifespan**: arranca/detiene junto al worker social.
- **Test manual end-to-end validado**: 4 escenarios (KM sobre/bajo umbral,
  fecha pasada/futura) -> 2 ENVIADOS + 2 PENDIENTES, sin errores.
- **Commit** `822e145`.

**Estado final del modulo oficios:**
- M1 (objetos_servicio + vehiculos): ✅ COMPLETA (backend + frontend + tests)
- M2 (ordenes + state machine): ✅ COMPLETA (backend + frontend + tests)
- M3 (turnos + agenda): ✅ COMPLETA (backend + frontend + tests)
- M4 (garantias + recordatorios + worker): ✅ **Backend completo** — frontend pendiente
- M5 (fotos + notificaciones + reportes): ⏳

**Pendiente para proxima sesion:**
1. Frontend de M4 (garantias + recordatorios): ~4 pantallas + integraciones.
2. Notificaciones push (FCM) para el worker de recordatorios (hoy solo loggea).
3. Smoke test visual completo de M3 (reservar turno -> confirmar -> completar)
   en emulador.
4. M5 del roadmap: fotos + notificaciones + reportes.
### 2026-10-12 (cont.) - Modulo oficios Fase M4 backend (garantias + recordatorios)

**Backend M4 completo. Total oficios: 131 tests verdes.**

- **Tabla `garantias`**: tipo (mano_obra/repuesto/completo), duracion_dias,
  fecha_inicio/fin, cobertura, condiciones. Asociada a orden entregada.
- **Tabla `recordatorios`**: tipo (km/fecha/evento), condicion JSONB, mensaje,
  enviado, fecha_envio. Asociada a objeto_servicio (vehiculo).
- **Auto-generacion de garantia al entregar orden**: wired en
  `services.cambiar_estado()`. Cuando la orden pasa a ENTREGADO, se genera
  automaticamente una garantia COMPLETO de 30 dias. Idempotente (si ya existe,
  la retorna). Configurable a futuro (por categoria de servicio).
- **6 services de garantias**: crear, obtener por orden (activa), actualizar
  (con recalculo de fecha_fin), generar_garantia_automatica (idempotente).
- **6 services de recordatorios**: crear, listar por objeto, eliminar (soft),
  marcar como enviado, buscar pendientes (para worker), crear batch.
- **Endpoints (~9 nuevos)**:
  - Cliente: `GET /mis-ordenes/{id}/garantia`,
    CRUD `/mis-vehiculos/{oid}/recordatorios` (listar, crear, actualizar,
    eliminar).
  - Prestador: `GET /mis-prestadores/{id}/ordenes/{oid}/garantia`,
    `POST .../garantia` (crear/actualizar garantia manual).
- **Migracion** `de89315a2610`.
- **12 tests nuevos** (`test_services_garantias.py`): auto-generacion,
  idempotencia, 409 en no-entregada, actualizacion con recalculo, CRUD
  recordatorios, busqueda de pendientes.
- **Pendiente M4**: worker APScheduler que revisa recordatorios cada X horas
  y los envia (no implementado aun), frontend de garantias + recordatorios.

**Roadmap del modulo oficios:**
- M1 (objetos_servicio + vehiculos): ✅ COMPLETA
- M2 (ordenes + state machine): ✅ COMPLETA
- M3 (turnos + agenda): ✅ COMPLETA
- M4 (garantias + recordatorios): ✅ Backend completo — worker + frontend pendientes
- M5 (fotos + notificaciones + reportes): ⏳

**Commits recientes:**
- `6a2b7eb` feat(oficios): M4 backend - garantias + recordatorios
- `b4288cf` test: conftest actualizado con turnos + garantias + recordatorios
### 2026-10-12 - Modulo oficios Fases M3 (turnos) + mejora UX formulario de ordenes

**Estado del modulo oficios: M1 + M2 + M3 completas (backend + frontend + tests).**

- **Mejora UX formulario crear orden** (commit `57e0d5d` + `88de440`):
  - Backend: 2 endpoints nuevos (`GET /mis-prestadores/{id}/clientes?q=...`
    para buscar clientes, `GET .../clientes/{cid}/vehiculos` para listar
    vehiculos del cliente). Service `buscar_clientes` (busca por email,
    nombre o apellido con min 2 chars) + `listar_vehiculos_de_cliente`.
  - Frontend: `FormularioOrdenScreen` reescrito. Ya NO pide UUIDs manuales.
    Ahora tiene buscador de cliente con debounce 400ms + dropdown de
    resultados + chip del cliente + selector de vehiculo del cliente.
  - 8 tests nuevos en `test_services_busqueda.py`.

- **Fase M3 backend - turnos + agenda** (commit `13b7d8f`):
  - Tabla `turnos`: cliente + prestador + objeto_servicio + fecha_inicio +
    duracion_min + motivo + notas + orden_id (opcional para vincular).
  - State machine de 7 estados: `pendiente -> confirmado -> en_curso ->
    completado`. Ramas: `pendiente -> rechazado`, `pendiente|confirmado ->
    cancelado`, `confirmado -> no_asistio`.
  - Transiciones por rol (prestador mueve operativos, cliente cancela).
  - 9 services: crear_turno, listar_turnos_cliente/prestador, obtener_turno,
    actualizar_turno, cambiar_estado_turno, rechazar_turno, cancelar_turno,
    vincular_orden_a_turno.
  - 10 endpoints: 5 cliente (`/mis-turnos` CRUD + cancelar) + 5 prestador
    (`/mis-prestadores/{id}/turnos` listar/detalle/estado/rechazar/vincular).
  - Migracion `3fa886c2e6d7`.
  - 34 tests nuevos: state machine (19) + services (15).

- **Fase M3 frontend** (commit `b7053ef`):
  - Domain: `Turno` + `EstadoTurno` enum (7 valores con colorHex).
  - Repository: 8 metodos M3 (4 cliente, 4 prestador + vincular).
  - Providers: 4 providers family con params inmutables.
  - 5 pantallas nuevas:
    - `MisTurnosScreen` (cliente): lista con filtros por estado.
    - `DetalleMiTurnoScreen` (cliente): detalle + cancelar con motivo.
    - `AgendaTallerScreen` (prestador): agenda con filtros.
    - `DetalleTurnoTallerScreen` (prestador): acciones contextuales segun
      estado (confirmar / rechazar / en_curso / completar / no_asistio).
    - `ReservarTurnoScreen` (cliente): selector de vehiculo + date picker +
      time picker + duracion configurable + motivo + notas.
  - Router: 5 rutas nuevas.
  - Home: card "Mis turnos" en Mi actividad.
  - Detalle publico del prestador: boton "Reservar turno" (CTA principal).
  - Detalle mi prestador: boton "Agenda del taller".

- **Estado del proyecto**:
  - Suite de tests del backend: **218 + 34 = 252 tests verdes** aproximadamente.
  - `flutter analyze`: limpio en cada paso.
  - Builds OK.

**Roadmap del modulo oficios:**
- M1 (objetos_servicio + vehiculos): ✅ COMPLETA
- M2 (ordenes + state machine): ✅ COMPLETA
- M3 (turnos + agenda): ✅ COMPLETA
- M4 (garantias + recordatorios + worker): ⏳ proxima
- M5 (fotos + notificaciones + reportes): ⏳
### 2026-10-11 (cont. 10) - Modulo oficios: tests automatizados M1+M2 (77 tests) + fix populate_existing

**Deuda tecnica cerrada. Suite completa del proyecto: 218 tests verdes.**

- **Bug critico encontrado por tests en `services.obtener_orden`**:
  - Sintoma: `aprobar_presupuesto` veia `orden.items = []` aunque hubiera items en la DB -> el
    cliente que aprobaba todos los items terminaba viendo la orden como RECHAZADA.
  - Causa: SQLAlchemy identity map devolvia la instancia cacheada sin refrescar la relacion
    `items` (los `selectinload` no aplican sobre objetos ya cargados en la sesion).
  - Fix: `.execution_options(populate_existing=True)` en el statement (SQLAlchemy 2.0).
    Fuerza refresco de la instancia desde la DB (y re-aplica los selectinload).
  - Impacto: **bug en produccion** — los tests lo detectaron antes que un cliente real.
- **Suite de tests nueva (77 tests)** en `backend/tests/modules/oficios/`:
  - `test_state_machine.py` (26): transiciones validas/invalidas por rol + completitud.
  - `test_schemas.py` (11): validaciones Pydantic (rangos, requeridos, defaults).
  - `test_models.py` (11): enums + creacion + relaciones ORM.
  - `test_services_vehiculos.py` (10): CRUD completo + patente unica + permisos (403).
  - `test_services_ordenes.py` (19): crear orden + items + cambiar estado + aprobar/rechazar
    + workflow end-to-end completo (crear -> items -> presupuestar -> aprobar -> ejecutar).
- **`conftest.py` raiz actualizado**: import de oficios + TRUNCATE de las 7 tablas de oficios.
- **`conftest.py` de oficios** con fixtures: `usuario_cliente`, `categoria_oficio`,
  `prestador_test`, `objeto_servicio_test`, `vehiculo_test`, `categoria_mecanica`.
- **`test_promocion.py` actualizado**: pasa a esperar 6 plantillas (agrega `lanzamiento`).
- **Suite completa del proyecto**: 218 passed en 86s (antes: 141).
- **Commits**: `c8bcc01` + `e313f0f` (rebased).

**Estado del modulo oficios:**
- M1 backend + frontend + tests ✅
- M2 backend + frontend + tests ✅
- Suite de tests: 77 tests propios + integracion con la suite global.
### 2026-10-11 (cont. 9) - Modulo oficios Fase M2 frontend completa (pantallas de ordenes)

**Frontend Flutter del ciclo completo de ordenes. M2 cerrada end-to-end.**

- **Domain (3 archivos nuevos)**:
  - `orden_trabajo.dart`: clase `OrdenTrabajo` con `EstadoOrden` (10 estados
    con `colorHex` por estado) y `PrioridadOrden` (4 niveles con color).
  - `orden_item.dart`: `OrdenItem` con `TipoItemOrden` (servicio, repuesto,
    mano_obra, otro). Estado `aprobado` nullable (pendiente/aprobado/rechazado).
  - `orden_historial.dart`: `OrdenHistorialEvento` con `TipoEventoHistorial`
    (7 tipos). Getters `descripcion` y helpers de formato.
- **Data extendida**:
  - `oficios_repository.dart`: +9 metodos M2 (listarOrdenesPrestador,
    crearOrden, detalleOrdenPrestador, agregarItem, eliminarItem,
    cambiarEstado, listarMisOrdenes, detalleMiOrden, aprobarPresupuesto).
  - `oficios_providers.dart`: +4 providers family (`ordenesPrestadorProvider`,
    `ordenPrestadorDetalleProvider`, `misOrdenesProvider`, `miOrdenDetalleProvider`)
    con params inmutables (`==`/`hashCode` para cache correcto).
- **5 pantallas nuevas**:
  - `MisOrdenesScreen` (cliente): lista con filtros por estado + badges.
  - `DetalleMiOrdenScreen` (cliente): items con **checkbox para aprobacion
    parcial**, timeline del historial, boton "Enviar respuesta".
  - `OrdenesTallerScreen` (prestador): lista con filtros + FAB "Nueva orden".
  - `DetalleOrdenTallerScreen` (prestador): editor de items (modal bottom
    sheet), acciones de cambio de estado contextuales (segun el estado actual),
    timeline, overlay de carga durante operaciones.
  - `FormularioOrdenScreen` (prestador): MVP con inputs manuales de UUIDs
    (busqueda de clientes/vehiculos es mejora futura).
- **Router**: +5 rutas (`/mis-ordenes`, `/mis-ordenes/:id`,
  `/mis-prestadores/:id/ordenes`, `/ordenes/nueva`, `/ordenes/:oid`).
- **Home**: card "Mis ordenes" en "Mi actividad" (icono recibo).
- **Detalle prestador**: boton "Ordenes del taller" junto a "Publicaciones".
- **Validado en emulador Android 14**:
  - Card "Mis ordenes" visible y navegable.
  - Pantalla de ordenes carga con empty state + filtros.
  - Formulario de nueva orden carga con todos los campos.
  - Filtros por estado disparan queries correctas (`?estado=...`).
  - Validacion del backend responde 422 en UUIDs invalidos (correcto).
- **`flutter analyze`**: No issues found.
- **Build apk client**: OK.
- **Commits**: `296a0f1` (M2 frontend).

**Deuda tecnica pendiente para M2:**
- Tests automatizados de oficios (pytest) — no existen aun.
- Formulario de nueva orden: reemplazar UUIDs manuales por busqueda.
- Notificaciones in-app cuando el cliente aprueba.
### 2026-10-11 (cont. 8) - Modulo oficios Fase M2 backend completa (ordenes de trabajo)

**Corazon del MVP de mecanica: ciclo completo de orden con state machine.**

- **3 tablas nuevas** (migracion `8597373be79b`):
  - `ordenes_trabajo`: numero OT-YYYY-NNNN, 10 estados, prioridad, cliente,
    prestador, objeto_servicio, totales, fechas, notas internas/cliente.
  - `orden_items`: items del presupuesto (servicio, repuesto, mano_obra, otro)
    con aprobacion por item individual (None=pendiente, True/False=decision).
  - `orden_historial`: timeline **append-only** con estado_anterior/nuevo,
    usuario_id y contenido JSONB. Fuente de verdad del ciclo de vida.
- **State machine de 10 estados**:
  `ingresado -> diagnosticando -> presupuestado -> aprobado -> en_proceso
   -> listo -> entregado -> garantia`.
  Ramas: `presupuestado -> rechazado`, cualquier estado inicial `-> cancelado`.
  Validacion por rol (prestador vs cliente) con retorno 409 en transicion invalida.
- **Numeracion automatica** de ordenes con formato `OT-2026-0001`.
- **Presupuesto con aprobacion parcial**: el cliente puede aprobar/rechazar
  items individualmente. Si aprueba todos -> estado `aprobado`. Si aprueba
  parcial -> sigue en `presupuestado`. Si rechaza todos -> `rechazado`.
- **Eventos registrados en `orden_historial`** para cada cambio de estado,
  aprobacion, rechazo. Con `usuario_id` y `contenido` (motivo, total, etc.).
- **Fix critico `MissingGreenlet`**: en endpoints que devuelven `OrdenTrabajo`
  serializada se recarga con `selectinload(items, historial)` antes de responder.
  Los listados tambien usan `selectinload(items)` en la query.
- **~20 endpoints nuevos**:
  - Prestador: `GET/POST /mis-prestadores/{id}/ordenes`,
    `GET/PATCH /mis-prestadores/{id}/ordenes/{oid}`,
    `POST/PATCH/DELETE .../items`, `POST .../estado`.
  - Cliente: `GET /mis-ordenes`, `GET /mis-ordenes/{id}`,
    `POST /mis-ordenes/{id}/aprobar`.
- **Validado end-to-end: 10/10 tests HTTP**:
  - Crear orden -> numero OT-2026-0001 en estado `ingresado`.
  - Agregar 3 items -> total $295.000.
  - Transiciones: `ingresado -> diagnosticando -> presupuestado`.
  - Aprobacion parcial (2/3 items) -> total aprobado $260.000, estado sigue
    en `presupuestado`.
  - Aprobacion total -> estado `aprobado`.
  - Ejecucion: `aprobado -> en_proceso -> listo -> entregado`.
  - Historial: 8 eventos registrados en orden correcto.
  - Transicion invalida `entregado -> ingresado` -> **409**.
  - Listados de taller + cliente funcionando.
- **Pendiente**: frontend Flutter de M2 (pantallas de ordenes).
- **Commits**: `a93904c` (M1 backend), `da1923d` (M1 frontend),
  `f17119a`/`280f136` (M2 backend).
### 2026-10-11 (cont. 7) - Modulo oficios Fase M1 completa (backend + frontend)

**Arranque del MVP de mecanica con arquitectura reutilizable al resto de oficios.**

- **Diseno fundacional** (`docs/oficios/DISENO.md`, 311 lineas):
  - Arquitectura en 2 capas: CORE (aplica a TODOS los oficios) + VERTICAL (mecanica).
  - `objetos_servicio` como punto de extension polimorfico (vehiculo, propiedad, jardin).
  - 13 tablas disenadas, ~45 endpoints, state machine de 10 estados, 7 flujos, 6 ADRs.
  - 80% del codigo reutilizable. Agregar gasfiteria = ~2 sesiones.
- **Fase M1 backend** (commit `a93904c`):
  - 4 tablas nuevas: `objetos_servicio`, `vehiculos`, `mecanica_categorias_servicio`,
    `mecanica_repuestos`.
  - Migracion `4db12ad04733` aplicada (Alembic autogenerate limpio).
  - 6 archivos: models, schemas, services, deps, routes, seed.
  - 4 routers nuevos: publico (categorias/repuestos), propietario (mis-vehiculos CRUD),
    admin categorias, admin repuestos.
  - 11 categorias mecanica seedeadas (Mantenimiento, Frenos, Motor, etc.).
  - 10/10 tests HTTP end-to-end verdes.
- **Fase M1 frontend** (commit `da1923d`):
  - Feature `oficios/` en Flutter: domain (Vehiculo + MecanicaCategoria),
    data (OficiosRepository + providers Riverpod 3), presentation (2 pantallas).
  - Pantalla "Mis vehiculos" (lista + empty state + refresh + delete).
  - Formulario crear/editar vehiculo con validaciones.
  - Card "Mis vehiculos" en el Home cliente.
  - 3 rutas: `/mis-vehiculos`, `/mis-vehiculos/nuevo`, `/mis-vehiculos/:id/editar`.
  - Validado end-to-end en emulador Android 14: POST/GET/PATCH/DELETE funcionando.
  - `flutter analyze` limpio + build apk client OK.
- **Estado del roadmap del modulo oficios**:
  - M1: objetos_servicio + vehiculos + CRUD ✅ COMPLETA
  - M2: ordenes_trabajo + items + presupuesto + state machine (proxima)
  - M3: turnos + agenda
  - M4: garantias + recordatorios + worker
  - M5: fotos + notificaciones + reportes
### 2026-10-11 (cont. 6) - Riverpod 3.4.3 (deuda tecnica #7 cerrada)
- **Migracion completa a Riverpod 3.4.3** (estaba en 2.6.1).
  Estrategia en 2 fases para cero downtime:
  - **Fase 1 (compatible con v2)**: migrar los 4 `StateNotifierProvider` a
    `NotifierProvider` (API moderna disponible desde Riverpod 2):
    - `auth_notifier.dart`: `AuthNotifier extends Notifier<AuthState>` con
      `build()` y `late final _repository = ref.read(...)`.
    - `comercio_providers.dart`: `ComerciosFiltrosNotifier`.
    - `prestador_providers.dart`: `PrestadoresFiltrosNotifier`.
    - `promocion_providers.dart`: `EditorAficheNotifier`.
  - **Fase 2**: bump `flutter_riverpod ^2.6.1 -> ^3.0.0` (resolvio 3.4.3).
    Dependencias: `flutter_riverpod 3.4.3`, `riverpod 3.4.3`, `+listen 1.0.1`.
- **Cero breaking changes en el codigo**: la migracion previa de providers dejo
  el proyecto sin deuda de API (`flutter analyze` = No issues found).
- **Validado end-to-end en emulador Android 14**: home admin, afiches (preview
  SVG con gradientes), filtros de prestadores y comercios, logout + re-login
  con Google -> todo OK.
- Beneficios habilitados para el futuro: reintento automatico de providers,
  persistencia offline (experimental), mutaciones (experimental).
- Sin cambios necesarios por auto-pause de `ref.watch` ni `UnmountedRefException`
  en los flujos actuales.
### 2026-10-11 (cont. 5) - Cloudflare Origin Certificate + SSL Full (Strict) + Cloudflare Global Key decisión
- **Deuda tecnica #3 resuelta**: SSL del server ahora usa Cloudflare Origin Certificate
  (reemplaza self-signed). Cloudflare SSL mode cambiado de `Full` a **`Full (strict)`**.
  Cloudflare ahora valida criptograficamente el cert del origen -> elimina riesgo MITM
  entre Cloudflare y el server.
  - Cert generado en Cloudflare (wildcard `*.baqueanonatales.com`, RSA 2048, 15 anos).
  - Instalado en `~/baqueano-natales/deploy/nginx/certs/origin.crt` + `origin.key` (600).
  - `deploy/nginx/conf.d/dev-api.conf` actualizado (rutas + comentario).
  - Certs viejos (`dev-api.crt/key`) y `authenticated_origin_pull_ca.pem` eliminados.
  - Health check HTTPS post-migracion: 200 OK.
- **Cloudflare Global API Key: DECISION CONSCIENTE (no es deuda tecnica)**.
  Se mantiene a proposito en el server para poder operar CUALQUIER proyecto/dominio
  de la cuenta desde este server sin crear/rotar tokens individuales. Reglas:
  nunca commitear ni pegar en chats/logs, permisos 600, rotar si se filtra.
  Documentado en `CONTEXTO_PROYECTO.md` (seccion nueva "Credenciales del server")
  y en `SERVER_CHEATSHEET.md`.
- **Gotcha nuevo documentado (cheatsheet #15)**: `Set-Content` de PowerShell 5.1
  escribe en Windows-1252 y rompe emojis/acentos al editar `.md`. Usar
  `[System.IO.File]::WriteAllText($path, $text, (New-Object System.Text.UTF8Encoding($false)))`.
### 2026-10-11 (cont. 4) - Flutter deps upgrade: secure_storage v11 + share_plus v13 + plantilla lanzamiento
- **Deuda tecnica #1 resuelta**: conflicto `win32` entre `flutter_secure_storage` y `share_plus`.
  Ahora ambos usan `win32 ^6.4.0`. Warning KGP de `share_plus` eliminado de paso.
- **`share_plus` 10.1.4 -> 13.3.1**:
  - Migracion de API: `Share.shareXFiles` -> `SharePlus.instance.share(ShareParams(...))`
    en las 2 llamadas del editor de promociones (descargar PNG + compartir PNG).
  - Se paso por 11.1.0 intermedio por conflicto con secure_storage 9.x.
- **`flutter_secure_storage` 9.2.2 -> 11.2.0**:
  - Migracion en 2 fases (9 -> 10.3.4 -> 11.2.0) para preservar los datos.
  - v10 migra el cifrado automaticamente; el log confirma:
    `Migration complete: 3 items migrated from EncryptedSharedPreferences to custom cipher storage`.
  - v11 elimina `encryptedSharedPreferences` de AndroidOptions (ya removido).
  - **JWT preservado sin re-login** (verificado: `auth/me 200` directo).
- **Plantilla `lanzamiento` nueva** en modulo promocion:
  - Backend: `render_lanzamiento` con hero diagonal (verde -> morado) + caja info
    con gradiente horizontal (verde claro -> blanco). Usa `svg_service.gradiente_linear`
    (helper que estaba sin uso).
  - Frontend: case visual en la galeria (icono cohete, fondo morado).
  - Validado end-to-end en emulador Android 14: SVG 3193 chars, PNG 200KB,
    cero warnings de flutter_svg.
- **Warning `<defs/>` flutter_svg**: descartado. No aplicaba - ninguna plantilla
  emitia `<defs>` antes. La nueva `lanzamiento` si lo hace, y **flutter_svg lo renderiza
  sin warnings** siempre que `<defs>` vaya antes de las formas.
- 5 commits nuevos en `origin/main` (116ac45 -> 1cd9036). Working tree limpio.
### 2026-10-11 - Modulo promocion Etapa 9: generador de afiches SVG (completo)
- Modulo backend/app/modules/promocion/ completo:
  - brand_kit.py: paleta Baqueano, fuentes web-safe, baseline grid, 5 tamanos industria
  - svg_service.py: helpers puros (canvas, texto, formas, gradientes). svgwrite escapa XML
  - templates.py: 5 plantillas ricas (nuevo_servicio, oferta, destacado, evento, profesional)
  - services.py: validacion anti-abuso (30 params, 2000 chars, 200KB SVG)
  - routes.py: 3 endpoints admin (plantillas, generar JSON, generar-svg directo)
  - 16 tests - 140 verdes totales
- Frontend Flutter (flavor admin):
  - domain/afiche.dart: modelos + TamanoAfiche enum
  - data/promocion_repository.dart + providers con editor state
  - Galeria: grid de 5 plantillas con preview visual
  - Editor con preview SVG en vivo (flutter_svg), debounce 400ms
  - Card nueva en AdminHome + 2 rutas (/admin/promocion + /editor/:id)
  - flutter_svg 2.3.0 agregado
- Etapa 9 completa. Modulo social cerrado: 9/9 etapas

### 2026-10-11 - Modulo social Etapa 8: Google Business Profile (codigo listo, gateado)
- Backend completo para publicar en GBP, esperando aprobacion de la API de Google:
  - google_business_service.py: cliente REST con httpx (sin SDK de Google).
    publicar_post_en_gbp() respeta el feature flag GOOGLE_BUSINESS_ENABLED.
  - 5 vars en Settings: GOOGLE_BUSINESS_ENABLED (default false), ACCOUNT_NAME,
    CLIENT_ID, CLIENT_SECRET, API_VERSION
  - services.obtener_google_business_ids_de_cuenta: resuelve account_name +
    location_id desde metadata_extra (cache) o fallback a settings
  - worker dispatch: GOOGLE_BUSINESS -> _publicar_en_google()
  - eventos_prestadores: al aprobar prestador o agregar servicio, encola
    tambien GBP si config.publicar_en_google=true
  - 10 tests nuevos (8 google_business_service + 2 worker) - 124 verdes totales
- Cuando Google apruebe la API, activar es solo:
  1. GOOGLE_BUSINESS_ENABLED=true en .env
  2. Cargar credenciales OAuth + account_name + location_id
  3. ConfigSocial.publicar_en_google=true en la DB

### 2026-10-11 - Modulo social Etapa 7: frontend propietario + endpoint reencolar
- Backend:
  - services.reencolar_publicacion: resetea estado a PENDIENTE, limpia
    intentos + error. Rechaza (409) si esta en PUBLICANDO.
  - PATCH /admin/social/publicaciones/{id}/reencolar
  - services.listar_publicaciones_de_prestador: publicaciones del prestador
    + publicaciones de sus servicios
  - GET /api/v1/mis-prestadores/{id}/publicaciones (dueno o admin)
- Frontend Flutter:
  - Boton Reencolar en las cards de la cola (solo estados fallado/agotado)
  - Pantalla MisPublicacionesScreen (read-only, vista del dueno)
  - Boton 'Publicaciones en redes' en DetalleMiPrestadorScreen
  - Ruta /mis-prestadores/:id/publicaciones
- 5 archivos backend + 5 archivos Flutter modificados/creados

### 2026-10-10 (cont. 7) - Frontend admin del modulo social (Etapa 6)
- 3 pantallas nuevas en el flavor admin (Flutter):
  - Redes sociales: lista cuentas conectadas (FB + IG) con badges por red,
    propietario, activa/manual
  - Configuracion: toggles auto-publish + FB/IG, radios de destino,
    boton "Procesar cola ahora"
  - Cola de publicaciones: filtros por estado + red, cards con preview,
    intentos, error, proximo intento, empty state
- Feature completa en Flutter:
  - domain/cuenta_social.dart + domain/publicacion_social.dart
  - data/social_repository.dart (listarCuentas, obtenerConfig,
    actualizarConfig, listarPublicaciones, procesarColaAhora)
  - data/social_providers.dart (5 providers)
  - 3 screens en presentation/screens/
- AdminHome: 3 cards nuevas (Redes sociales, Configuracion, Cola)
- 3 rutas nuevas: /admin/social/cuentas, /admin/social/config,
  /admin/social/publicaciones
- 7 archivos nuevos/modificados en Flutter (1800+ lineas)
- Backend fix: endpoint GET /publicaciones ignoraba query param red.
  Se agrego red: Red | None en routes + services (5 lineas)
- Verificado en emulador Android 14 end-to-end: filtros funcionando con
  los 3 posts reales de los smoke tests previos

### 2026-10-10 (cont. 6) - Modulo social Etapa 5: integracion con prestadores
- eventos_prestadores.py: al aprobar prestador o agregar servicio, encola
  publicaciones en FB + IG automaticamente:
  - encolar_prestador_nuevo(db, prestador)
  - encolar_servicio_nuevo(db, prestador, servicio)
- Respeta config_social: auto_publish + publicar_en_facebook/instagram
- Best-effort: nunca rompe el flujo del caller
- IG skip si no hay imagen (requisito Meta)
- Solo publica en la cuenta central de Baqueano
- config.py: PUBLIC_WEB_URL para links de los posts
- prestadores/routes.py: wire en admin_verificar_prestador + agregar_servicio
- 7 tests nuevos - 114 verdes totales
- Smoke test end-to-end: "Taller Mecanico del Sur" (sin fotos) -> pub FB ok

### 2026-10-10 (cont. 5) - Modulo social Etapa 4: Instagram via Facebook
- instagram_service.py: publicar_post_en_instagram con flujo de 2 pasos:
  - POST /{ig-user-id}/media (crear container)
  - POST /{ig-user-id}/media_publish (publicar)
  - Reintentos cortos (2s/4s/8s) para container asincronico
- services.obtener_instagram_id_de_cuenta: busca IG ID en metadata_extra
  (cache), si no esta lo consulta a Meta y lo guarda
- worker: dispatch por red (FACEBOOK | INSTAGRAM)
  - _publicar_en_instagram exige image_url (IG no acepta solo texto)
- 9 tests nuevos (7 instagram_service + 2 worker) - 107 verdes totales
- Smoke test end-to-end: post real publicado en @baqueanonatales
  (external_post_id=18131824649504757)

### 2026-10-10 (cont. 4) - Modulo social Etapa 3: worker de publicacion
- Worker in-process con APScheduler que procesa la cola publicaciones_sociales cada 30s:
  - facebook_service.publicar_post_en_pagina: POST a /feed (texto) o /photos (con imagen)
  - services: 5 funciones del worker (obtener pendientes, token vigente, marcar publicando/publicada/fallada)
  - Backoff exponencial: 1min -> 5min -> 30min -> 2h -> AGOTADO (5 intentos max)
  - worker.py: procesar_cola + start/stop + ejecutar_ciclo_manual (acepta db opcional)
  - Endpoint admin POST /publicaciones/procesar-ahora
  - main.py lifespan: arranca/detiene el scheduler automaticamente
  - config: SOCIAL_WORKER_ENABLED + SOCIAL_WORKER_INTERVAL_SEC
  - apscheduler==3.10.4 en requirements
  - 12 tests nuevos (6 publicar_post + 6 worker) - 98 verdes totales
- Smoke test end-to-end: post real publicado en la pagina Baqueano Natales
  (external_post_id=1319567627902106_122120360697479454)
- Aprendizaje: pip install manual se pierde al recrear el container -> siempre
  va primero a requirements.txt + docker compose build

### 2026-10-10 (cont. 3) - Modulo social Etapa 2: OAuth Facebook completo
- Backend OAuth Facebook end-to-end funcionando en produccion:
  - oauth_state.py - JWT firmados (state CSRF + token_ref stateless)
  - facebook_service.py - cliente Graph API v26.0 con httpx async
  - 4 endpoints admin: GET /facebook/oauth/url, GET /facebook/oauth/callback (sin auth, el state firmado prueba identidad), POST /facebook/pages, POST /facebook/conectar
  - 5 vars en Settings: FACEBOOK_APP_ID, FACEBOOK_APP_SECRET, FACEBOOK_OAUTH_REDIRECT_URI, FACEBOOK_GRAPH_API_VERSION, FACEBOOK_OAUTH_SCOPES
  - 6 schemas Pydantic para OAuth
  - 21 tests nuevos (7 oauth_state + 14 facebook_service) - 86 tests verdes en total
  - respx==0.22.0 en requirements para mockear httpx
- Infra HTTPS para OAuth (Facebook exige HTTPS en redirect URI):
  - Subdominio dev-api.baqueanonatales.com proxied por Cloudflare
  - SSL mode: full -> self-signed alcanza
  - deploy/nginx/conf.d/dev-api.conf (server block nuevo)
  - deploy/nginx/certs/ (self-signed 10 anos, fuera del repo via .gitignore)
  - docker-compose.yml monta los certs en /etc/nginx/certs:ro
- Smoke test end-to-end exitoso en produccion:
  - Admin autorizo la app en Facebook (flujo OAuth real)
  - Backend recibio callback HTTPS en dev-api.baqueanonatales.com
  - Intercambio code -> short token -> long token (60 dias)
  - Cifro el page token con Fernet
  - Listo las 3 paginas del usuario
  - Conecto "Baqueano Natales" (external_id=1319567627902106) como cuenta central
  - Verificado en DB: cuentas_sociales + tokens_sociales con access_token = enc:gAAAAAB... (cifrado, nunca en claro)
- Gotchas descubiertos (documentar en futuro docs/SERVER_CHEATSHEET.md):
  - PowerShell -> SSH manda CRLF -> tail -20, head -c 300, wc -l fallan. Fix: replace + bash -s.
  - Heredoc anidado dentro de SSH falla por CRLF en el marcador. Fix: Python via stdin directo.
  - JWT del backend requiere claim iss: "baqueano-natales" - usar core.security.create_access_token() en vez de armar el payload a mano.
  - pip install manual en el container falla con Permission denied -> usar docker compose exec -T -u root backend pip install ...
  - El backend aborta en produccion si falta TOKEN_ENCRYPTION_KEY - comportamiento intencional del modulo crypto.

### 2026-10-10 (cont. 2) — Módulo social Etapa 1 (esqueleto) + Infra de tests
- ✅ **Módulo `social/` completo (Etapa 1: esqueleto)** — base para publicar en Facebook, Instagram y Google Business desde el admin:
  - **4 tablas**: `cuentas_sociales`, `tokens_sociales`, `publicaciones_sociales`, `config_social`
  - **4 enums de Postgres**: `red_social`, `propietario_tipo_social`, `destino_publicacion`, `estado_publicacion`
  - **Multi-tenant** vía `(propietario_tipo, propietario_id)`: cuenta central (Baqueano), por prestador, o por comercio
  - **Índice único parcial** con `NULLS NOT DISTINCT` para garantizar UNA sola config global
  - **Tokens cifrados** con Fernet (`app/core/crypto.py` + `TOKEN_ENCRYPTION_KEY` en `.env`)
- ✅ **Backend del módulo** (arquitectura modular, alineada con `prestadores/`):
  - `models.py` — 4 tablas + 4 enums + `TimestampMixin` / `SoftDeleteMixin`
  - `schemas.py` — 11 clases Pydantic
  - `deps.py` — `AdminUser`, `CurrentUser`, `CuentaDelPropietario`
  - `services.py` — 14 funciones async (CRUD de cuentas, tokens, config, publicaciones)
  - `routes.py` — router admin con 10 endpoints
  - `README.md` — doc del módulo + roadmap de 9 etapas
- ✅ **Crypto transversal** (`app/core/crypto.py`):
  - Fernet (AES-128 + HMAC-SHA256)
  - Fallback a texto plano en dev, **aborta en producción** si falta la clave
  - `TOKEN_ENCRYPTION_KEY` agregada a `Settings` + `.env` del server
- ✅ **Infraestructura de tests** (primera vez en el proyecto):
  - `backend/pytest.ini` + `backend/tests/conftest.py`
  - Tests con DB corren contra `baqueano_test` (DB separada, no toca producción)
  - **65 tests** en total (29 unit + 36 con DB)
  - `drop_all + create_all` al inicio de cada sesión para que el schema de test siempre refleje el código
- 🐛 **Fixes de infraestructura Docker**:
  - Montar `alembic/` + `alembic.ini` en el container (los archivos se quedaban "atrapados" dentro de la imagen)
  - Montar `tests/` + `pytest.ini` en el container
  - Estos fixes son **estructurales**: a partir de ahora las migraciones y tests nuevos se ven sin rebuild
- 🐛 **Fix alembic autogenerate**: detecta `server_default` falsos en `usuarios.*` en cada `--autogenerate`. Hay que removerlos a mano de cada migración (documentado en los docstrings de las migraciones del módulo social).
- 🐛 **Fix índice único**: en Postgres, `UNIQUE(a, b)` **no** bloquea duplicados cuando uno es NULL. Se agregó `NULLS NOT DISTINCT` (Postgres 15+) al índice parcial de config global.

### 2026-10-10 (cont.) — Editor de horarios de comercios
- ✅ **`EditorHorariosScreen`** para dueños:
  - Configuración de los 7 días con **multi-franja** (horario partido: 12-15 + 19-23)
  - Time picker nativo por franja
  - Toggle "Abierto/Cerrado" por día
  - Botón "Agregar franja" (para horario partido)
  - Botón "Copiar a todos los días" (útil para configurar rápido)
  - Validación: si está abierto, requiere abre y cierra
- ✅ **Integración en el detalle del comercio**:
  - Link "Gestionar" junto al título "Horarios"
  - Botón "Gestionar horarios" en la zona de acciones
- ✅ **Ruta** `/mis-comercios/:id/horarios` en el router
- ✅ **Verificado end-to-end** en emulador: `PUT /mis-comercios/{id}/horarios → 200`
- 🎉 **Módulo comercios 100% cerrado** (cliente + dueño + admin)

### 2026-10-10 — Admin de Comercios + Fix crítico del diálogo
- ✅ **Admin de comercios completo** (paralelo al de prestadores):
  - `AdminComerciosScreen`: listado con filtros por estado (Pendientes/Verificados/Rechazados/Suspendidos/Borradores)
  - `AdminDetalleComercioScreen`: verificar/rechazar/suspender/destacar
  - `AdminCategoriasComercioScreen`: CRUD completo de categorías con vista previa
  - Integración en AdminHome con badge de pendientes
- ✅ **3 rutas nuevas** en el router: `/admin/comercios`, `/admin/comercios/:id`, `/admin/categorias-comercio`
- ✅ **Provider** `adminComercioDetalleProvider` agregado
- 🐛 **Fix crítico**: el diálogo de motivo (rechazar/suspender) ahora usa `StatefulWidget`
  con `dispose()` correcto. Antes crasheaba con `TextEditingController was used after being disposed`
- ✅ **Verificado en emulador** end-to-end (suspender / re-verificar / destacar)

### 2026-10-09 (cont.) — Panel admin operativo (flavor admin)
- ✅ **Panel de administración** en flavor `admin` con Home diferenciado:
  - Sección **Gestión**: Prestadores (con badge de pendientes), Comercios (próx.), Usuarios (próx.)
  - Sección **Configuración**: Categorías de oficio (CRUD), Categorías de comercio (próx.)
  - Sección **Análisis**: Estadísticas globales (próx.)
- ✅ **Gestión de prestadores** (admin):
  - Listado con filtros por estado (Pendientes/Verificados/Rechazados/Suspendidos/Borradores)
  - Detalle con acciones: Verificar / Rechazar / Suspender / Destacar
  - Diálogos con motivo para rechazo/suspensión
- ✅ **CRUD de categorías de oficio** (admin):
  - Listar todas (activas + inactivas) con toggle activa/inactiva
  - Crear/editar con modal bottom sheet (nombre, slug auto, descripción, ícono, color, orden)
  - Vista previa en vivo
- ✅ **Router detecta `AppConfig.appType`**:
  - Flavor `admin` → arranca en `/admin/home` (panel morado)
  - Flavor `client` → arranca en `/home` (Home normal)
- ✅ **Verificado end-to-end** en emulador:
  - Login con Google en flavor admin → 200
  - `GET /admin/prestadores?estado=pendiente` → 200

### 2026-10-09 (cont.) — Prestadores: formulario + editor de servicios
- ✅ **Formulario real de crear/editar prestador** (dueño):
  - Información básica: nombre, categoría (dropdown con 11 categorías), descripción, años experiencia
  - Contacto: teléfono, WhatsApp, mensaje pre-armado, email, sitio web
  - Ubicación: dirección
  - Modalidad: 3 switches (domicilio/local/emergencias) + horario
  - Especialidades: chips dinámicos (agregar/eliminar)
  - Redes sociales: Instagram, Facebook, TikTok, YouTube
- ✅ **Editor de servicios real** (dueño):
  - Listado con precios, duración, garantía
  - Modal bottom sheet para agregar/editar
  - Categorías sugeridas: Mantenimiento, Frenos, Motor, Suspensión, Eléctrico, Emergencias, Instalaciones, Reparaciones
  - Eliminar con confirmación
- ✅ **Flujo CRUD completo verificado** end-to-end en emulador:
  - POST/GET/PATCH/DELETE a `/mis-prestadores` y `/mis-prestadores/{id}/servicios`

### 2026-10-09 (cont.) — Prestadores: pantallas dueño + entorno dev optimizado
- ✅ **Pantallas dueño de prestadores**:
  - `MisPrestadoresScreen` (listado con estados + rechazo visible)
  - `DetalleMiPrestadorScreen` (con acciones: enviar a revisión, editar, gestionar servicios, eliminar)
  - `FormularioPrestadorScreen` (placeholder — próxima iteración)
  - `EditorServiciosScreen` (placeholder — próxima iteración)
- ✅ 5 rutas nuevas integradas en `app_router.dart`
- ✅ Home actualizado con card **"Mis oficios"** en sección "Mi actividad"
- ✅ **Entorno de desarrollo optimizado**:
  - Emulador migrado de Android 17 → **Android 14** (estable)
  - GPU cambiada de `swiftshader_indirect` → **`host`** (1.200x más rápido)
  - RAM del AVD subida de 2 GB → **4 GB**
  - Frame time promedio: de **36.000 ms** a **28 ms**
- ✅ **Deep links seguros**: `canLaunchUrl` + fallback SnackBar (ya no crashea sin WhatsApp)

### 2026-10-09 — Módulo prestadores v2 (servicios + perfil industrial)
- ✅ **Backend v2 completo**:
  - Tabla nueva `prestador_servicios` (catálogo con precios/duración/garantía)
  - 4 columnas nuevas en `prestadores`: `anios_experiencia`, `whatsapp_mensaje`, `foto_portada_url`, `redes_sociales` (JSONB)
  - 4 endpoints nuevos: `PUT/POST/PATCH/DELETE /mis-prestadores/{id}/servicios`
  - 64 rutas totales en la API
- ✅ **Prestador modelo cargado en producción**: "Taller Mecánico del Sur"
  - 15 años experiencia, 12 servicios, 7 especialidades, 3 redes sociales
- ✅ **Frontend v2 completo**:
  - Modelo `PrestadorServicio` (Dart)
  - Modelo `Prestador` extendido con campos v2
  - `PrestadorRepository` con métodos de catálogo
  - **`DetallePrestadorScreen` industrial**: banner + avatar overlap, servicios agrupados con precios, redes sociales clickeables, FAB de WhatsApp
  - Deep links seguros con `canLaunchUrl` + fallback SnackBar (evita crashes)
- ✅ `url_launcher ^6.3.1` agregado

### 2026-10-09 — Módulo prestadores: backend completo
- ✅ **Backend completo** del módulo `prestadores` (schemas, services, deps, routers, seed)
- ✅ **4 routers registrados**: público, dueño, admin categorías, admin prestadores
- ✅ **11 categorías base** seedeadas en producción (mecánica, electricidad, gasfitería, etc.)
- ✅ **20 endpoints nuevos** respondiendo (`/prestadores`, `/mis-prestadores`, `/admin/categorias-oficio`, `/admin/prestadores`)
- ✅ Verificado end-to-end con `curl` en producción
- ⏳ Pendiente: frontend Flutter del módulo prestadores

### 2026-10-08 (cont.) — Módulo prestadores: modelos + migración
- ✅ **Capa reutilizable**: `core/mixins.py` (Timestamp + SoftDelete) + `shared/utils/slug.py` (slug único genérico)
- ✅ **Modelos `prestadores`**: `CategoriaOficio`, `Prestador`, `FotoTrabajo`
- ✅ **Migración aplicada** en producción (`ca0aef61fba0`)
- ✅ **3 tablas nuevas** en la DB (`categorias_oficio`, `prestadores`, `fotos_trabajo`)
- 🎯 **Pivote estratégico**: empezamos por **Oficios (mecánica primero)**, después Movilidad
- 📌 Decisiones arquitectónicas documentadas en `docs/VISION.md` y `docs/ARCHITECTURE.md`

### 2026-10-08 (cont.) — Documentación fundacional
- ✅ **`docs/VISION.md`** creado: visión de superapp multi-vertical, principios de arquitectura
- ✅ **`docs/ARCHITECTURE.md`** reescrito: monolito modular, transversal vs vertical, cómo agregar un módulo
- ✅ **`docs/LEGACY_ANALYSIS.md`** creado: análisis del sistema anterior (4 actores, 4 ejes de verificación, zonas por cuadrícula, sistema tarifario)
- 🎯 **Pivote estratégico**: empezamos por **Oficios (mecánica de autos)**, después Movilidad, después el resto
- 📌 Decisión: **monolito modular** ahora, microservicios solo cuando haga falta

### 2026-10-08 — Fix login con Google (end-to-end)
- ✅ **Login con Google funcional end-to-end** (Google → Firebase → Backend → JWT → Home)
- ✅ **Persistencia de sesión funcional** (sobrevive al cierre de la app)
- 🔧 Migración de `google_sign_in` **v7 → v6** (v7 tenía bug conocido con Credential Manager)
- 🔧 Agregado `serverClientId` al constructor de `GoogleSignIn` (obligatorio para `idToken` en Android)
- 🔧 Deshabilitado Credential Manager vía `meta-data` en AndroidManifest
- 🔧 Agregado `network_security_config.xml` para permitir HTTP en dev
- 🔧 Cambio de `https://` a `http://` en `AppConfig.dev` (server no tiene SSL aún)
- ⚠️ **SHA-1 de debug cambió** (ver sección Firebase)
- ✅ **App admin verificada** (login + persistencia funcional en `flutter run --flavor admin`)

### 2026-10-08 (cont.) — Módulo comercios (backend)
- ✅ **Nuevo módulo `comercios`** con 3 tablas (categorias_comercio, comercios, horarios_comercio)
- ✅ Migración Alembic aplicada en producción (`d6654af1dbf2`)
- ✅ 20 endpoints nuevos (público, propietario, admin)
- ✅ 9 categorías base seedeadas en la DB
- ✅ Endpoint público `/api/v1/comercios/categorias` funcionando
- ⏳ Pendiente: frontend Flutter del módulo

### 2026-10-08 (cont.) — Fixes críticos y migración de emulador
- ✅ **Fix `DioClient.validateStatus`**: 4xx ahora se mapean a `ApiException` (antes intentaban parsear el body como modelo)
- ✅ **`Comercio.fromJson` defensivo**: parseo robusto con logging de campos null
- ✅ **Migración de emulador Android 17 → Android 14** (`Pixel6_API34`)
  - Motivo: Android 17 (API 37) tiene bugs sin resolver de IME (teclado virtual no se despliega) y OpenGL (crash con `swiftshader_indirect`)
  - Android 14 funciona perfecto: teclado físico Y virtual OK
- 📌 Tip de emulador: usar `-gpu swiftshader_indirect` en el launch

### 2026-10-08 (cont.) — Frontend comercios (cliente)
- ✅ Modelos Dart: `Categoria`, `Horario`, `Comercio` (+ enum `EstadoComercio`)
- ✅ Repositorio `ComercioRepository` con 20+ métodos (público, dueño, admin)
- ✅ Providers Riverpod (categorías, listado con filtros, detalle, admin)
- ✅ Widget `ComercioCard` reutilizable
- ✅ Pantalla lista de comercios (búsqueda + chips categorías + filtros destacados/delivery)
- ✅ Pantalla detalle (portada, logo, contacto, ubicación, horarios multi-franja)
- ✅ Router corregido (permite rutas autenticadas fuera de `/home`)
- ✅ Home linkeado a Comercios
- ✅ **Flujo end-to-end verificado en emulador** con comercio de prueba
- ⏳ Pendiente: pantallas dueño (mis comercios, crear/editar, horarios)
- ⏳ Pendiente: pantallas admin (verificar/rechazar, CRUD categorías)

### 2026-10-08 (cont.) — App admin verificada
- ✅ Login con Google funcional en flavor admin
- ✅ Home admin con tema morado + badge ADMIN
- ✅ SHA-1 nuevo registrado en Firebase para `cl.baqueanonatales.admin`

---

## 📌 Resumen ejecutivo

**Baqueano Natales** es una superapp regional para Puerto Natales, Chile (movilidad, delivery, comercio local). Actualmente en desarrollo activo con backend desplegado y app Flutter con login funcional completo.

**Estado actual:**
- ✅ Backend desplegado en producción (server nuevo)
- ✅ 5 módulos backend completos (auth, usuarios, admin, comercios, prestadores)
- Modulo social (Etapas 1-6) - OAuth FB + worker + IG + integracion prestadores + frontend admin, 114 tests
- ✅ **Infraestructura de tests** (pytest + DB de test aislada)
- ✅ 3 módulos backend completos (auth, usuarios, admin)
- ✅ App Flutter con flavors (client + admin)
- ✅ Login con Google funcional **end-to-end**
- ✅ Persistencia de sesión funcional
- ✅ App admin verificada (login + Home con badge ADMIN)
- ✅ **Backend módulo comercios** (modelos, migración, endpoints, seed)
- ⏳ Pendiente: frontend Flutter del módulo comercios
- ⏳ Pendiente: features core restantes (mapa, delivery, carta QR, recompensas)

---

## 🖥️ Servidores

### Server nuevo (producción activa)
| Item | Valor |
|---|---|
| **Hostname** | `baqueano-natales-prod` |
| **IP pública** | `104.129.59.151` |
| **Proveedor** | RackNerd |
| **Panel** | `ctrl.racknerd.com` |
| **OS** | Ubuntu 24.04.5 LTS |
| **Hardware** | 3 vCPU / 4 GB RAM / 60 GB disco |
| **Acceso** | `ssh deploy@104.129.59.151` (clave SSH) |
| **Usuario** | `deploy` (sudo configurado) |

**Puertos abiertos (UFW):** 22 (SSH), 80 (HTTP), 443 (HTTPS).

**Subdominios (Cloudflare, proxied):**
| Subdominio | Apunta a | Uso |
|---|---|---|
| `api.baqueanonatales.com` | Server viejo (`161.118.240.229`) | Producci?n actual (a migrar en Fase 6) |
| `dev-api.baqueanonatales.com` | **Server nuevo** (`104.129.59.151`) | Dev + OAuth Facebook (SSL mode: full) |

**Estado actual del server:**
- ✅ HTTP (puerto 80) responde OK: `curl http://104.129.59.151/health` → `{"status":"ok"}`
- ❌ HTTPS (puerto 443) **no configurado** (Let's Encrypt es Fase 6)

**Servicios corriendo (Docker):**
- `baqueano_backend` — FastAPI en `127.0.0.1:8000`
- `baqueano_db` — PostgreSQL 16 en `127.0.0.1:5432`
- `baqueano_nginx` — Reverse proxy en `0.0.0.0:80,443`

**Path del proyecto:** `/home/deploy/baqueano-natales/`

### 🔐 Credenciales del server (decisiones conscientes)

**Cloudflare Global API Key** — se mantiene **a propósito** en el server
(`~/.cf-env` + `~/.bashrc`) para poder operar CUALQUIER proyecto/dominio
de la cuenta Cloudflare desde este server, sin crear/rotar tokens por
proyecto. **No es deuda técnica.** Reglas: nunca commitear, nunca pegar
en chats/logs, permisos 600, y si se filtra → rotar YA + auditar en
Cloudflare.

### Server viejo (a decommissionar)
| Item | Valor |
|---|---|
| **Hostname** | `superapp-natales-backend` |
| **IP pública** | `161.118.240.229` |
| **IP privada** | `10.0.0.236` |
| **Proveedor** | Oracle Cloud |
| **OS** | Ubuntu 22.04.5 LTS |
| **Acceso** | `ssh ubuntu@161.118.240.229` |

**Estado:** corriendo el sistema viejo. **Será apagado** cuando la migración esté completa y validada.

---

## 📦 Repositorios GitHub

**Cuenta:** `victorneyraars`

| Repo | Descripción | Estado |
|---|---|---|
| `baqueano-natales` | Monorepo (backend + flutter + deploy + docs) | ✅ Activo |
| `baqueano-natales-legacy` | Repo viejo (build 400 del 24 agosto) | 📦 Archivado |
| `rnstp-service` | Microservicio RNSTP | ⏳ Vacío (a poblar) |
| `studiodigital360` | Otro proyecto (Next.js) | ✅ |
| `sealquilamarido-web` | Otro proyecto (Astro en Vercel) | ✅ |

**Rama principal:** `main`.

---

## 🏗️ Stack del backend

### Tecnologías
| Capa | Tecnología | Versión |
|---|---|---|
| **Lenguaje** | Python | 3.12 |
| **Framework** | FastAPI | 0.115.6 |
| **ORM** | SQLAlchemy | 2.0.36 (async) |
| **Migraciones** | Alembic | 1.14.0 |
| **BD** | PostgreSQL | 16 (contenedor) |
| **Driver async** | asyncpg | 0.30.0 |
| **Driver sync** | psycopg2-binary | 2.9.10 |
| **Validación** | Pydantic | 2.10.4 |
| **Firebase** | firebase-admin | 6.6.0 |
| **HTTP client** | httpx | 0.28.1 |
| **Rate limiting** | slowapi | 0.1.9 |
| **Procesamiento imágenes** | Pillow | 11.0.0 |
| **Validación archivos** | filetype | 1.2.0 |
| **Contenedores** | Docker | 29.8.2 |
| **Orquestación** | Docker Compose | 5.6.0 |
| **Reverse proxy** | Nginx | 1.27 (alpine) |

### Estructura del proyecto
```
backend/
├── app/
│   ├── core/                    # Configuración transversal
│   │   ├── config.py            # Pydantic Settings
│   │   ├── db.py                # SQLAlchemy async
│   │   ├── firebase.py          # Firebase Admin SDK
│   │   ├── logging.py           # Logs JSON
│   │   └── security.py          # JWT propio
│   ├── modules/                 # Por dominio de negocio
│   │   ├── auth/
│   │   │   ├── models.py        # Usuario + RolUsuario (enum)
│   │   │   ├── schemas.py
│   │   │   ├── deps.py          # get_current_user, require_admin
│   │   │   ├── services.py      # login con Google
│   │   │   └── routes.py
│   │   ├── usuarios/
│   │   │   ├── schemas.py
│   │   │   ├── services.py
│   │   │   └── routes.py
│   │   └── admin/
│   │       ├── schemas.py
│   │       ├── services.py
│   │       ├── routes.py
│   │       └── seed.py          # Promover admin
│   ├── shared/
│   │   └── storage/
│   │       ├── base.py          # Interfaz AvatarStorage (ABC)
│   │       └── local.py         # Implementación local
│   └── main.py
├── alembic/                     # Migraciones
├── secrets/                     # ⚠️ NO commitear
│   └── firebase-service-account.json
├── .dockerignore
├── .env.example
├── Dockerfile
└── requirements.txt
```

### Modelo de datos (actual)

**Tabla `usuarios`:**
```
id (UUID, PK)
firebase_uid (varchar 128, unique, not null)
email (varchar 255, unique, nullable)
phone (varchar 20, unique, nullable)
nombre (varchar 100, nullable)
apellido (varchar 100, nullable)
avatar_url (varchar 500, nullable)
rol (enum: cliente, comercio, prestador, admin)
verificado (bool, default false)
activo (bool, default true)
tiene_google (bool, default false)
tiene_whatsapp (bool, default false)
tiene_sms (bool, default false)
created_at (timestamp tz)
updated_at (timestamp tz)
ultimo_login (timestamp tz, nullable)

Índices: email, phone, firebase_uid, rol
```

### Endpoints activos

**Sistema:**
- `GET /health`
- `GET /`

**Auth:**
- `POST /api/v1/auth/google` — Login con Google (recibe id_token de Firebase)
- `GET /api/v1/auth/me` — Datos del usuario autenticado

**Usuarios:**
- `GET /api/v1/usuarios/me` — Perfil completo
- `PATCH /api/v1/usuarios/me` — Editar nombre/apellido
- `POST /api/v1/usuarios/me/avatar` — Subir avatar (multipart)
- `DELETE /api/v1/usuarios/me` — Desactivar cuenta (soft delete)
- `GET /api/v1/usuarios/{id}` — Perfil público

**Admin (requieren rol admin):**
- `GET /api/v1/admin/usuarios` — Listar con filtros + paginación
- `GET /api/v1/admin/usuarios/{id}` — Detalle
- `PATCH /api/v1/admin/usuarios/{id}/rol` — Cambiar rol
- `PATCH /api/v1/admin/usuarios/{id}/verificar` — Verificar/desverificar
- `PATCH /api/v1/admin/usuarios/{id}/reactivar` — Reactivar
- `DELETE /api/v1/admin/usuarios/{id}` — Desactivar
- `GET /api/v1/admin/estadisticas` — Métricas globales

---

## 📱 Stack de Flutter (PC Windows)

### Entorno de desarrollo
| Item | Valor |
|---|---|
| **Flutter SDK** | 3.47.6 (stable) |
| **Dart** | 3.13.5 |
| **DevTools** | 2.60.0 |
| **Flutter path** | `D:\dev\flutter` |
| **Android Studio** | 2026.2.1 Rabbit |
| **Android SDK** | API 37, build-tools 36.0.0 |
| **NDK** | 28.2.13676358 |
| **JDK** | 25 (bundled con Android Studio) |
| **VS Code** | 1.140.0 + extensión Flutter |
| **Emulador** | `Pixel6_API34` (Android 14 — RECOMENDADO) |
| **Emulador viejo** | `Pixel6_API37` (Android 17 — deprecado, tiene bugs de IME/GPU) |
| **PUB_CACHE** | `D:\DartCache` |

### Configuración crítica del PC
**Variable de entorno (User):**
```
PUB_CACHE=D:\DartCache
```

**`android/gradle.properties`:**
```
org.gradle.jvmargs=-Xmx8G -XX:MaxMetaspaceSize=4G -XX:ReservedCodeCacheSize=512m -XX:+HeapDumpOnOutOfMemoryError
android.useAndroidX=true
android.newDsl=false
android.builtInKotlin=false
kotlin.incremental=false
org.gradle.daemon=false
org.gradle.parallel=false
```

**Razón:** evitar el error de Kotlin daemon "different roots" entre `D:\` (proyecto) y `C:\` (pub-cache original). Trade-off: builds más lentos pero estables.

### Estructura del proyecto Flutter
```
flutter/
├── lib/
│   ├── main_client.dart             # Entry point cliente
│   ├── main_admin.dart              # Entry point admin
│   ├── core/
│   │   ├── config/
│   │   │   └── app_config.dart      # AppConfig + enum AppType/Environment
│   │   ├── network/
│   │   │   ├── api_exceptions.dart  # ApiException + variantes
│   │   │   └── dio_client.dart      # Dio con interceptores JWT
│   │   ├── storage/
│   │   │   └── secure_storage.dart  # flutter_secure_storage wrapper
│   │   └── theme/
│   │       └── app_theme.dart       # Verde (client) / morado (admin)
│   ├── features/
│   │   ├── auth/
│   │   │   ├── domain/
│   │   │   │   └── user.dart        # Modelo User
│   │   │   ├── data/
│   │   │   │   ├── auth_repository.dart
│   │   │   │   └── auth_notifier.dart
│   │   │   └── presentation/
│   │   │       ├── splash_screen.dart
│   │   │       └── login_screen.dart
│   │   └── home/
│   │       └── presentation/
│   │           └── home_screen.dart
│   └── shared/
│       └── router/
│           └── app_router.dart      # GoRouter + auto-redirect
├── android/
│   ├── app/
│   │   ├── build.gradle.kts         # Flavors client + admin + deps Credential Manager
│   │   ├── google-services.json     # Firebase (SÍ va al repo)
│   │   └── src/main/
│   │       ├── AndroidManifest.xml  # Con meta-data + networkSecurityConfig
│   │       ├── kotlin/cl/baqueanonatales/
│   │       │   └── MainActivity.kt
│   │       └── res/xml/
│   │           └── network_security_config.xml  # Permite HTTP solo a 104.129.59.151
│   └── gradle.properties
├── ios/
├── pubspec.yaml
└── README.md
```

### Dependencias Flutter
```yaml
dependencies:
  flutter: sdk: flutter
  cupertino_icons: ^1.0.8
  firebase_core: ^3.8.0
  firebase_auth: ^5.3.3
  google_sign_in: ^6.2.0    # v6 (v7 tiene bug con Credential Manager)
  dio: ^5.7.0
  flutter_secure_storage: ^11.2.0
  go_router: ^14.6.2
  flutter_riverpod: ^2.6.1
  share_plus: ^13.3.1

dev_dependencies:
  flutter_test: sdk: flutter
  flutter_lints: ^5.0.0
```

**Notas sobre versiones resueltas:**
- `firebase_core: 3.15.2` (resolvió más nueva)
- `firebase_auth: 5.7.0` (resolvió más nueva)
- `google_sign_in: 6.3.0` (API v6, estable)
- `dio: 5.11.1`
- `flutter_riverpod: 2.6.1`
- `flutter_secure_storage: 11.2.0` (upgrade v9 -> v11 en 2 fases)
- `share_plus: 13.3.1` (upgrade v10 -> v13)

### ⚠️ Configuración nativa Android (CRÍTICA para login con Google)

**1. `android/app/build.gradle.kts` — bloque `dependencies` obligatorio:**
```kotlin
dependencies {
    // Credential Manager (requerido por google_sign_in v7)
    implementation("androidx.credentials:credentials:1.3.0")
    implementation("androidx.credentials:credentials-play-services-auth:1.3.0")
    implementation("com.google.android.libraries.identity.googleid:googleid:1.1.1")
}
```
> Nota: aunque usamos v6, estas deps se dejaron por si se migra a v7 en el futuro. No molestan.

**2. `AndroidManifest.xml` — dos elementos obligatorios:**
```xml
<application
    android:networkSecurityConfig="@xml/network_security_config"
    ...>
    <!-- Deshabilitar Credential Manager para forzar el flujo clásico -->
    <meta-data
        android:name="com.google.android.gms.credentials.API_ENABLED"
        android:value="false" />
</application>
```

**3. `res/xml/network_security_config.xml`:**
```xml
<?xml version="1.0" encoding="utf-8"?>
<network-security-config>
    <!-- Permitir HTTP sin cifrar SOLO para el server de desarrollo -->
    <domain-config cleartextTrafficPermitted="true">
        <domain includeSubdomains="true">104.129.59.151</domain>
    </domain-config>
</network-security-config>
```

**Razón:** Android 9+ bloquea HTTP en claro por defecto. Esta config permite HTTP **solo** al server de dev, manteniendo HTTPS como requerido para todo el resto.

### Arquitectura Flutter

**State management:** Riverpod 2.6.1 (StateNotifier + Provider).

**Navegación:** GoRouter 14.8.1 con auto-redirect según `authNotifierProvider`.

**HTTP:** Dio 5.11.1 con 2 interceptores:
1. **Request:** agrega `Authorization: Bearer <jwt>` si hay token guardado.
2. **Error:** mapea DioException a ApiException tipada.

**Storage:** `flutter_secure_storage` 11.2.0 con custom cipher storage (RSA OAEP + AES-GCM, Android Keystore). Nota: `encryptedSharedPreferences` fue deprecado en v10 y eliminado en v11.

**Config central:** `AppConfig` con `AppType` (client/admin) y `Environment` (dev/prod).

**API en dev:** `http://104.129.59.151` (HTTP, sin SSL — el server aún no tiene cert).
**API en prod:** `https://api.baqueanonatales.com` (cuando se haga el cutover DNS).

**AuthRepository — Google Sign-In v6:**
- `GoogleSignIn(scopes: [...], serverClientId: AppConfig.googleServerClientId)`
- `signIn()` → `GoogleSignInAccount`
- `googleUser.authentication` → `idToken` + `accessToken`
- **`serverClientId` es OBLIGATORIO** para obtener `idToken` en Android.

---

## 🔥 Firebase

### Proyecto Firebase
| Item | Valor |
|---|---|
| **Project ID** | `baqueano-natales-prod` |
| **Project Number** | `1072830106109` |
| **Plan** | Spark (gratuito) |

### Apps Android registradas
| Package | Rol | Client ID (Android) |
|---|---|---|
| `cl.baqueanonatales` | Cliente | `1072830106109-rb18p4oksc8607kr9c80i6mv92112kf5` (SHA-1 viejo) |
| `cl.baqueanonatales` | Cliente | `1072830106109-eh5i191lkg7d6185fr45c1difjvsqj66` (SHA-1 nuevo) |
| `cl.baqueanonatales.admin` | Admin | `1072830106109-0dao16e11pjkg0pnrnejpn3abumenfhv` (SHA-1 viejo) |

**Web Client ID (para serverClientId):**
```
1072830106109-c1b5cktisbj3khu8s9jmf7crn8ni0dh7.apps.googleusercontent.com
```

### ⚠️ Huellas SHA (CAMBIARON el 2026-10-08)

**SHA-1 de debug (ACTUAL):**
```
6E:0B:71:E0:63:01:E8:F7:CF:0E:3D:BC:1F:29:77:C8:D6:BE:63:3D
```

**SHA-256 de debug (ACTUAL):**
```
B2:A9:81:11:D4:55:81:B1:E8:5A:15:E7:6D:C1:5F:9E:20:0A:FE:72:FD:C5:EB:33:25:6E:97:82:B2:20:7C:BE
```

**SHA-1 viejo (ya no válido, pero registrado en Firebase):**
```
5C:1E:05:A3:10:92:65:4B:C7:7C:85:60:D7:F2:FB:6B:33:E0:B9:F5
```

**✅ Actualización 2026-10-08:** La app **`cl.baqueanonatales.admin`** ya tiene el SHA-1 nuevo registrado en Firebase. Se generó un client_id nuevo (`1072830106109-nv8q2jjt7kateq7cmqesg383entpu2sb`) que ya está en el `google-services.json` del repo.

**Nota:** El `debug.keystore` cambió (probablemente por reinstalación de Android Studio o cambio de PC). El SHA-1 viejo está en el doc antiguo y **ya no aplica**.

### Firebase Console
- URL: `https://console.firebase.google.com/project/baqueano-natales-prod`
- Authentication → Google habilitado
- OAuth consent screen: configurado (External, "Baqueano Natales")

### Service Account (backend)
- **Path en server:** `/home/deploy/baqueano-natales/backend/secrets/firebase-service-account.json`
- **Client email:** `firebase-adminsdk-fbsvc@baqueano-natales-prod.iam.gserviceaccount.com`
- **Mount en Docker:** `/app/secrets/firebase-service-account.json:ro`

---


## 🏪 Google Play Console

| Item | Valor |
|---|---|
| **URL** | https://play.google.com/console |
| **Login** | `victorneyraars@gmail.com` (cuenta Google) |
| **Developer account** | **Studio Digital 360** |
| **Tipo de cuenta** | Personal |
| **Account ID** | `5489050729101024675` |
| **URL directa** | https://play.google.com/console/u/0/developers/5489050729101024675 |

### Apps registradas (estado 2026-10-13)

| App | Package | Estado |
|---|---|---|
| PartFinder 360 | `com.studiodigital360.partfinder360` | Borrador / Prueba interna (últ. act. 2 oct 2026) |
| Baqueano Natales | `cl.baqueanonatales` | ⏳ Por crear |
| Baqueano Admin | `cl.baqueanonatales.admin` | ⏳ Por crear (solo internal testing) |

### Notas operativas

- **Cuenta con experiencia**: ya publicó `PartFinder 360`, lo que confirma que el workflow de Play Console funciona y se pasó el período de "closed testing de 14 días" que aplica a cuentas personales nuevas.
- **Play App Signing es obligatorio**: la upload key (`baqueano-release.jks`) firma el AAB; Google firma el APK final con su app signing key (RSA 4096).
- **Ubicación del SHA-1 del app signing key** (Google movió esto en 2026):
  - **Antes**: `Configuración → Integridad de la app → Firma de apps`
  - **Ahora**: `Protección con Play → Protección de Play Store → Gestionar la firma de apps de Play`
- **Firebase necesita el SHA-1 del app signing key de Google**, NO el de la upload key. El de la upload key (`89:A1:E9:...`) solo sirve para autenticar la subida.
- **Requirement nuevo 2026**: Google pide registrar package names de apps distribuidas **fuera de Play Store** (deadline 30 sept 2026). No aplica a nuestras apps (todas van a Play Store), pero tenerlo presente si en el futuro distribuimos APKs sideloaded.
## 🌐 Dominios y DNS

### Cloudflare
**Nameservers:**
- `april.ns.cloudflare.com`
- `simon.ns.cloudflare.com`

**Registros DNS actuales:**
| Dominio | Tipo | Apunta a | Estado |
|---|---|---|---|
| `api.baqueanonatales.com` | A | `161.118.240.229` (server viejo) | ⏳ Pendiente migrar a `104.129.59.151` |
| `baqueanonatales.com` | A | Vercel (`76.76.21.21`) | ✅ |
| `www.baqueanonatales.com` | CNAME | Vercel | ✅ |

**Estado:** el DNS de `api.baqueanonatales.com` **aún apunta al server viejo**. El cutover se hará cuando la migración esté validada.

### Vercel
- **Team:** `studio-digital-360`
- **Proyecto:** `baqueano-natales-web` (Astro)
- **URL producción:** `https://www.baqueanonatales.com`
- **Estado:** activo, sin tocar durante la migración

---

## 🔧 Fases del proyecto

### ✅ Fase 1 — Infraestructura (completada)
- Server nuevo provisionado y hardened
- Docker + Compose
- Backend FastAPI + Postgres + Nginx
- Healthchecks, logs JSON
- Documentación inicial (`docs/`)

### ✅ Fase 2 — Auth con Google (completada)
- Firebase Admin SDK integrado
- Endpoint `POST /api/v1/auth/google`
- Verificación de tokens
- JWT propio con roles
- Middleware `get_current_user` + `require_admin`

### ✅ Fase 3.1 — Módulo usuarios (completada)
- Modelo `Usuario` + migración
- CRUD de perfil
- Avatares con `LocalAvatarStorage` (interfaz ABC migrable a S3/Firebase)
- Nginx sirviendo `/media/` con caché 30d

### ✅ Fase 3.2 — Módulo admin (completada)
- 7 endpoints de gestión
- Filtros, paginación, validaciones
- Auto-admin por email (`ADMIN_EMAILS` en `.env`)
- Script de seed
- Fix crítico: `values_callable` en ENUM RolUsuario

### ✅ Fase 3.3 — Flutter base + login con Google (COMPLETADA 2026-10-08)
- Proyecto Flutter con estructura feature-first
- Flavors `client` (verde) + `admin` (morado)
- Router GoRouter con auto-redirect
- Splash + Login + Home
- **Login con Google funcional end-to-end** (Google → Firebase → Backend → JWT → Home)
- **Persistencia de sesión funcional** (sobrevive al cierre de la app)
- JWT guardado en secure storage
- Migración `google_sign_in` v7 → v6
- Configuración nativa Android completa (Credential Manager off, network security config)
- HTTP en dev (SSL pendiente para Fase 6)

### ✅ Fase 3.4 — Commit del código Flutter (COMPLETADA 2026-10-08)
- Todo el código Flutter commiteado y pusheado
- `CONTEXTO_PROYECTO.md` commiteado
- Fix del login commiteado

### ✅ Fase 3.5 — App admin con login (COMPLETADA 2026-10-08)
- ✅ SHA-1 nuevo registrado en `cl.baqueanonatales.admin` en Firebase Console
- ✅ `google-services.json` actualizado y commiteado
- ✅ Login con Google funcional end-to-end en flavor admin
- ✅ Home admin con tema morado + badge ADMIN
- ✅ Misma arquitectura que client (comparte `home_screen.dart` por ahora)

### ⏳ Fase 3.6 — Features core (pendiente)
- Mapa en vivo (Google Maps + WebSocket)
- Delivery (flujo de pedidos)
- Carta QR (menús interactivos)
- Recompensas (puntos por compras)

### ⏳ Fase 4 — CI/CD con GitHub Actions (pendiente)
- Tests en cada push
- Build APK automático
- Deploy backend automático vía SSH

### ⏳ Fase 5 — Play Store (pendiente)
- Crear keystore nuevo
- Activar Play App Signing
- Subir AAB a Play Console
- Completar metadata

### ⏳ Fase 6 — Cutover DNS + SSL (pendiente)
- Bajar TTL en Cloudflare
- Cambiar A record de `api.baqueanonatales.com` a `104.129.59.151`
- **Emitir certificado Let's Encrypt en el server nuevo**
- **Cambiar `AppConfig.dev` de `http://` a `https://`** (o dejar que prod lo use)
- Verificar HTTPS

### ⏳ Fase 7 — Decommission server viejo (pendiente)
- Apagar server viejo después de 1 semana sin incidentes
- Archivar repos viejos

---

## 🔍 Temas pendientes de análisis (no deuda técnica activa)

### Fase 6 — DNS cutover + SSL del server nuevo (PENDIENTE DE ANALIZAR)

**Contexto (2026-10-11):** se posterga hasta tener claridad sobre el modelo
final. No es deuda técnica activa porque hay decisiones estratégicas sin tomar.

**Estado actual:**
- `api.baqueanonatales.com` → server viejo (sistema legacy en producción).
- `dev-api.baqueanonatales.com` → server nuevo (proyecto nuevo + OAuth FB).
- SSL del server nuevo: Cloudflare Origin Certificate + modo `Full (strict)`.

**Por qué se posterga:**
1. El server nuevo aún no tiene paridad de features con el viejo.
2. Sin usuarios reales, no hay urgencia de consolidar.
3. **Decisión estratégica abierta:** Cloudflare proxied vs directo.
   - Si se mantiene **Cloudflare proxied** → el Origin Certificate es suficiente,
     **Let's Encrypt no aporta valor** (el usuario final ve el cert Edge de CF,
     nunca el del server).
   - Si se saca Cloudflare del medio (proxied=off) → ahí sí Let's Encrypt es
     la solución correcta.
4. Antes de decidir hay que definir el modelo de despliegue final del MVP.

**Antes de ejecutar hay que definir:**
- ¿Cloudflare queda proxied en producción final o no?
- ¿Cuándo el proyecto nuevo reemplaza al legacy (paridad de features)?
- ¿Se consolida en 1 solo server o se mantienen 2?

**Estimación tentativa cuando se decida:** ~1.5 horas (DNS cutover + SSL + AppConfig Flutter + validación).
## 🚨 Secretos expuestos (pendientes rotar)

**Durante el desarrollo, quedaron expuestos en chats/logs:**

| Secreto | Estado | Acción pendiente |
|---|---|---|
| `SECRET_KEY` (JWT) | ⚠️ Expuesto | Rotar en `.env` del server nuevo |
| `BOOSTR_API_KEY` | ⚠️ Expuesto | Regenerar desde Boostr |
| `RUTIFICADOR_API_KEY` | ⚠️ Expuesto | Regenerar desde Rutificador |
| `DIDIT_API_KEY` + `DIDIT_WEBHOOK_SECRET` | ⚠️ Expuesto | Regenerar en Didit |
| `RNSTP_API_KEY` | ⚠️ Expuesto | Regenerar |
| `FACEBOOK_PAGE_ACCESS_TOKEN` (x2) | ⚠️ Expuesto | Revocar en Meta + regenerar |
| `FACEBOOK_TOKEN_KEY` | ⚠️ Expuesto | Rotar |
| `GOOGLE_CLIENT_SECRET` | ⚠️ Expuesto | Regenerar en Google Cloud |
| `VERCEL_DEPLOY_HOOK_URL` | ⚠️ Expuesto | Regenerar en Vercel |
| `CLAVE_PRUEBAS`, `CLAVE_TAREAS` | ⚠️ Expuesto | Cambiar |
| Frase GPG de backups | 🚨 **MÁS CRÍTICO** | Rotar YA |
| GitHub PAT viejo | ⚠️ Expuesto | Revocar en GitHub |
| DuckDNS token | ⚠️ Expuesto | Descartado (no se usa DuckDNS) |
| Facebook token en `/root/main.py` del server nuevo | ⚠️ Expuesto | Revocar |

**⚠️ Rotación pendiente completa.** No se ha hecho todavía.

---

## 🧪 Infraestructura de tests

**Primera vez que el proyecto tiene tests automatizados.**

### Estructura
```nbackend/
├── pytest.ini
└── tests/
    ├── conftest.py        # fixtures: test_engine, db
    └── modules/
        └── social/
            ├── test_crypto.py      # 13 tests (unit)
            ├── test_schemas.py     # 16 tests (unit)
            ├── test_models.py      # 12 tests (con DB)
            └── test_services.py    # 24 tests (con DB)
```

### Cómo correr los tests

**Local (solo unit, sin DB):**
``powershell
cd backend
.\.venv\Scripts\python.exe -m pytest tests/modules/social/ -q
``
→ 29 passed, 36 skipped (los con DB se saltan sin `POSTGRES_PASSWORD` local)

**Server (con DB de test):**
``powershell
ssh deploy@104.129.59.151 "cd ~/baqueano-natales && docker compose exec -T backend pytest tests/ -q"
``
→ 65 passed

### DB de test

- Nombre: `baqueano_test` (en el Postgres del server)
- **NO toca producción** (`baqueano_natales`)
- El `conftest.py` hace `drop_all + create_all` al inicio de cada sesión
- TRUNCATE de las tablas del módulo antes de cada test

### Warning cosmético conocido

`PytestCacheWarning: could not create cache path /app/.pytest_cache` —
el container corre como `appuser` y `/app` es de `root`. No afecta los tests.

## 🗂️ Configuración crítica del server nuevo

### `docker-compose.yml`
3 servicios: `db`, `backend`, `nginx`.

**Volúmenes:**
- `postgres_data` — persistencia de DB
- `media_data` — avatares subidos
- `nginx_cache` — caché de Nginx

**Mounts del backend:**
- `./backend/app:/app/app` — hot reload en dev
- `./backend/secrets:/app/secrets:ro` — service account (read-only)
- `media_data:/app/media` — avatares

### `.env` (backend)
Variables clave:
```
ENVIRONMENT=production
DEBUG=false
POSTGRES_USER=baqueano_user
POSTGRES_PASSWORD=<ROTAR>
POSTGRES_DB=baqueano_natales
DATABASE_URL=postgresql://...
SECRET_KEY=<ROTAR>
FIREBASE_PROJECT_ID=baqueano-natales-prod
FIREBASE_SERVICE_ACCOUNT_PATH=/app/secrets/firebase-service-account.json
ADMIN_EMAILS=victorneyraars@gmail.com
PUBLIC_API_URL=https://api.baqueanonatales.com
AVATAR_STORAGE_PATH=/app/media/avatars
MAX_AVATAR_SIZE_BYTES=5242880
```

### Nginx
- Proxy reverso a `backend:8000`
- Rate limiting: 60/min general, 5/min en `/api/v1/auth/`
- Security headers (X-Content-Type-Options, X-Frame-Options, Referrer-Policy)
- Sirve `/media/` con caché 30d
- `server_tokens off`
- Upstream con `keepalive 32`

---

## 🛠️ Comandos rápidos

### Correr app Flutter (client)
```powershell
cd D:\dev\baqueano-natales\flutter
flutter run --flavor client -t lib/main_client.dart -d emulator-5554
```

### Correr app Flutter (admin)
```powershell
cd D:\dev\baqueano-natales\flutter
flutter run --flavor admin -t lib/main_admin.dart -d emulator-5554
```

### Rebuild limpio (cuando hay cambios nativos)
```powershell
cd D:\dev\baqueano-natales\flutter
flutter clean
flutter pub get
flutter run --flavor client -t lib/main_client.dart -d emulator-5554
```

### Matar procesos Flutter bloqueados
```powershell
Get-Process | Where-Object { $_.ProcessName -match "flutter|dart" } | Stop-Process -Force -ErrorAction SilentlyContinue
```

### Ver SHA-1 debug actual (¡cambió!)
```powershell
cd D:\dev\baqueano-natales\flutter\android
./gradlew signingReport
```

### Emulador Android 14 (recomendado)
```powershell
& "D:\Android\Sdk\emulator\emulator.exe" -avd Pixel6_API34 -no-snapshot-load -gpu swiftshader_indirect
```powershell
Get-Process | Where-Object { $_.ProcessName -match "emulator|qemu|adb" } | Stop-Process -Force -ErrorAction SilentlyContinue
& "D:\Android\Sdk\emulator\emulator.exe" -avd Pixel6_API37 -no-snapshot-load -wipe-data -gpu swiftshader_indirect
```

### Ver logs del backend (server)
```bash
ssh deploy@104.129.59.151 "cd baqueano-natales && docker compose logs --tail=50 backend"
```

### Rebuild backend (server)
```bash
ssh deploy@104.129.59.151 "cd baqueano-natales && docker compose build backend && docker compose up -d"
```

### Query DB (server)
```bash
ssh deploy@104.129.59.151 "cd baqueano-natales && docker compose exec -T db psql -U baqueano_user -d baqueano_natales -c 'SELECT id, email, rol FROM usuarios;'"
```

### Verificar salud del backend (HTTP dev)
```bash
curl http://104.129.59.151/health
```

---

### Recargar cambios del `.env` en el backend

⚠️ **`docker compose restart backend` NO recarga el `.env`.** Recrear el container:

``bash
ssh deploy@104.129.59.151 "cd ~/baqueano-natales && docker compose up -d backend"
``

(Palabra clave en el output: **"Recreated"**, no "Started".)

### Correr tests local (unit, sin DB)

``powershell
cd D:\dev\baqueano-natales\backend
.\.venv\Scripts\python.exe -m pytest tests/modules/social/ -q
``

### Correr tests completos (server, con DB)

``powershell
ssh deploy@104.129.59.151 "cd ~/baqueano-natales && docker compose exec -T backend pytest tests/ -q"
``

### Aplicar migraciones en el server

``powershell
ssh deploy@104.129.59.151 "cd ~/baqueano-natales && docker compose exec -T backend alembic upgrade head"
``

### Ver migraciones aplicadas

``powershell
ssh deploy@104.129.59.151 "cd ~/baqueano-natales && docker compose exec -T backend alembic current"
``

## 📚 Documentación existente

**En el repo `baqueano-natales`:**

| Archivo | Contenido |
|---|---|
| `README.md` | Intro + estructura + stack |
| `docs/VISION.md` | 🎯 Visión de superapp multi-vertical + cómo crece |
| `docs/ARCHITECTURE.md` | Arquitectura técnica + modular estricta |
| `docs/LEGACY_ANALYSIS.md` | 📚 Análisis del sistema anterior (4 actores, verificación, zonas) |
| `docs/DEPLOYMENT.md` | Guía de deploy paso a paso |
| `docs/DEVELOPMENT.md` | Convenciones + setup dev |
| `docs/DECISIONS/0001-docker-compose.md` | ADR inicial |
| `backend/app/modules/social/README.md` | Doc del módulo social + roadmap de 9 etapas |
| `CONTEXTO_PROYECTO.md` | Este archivo |

---

## 🎯 Estado exacto al retomar

**Lo que está funcionando:**
- Server nuevo con backend corriendo en `104.129.59.151` (HTTP)
- Postgres 16 con 13 tablas (usuarios, comercios, prestadores, social)
- 5 módulos backend completos (auth, usuarios, admin, comercios, prestadores) + social (Etapa 1)
- App Flutter client con **login funcional end-to-end**
- App Flutter client con **persistencia de sesión funcional**
- Home con datos reales (nombre, email, rol ADMIN)
- Flujo verificado: Google Sign-In → Firebase → backend → JWT → Home
- **114 tests automatizados** (78 unit + 36 con DB) - todos verdes
- **Modulo social (Etapas 1-6)** desplegado: OAuth FB + worker + IG + prestadores + admin frontend

**Lo que queda pendiente inmediato:**
1. **Rotar secretos expuestos** (pendiente desde 2026-10-08)
2. 🚨 **Rotar secretos expuestos** (ver sección "Secretos expuestos") — CRÍTICO
   - Prioridad alta: `SECRET_KEY` (JWT), frase GPG de backups, GitHub PAT viejo
   - **Nuevo:** `POSTGRES_PASSWORD` expuesto en chat 2026-10-08
3. **Features core restantes**: mapa, delivery, carta QR, recompensas
4. **Diferenciar Home admin** del Home client (ahora comparten `home_screen.dart`)

**Lo que falta por construir:**
- Features core (mapa, delivery, carta QR, recompensas) — Fase 3.6
- CI/CD (GitHub Actions) — Fase 4
- Play Store setup — Fase 5
- DNS cutover + SSL — Fase 6
- Decommission server viejo — Fase 7

---

## 🚀 Cómo retomar en un chat nuevo

**Al inicio del nuevo chat, pegar este documento completo.**

Luego, los primeros comandos a correr son:

1. **Verificar estado del repo:**
   ```powershell
   cd D:\dev\baqueano-natales
   git status
   git log --oneline -5
   ```

2. **Verificar server:**
   ```bash
   curl http://104.129.59.151/health
   ```

3. **Verificar emulador (si aplica):**
   ```powershell
   cd D:\dev\baqueano-natales\flutter
   flutter devices
   ```

**Con esto, se retoma el trabajo exactamente donde quedó.**

---

## 📝 Convenciones de código

**Backend (Python):**
- Estructura por módulos de dominio
- Async/await en todo
- Pydantic para validación
- SQLAlchemy 2.0 style (Mapped, mapped_column)
- Logs JSON estructurados

**Flutter (Dart):**
- Feature-first
- Riverpod para state
- GoRouter para navegación
- Nombres: `snake_case` archivos, `PascalCase` clases
- Lints: `flutter_lints: ^5.0.0`

**Commits Git:**
- `feat:` nueva feature
- `fix:` corrección
- `docs:` documentación
- `refactor:` sin cambio funcional
- `test:` tests
- `chore:` tareas varias

**Regla de oro de secretos:**
- `.env` → NUNCA al repo
- `secrets/` → NUNCA al repo
- `*.jks`, `*.keystore` → NUNCA al repo
- `google-services.json` → **SÍ va al repo** (es config pública)

---

## 🔨 Módulo `prestadores` — estado actual (v2 + pantallas dueño)

| Componente | Estado |
|---|---|
| Backend (modelos + migración) | ✅ |
| Backend (schemas + services + routes) | ✅ |
| Backend (seed + prestador modelo) | ✅ |
| Frontend (modelos + repo + providers) | ✅ |
| Frontend (lista cliente + detalle industrial) | ✅ |
| Fix deep links (WhatsApp, redes) | ✅ |
| Prestador modelo cargado | ✅ "Taller Mecánico del Sur" |
| Pantallas dueño (crear/editar mis prestadores) | ⏳ |
| Pantallas admin (verificar/rechazar + CRUD catálogo) | ⏳ |
| Editor de servicios en frontend (dueño) | ⏳ |
| Upload de portada + galería | ⏳ |
| **Pantallas dueño (listar + detalle)** | ✅ |
| **Formulario crear/editar** | ⏳ placeholder |
| **Editor de servicios** | ⏳ placeholder |

**Ruta del módulo:** `backend/app/modules/prestadores/` y `flutter/lib/features/prestadores/`
**Tablas:** `categorias_oficio`, `prestadores`, `prestador_servicios`, `fotos_trabajo`
**Prestador modelo:** `taller-mecanico-del-sur` (accesible en `GET /api/v1/prestadores/taller-mecanico-del-sur`)

| Componente | Estado |
|---|---|
| Capa reutilizable (`mixins` + `slug`) | ✅ |
| Modelos SQLAlchemy | ✅ |
| Migración aplicada en producción | ✅ |
| Schemas Pydantic | ✅ |
| Services | ✅ |
| Deps | ✅ |
| Routers | ✅ |
| Seed de categorías base | ✅ |
| Integración `main.py` | ✅ |
| Deploy + verificación en producción | ✅ |
| Frontend Flutter (cliente + dueño + admin) | ⏳ Próxima sesión |

**Ruta del módulo:** `backend/app/modules/prestadores/`
**Tablas:** `categorias_oficio`, `prestadores`, `fotos_trabajo`
**Categorías base seedeadas:** 11 (Mecánica automotriz, Electricidad, Gasfitería, Carpintería, Albañilería, Pintura, Cerrajería, Jardinería, Limpieza, Fletes y mudanzas, Otros oficios)

**Endpoints activos:**
- Público: `GET /api/v1/prestadores`, `/prestadores/categorias`, `/prestadores/{slug}`
- Dueño: `POST/GET/PATCH/DELETE /api/v1/mis-prestadores`, `/mis-prestadores/{id}/fotos`, `/mis-prestadores/{id}/enviar-revision`
- Admin: `GET/POST/PATCH/DELETE /api/v1/admin/categorias-oficio`, `/admin/prestadores/{id}/verificar|rechazar|suspender|destacar`

---

---

## Modulo `social` - estado actual (9/9 etapas completas)

Publicación en redes sociales (Facebook, Instagram, Google Business) con
multi-tenant por recurso y tokens cifrados.

| Componente | Estado |
|---|---|
| Backend (modelos + migración) | ✅ |
| Backend (crypto Fernet) | ✅ |
| Backend (schemas + services + deps) | ✅ |
| Backend (router admin + 15 endpoints) | OK |
| Backend (README del módulo) | ✅ |
| Tests (114: 78 unit + 36 con DB) | OK |
| Deploy en producción | ✅ |
| **Etapa 2 (OAuth Facebook)** | backend + smoke test end-to-end OK |
| Etapa 3 (publicacion FB con worker) | worker in-process + smoke test real OK |
| Etapa 4 (Instagram via FB) | instagram_service + smoke test real OK |
| Etapa 5 (integracion con prestadores) | eventos + smoke test real OK |
| Etapa 6 (frontend admin) | 3 pantallas Flutter + filtros OK |
| Etapa 8 (Google Business Profile) | codigo listo, gateado por flag (espera aprobacion API) |
| Etapa 9 (modulo promocion) | 5 plantillas SVG + editor + preview OK |

**Ruta:** `backend/app/modules/social/` y `backend/app/core/crypto.py`

**Tablas:** `cuentas_sociales`, `tokens_sociales`, `publicaciones_sociales`, `config_social`

**Enums de Postgres:** `red_social`, `propietario_tipo_social`, `destino_publicacion`, `estado_publicacion`

**Endpoints (admin, 10 total):**
```nGET/POST         /api/v1/admin/social/cuentas
GET/PATCH/DELETE /api/v1/admin/social/cuentas/{id}
GET/PATCH        /api/v1/admin/social/config
GET/POST         /api/v1/admin/social/publicaciones
GET              /api/v1/admin/social/publicaciones/{id}
```

**Migraciones aplicadas:**
- `3a833c2fff44` — tablas del módulo social
- `d16ad0e2b9dc` — índice único parcial de config global
- `3baba5a761b4` — recrear índice con `NULLS NOT DISTINCT`

**Variable crítica:** `TOKEN_ENCRYPTION_KEY` (clave Fernet, 44 caracteres)
en `~/baqueano-natales/.env` del server. Sin ella el backend **no arranca
en producción**.

---

**Fin del documento de contexto.**
### 2026-10-17 - Fase 1: Distribución Dev a celulares (Firebase App Distribution) + Fixes H8/H9/H10/H11

**Creado el pipeline de CI/CD para probar en celulares reales sin PC.**

- **H8 (P1, fixeado)**: `Turno.fromJson` fallaba porque `TurnoListItemResponse` no enviaba `created_at`/`updated_at`. Se agregaron al schema y se hizo el parseo defensivo en Flutter.
- **Fase 1 (Completada)**: Workflow `.github/workflows/dev-build.yml` que compila `clientDev`/`adminDev` en release y sube la APK a Firebase App Distribution.
- **H9 (fixeado)**: Heredoc con `${{ secrets.X }}` inline corrompía el `key.properties` si el password tenía caracteres especiales. Se cambió a `env:` + `printf`.
- **H10 (fixeado)**: APK path hardcodeado (`app-clientDev-release.apk`) fallaba por case-sensitivity. Se cambió a búsqueda dinámica con `find`.
- **H11 (fixeado)**: `firebase-tools` no autenticaba. Se agregó `export GOOGLE_APPLICATION_CREDENTIALS=/tmp/firebase-sa.json`.
- **Secrets nuevos**: `FIREBASE_SERVICE_ACCOUNT`, `FIREBASE_APP_ID_CLIENT_DEV`, `FIREBASE_APP_ID_ADMIN_DEV`.
- **Rol GCP**: Se agregó `Firebase App Distribution Admin` al service account.


### 2026-10-17 - Sesión épica: App Store privado + APK firmado + Login en device

**De bugs en producción a infraestructura de nivel industrial en un día.**

**H8 (P1) cerrado:**
- Backend: `created_at`/`updated_at` agregados a `TurnoListItemResponse`.
- Frontend: `_parseFechaOpcional()` defensivo en `Turno.fromJson`.
- Verificado end-to-end en emulador + device real.

**App Store privado creado:**
- Nginx sirviendo `https://api-dev.baqueanonatales.com/apks/` con autoindex.
- Bind mount `./deploy/apks:/usr/share/nginx/apks:ro` en docker-compose.
- Ruta pública: `app-clientdev.apk` + `.sha256` + `app-admindev.apk`.

**Pipeline de distribución con bundletool:**
- Workflow `.github/workflows/dev-build.yml` reescrito.
- Compila AAB → extrae APK universal con `roberteggl/bundletool-action@v1.0.0` → firma con upload key → genera SHA-256 → sube a servidor vía SCP → renombra.
- Sin dependencia de la API `generatedapks` de Google (que devuelve HTTP 204).

**SHA-1 registrado automáticamente en Firebase:**
- Script `scripts/register_sha1_firebase.py` (Firebase Management API).
- Extrae SHA-1 con `apksigner` en el workflow.
- Registra en `cl.baqueanonatales.dev` y `.admin.dev` (idempotente).
- Google Sign-In funciona en APK sideloaded firmado con upload key.

**Bugs resueltos en el camino:**
- H9 (heredoc corrompía passwords) → `printf` + `env:` vars.
- H10 (path case-sensitive) → `find` dinámico.
- H11 (Firebase sin credenciales) → `GOOGLE_APPLICATION_CREDENTIALS`.
- H12 (API generatedapks HTTP 204) → abandonada, reemplazada por bundletool.
- H13 (scp creaba carpeta) → `target: .../apks/` + rename SSH.
- H14 (keytool no lee v2/v3) → `apksigner verify --print-certs`.
- H15 (gh secret get no existe) → pasar SHA-1 directo.
- H16 (login falla por SHA-1) → registro automático en Firebase.

**Commits relevantes:**
- `350d6de` fix(turnos): created_at/updated_at en schema
- `88ec3ad` fix(oficios): Turno.fromJson tolerante
- `5ee46a9` feat(ci): bundletool para APK universal
- `982ea2c` fix(ci): MediaIoBaseDownload
- `0d6d581` fix(ci): retry HTTP 204
- `78e96d7` feat(ci): registrar SHA-1 automáticamente

**Infra nueva:**
- `deploy/apks/` (bind mount en Nginx, gitignored).
- `/usr/share/nginx/apks/` (alias público).
- `apksigner` instalado en servidor (para verificar certificados).


### 2026-10-18 (cont. 47) - Web Frontend: Adapter Vercel + ISR preparado

**Webhook de revalidación backend → Vercel funcionando end-to-end.**

**Backend (commit `bc5ae08`):**
- `POST /api/v1/ops/webhooks/revalidate` con API key.
- `_notificar_cambio_web()` en `prestadores/services.py` (dispara al verificar prestador).
- Variables: `REVALIDATE_API_KEY`, `VERCEL_BYPASS_TOKEN`, `PUBLIC_WEB_URL`.
- Gotcha: `docker compose restart` NO relee `.env` → usar `up -d --force-recreate`.

**Nginx fix:**
- Routing dev/prod estaba invertido por config stale en memoria.
- Fix: `docker exec baqueano_nginx nginx -s reload`.
- Backups movidos a `/tmp/nginx-backups/`.

**Frontend (commit `890e833`):**
- `@astrojs/vercel@9.0.5` instalado (compatible con Astro 5).
- `astro.config.mjs` con `adapter: vercel({ isr: { bypassToken, expiration } })`.
- `VERCEL_BYPASS_TOKEN` configurado en Vercel (Prod/Preview/Dev).
- Deployment Protection NO afecta dominio público.

**Infra Vercel CLI documentada** en `SERVER_CHEATSHEET.md`.


### 2026-10-18 (cont. 48) - Web ISR END-TO-END FUNCIONAL

**Frontend Astro + ISR bajo demanda + webhook backend = ciclo automático completo.**

**Frontend (commit `43b5fd1`):**
- `/locales` y `/locales/[tipo]/[slug]` reconstruidos con `fetch()` dinámico a la API.
- `export const prerender = false` → ISR activo en runtime.
- `src/config/api.ts` centralizado con tipos TypeScript completos.
- Solo `/` (home) queda prerenderizada estáticamente.
- `sync-locales.mjs` eliminado del build (ya no se necesita).

**Backend (commits `bc5ae08` + `e03e7fc`):**
- `POST /api/v1/ops/webhooks/revalidate` operativo.
- `_notificar_cambio_web(comercio)` en `comercios/services.py`:
  - Notifica a Vercel con paths `/locales` y `/locales/{categoria}/{slug}`.
  - Llamada desde `verificar_comercio`, `rechazar_comercio`, `suspender_comercio`, `destacar_comercio`.
  - Best-effort (nunca rompe el flujo principal).
- `_notify_web_revalidation(prestador)` corregido: ahora usa `PUBLIC_API_URL` (antes `INTERNAL_API_URL` que no existía) y apunta a `/` en lugar de `/prestadores`.

**Variables de entorno:**
- `REVALIDATE_API_KEY`, `VERCEL_BYPASS_TOKEN`, `PUBLIC_API_URL` en `.env.dev` y `.env.prod`.
- Ambas variables críticas cargadas en `settings` de dev y prod (rebuild necesario en prod por imagen autocontenida).

**Prueba end-to-end verificado (2026-10-18):**
- Cache antes: `age: 421` (7 min).
- Webhook dispara: `HEAD /locales` y `HEAD /locales/restaurante/la-picada-de-natales` → `HTTP 200 OK`.
- Cache después: `age: 12` (regenerado hace 12s).

**Configuración Vercel:**
- `@astrojs/vercel@9.0.5` (compatible con Astro 5).
- `adapter: vercel({ isr: { bypassToken, expiration: 86400 } })`.
- `VERCEL_BYPASS_TOKEN` configurado en Prod/Preview/Dev.
- Deployment Protection NO afecta dominio público.

**Gotchas críticos descubiertos:**
- `docker compose restart` NO recarga variables de `.env` → `up -d --force-recreate`.
- Backend prod es imagen autocontenida → rebuild obligatorio tras cambios en código.
- El schema `HorarioResponse` espera `dia_semana` en rango 0-6 (domingo=0), no 1-7 (ISO).


### 2026-10-18 (cont. 49) - Limpieza de código legacy en la web

**Eliminado todo el código de la web anterior (menús hardcoded).**

**Archivos borrados (247 líneas):**
- `src/data/menus.ts` (data hardcoded, sin referencias).
- `scripts/sync-locales.mjs` (legacy, fallaba con 404).
- `src/styles/global.css` (huérfano, no importado).
- `public/assets/*` (8 assets obsoletos: icono PNG, mono, logo, logo oscuro, duplicados).
- `package.json`: script `sync` eliminado.

**Estado final del proyecto web:**
- `src/config/api.ts` — cliente API + tipos.
- `src/layouts/Layout.astro` — layout base.
- `src/pages/index.astro` — home (prerenderizada).
- `src/pages/locales/index.astro` — listado (ISR runtime).
- `src/pages/locales/[tipo]/[slug].astro` — detalle (ISR runtime).
- `public/assets/baqueano_icono.svg` — único asset.

**Verificado post-limpieza:**
- Home, `/locales`, detalle: HTTP 200.
- Assets borrados: 404 (esperado).
- Asset conservado: 200.
- ISR sigue funcionando: `age` 51s → 7s tras webhook.
- Build exitoso (10s), deploy exitoso (14s).

**Backup:** `/tmp/web-backup-20261018-023355/` (rollback disponible si se necesita).

