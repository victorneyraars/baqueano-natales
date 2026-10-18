# Roadmap — Pendientes diferidos

> **Ultima actualizacion:** 2026-10-16
> **Proposito:** items planificados que se difieren para priorizar el MVP.
> No es deuda tecnica — son mejoras reales con plan ya pensado.

---

## Modulo ops — Fase 3: Live streaming

**Estado:** planeado, no implementado.
**Esfuerzo estimado:** 2 sesiones (opcion polling) o 2-3 sesiones (opcion SSE).
**Prioridad relativa:** media-baja (el feature actual ya cumple el objetivo).

### Objetivo
Ver en tiempo real desde la app admin el progreso del release.

### Opcion A — Polling (recomendado primero)

| Item | Detalle |
|---|---|
| Esfuerzo | 2-3h (1 sesion) |
| Latencia | ~5 seg (indistinguible para el usuario) |
| Dependencias | Ninguna nueva |

**Que hace:**
- Pantalla `OpsLiveScreen` que muestra el run activo.
- Refresca cada 5s via `opsRunDetailProvider` (ya existe).
- Reusa 100% lo que ya tenemos.

**Implementacion:**
- Reusar `ops_run_detail_provider` con auto-refresh.
- Nueva ruta `/admin/ops/live/:run_id`.
- Lista de jobs + steps en vivo.
- Boton "Cancelar run" (opcional).

### Opcion B — SSE real (solo si polling no alcanza)

| Item | Detalle |
|---|---|
| Esfuerzo | 6-8h (2-3 sesiones) |
| Latencia | <1 seg (real-time verdadero) |
| Dependencias | Webhooks GitHub + HTTPS + HMAC |

**Arquitectura:**
- Webhooks GitHub -> backend (con HMAC + secret).
- Pub/sub en memoria para SSE.
- Endpoint `GET /admin/ops/events` con SSE.
- Cliente SSE en Flutter (reconexion + backoff + lifecycle).
- Pantalla "Ops Live" con log en vivo.

**Cuando SI vale la pena:**
- Multiples admins mirando simultaneamente (>10).
- Latencia <1s requerida.
- Eventos de alta frecuencia.

**Cuando NO:**
- Un solo admin ocasional.
- Cambios cada 30s-1min (el release tarda 25min).
- Simplicidad > velocidad.

---

## Modulo ops — Fase 2f: Migracion a GitHub App

**Estado:** diferido (deuda tecnica documentada).
**Esfuerzo estimado:** 2-3h (1 sesion).

### Por que migrar
- PAT actual: fijo, manual, expira cada 6-12 meses.
- GitHub App: auto-rotacion de tokens (1h), permisos granulares, rate limit 3x.

### Que hay que hacer
- Crear GitHub App en la org (UI web).
- Generar private key + guardar en secrets.
- Implementar `get_installation_token()` en `services_github.py`.
- Cambiar el cliente httpx para usar el token dinamico.
- Actualizar `README.md` del modulo ops.

### Cuando hacerlo
- Cuando el PAT cumpla 6 meses o haya que rotarlo.
- Cuando la tasa de uso justifique los 15k req/h.

---

## Modulo ops — Fases 4 y 5 (roadmap original)

**Estado:** planeado en `backend/app/modules/ops/README.md`.
**Prioridad:** baja (no bloquea MVP).

### Fase 4 — Multi-proyecto
- Operar RNSTP, Studio Digital, etc. desde el mismo panel.
- Refactor: repo configurable per proyecto.

### Fase 5 — Automatizaciones
- Scheduled releases.
- Aprobaciones en 2 pasos.
- Rollback automatico si falla el deploy.

---

## Infra — Fase 6: DNS cutover + SSL final

**Estado:** pendiente.
**Prioridad:** media (no bloquea features).

- Decidir: mantener Cloudflare proxied o directo.
- Si proxied: Origin Cert ya esta.
- Si directo: Let's Encrypt + cambiar AppConfig.

### Cuando hacerlo
- Cuando el MVP este cerrado.

---

## Infra — Fase 7: Decommission server viejo

**Estado:** pendiente.
**Prioridad:** baja.

- Snapshot del legacy ya guardado.
- Apagar server viejo tras 1 semana sin incidentes.
- Archivar repo `sandraalvaradoclp/superapp-natales`.

---

## Deuda tecnica acumulada

Ver seccion "Secretos expuestos" en `CONTEXTO_PROYECTO.md`.

