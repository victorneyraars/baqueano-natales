# Arquitectura — Baqueano Natales

> **Última actualización:** 2026-10-08
> **Estado:** Documento vivo. Se actualiza cuando cambia la infraestructura o la arquitectura modular.

---

## Visión general

Cliente (Android) y Admin (Android) consumen la API publicada en `api.baqueanonatales.com`, servida por Nginx (reverse proxy) que enruta al backend FastAPI. El backend accede a PostgreSQL 16. La landing pública (`baqueanonatales.com`) se hostea en Vercel como sitio estático.

---

## Componentes

### Cliente (app móvil)
- **Tecnología:** Flutter (Android)
- **Distribución:** Play Store
- **Autenticación:** Google Sign-In + OTP WhatsApp + OTP SMS
- **Consume:** `api.baqueanonatales.com`

### Admin (app móvil)
- **Tecnología:** Flutter (Android, flavor admin)
- **Distribución:** Firebase App Distribution (uso interno)
- **Autenticación:** Google Sign-In + rol admin
- **Consume:** `api.baqueanonatales.com/api/v1/admin/*`

### Backend (API)
- **Tecnología:** Python 3.12 + FastAPI + SQLAlchemy 2.0 (async)
- **Arquitectura interna:** **monolito modular** (ver sección siguiente)
- **Autenticación:** JWT propio + verificación con Firebase
- **Rate limiting:** slowapi (backend) + nginx (borde)
- **Logs:** JSON estructurado a stdout
- **OpenAPI:** auto-generado por FastAPI

### Base de datos
- **Tecnología:** PostgreSQL 16
- **Migraciones:** Alembic
- **Persistencia:** volumen Docker `postgres_data`
- **Backups:** pg_dump + GPG + Backblaze B2

### Reverse proxy
- **Tecnología:** Nginx 1.27 (Docker)
- **Función:** terminar TLS, rate limiting, headers de seguridad
- **TLS:** Let's Encrypt (Certbot) — pendiente Fase 6

### Landing
- **Tecnología:** Astro (hosteado en Vercel)
- **Dominio:** `baqueanonatales.com` + `www`
- **No consume API directamente**

---

## 🏛️ Arquitectura modular (la base de todo)

**Decisión:** monolito modular **ahora**. Migración a microservicios **solo cuando haga falta** (nunca antes).

### Estructura del backend

```
backend/app/
├── core/              # Transversal: config, db, security, logging, firebase
├── shared/            # Transversal reutilizable: media, geo, notif, chat, reviews
└── modules/           # Verticales (cada uno autocontenido)
    ├── auth/          # ✅ Implementado
    ├── usuarios/      # ✅ Implementado
    ├── admin/         # ✅ Implementado
    ├── comercios/     # ✅ Implementado
    ├── prestadores/   # 🎯 En desarrollo (mecánica primero)
    ├── socios/        # ⏳ Movilidad
    ├── solicitudes/   # ⏳ Movilidad
    ├── alojamientos/  # ⏳ Futuro
    └── ...
```

### Reglas de import (obligatorias)

| Regla | Sí | No |
|---|---|---|
| **Un módulo NO importa modelos de otro** | `from app.modules.auth.schemas import UsuarioResponse` | `from app.modules.auth.models import Usuario` |
| **Transversal vive en `core/` o `shared/`** | `from app.core.security import create_token` | Meter auth dentro de `comercios/` |
| **Comunicación entre módulos vía servicios** | Llamar a `auth_services.get_user_by_id()` | Importar `models.Usuario` directo |
| **Endpoints con su propio `prefix`** | `router = APIRouter(prefix="/comercios")` | Rutas mezcladas en `main.py` |

**Por qué:** si un módulo necesita datos de otro, lo hace por **contrato** (schemas + servicios), no por **implementación** (models). Así, cuando ese módulo se extraiga a microservicio, no se rompe nada.

### Transversal vs. Vertical

**Transversal** = se construye UNA vez, lo usan TODOS los verticales.

| Transversal | Ubicación | Sirve para |
|---|---|---|
| Config | `core/config.py` | Todos |
| DB | `core/db.py` | Todos |
| Security (JWT) | `core/security.py` | Todos |
| Firebase Admin | `core/firebase.py` | Todos |
| Logging JSON | `core/logging.py` | Todos |
| Media (upload) | `shared/storage/` | Avatares, logos, fotos |
| Chat | `shared/chat/` (⏳) | Movilidad, hospedaje, marketplace |
| Reviews | `shared/reviews/` (⏳) | Cualquier actor con rating |
| Geo | `shared/geo/` (⏳) | Movilidad, hospedaje, delivery |
| Notif (FCM) | `shared/notif/` (⏳) | Todos |

**Vertical** = un dominio de negocio completo con sus propios modelos/endpoints/flujos.

---

## 🚦 Cómo se agrega un módulo nuevo

**Regla de oro:** nunca se mete un vertical dentro de otro. Siempre se crea un módulo nuevo.

**Checklist:**

