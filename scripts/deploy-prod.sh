#!/bin/bash
# Deploy automatico del backend a PROD.
# Uso: bash scripts/deploy-prod.sh
#
# IMPORTANTE: pide confirmacion antes de tocar produccion.
# Hace: pull + rebuild + restart + healthcheck.

set -e
cd ~/baqueano-natales

echo "================================================================"
echo "  DEPLOY BACKEND PROD"
echo "  $(date '+%Y-%m-%d %H:%M:%S')"
echo "================================================================"
echo ""
echo "ADVERTENCIA: esto va a tocar PRODUCCION (api.baqueanonatales.com)."
echo ""
read -p "Escribi CONFIRMAR para continuar: " CONFIRM
if [ "$CONFIRM" != "CONFIRMAR" ]; then
    echo "Cancelado."
    exit 1
fi
echo ""

echo "=== 1/4 - git pull --rebase ==="
git pull --rebase origin main
echo ""

echo "=== 2/4 - Build imagen backend-prod ==="
docker compose -f docker-compose.yml -f docker-compose.prod.yml build backend-prod
echo ""

echo "=== 3/4 - Recrear container backend-prod ==="
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d backend-prod
echo ""

echo "=== 4/4 - Healthcheck (esperando 5s) ==="
sleep 5
HEALTH=$(curl -fsS https://api.baqueanonatales.com/health)
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
    docker compose -f docker-compose.yml -f docker-compose.prod.yml logs --tail=50 backend-prod
    exit 1
fi