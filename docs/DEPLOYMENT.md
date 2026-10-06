# Deployment — Baqueano Natales

Guía completa de despliegue, actualización y rollback del sistema.

## Entornos

| Entorno | Server | Dominio | Rama Git |
|---|---|---|---|
| Producción | baqueano-natales-prod (104.129.59.151) | api.baqueanonatales.com | main |
| Desarrollo | Local | localhost:8000 | cualquier rama |

## Requisitos del servidor

- Ubuntu 24.04 LTS
- Docker 29+
- Docker Compose 5+
- Acceso SSH con clave (usuario `deploy`)
- Dominio apuntando al servidor (Cloudflare)

## Primera instalación

### 1. Preparar el servidor

```bash
# Actualizar sistema
sudo apt update && sudo apt upgrade -y

# Instalar Docker (si no está)
sudo apt install -y docker.io docker-compose-v2
sudo usermod -aG docker deploy

# Cerrar sesión y reconectar para aplicar grupo docker
exit
```

### 2. Clonar el repositorio

```bash
cd ~
git clone git@github.com:victorneyraars/baqueano-natales.git
cd baqueano-natales
```

### 3. Configurar variables de entorno

```bash
cp .env.example .env
chmod 600 .env
nano .env  # Editar con valores reales
```

### 4. Levantar el stack

```bash
docker compose up -d --build
```

### 5. Verificar

```bash
# Estado de contenedores
docker compose ps

# Healthcheck del backend
curl http://localhost/health

# Healthcheck de nginx
curl http://localhost/nginx-health
```

Todos los servicios deben estar `Up (healthy)`.

## Actualización (deploy)

### Opción A — Deploy manual

```bash
cd ~/baqueano-natales

# 1. Traer cambios
git pull origin main

# 2. Rebuild si cambió código
docker compose build backend

# 3. Aplicar migraciones DB
docker compose exec backend alembic upgrade head

# 4. Reiniciar servicios
docker compose up -d

# 5. Verificar
docker compose ps
curl http://localhost/health
```

### Opción B — Deploy automático (GitHub Actions)

(pendiente de configurar)

## Rollback

### Rollback de código

```bash
cd ~/baqueano-natales

# Ver commits recientes
git log --oneline -10

# Volver a un commit anterior
git checkout <commit-hash>

# Rebuild y restart
docker compose build backend
docker compose up -d
```

### Rollback de base de datos

```bash
# 1. Parar el backend
docker compose stop backend

# 2. Restaurar desde backup
gunzip -c backups/xxx.sql.gz | docker compose exec -T db psql -U baqueano_user baqueano_natales

# 3. Reiniciar
docker compose start backend
```

## Backups

### Backup manual

```bash
./deploy/scripts/backup-db.sh
```

### Backup automático

Cron diario a las 3 AM UTC.

### Restaurar backup

```bash
gunzip -c backups/baqueano_natales_YYYYMMDD.sql.gz | \
  docker compose exec -T db psql -U baqueano_user baqueano_natales
```

## Troubleshooting

### El backend no arranca

```bash
docker compose logs backend | tail -n 50
```

Causas comunes:
- `.env` mal configurado (faltan variables)
- Error de import en Python
- Base de datos no disponible

### Nginx da 502 Bad Gateway

El backend no está respondiendo. Verificar:

```bash
docker compose ps backend
docker compose logs backend | tail -n 30
```

### La base de datos no arranca

```bash
docker compose logs db | tail -n 30
```

Causas comunes:
- Volumen corrupto
- Contraseña incorrecta en `.env`
- Falta de espacio en disco

### Puerto 80/443 ocupado

```bash
sudo ss -tulpn | grep -E ":80|:443"
```

Matar el proceso conflictivo o cambiar el puerto en `docker-compose.yml`.

## Comandos útiles

```bash
# Ver logs en vivo
docker compose logs -f backend

# Entrar al shell del backend
docker compose exec backend bash

# Entrar a psql
docker compose exec db psql -U baqueano_user baqueano_natales

# Reiniciar un servicio
docker compose restart backend

# Ver uso de recursos
docker stats

# Limpiar imágenes viejas
docker image prune -a
```

## Certificados TLS

(pendiente de configurar con Certbot)

## Dominios

Gestión en Cloudflare. Ver `docs/ARCHITECTURE.md`.