**Prioridad ALTA (seguridad):**
- Rotar `SECRET_KEY` (JWT).
- Rotar `TOKEN_ENCRYPTION_KEY` (re-cifrado de tokens Facebook).
- Rotar `FACEBOOK_APP_SECRET`.
- Revocar 2 PATs legacy.

**Prioridad MEDIA:**
- Tests automatizados en Flutter (hoy no hay).
- Migracion a GitHub App (arriba).
- Analytics de uso del MVP (medir features).

---

## Features core del MVP (Fase 3.6 original)

**Estado:** nunca empezadas.
**Prioridad:** alta para MVP completo.

- **Mapa en vivo** (Google Maps + WebSocket).
- **Delivery** (flujo de pedidos).
- **Carta QR** (menus interactivos).
- **Recompensas** (puntos por compras).

Cada una es un bloque de 1-2 sesiones.

---

## Como usar este documento

- **Antes de cada sesion:** revisar si algun item de aca se desbloqueo.
- **Al cerrar un item:** mover a `CONTEXTO_PROYECTO.md` con entry de changelog.
- **Al agregar un item nuevo:** documentar en la seccion correspondiente.

Fin del documento.

## Mejoras UI/UX y Automatizaciones (Post-Fase 1)

- **H4 (UX, P2)**: Card de usuario en Home sin `onTap` (debería navegar a perfil).
- **H6 (Perf, P2)**: Doble llamada a `auth/me` y `POST /fcm-token` al restaurar sesión.
- **H7 (UX, P2)**: Notificaciones in-app sin distinción visual entre leídas y no leídas.
- **H1 (UX, P3)**: Home en landscape/tablet sin grid responsive (1 sola columna).
- **NUEVO (Feature, P3)**: Trigger de "Dev Build" desde la app Admin (Nivel 1: botón a GitHub Actions / Nivel 2: endpoint + modal).

## Backlog actualizado (post-sesión 2026-10-17)

### Bugs pendientes (encontrados en audit)
- **H4 (P2)**: Card de usuario en Home sin `onTap` (ir a perfil).
- **H6 (P2)**: Doble llamada `auth/me` + `POST fcm-token` en restore.
- **H7 (P2)**: Notificaciones in-app sin distinción visual leída/no leída.
- **H1 (P3)**: Home landscape/tablet sin grid responsive.

### Infra pendiente
- **APK producción firmado por Google**: API `generatedapks` de Google Play devuelve HTTP 204 (no materializa APK universal). Documentado, se retomará cuando Google arregle o cuando haya tiempo de implementar fastlane.
- **Trigger dev-build desde app Admin**: Nivel 1 (link a GitHub Actions) o Nivel 2 (endpoint + modal).

### Deuda técnica menor
- El paso `Debug — listar APKs generados` quedó en el workflow (útil para debug, se puede quitar).
- `scripts/register_sha1_firebase.py` tiene argumento `--keystore-b64` que ya no se usa (siempre pasamos `--sha1` directo).


## Frontend Web - Pendientes post sesión 2026-10-18

### Migración a ISR real (prioridad alta)
- **Qué**: refactorizar páginas de Astro para usar `fetch()` dinámico + `prerender = false`.
- **Por qué**: hoy las páginas son estáticas puras, el webhook no las revalida.
- **Páginas afectadas**: `/locales/index.astro`, `/locales/[tipo]/[slug].astro`.
- **Cambios**:
  1. Reemplazar `import { locales } from '../../data/menus'` con `fetch()` a la API.
  2. Quitar `getStaticPaths()` de `[slug].astro`.
  3. Agregar `export const prerender = false;` al inicio.
  4. Actualizar paths del webhook backend (`/prestadores` → `/locales`).
- **Testing**: crear comercio en DB → webhook → verificar `/locales` muestra el nuevo en <30s.

### Bug: sync-locales.mjs retorna 404
- El script `scripts/sync-locales.mjs` consulta la API para ID 4 (`puro-verde`) y recibe 404.
- Build continúa por el `|| true`, pero la página queda con datos vacíos.
- Fix pendiente: revisar si el local existe en la DB o si el ID está mal hardcodeado.


## Web Frontend - Estado post 2026-10-18

### ✅ Cerrado
- Adapter Vercel + ISR
- Webhook backend de revalidación
- `/locales` + `/locales/[tipo]/[slug]` con fetch dinámico
- Ciclo automático: cambio DB → webhook → Vercel regenera

