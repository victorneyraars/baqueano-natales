#!/usr/bin/env bash
# Estado consolidado de todos los entornos
# Uso: scripts/status.sh
set -euo pipefail
cd "$(dirname "$0")/.."

echo "=========================================="
echo "  Estado del stack Baqueano Natales"
echo "=========================================="
echo ""

echo "==> Contenedores:"
docker compose \
    -f docker-compose.yml \
    -f docker-compose.prod.yml \
    -f docker-compose.dev.yml \
    ps -a

echo ""
echo "==> Health publico prod:"
curl -sS -m 5 https://api.baqueanonatales.com/health 2>&1 || echo "  (sin respuesta)"

echo ""
echo "==> Health publico dev:"
curl -sS -m 5 https://api-dev.baqueanonatales.com/health 2>&1 || echo "  (sin respuesta)"

echo ""
echo "==> Uso de recursos:"
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}" 2>/dev/null || true
