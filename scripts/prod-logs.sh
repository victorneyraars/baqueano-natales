#!/usr/bin/env bash
# Logs de backend-prod (follow por defecto)
# Uso: scripts/prod-logs.sh [--tail=N]
set -euo pipefail
cd "$(dirname "$0")/.."

docker compose -f docker-compose.yml -f docker-compose.prod.yml logs -f --tail="${1:-50}" backend-prod
