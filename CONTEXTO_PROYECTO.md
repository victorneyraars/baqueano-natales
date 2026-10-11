# Baqueano Natales — Contexto Completo del Proyecto

> **Última actualización:** 2026-10-10
> **Propósito:** Documento maestro que resume el estado completo del proyecto para retomar el trabajo en cualquier momento sin perder contexto.

---

## 📋 Changelog reciente

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