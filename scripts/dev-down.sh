#!/usr/bin/env bash
# Baja solo el backend de DESARROLLO (deja db y nginx)
# Uso: scripts/dev-down.sh
set -euo pipefail
cd "$(dirname "$0")/.."

echo "==> Bajando backend-dev"
docker compose -f docker-compose.yml -f docker-compose.dev.yml down
