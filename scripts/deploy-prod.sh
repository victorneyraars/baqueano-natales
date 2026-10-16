#!/bin/bash
# Deploy automatico del backend a PROD.
# Uso: bash scripts/deploy-prod.sh
#
# IMPORTANTE: pide confirmacion antes de tocar produccion.
# Hace: pull + rebuild + restart + healthcheck (con retry).

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

echo "=== 4/4 - Healthcheck (retry hasta 60s) ==="
URL="https://api.baqueanonatales.com/health"
MAX=20
SLEEP=3
OK=0
for i in $(seq 1 $MAX); do
    HEALTH=$(curl -fsS "$URL" 2>/dev/null || echo "")
    if echo "$HEALTH" | grep -q '"status":"ok"'; then
        echo "  [${i}/${MAX}] OK: $HEALTH"
        OK=1
        break
    fi
    echo "  [${i}/${MAX}] esperando... (intento $i)"
    sleep $SLEEP
done

echo ""
if [ "$OK" = "1" ]; then
    echo "================================================================"
    echo "  DEPLOY OK"
    echo "================================================================"
    docker ps --format 'table {{.Names}}\t{{.Status}}' | grep backend
    exit 0
else
    echo "================================================================"
    echo "  ERROR: Healthcheck fallo tras $((MAX * SLEEP))s."
    echo "================================================================"
    docker compose -f docker-compose.yml -f docker-compose.prod.yml logs --tail=50 backend-prod
    exit 1
fi