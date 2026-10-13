#!/usr/bin/env bash
# Baja TODO el stack (incluye db y nginx)
# Uso: scripts/all-down.sh
# ATENCION: baja la DB. Para bajar solo los backends usar prod-down.sh y dev-down.sh
set -euo pipefail
cd "$(dirname "$0")/.."

echo "==> Bajando stack completo (incluye db y nginx)"
docker compose \
    -f docker-compose.yml \
    -f docker-compose.prod.yml \
    -f docker-compose.dev.yml \
    down
