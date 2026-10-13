#!/usr/bin/env bash
# Reinicia el backend de PRODUCCION (sin recrear el container)
# Uso: scripts/prod-restart.sh
set -euo pipefail
cd "$(dirname "$0")/.."

echo "==> Reiniciando backend-prod"
docker compose -f docker-compose.yml -f docker-compose.prod.yml restart backend-prod
