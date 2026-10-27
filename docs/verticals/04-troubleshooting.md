# 04 - Troubleshooting: Bugs Conocidos y Soluciones

> Registro de todos los errores que encontramos durante el desarrollo del primer vertical (Rent a Car Vásquez). Cada uno tiene causa raíz y solución probada.

## Bugs del Backend

### 1. `NoReferencedTableError: Foreign key ... could not find table 'users'`

**Causa**: Se usó `ForeignKey("users.id")` pero la tabla se llama `usuarios` (en español).

**Solución**: Cambiar a `ForeignKey("usuarios.id")` en el modelo.

~~~python
# ❌ MAL
cliente_id = mapped_column(ForeignKey("users.id"))

# ✅ BIEN
cliente_id = mapped_column(ForeignKey("usuarios.id"))
~~~

**Verificar nombres reales**:

~~~bash
docker exec baqueano_db psql -U baqueano_user -d baqueano_natales_dev -c "\dt" | grep -iE "user|usuario"
~~~

---

### 2. `alembic revision --autogenerate` genera `DROP TABLE` peligrosos

**Causa**: Alembic detecta "schema drift" en tablas que no están importadas en `env.py`. Genera migraciones con `op.drop_table('media_assets')` que borrarían datos reales.

**Solución**: **Nunca confiar ciegamente en el autogenerate**. Revisar el archivo generado. Si contiene DROPs de tablas existentes, **borrar la migración y crearla manualmente**.

~~~bash
# 1. Revisar el archivo generado
cat backend/alembic/versions/xxx_add_rentacar_tables.py

# 2. Si tiene DROPs peligrosos, eliminarlo
rm backend/alembic/versions/xxx_add_rentacar_tables.py

# 3. Crear migración manual
# (ver ejemplo: backend/alembic/versions/20261027_manual_rentacar.py)

# 4. Aplicar
docker exec baqueano_backend_dev alembic upgrade head
~~~

**Regla**: Solo crear `op.create_table()` y `op.create_index()`. Nunca `op.drop_table()` o `op.drop_index()` sobre tablas preexistentes.

---

### 3. `ModuleNotFoundError: No module named 'app.core.database'`

**Causa**: El import correcto es `app.core.db`, no `app.core.database`.

**Solución**:

~~~python
# ❌ MAL
from app.core.database import Base

# ✅ BIEN
from app.core.db import Base
~~~

**Verificar imports actuales**:

~~~bash
grep -n "^from app.core" backend/app/modules/social/models.py
~~~

---

### 4. `too many values to unpack (expected 2)` en OAuth

**Causa**: Inconsistencia entre lo que devuelve una función y lo que espera el consumidor. En este caso, `verificar_state()` devolvía 1 valor pero `procesar_callback_oauth()` esperaba 2.

**Solución**: Actualizar la función para devolver la tupla completa con type hint.

~~~python
# ❌ ANTES
def verificar_state(state: str) -> str:
    return sub

# ✅ DESPUÉS
def verificar_state(state: str) -> tuple[str, bool]:
    return sub, app_redirect
~~~

**Regla**: Cuando una función devuelve múltiples valores, documentar el tipo en el type hint (`tuple[str, bool]`) y mantener el contrato con todos sus consumidores.

## Bugs del Frontend

### 5. `spawn pnpm ENOENT` al crear Next.js

**Causa**: `pnpm` no está instalado en el sistema, y `create-next-app` intenta usarlo.

**Solución**:

~~~bash
# Opción A: Activar pnpm con corepack (requiere sudo la primera vez)
sudo corepack enable pnpm
pnpm --version

# Opción B: Usar npm en lugar de pnpm
npx --yes create-next-app@latest <app> --typescript --tailwind --app
~~~

**Nota**: `corepack enable pnpm` falla con `EACCES` si no se corre con sudo la primera vez (quiere escribir en `/usr/bin/pnpm`).

---

### 6. CSS vacío (0 bytes) en producción

**Causa**: `create-next-app --turbopack` **NO crea** `postcss.config.mjs`. En `dev` funciona (Turbopack maneja Tailwind), pero en `build` (Webpack) el CSS queda **vacío** porque no hay plugin de PostCSS.

