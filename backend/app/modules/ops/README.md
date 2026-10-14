# Modulo `ops` — Ops Dashboard

Panel de operaciones para el admin de Baqueano. Integra GitHub Actions + Play Console en una sola API.

## Objetivo

Permitir que la app admin opere el ciclo completo de publicacion (ver estado, monitorear runs, gestionar releases) sin abrir GitHub ni Play Console.

## Roadmap por fases

| Fase | Estado | Que incluye |
|---|---|---|
| **1 — Read-only** | ✅ **Implementado** | Estado del sistema + runs + tracks + links |
| **2 — Trigger** | ⏳ Pendiente | Boton "Publicar version" desde la app (crea tag) |
| **3 — Live** | ⏳ Pendiente | Webhooks GitHub + SSE + audit log |
| **4 — Multi-proyecto** | ⏳ Pendiente | Operar RNSTP, Studiodigital, etc. desde el mismo panel |
| **5 — Automatizaciones** | ⏳ Pendiente | Scheduled releases, aprobaciones, rollback automatico |

## Arquitectura (Fase 1)

    App Admin (Flutter)  ->  Backend FastAPI  ->  GitHub Actions API
                                              \->  Play Console API

El backend actua como **proxy seguro**:

- La app admin NUNCA tiene el token de GitHub (solo el backend).
- RBAC: solo rol `admin` puede acceder (`AdminUser`).
- Cache en memoria (20s GitHub, 30s Play) para reducir rate limit.

## Endpoints (Fase 1)

    GET /api/v1/admin/ops/health          Estado consolidado
    GET /api/v1/admin/ops/runs            Lista de runs (?limit=10&branch=main)
    GET /api/v1/admin/ops/runs/{id}       Detalle (jobs + steps)
    GET /api/v1/admin/ops/tracks          Versiones por track (Play Console)
    GET /api/v1/admin/ops/links           Links de descarga

Todos requieren `Authorization: Bearer <jwt>` con rol `admin`.

## Configuracion (.env)

    # Ops Dashboard
    GITHUB_OPS_TOKEN=gho_xxx          # PAT del gh CLI (solo lectura por ahora)
    GITHUB_OPS_REPO=victorneyraars/baqueano-natales
    GITHUB_API_BASE=https://api.github.com
    GITHUB_OPS_CACHE_TTL_SEC=20

    # Paquetes Play
    PLAY_PACKAGE_CLIENT=cl.baqueanonatales
    PLAY_PACKAGE_ADMIN=cl.baqueanonatales.admin

    # Links opt-in (internal testing)
    PLAY_OPT_IN_CLIENT=https://play.google.com/apps/internaltest/...
    PLAY_OPT_IN_ADMIN=https://play.google.com/apps/internaltest/...

## Estructura

    ops/
    ├── __init__.py
    ├── README.md              <- este archivo
    ├── schemas.py             <- Pydantic models (RunInfo, TrackInfo, etc.)
    ├── services_github.py     <- cliente GitHub Actions (httpx + cache)
    ├── services_play.py       <- cliente Play Console (google-api-python-client)
    ├── services_links.py      <- links de descarga (config)
    ├── services_health.py     <- estado consolidado
    ├── deps.py                <- re-export AdminUser
    └── routes.py              <- 5 endpoints admin

## Fase 2 (diseno preliminar)

Cuando implementemos **trigger de releases**:

1. **Migrar a GitHub App** en vez de PAT. Mejores razones:
   - Token de 1h con auto-refresh (vs PAT de meses).
   - Permisos granulares (Contents, Actions, Workflows por separado).
   - Rate limit 3x mayor (15,000/h vs 5,000/h).
   - No depende de un usuario humano (offboarding seguro).

2. **Tabla `ops_audit_log`** (append-only):
   - `id`, `user_id`, `action`, `payload` (JSONB), `result`, `timestamp`.
   - Escribir en `BackgroundTasks` de FastAPI (no bloquea el request).

3. **Endpoints nuevos**:
   - `POST /release/preview` — devuelve "esto va a pasar" sin ejecutar.
   - `POST /release` — crea tag, dispara workflow. Requiere `{"confirm": "CONFIRMAR"}`.
   - `POST /tracks/promote` — promueve entre tracks (internal -> alpha -> production).

## Fase 3 (diseno preliminar)

**Live updates**:

- Webhooks de GitHub -> backend (`POST /webhooks/github` con HMAC).
- SSE endpoint (`GET /events`) para push al cliente.
- Pantalla "Ops -> Live" en la app admin con log en tiempo real.

## Tests

- Fase 1: se valida con `curl` + JWT admin.
- Fase 2: agregar `tests/modules/ops/` con HTTP tests (patron del proyecto).

## Referencias

- `docs/CICD.md` — Pipeline de CI/CD
- `docs/ACCESOS_SERVER.md` — Inventario de accesos
- `docs/OPERATIVA_DEV.md` — Metodologia
