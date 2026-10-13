#!/usr/bin/env bash
# Logs de backend-dev (follow por defecto)
# Uso: scripts/dev-logs.sh [--tail=N]
set -euo pipefail
cd "$(dirname "$0")/.."

docker compose -f docker-compose.yml -f docker-compose.dev.yml logs -f --tail="${1:-50}" backend-dev
