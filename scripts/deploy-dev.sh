#!/bin/bash
# Deploy automatico del backend a DEV.
# Uso: bash scripts/deploy-dev.sh
#
# Hace: pull + rebuild + restart + healthcheck (con retry).

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

echo "=== 4/4 - Healthcheck (retry hasta 60s) ==="
URL="https://api-dev.baqueanonatales.com/health"
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
    docker compose -f docker-compose.yml -f docker-compose.dev.yml logs --tail=50 backend-dev
    exit 1
fi