**Síntomas**:
- `ls -la .next/static/chunks/*.css` → archivo de 0-3000 bytes (debería ser >10.000).
- El sitio se ve sin estilos (Times New Roman, links azules subrayados).
- `curl .../css | wc -c` → 0.

**Solución**:

~~~bash
cd /home/deploy/<vertical>-web
pnpm add -D @tailwindcss/postcss

cat > postcss.config.mjs << 'EOF2'
const config = {
  plugins: {
    "@tailwindcss/postcss": {},
  },
};
export default config;
EOF2

# Rebuild del container
sudo docker compose -f docker-compose.<vertical>.yml build
sudo docker compose -f docker-compose.<vertical>.yml up -d
~~~

**Verificación**:

~~~bash
CSS_FILE=$(curl -s https://<dominio>.com/ | grep -oE 'href="[^"]+\.css"' | head -1 | sed 's/href="//;s/"//g')
curl -s "https://<dominio>.com$CSS_FILE" | wc -c
# Debe ser >10.000
~~~

---

### 7. Healthcheck `unhealthy` en Alpine

**Causa**: `wget --spider` en Alpine falla silenciosamente en algunos casos (depende de la versión).

**Solución**: Cambiar el healthcheck a `wget -q -O /dev/null`:

~~~yaml
healthcheck:
  test: ["CMD", "wget", "-q", "-O", "/dev/null", "http://127.0.0.1:3000/"]
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 40s
~~~

Alternativa con `node` (más robusta):

~~~yaml
healthcheck:
  test: ["CMD", "node", "-e", "require('http').get('http://127.0.0.1:3000/',r=>process.exit(r.statusCode===200?0:1)).on('error',()=>process.exit(1))"]
~~~

---

## Bugs del Deploy

### 8. `host not found in upstream "..."` en `nginx -t`

**Causa**: Nginx resuelve los `upstream` **al cargar la configuración**. Si el container `<vertical>_web` no existe todavía, falla.

**Solución**: **Build y `up -d` del container ANTES de `nginx -t`**.

~~~bash
# Orden correcto:
sudo docker compose -f docker-compose.<vertical>.yml build
sudo docker compose -f docker-compose.<vertical>.yml up -d
sleep 20   # esperar que el container esté corriendo
sudo docker exec baqueano_nginx nginx -t
sudo docker exec baqueano_nginx nginx -s reload
~~~

---

### 9. CSS vacío a pesar de existir en el container (proxy_cache)

**Causa**: Nginx cacheó una respuesta vacía del CSS durante el build (cuando aún no existía). Con `proxy_cache_valid 200 1y` en `/_next/static/`, el CSS roto se sirve por **1 año**.

**Síntomas**:
- Container tiene el CSS (19977 bytes).
- `nginx` interno sirve el CSS (19977 bytes).
- `curl` desde internet devuelve 0 bytes.

**Solución**:

1. **Quitar `proxy_cache`** de la config de nginx (en `/_next/static/`):

~~~nginx
location /_next/static/ {
    proxy_pass http://<vertical>_web:3000;
    # NO usar proxy_cache: Next.js ya maneja el cache con hashes
    add_header Cache-Control "public, max-age=31536000, immutable";
}
~~~

2. **Limpiar el cache existente**:

~~~bash
sudo docker exec baqueano_nginx sh -c "rm -rf /var/cache/nginx/*"
sudo docker exec baqueano_nginx nginx -s reload
~~~

3. **Verificar**:

~~~bash
curl -s https://<dominio>.com/_next/static/chunks/xxx.css | wc -c
# Debe ser >10.000
~~~

**Regla**: Nunca cachear assets de Next.js con hash en nginx. Next.js ya envía `Cache-Control: public, max-age=31536000, immutable` en los nombres con hash (los archivos que cambian reciben nombres nuevos).

---

## Bugs de la App Flutter

### 10. `MissingPluginException` en MethodChannel

**Causa**: El nombre del canal en Dart no coincide **exactamente** con el de Kotlin.

**Síntomas**:
- `MissingPluginException(No implementation found for method launchUrl on channel X)`.
- El botón no hace nada.

**Solución**: Unificar el nombre del canal en ambos lados.

~~~dart
// flutter/lib/core/utils/safe_browser_launcher.dart
static const MethodChannel _channel = MethodChannel('com.baqueano/url_launcher');
~~~

~~~kotlin
// flutter/android/app/src/main/kotlin/cl/baqueanonatales/MainActivity.kt
private val CHANNEL = "com.baqueano/url_launcher"  // MISMO NOMBRE
~~~

**Regla**: El canal debe ser idéntico carácter por carácter. Es un contrato estricto.

---

### 11. Actualizaciones in-app fallan con "paquete no es válido"

**Causa A**: El `versionCode` del nuevo APK es menor o igual al instalado → Android rechaza como downgrade.

**Causa B**: La firma digital cambió (keystore distinta) → Android rechaza por seguridad.

**Solución Causa A**: Inyectar `--build-number=${{ github.run_number }}` en el workflow.

~~~yaml
- name: Build AAB (adminDev)
  working-directory: flutter
  run: |
    flutter build appbundle --release --flavor adminDev \
      -t lib/main_admin.dart \
      --dart-define=GIT_SHA=${{ github.sha }} \
      --dart-define-from-file=dart_defines/admin_dev.json \
      --build-number=${{ github.run_number }}
~~~

**Solución Causa B**: Desinstalar una vez e instalar la nueva versión. Después, todas las actualizaciones funcionarán sin problemas (misma keystore).

**Regla del proyecto**: **NUNCA** modificar manualmente el `+N` del `pubspec.yaml`. Dejar `version: X.Y.Z+0` y el CI inyecta el `+N` real.

---

### 12. `state inválido: Token expirado` durante pruebas OAuth

**Causa**: El `state` de OAuth es un JWT con TTL de 10 minutos. Si la pantalla "Agregar cuenta" se abrió hace mucho, el token expira antes de que el usuario haga clic en "Abrir en navegador".

**Solución (procedimental)**: Salir y volver a entrar a la pantalla antes de probar. Esto regenera el `state` con un TTL fresco.

**Solución (UX futura)**: Agregar botón "Regenerar enlace" que vuelva a pedir `/oauth/url`.

---

## Resumen de bugs por categoría

| Categoría | Bugs |
|---|---|
| **Backend** | 1, 2, 3, 4 |
| **Frontend** | 5, 6, 7 |
| **Deploy** | 8, 9 |
| **Flutter** | 10, 11, 12 |

---

### 13. `Failed to fetch` en el navegador (CORS)

**Causa**: El dominio del frontend no está en `CORS_ORIGINS` del backend. El navegador bloquea el POST silenciosamente (solo visible en DevTools → Network → `(failed) net::ERR_FAILED`).

**Síntomas**:
- Formulario muestra `Failed to fetch` (o `TypeError: Failed to fetch`).
- La API responde bien con `curl` (porque curl no hace preflight).
- DevTools muestra `CORS policy: No 'Access-Control-Allow-Origin' header`.

**Diagnóstico**:

~~~bash
# Preflight (simula lo que hace el navegador)
curl -s -o /dev/null -w "HTTP %{http_code}\n" -X OPTIONS \
  "https://api-dev.baqueanonatales.com/api/v1/public/rentacar/reservas" \
  -H "Origin: https://rentacarvasquez.com" \
  -H "Access-Control-Request-Method: POST"
# 200 = OK, 400 = CORS bloqueado
~~~

**Solución**:

1. Agregar el dominio en `.env.dev` y `.env.prod`:

~~~text
CORS_ORIGINS=http://localhost:3000,...,https://rentacarvasquez.com,https://www.rentacarvasquez.com
~~~

2. **Recrear el container** (NO restart — restart no recarga env vars):

~~~bash
cd ~/baqueano-natales
sudo docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d --force-recreate backend-dev
~~~

3. Verificar:

~~~bash
docker exec baqueano_backend_dev env | grep CORS_ORIGINS
# Debe incluir el nuevo dominio
~~~

**Regla**: `docker restart` NO recarga env vars. Solo `up -d --force-recreate` lo hace.

---

### 14. `R2_PUBLIC_URL` con placeholder no sirve imágenes

**Causa**: Si el `.env.dev` tiene `R2_PUBLIC_URL=https://pub-xxxx.r2.dev` (literal `xxxx`), las URLs devueltas no funcionan → `HTTP 401` de Cloudflare.

**Síntomas**:
- Las imágenes devuelven `HTTP 401` (no 404, porque R2.dev requiere enable explícito).
- En logs de nginx: `access forbidden` o similar.

**Solución**:

1. Habilitar acceso público al bucket vía API:

~~~bash
ACCOUNT_ID="<account-id>"
curl -X PUT "https://api.cloudflare.com/client/v4/accounts/$ACCOUNT_ID/r2/buckets/<bucket>/domains/managed" \
  -H "X-Auth-Email: $CF_API_EMAIL" \
  -H "X-Auth-Key: $CF_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"enabled": true}'
~~~

2. Copiar el `<hash>` que devuelve (ej. `pub-26428d066b4c...`).

3. Actualizar `.env.dev`:

~~~text
R2_PUBLIC_URL=https://pub-26428d066b4c...r2.dev
~~~

4. Recrear backend.

**Regla**: cada bucket tiene su propio `pub-<hash>.r2.dev`. No se puede reutilizar uno entre buckets.

---

### 15. `create-next-app --turbopack` deja CSS vacío en producción

**Causa**: `--turbopack` **NO** crea `postcss.config.mjs` (solo lo usa en `dev`). En `build` (Webpack) no procesa Tailwind → CSS = 0 bytes.

**Síntomas**:
- Sitio se ve sin estilos (Times New Roman, links azules subrayados).
- `ls -la .next/static/chunks/*.css` → archivo <1000 bytes.
- `curl .../css | wc -c` → 0.

**Solución**: ver Doc 04, bug #6.

**Diagnóstico rápido**:

~~~bash
# Verificar tamaño del CSS compilado
ls -la .next/static/chunks/*.css
# Si es <1000 bytes, falta postcss.config.mjs
~~~

---

### 16. Nginx `proxy_cache` cachea respuestas vacías de CSS

**Causa**: `proxy_cache_valid 200 1y` en `/_next/static/` cachea respuestas 200, incluso si son vacías (0 bytes). Si el CSS aún no existía en el primer request, se cachea vacío por 1 año.

**Síntomas**:
- Container tiene CSS (19977 bytes).
- Nginx interno sirve CSS (19977 bytes).
- `curl` desde internet → 0 bytes.
- El sitio sigue sin estilos a pesar de rebuild.

**Solución**:

1. **Quitar `proxy_cache`** de `/_next/static/`:

~~~nginx
location /_next/static/ {
    proxy_pass http://<vertical>_web:3000;
    # NO usar proxy_cache: Next.js ya maneja el cache con hashes
    add_header Cache-Control "public, max-age=31536000, immutable";
}
~~~

2. Limpiar el cache existente:

~~~bash
sudo docker exec baqueano_nginx sh -c "rm -rf /var/cache/nginx/*"
sudo docker exec baqueano_nginx nginx -s reload
~~~

3. Verificar:

~~~bash
curl -s https://<dominio>.com/_next/static/chunks/xxx.css | wc -c
# Debe ser >10000
~~~

**Regla**: nunca cachear assets de Next.js con hash en nginx. Next.js ya envía `Cache-Control: immutable` en los nombres con hash.

---

### 17. `docker restart` no recarga env vars

**Causa**: `docker restart` solo reinicia el proceso dentro del container existente. Los env vars se setean al **crear** el container (en `docker run` o `docker compose up`).

**Síntomas**:
- Editas `.env.dev`.
- `docker restart baqueano_backend_dev`.
- `docker exec ... env | grep X` muestra el valor viejo.

**Solución**: usar `--force-recreate`:

~~~bash
sudo docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d --force-recreate backend-dev
~~~

**Regla**: cada vez que cambies `.env*`, hay que recrear el container. `restart` solo sirve para reiniciar código que ya está dentro del container.
