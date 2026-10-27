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
