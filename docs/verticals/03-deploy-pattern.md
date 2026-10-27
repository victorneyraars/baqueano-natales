# 03 - Patrón Deploy (Docker + Nginx + SSL + DNS)

> Guía paso a paso para poner en producción una nueva vertical.

## Arquitectura de deploy

~~~text
Internet
  ↓
Cloudflare DNS (A @ → IP servidor)
  ↓
Nginx (Docker: baqueano_nginx, puertos 80/443)
  ↓ (proxy interno por red Docker)
Next.js standalone (Docker: <vertical>_web, puerto 3000)
  ↓ (fetch)
FastAPI Backend (Docker: baqueano_backend_dev/prod, puerto 8000)
~~~

**Red Docker compartida**: `baqueano-natales_baqueano_net`.

## Paso 1: `Dockerfile` multi-stage

Crear `/home/deploy/<vertical>-web/Dockerfile`:

~~~dockerfile
FROM node:22-alpine AS base

FROM base AS deps
RUN apk add --no-cache libc6-compat
WORKDIR /app
COPY package.json pnpm-lock.yaml* pnpm-workspace.yaml* ./
RUN corepack enable pnpm && pnpm install --frozen-lockfile

FROM base AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .
ENV NEXT_TELEMETRY_DISABLED=1
RUN corepack enable pnpm && pnpm run build

FROM base AS runner
WORKDIR /app
ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1
RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs

COPY --from=builder /app/public ./public
RUN mkdir .next && chown nextjs:nodejs .next
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

USER nextjs
EXPOSE 3000
ENV PORT=3000
ENV HOSTNAME="0.0.0.0"
CMD ["node", "server.js"]
~~~

## Paso 2: `.dockerignore`

~~~text
node_modules
.next
.git
.gitignore
.env.local
.env*.local
npm-debug.log*
pnpm-debug.log*
README.md
Dockerfile
.dockerignore
~~~

## Paso 3: `docker-compose.rentacar.yml` (o `<vertical>.yml`)

