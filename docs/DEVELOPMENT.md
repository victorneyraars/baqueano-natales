# Development — Baqueano Natales

Guía para desarrollar en el proyecto.

## Setup local

### 1. Clonar

```bash
git clone git@github.com:victorneyraars/baqueano-natales.git
cd baqueano-natales
```

### 2. Variables de entorno

```bash
cp .env.example .env
# Editar con valores de desarrollo
nano .env
```

Para desarrollo local, cambiar:
- `ENVIRONMENT=development`
- `DEBUG=true`

### 3. Levantar el stack

```bash
docker compose up -d --build
```

### 4. Verificar

```bash
curl http://localhost/health
# En modo development, /docs está disponible:
# http://localhost/docs
```

## Estructura del backend

```
backend/app/
├── core/                 # Configuración central
│   ├── config.py         # Settings (pydantic)
│   ├── logging.py        # Logs JSON
│   ├── db.py             # Conexión SQLAlchemy
│   └── security.py       # JWT, hashing
├── modules/              # Por dominio de negocio
│   ├── auth/
│   │   ├── models.py     # Tablas SQLAlchemy
│   │   ├── schemas.py    # Pydantic
│   │   ├── routes.py     # Endpoints
│   │   ├── services.py   # Lógica de negocio
│   │   └── tests/
│   ├── usuarios/
│   ├── comercios/
│   ├── pedidos/
│   └── admin/
├── shared/               # Utilidades transversales
└── main.py               # Entry point
```

**Principio:** cada módulo es autocontenido. Si crece, se puede extraer a microservicio sin romper el resto.

## Convenciones de código

### Python

- **Formato:** Black (line length 100)
- **Lint:** Ruff
- **Tipos:** anotaciones obligatorias
- **Imports:** ordenados con isort (perfil black)
- **Nombres:** snake_case para funciones/variables, PascalCase para clases

### Git

- **Ramas:** `main` (producción), `dev` (integración), `feat/xxx`, `fix/xxx`
- **Commits:** Conventional Commits
  - `feat:` nueva feature
  - `fix:` corrección
  - `docs:` documentación
  - `refactor:` sin cambio funcional
  - `test:` tests
  - `chore:` tareas varias

Ejemplo:
```
feat(auth): agregar login con Google Sign-In
fix(pedidos): corregir cálculo de tarifa
docs(api): actualizar README con nuevos endpoints
```

## Flujo de trabajo

### Para nueva feature

```bash
# 1. Actualizar main local
git checkout main
git pull origin main

# 2. Crear rama
git checkout -b feat/mi-feature

# 3. Desarrollar
# ... editar archivos ...

# 4. Tests
docker compose exec backend pytest

# 5. Commit
git add .
git commit -m "feat: descripción"

# 6. Push
git push origin feat/mi-feature

# 7. Abrir PR en GitHub
```

### Code review

- Todo cambio va por PR
- Al menos 1 aprobación antes de merge
- CI debe estar en verde

## Tests

### Correr tests

```bash
# Dentro del contenedor
docker compose exec backend pytest

# Con cobertura
docker compose exec backend pytest --cov=app --cov-report=term-missing

# Un archivo específico
docker compose exec backend pytest tests/test_auth.py
```

### Escribir tests

- Un archivo `test_*.py` por módulo
- Usar `pytest` + `pytest-asyncio`
- Base de datos en memoria (SQLite) para tests
- Sin dependencias externas

## Migraciones con Alembic

### Crear nueva migración

```bash
docker compose exec backend alembic revision --autogenerate -m "descripción"
```

### Aplicar migraciones

```bash
docker compose exec backend alembic upgrade head
```

### Ver historial

```bash
docker compose exec backend alembic history
```

### Revertir última migración

```bash
docker compose exec backend alembic downgrade -1
```

## Debugging

### Logs en vivo

```bash
docker compose logs -f backend
```

### Entrar al contenedor

```bash
docker compose exec backend bash
```

### Acceder a la DB

```bash
docker compose exec db psql -U baqueano_user baqueano_natales
```

### Python REPL con contexto

```bash
docker compose exec backend python
>>> from app.core.config import settings
>>> print(settings.ENVIRONMENT)
```

## Hot reload

En desarrollo, el backend tiene hot reload activado.
Los cambios en `backend/app/` se aplican automáticamente.

Para activarlo, usar `docker-compose.dev.yml`:

```bash
docker compose -f docker-compose.yml -f docker-compose.dev.yml up
```

## Agregar dependencias

```bash
# 1. Editar requirements.txt
nano backend/requirements.txt

# 2. Rebuild
docker compose build backend

# 3. Restart
docker compose up -d backend
```

## Recursos

- [FastAPI docs](https://fastapi.tiangolo.com/)
- [SQLAlchemy 2.0](https://docs.sqlalchemy.org/en/20/)
- [Alembic](https://alembic.sqlalchemy.org/)
- [Pydantic v2](https://docs.pydantic.dev/)
- [Docker Compose](https://docs.docker.com/compose/)
