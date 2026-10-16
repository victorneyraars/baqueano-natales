#!/bin/bash
# Deploy automatico del backend a DEV.
# Uso: bash scripts/deploy-dev.sh
#
# Hace: pull + rebuild + restart + healthcheck.
# Si el healthcheck falla, sale con codigo != 0.

set -e
cd ~/baqueano-natales

echo "================================================================"
echo "  DEPLOY BACKEND DEV"
echo "  $(date '+%Y-%m-%d %H:%M:%S')"
echo "================================================================"
echo ""

echo "=== 1/4 - git pull --rebase ==="
git pull --rebase origin main
echo ""

echo "=== 2/4 - Build imagen backend-dev ==="
docker compose -f docker-compose.yml -f docker-compose.dev.yml build backend-dev
echo ""

echo "=== 3/4 - Recrear container backend-dev ==="
docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d backend-dev
echo ""

echo "=== 4/4 - Healthcheck (esperando 5s) ==="
sleep 5
HEALTH=$(curl -fsS https://api-dev.baqueanonatales.com/health)
echo "$HEALTH"
if echo "$HEALTH" | grep -q '"status":"ok"'; then
    echo ""
    echo "================================================================"
    echo "  DEPLOY OK"
    echo "================================================================"
    docker ps --format 'table {{.Names}}\t{{.Status}}' | grep backend
    exit 0
else
    echo ""
    echo "================================================================"
    echo "  ERROR: Healthcheck fallo. Revisar logs."
    echo "================================================================"
    docker compose -f docker-compose.yml -f docker-compose.dev.yml logs --tail=50 backend-dev
    exit 1
fi