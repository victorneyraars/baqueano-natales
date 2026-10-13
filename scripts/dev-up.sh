#!/usr/bin/env bash
# Levanta (o recrea) el backend de DESARROLLO
# Uso: scripts/dev-up.sh [--build]
set -euo pipefail
cd "$(dirname "$0")/.."

BUILD_FLAG=""
if [[ "${1:-}" == "--build" ]]; then
    BUILD_FLAG="--build"
fi

echo "==> Levantando backend-dev ${BUILD_FLAG:+(con build)}"
docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d $BUILD_FLAG

echo "==> Estado:"
docker compose -f docker-compose.yml -f docker-compose.dev.yml ps
