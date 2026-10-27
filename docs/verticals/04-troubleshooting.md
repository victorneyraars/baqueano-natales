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
