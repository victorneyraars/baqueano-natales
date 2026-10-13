#!/usr/bin/env bash
# Baja solo el backend de PRODUCCION (deja db y nginx)
# Uso: scripts/prod-down.sh
set -euo pipefail
cd "$(dirname "$0")/.."

echo "==> Bajando backend-prod"
docker compose -f docker-compose.yml -f docker-compose.prod.yml down
