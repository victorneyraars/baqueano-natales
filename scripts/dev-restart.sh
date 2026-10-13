#!/usr/bin/env bash
# Reinicia el backend de DESARROLLO (sin recrear el container)
# Uso: scripts/dev-restart.sh
set -euo pipefail
cd "$(dirname "$0")/.."

echo "==> Reiniciando backend-dev"
docker compose -f docker-compose.yml -f docker-compose.dev.yml restart backend-dev
