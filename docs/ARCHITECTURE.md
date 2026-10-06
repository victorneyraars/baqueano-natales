# Arquitectura — Baqueano Natales

Este documento describe la arquitectura de la superapp regional Baqueano Natales.

## Visión general

Cliente (Android) y Admin (Android) consumen la API publicada en `api.baqueanonatales.com`,
la cual es servida por Nginx (reverse proxy) que enruta al backend FastAPI.
El backend accede a PostgreSQL 16. La landing pública (`baqueanonatales.com`)
se hostea en Vercel como sitio estático.

## Componentes

### Cliente (app móvil)
- **Tecnología:** Flutter (Android)
- **Distribución:** Play Store
- **Autenticación:** Google Sign-In + OTP WhatsApp + OTP SMS
- **Consume:** api.baqueanonatales.com

### Admin (app móvil)
- **Tecnología:** Flutter (Android, flavor admin)
- **Distribución:** Firebase App Distribution (uso interno)
- **Autenticación:** Google Sign-In + rol admin
- **Consume:** api.baqueanonatales.com/api/v1/admin/*

### Backend (API)
- **Tecnología:** Python 3.12 + FastAPI + SQLAlchemy 2.0
- **Arquitectura interna:** módulos por dominio
- **Autenticación:** JWT propio + verificación con Firebase
- **Rate limiting:** slowapi (backend) + nginx (borde)
- **Logs:** JSON estructurado a stdout

### Base de datos
- **Tecnología:** PostgreSQL 16
- **Migraciones:** Alembic
- **Persistencia:** volumen Docker postgres_data
- **Backups:** pg_dump + GPG + Backblaze B2

### Reverse proxy
- **Tecnología:** Nginx 1.27 (Docker)
- **Función:** terminar TLS, rate limiting, headers de seguridad
- **TLS:** Let's Encrypt (Certbot)

### Landing
- **Tecnología:** Astro (hosteado en Vercel)
- **Dominio:** baqueanonatales.com + www
- **No consume API** directamente

## Redes y dominios

| Dominio | Apunta a | Servicio |
|---|---|---|
| api.baqueanonatales.com | Server nuevo | Backend API |
| baqueanonatales.com | Vercel | Landing |
| www.baqueanonatales.com | Vercel | Landing |

## Estructura del repositorio

```
baqueano-natales/
├── backend/              # API FastAPI
│   ├── app/
│   │   ├── core/         # config, logging, security, db
│   │   ├── modules/      # por dominio de negocio
│   │   └── shared/
│   ├── alembic/          # migraciones DB
│   ├── tests/
│   └── Dockerfile
├── flutter/              # Apps Flutter (cliente + admin)
├── deploy/               # nginx, scripts, systemd
├── docs/                 # esta carpeta
├── docker-compose.yml
└── README.md
```

## Principios de diseño

1. Separación de responsabilidades.
2. Configuración por entorno.
3. Contratos estables (API versionada).
4. Migraciones versionadas desde el día uno.
5. Deploy idempotente.
6. Infra como código.
7. Seguridad por defecto.
8. Observabilidad (healthchecks, logs).
9. Evolutivo (fácil refactorizar).

## Stack completo

| Capa | Tecnología |
|---|---|
| App móvil | Flutter 3.27+ |
| API | Python 3.12 + FastAPI |
| ORM | SQLAlchemy 2.0 |
| Migraciones | Alembic |
| DB | PostgreSQL 16 |
| Reverse proxy | Nginx 1.27 |
| TLS | Let's Encrypt |
| Auth | Firebase Auth + JWT |
| Push | Firebase Cloud Messaging |
| OTP WhatsApp | Meta Cloud API |
| OTP SMS | Twilio |
| Contenedores | Docker Compose |
| CI/CD | GitHub Actions |
| Backups | pg_dump + GPG + Backblaze B2 |
| DNS | Cloudflare |
| Landing | Astro (Vercel) |