1. **Nombrar el módulo** (`alojamientos`, `marketplace`, etc.)
2. **Definir el actor de oferta** (¿rol nuevo? ¿perfil sobre `usuarios`?)
3. **Diseñar el modelo de datos** — patrón `comercios`:
   - `models.py` (SQLAlchemy con UUID, enums tipados, timestamps)
   - `schemas.py` (Pydantic con validaciones)
   - `services.py` (lógica de negocio + state machine)
   - `deps.py` (dependencias FastAPI específicas)
   - `routes.py` (endpoints)
   - `seed.py` (datos iniciales idempotentes)
4. **Identificar qué transversales reutiliza**
5. **Migración Alembic** (`alembic revision --autogenerate`)
6. **Registrar en `main.py`** con su `prefix` y `tags`
7. **Documentar** en `CONTEXTO_PROYECTO.md` y `VISION.md`

---

## 🔌 Consumo por otros proyectos (futuro)

La API ya está preparada para ser consumida por otros proyectos del studio:

| Tipo | Ejemplo | Disponible hoy |
|---|---|---|
| **API REST pública** | `GET /api/v1/comercios` | ✅ |
| **OpenAPI / Swagger** | `GET /openapi.json` (solo dev) | ✅ |
| **SDK autogenerado** | Desde OpenAPI | ⏳ Se genera cuando haya consumidor |
| **Webhooks** | `comercio.verificado`, `viaje.completado` | ⏳ Futuro |
| **Auth delegado** | Otro proyecto usa nuestro JWT | ⏳ Futuro |

**Decisión actual:** versionado estricto (`/api/v1/`). No se rompe compatibilidad sin subir versión.

---

## Redes y dominios

| Dominio | Apunta a | Servicio |
|---|---|---|
| `api.baqueanonatales.com` | Server nuevo (`104.129.59.151`) | Backend API |
| `baqueanonatales.com` | Vercel | Landing |
| `www.baqueanonatales.com` | Vercel | Landing |

---

## Estructura del repositorio

```
baqueano-natales/
├── backend/              # API FastAPI
│   ├── app/
│   │   ├── core/         # config, logging, security, db, firebase
│   │   ├── shared/       # media, geo, chat, reviews (transversal)
│   │   └── modules/      # por dominio (verticales)
│   ├── alembic/          # migraciones DB
│   ├── tests/
│   └── Dockerfile
├── flutter/              # Apps Flutter (cliente + admin)
├── deploy/               # nginx, scripts, systemd
├── docs/                 # documentación
├── docker-compose.yml
└── README.md
```

---

## Principios de diseño

1. **Modularidad estricta** — un módulo no importa modelos de otro
2. **Transversal o vertical** — toda feature se clasifica en una categoría
3. **API-first** — contratos versionados, OpenAPI auto-generado
4. **Humano en el loop** — decisiones críticas las toma un admin
5. **Idempotencia** — seeds y migraciones corren N veces sin romper
6. **Preparado para escalar, sin sobre-ingeniería** — monolito ahora, extracción después
7. **Configuración por entorno** — `.env`, sin hardcodeo
8. **Migraciones versionadas** desde el día uno
9. **Deploy idempotente** — `docker compose up -d` siempre
10. **Seguridad por defecto** — TLS, headers, rate limiting, secrets fuera del repo
11. **Observabilidad** — healthchecks, logs JSON estructurados

---

## 🚫 Anti-patrones prohibidos

| Anti-patrón | Por qué está prohibido |
|---|---|
| Meter feature de movilidad dentro de `comercios` | Rompe la modularidad |
| Importar `models.Comercio` desde `modules.prestadores` | Acoplamiento entre verticales |
| Duplicar chat/reviews en cada vertical | Ignora lo transversal |
| Microservicios antes de tener escala | Sobre-ingeniería |
| Enum de roles que crece sin control | Migrar a tabla relacional con 6+ roles |
| Cambiar diseño de vertical en producción sin migración | Rompe usuarios activos |

---

## Stack completo

| Capa | Tecnología |
|---|---|
| App móvil | Flutter 3.47+ |
| API | Python 3.12 + FastAPI |
| ORM | SQLAlchemy 2.0 (async) |
| Migraciones | Alembic |
| DB | PostgreSQL 16 |
| Reverse proxy | Nginx 1.27 |
| TLS | Let's Encrypt (pendiente) |
| Auth | Firebase Auth + JWT |
| Push | Firebase Cloud Messaging |
| OTP WhatsApp | Meta Cloud API |
| OTP SMS | Twilio |
| KYC | Didit |
| RUT | Boostr |
| Patentes | RNSTP (MTT) |
| Contenedores | Docker Compose |
| CI/CD | GitHub Actions (pendiente) |
| Backups | pg_dump + GPG + Backblaze B2 |
| DNS | Cloudflare |
| Landing | Astro (Vercel) |

---

## Referencias

- **Visión de producto:** `docs/VISION.md`
- **Análisis del sistema anterior:** `docs/LEGACY_ANALYSIS.md`
- **Estado del proyecto:** `CONTEXTO_PROYECTO.md`
- **Decisiones arquitectónicas (ADR):** `docs/DECISIONS/`

---

**Fin del documento.**