### Pendiente próximo
1. **Página `/` (home)**: hoy es estática, no tiene `prerender=false`. Si querés que se actualice con datos de la API (ej: contador de comercios), hay que migrarla también.
2. **Ampliar webhook a más acciones**: hoy solo se dispara desde comercios. Se puede agregar en:
   - Prestadores verificados (cuando haya página pública).
   - Cambios en `categorias_comercio` (reflejar en filtros).
   - Reviews (si se muestran en el sitio público).
3. **Bug `sync-locales.mjs`**: el script legacy consultaba `/catalogo/local/{id}` que devuelve 404. Ya no se ejecuta en build pero el archivo `scripts/sync-locales.mjs` sigue en el repo. Se puede eliminar.
4. **Filtros y búsqueda en `/locales`**: hoy no hay filtro por categoría ni búsqueda. Próxima iteración.
5. **Mapa de locales en `/locales`**: integrar Google Maps o Leaflet con `latitud`/`longitud` (los campos existen en el modelo pero están null en el seed).

### Bug conocidos
- `sync-locales.mjs` consulta `/catalogo/local/4` (404) — no se ejecuta en build pero se puede borrar.
- El comercio `la-picada-de-natales` tiene todos los horarios como `cerrado: true` en prod. Se puede ajustar el seed.


## Bypass de caché para APKs (implementado 2026-10-18)

**Problema:** Cloudflare cacheaba archivos `.apk` (comportamiento por defecto). Al reemplazar un APK, seguía sirviendo la versión vieja (o un 404 cacheado) hasta que el cache expiraba.

**Solución implementada (2 capas):**

1. **Cache Rule en Cloudflare:**
   - Nombre: `Bypass APKs`
   - Expresión: `starts_with(http.request.uri.path, "/apks/")`
   - Acción: `cache: false`
   - ID: `4ab3e757be074b7ea62a0bdb9c5ba5f8`
   - Creada vía API.

2. **Cache-Control en Nginx (respaldo):**
   - Agregado en `location /apks/` de `api.conf` y `api-dev.conf`:
   - `add_header Cache-Control "no-store, no-cache, must-revalidate, proxy-revalidate, max-age=0";`

**Resultado:** `cf-cache-status: DYNAMIC` en cada petición a `/apks/*`. Los APKs se sirven siempre desde el origen (server). No hace falta purgar manualmente tras cada actualización.


## Web: Pendientes post-sesión 2026-10-18

### Features faltantes
1. **Filtros avanzados en `/prestadores`**: búsqueda por texto, ordenamiento por rating/precio.
2. **Paginación** cuando haya >20 prestadores.
3. **Mapa de prestadores** (Leaflet) — requiere lat/lng.
4. **Galería de fotos de trabajos** — la API ya devuelve `fotos_trabajos[]`.
5. **Página `/prestadores/categorias`** con conteo por categoría.

### Bugs conocidos
- **`casa`** en prod es un prestador de prueba con `especialidades: null`. Filtrado del listado pero conviene limpiarlo de la DB.
- **`prod-client.apk`** es placeholder (copia del dev). Se reemplaza en release `v0.4.0`.

### Prioridad
- **Alta**: limpiar prestadores de prueba en prod.
- **Media**: búsqueda por texto en `/prestadores`.
- **Baja**: mapa, galería.


## Web + Ops: Estado post-sesión 2026-10-18

### ✅ Cerrado
- Webhook de revalidación ISR (prestadores + comercios)
- Cleanup automático de datos incompletos (cron 24h)
- Endpoints admin: `/cleanup/preview` + `/cleanup`
- Audit log en `ops_audit_log`
- Filtro client-side en `/prestadores` (compatible con ISR cacheado)
- `casa` sanitizado en prod

### 🔜 Pendiente próximas sesiones

**Backend:**
- Notificar cleanup de comercios (requiere revisión manual por FK).
- Worker cleanup de imágenes huérfanas (fotos sin orden activa).

**Web:**
- Filtros avanzados en `/prestadores` (búsqueda por texto, ordenamiento).
- Mapa de prestadores/comercios (Leaflet).
- Galería de fotos de trabajos en detalle del prestador (API ya devuelve `fotos_trabajos[]`).

**Ops Dashboard:**
- Mostrar historial de cleanups en el Ops Dashboard.
- Alertas si el cleanup sanitiza >5 registros (posible ataque o bug masivo).

