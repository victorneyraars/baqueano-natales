# Baqueano Natales

Superapp regional para Puerto Natales: movilidad, delivery, encomiendas y servicios locales.

## Estructura

```
baqueano-natales/
├── backend/          # API FastAPI (Python 3.12)
├── flutter/          # Apps Flutter (cliente + admin, flavors)
├── deploy/           # Configs de infraestructura
├── docs/             # Documentación y ADRs
└── docker-compose.yml
```

## Stack

| Capa | Tecnología |
|---|---|
| Backend | Python 3.12, FastAPI, SQLAlchemy 2.0 |
| Base de datos | PostgreSQL 16 |
| Reverse proxy | Nginx 1.27 |
| Apps móviles | Flutter (cliente + admin) |
| Contenedores | Docker Compose |

## Servicios

- **API:** https://api.baqueanonatales.com
- **Landing:** https://baqueanonatales.com (Vercel)

## Setup rápido

```bash
cp .env.example .env
nano .env
docker compose up -d --build
curl http://localhost/health
```

## Licencia

Privado. Todos los derechos reservados.

## 🐛 Bugs resueltos
- [Épico: OAuth Motorola](docs/EPIC-OAUTH-MOTOROLA.md)

## Verticales

Cada vertical de Baqueano Natales tiene su propio dominio, backend y web premium. Ver [docs/verticals/](docs/verticals/) para la documentación completa.

| Vertical | Dominio | Estado |
|---|---|---|
| Oficios | sealquilamarido.cl | ✅ Producción |
| Rent a Car Vásquez | rentacarvasquez.com | ✅ Producción |

**Documentación:**
- [Patrón Backend](docs/verticals/01-backend-pattern.md)
- [Patrón Frontend](docs/verticals/02-frontend-pattern.md)
- [Patrón Deploy](docs/verticals/03-deploy-pattern.md)
- [Troubleshooting](docs/verticals/04-troubleshooting.md)
- [Caso: Rent a Car Vásquez](docs/verticals/rentacar-vasquez-case-study.md)
