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