~~~yaml
services:
  <vertical>-web:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: <vertical>_web
    restart: unless-stopped
    env_file:
      - .env.production
    expose:
      - "3000"
    healthcheck:
      test: ["CMD", "wget", "-q", "-O", "/dev/null", "http://127.0.0.1:3000/"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
    networks:
      - baqueano_net

networks:
  baqueano_net:
    external: true
    name: baqueano-natales_baqueano_net
~~~

**Nota sobre healthcheck**: usar `wget -q -O /dev/null` (no `--spider`) porque en Alpine la opción `--spider` falla silenciosamente en algunos casos.

## Paso 4: Build + Deploy del container

~~~bash
cd /home/deploy/<vertical>-web
sudo docker compose -f docker-compose.<vertical>.yml build
sudo docker compose -f docker-compose.<vertical>.yml up -d
sleep 20
sudo docker ps | grep <vertical>
~~~

**Verificar**:

- Container `Up (healthy)`.
- Logs: `▲ Next.js 16.4.3` + `✓ Ready`.

## Paso 5: Nginx config

Crear `/home/deploy/baqueano-natales/deploy/nginx/conf.d/<dominio>.conf`:

~~~nginx
server {
    listen 80;
    listen [::]:80;
    server_name <dominio>.com www.<dominio>.com;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl;
    listen [::]:443 ssl;
    http2 on;
    server_name <dominio>.com www.<dominio>.com;

    ssl_certificate     /etc/nginx/certs/<dominio>.crt;
    ssl_certificate_key /etc/nginx/certs/<dominio>.key;
    ssl_protocols       TLSv1.2 TLSv1.3;
    ssl_ciphers         HIGH:!aNULL:!MD5;
    ssl_session_cache   shared:SSL:10m;

    access_log /var/log/nginx/<dominio>.access.log;
    error_log  /var/log/nginx/<dominio>.error.log;

    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;

    location /_next/static/ {
        proxy_pass http://<vertical>_web:3000;
        add_header Cache-Control "public, max-age=31536000, immutable";
    }

    location / {
        proxy_pass http://<vertical>_web:3000;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        proxy_read_timeout 60s;
    }
}
~~~

**CRÍTICO**: **NO usar `proxy_cache`** en `/_next/static/`. Puede cachear respuestas vacías (bug real que nos pasó) y servir CSS roto. Next.js ya maneja el cache con hashes en los nombres.

## Paso 6: Certificado SSL con acme.sh

Ya tienes `acme.sh` instalado en `~/.acme.sh/` y las credenciales de Cloudflare en `$CF_API_KEY` / `$CF_API_EMAIL`.

### 6.1 Emitir certificado (Let's Encrypt via Cloudflare DNS-01)

~~~bash
export CF_Key="$CF_API_KEY"
export CF_Email="$CF_API_EMAIL"

~/.acme.sh/acme.sh --issue --dns dns_cf \
  -d <dominio>.com -d www.<dominio>.com \
  --keylength ec-256
~~~

**Tarda 30-90 segundos** mientras propaga el TXT record `_acme-challenge.<dominio>.com`.

### 6.2 Instalar cert en la carpeta compartida de nginx

~~~bash
~/.acme.sh/acme.sh --install-cert -d <dominio>.com --ecc \
  --key-file /home/deploy/baqueano-natales/deploy/nginx/certs/<dominio>.key \
  --fullchain-file /home/deploy/baqueano-natales/deploy/nginx/certs/<dominio>.crt \
  --reloadcmd "sudo docker exec baqueano_nginx nginx -s reload"
~~~

### 6.3 Verificar

~~~bash
sudo ls -la /home/deploy/baqueano-natales/deploy/nginx/certs/ | grep <dominio>
# Debe mostrar <dominio>.crt y <dominio>.key
~~~

**Renovación automática**: `acme.sh` renueva cada 60 días y ejecuta el `--reloadcmd` automáticamente. No hay que hacer nada.

## Paso 7: DNS en Cloudflare (vía API)

### 7.1 Obtener Zone ID

~~~bash
curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=<dominio>.com" \
  -H "X-Auth-Email: $CF_API_EMAIL" \
  -H "X-Auth-Key: $CF_API_KEY" \
  -H "Content-Type: application/json" | python3 -c "
import sys, json
d = json.load(sys.stdin)
z = d['result'][0]
print(f\"Zone ID: {z['id']}\")
"
~~~

Anotar el Zone ID.

### 7.2 Crear registros A

~~~bash
ZONE_ID="<zone-id-obtenido-arriba>"
SERVER_IP=$(curl -s ifconfig.me)

for RECORD in "@" "www"; do
  curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records" \
    -H "X-Auth-Email: $CF_API_EMAIL" \
    -H "X-Auth-Key: $CF_API_KEY" \
    -H "Content-Type: application/json" \
    --data "{\"type\":\"A\",\"name\":\"$RECORD\",\"content\":\"$SERVER_IP\",\"ttl\":1,\"proxied\":false}"
done
~~~

**`proxied: false`** (naranja apagado) para que Let's Encrypt valide directo y el SSL funcione. Activar `proxied: true` requiere cambiar a Cloudflare Origin cert (más complejo, no necesario al inicio).

### 7.3 Esperar propagación DNS

~~~bash
sleep 30
dig +short <dominio>.com
dig +short www.<dominio>.com
# Ambos deben mostrar $SERVER_IP
~~~

## Paso 8: Verificación final

~~~bash
# 1. Test nginx config
sudo docker exec baqueano_nginx nginx -t

# 2. Recargar nginx
sudo docker exec baqueano_nginx nginx -s reload

# 3. Test público apex
curl -s -o /dev/null -w "apex: HTTP %{http_code}\n" https://<dominio>.com/

# 4. Test público www
curl -s -o /dev/null -w "www:  HTTP %{http_code}\n" https://www.<dominio>.com/

# 5. Verificar contenido
curl -s https://<dominio>.com/ | grep -oE "<Texto-buscado>" | sort -u

# 6. Verificar CSS (debe ser >10.000 bytes)
CSS_FILE=$(curl -s https://<dominio>.com/ | grep -oE 'href="[^"]+\.css"' | head -1 | sed 's/href="//;s/"//g')
curl -s "https://<dominio>.com$CSS_FILE" | wc -c

# 7. Verificar SSL
curl -sv https://<dominio>.com/ 2>&1 | grep -E "subject:|issuer:|expire"
~~~

**Todos deben devolver HTTP 200** y el CSS >10.000 bytes.

## Troubleshooting del deploy

| Síntoma | Causa | Solución |
|---|---|---|
| CSS vacío (0 bytes) | `postcss.config.mjs` faltante | Ver Doc 02 Paso 2 |
| CSS vacío a pesar de existir | `proxy_cache` en nginx cacheó respuesta vacía | Quitar `proxy_cache_valid` de `/_next/static/` |
| `host not found in upstream` | Container no existe aún | Build + up del container ANTES de `nginx -t` |
| `certificate has expired` | acme.sh no renovó | `~/.acme.sh/acme.sh --renew -d <dominio>.com` |
| `DNS not resolving` | Propagación pendiente | Esperar 5-15 min, verificar con `dig` |
| Healthcheck unhealthy | `wget --spider` falla en Alpine | Cambiar a `wget -q -O /dev/null` |

## Rollback

Si algo sale mal en producción:

~~~bash
# Detener container
sudo docker compose -f docker-compose.<vertical>.yml down

# Revertir nginx (eliminar el .conf)
sudo rm /home/deploy/baqueano-natales/deploy/nginx/conf.d/<dominio>.conf
sudo docker exec baqueano_nginx nginx -s reload

# Eliminar DNS (opcional, si se quiere despublicar)
# Usar Cloudflare API DELETE /dns_records/<record-id>
~~~

## Referencias del caso real

- **Dockerfile**: `/home/deploy/rentacarvasquez-web/Dockerfile`
- **Docker Compose**: `/home/deploy/rentacarvasquez-web/docker-compose.rentacar.yml`
- **Nginx config**: `/home/deploy/baqueano-natales/deploy/nginx/conf.d/rentacarvasquez.conf`
- **Cert SSL**: `/home/deploy/baqueano-natales/deploy/nginx/certs/rentacarvasquez.{crt,key}`

## Checklist de deploy completo

- [ ] `next.config.ts` con `output: "standalone"`
- [ ] `postcss.config.mjs` creado (CRÍTICO para Tailwind)
- [ ] `Dockerfile` multi-stage
- [ ] `.dockerignore`
- [ ] `docker-compose.<vertical>.yml` en red `baqueano_net`
- [ ] Container `Up (healthy)`
- [ ] `nginx/conf.d/<dominio>.conf` con SSL y sin `proxy_cache`
- [ ] Cert SSL emitido y verificado
- [ ] DNS apex + www en Cloudflare
- [ ] HTTP 200 en apex + www
- [ ] CSS >10.000 bytes servido correctamente
- [ ] Certificado válido (no expirado)
- [ ] Contenido renderizado desde el backend

---

**Tiempo total de deploy**: 45-60 minutos por vertical (primera vez), 15-20 min (réplicas).
