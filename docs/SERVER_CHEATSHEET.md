# Server Cheatsheet ? Baqueano Natales

Referencia r?pida: d?nde vive cada cosa, c?mo cargarla, y los gotchas que
nos costaron tiempo. Mantener actualizado cuando aparezcan nuevos.

---

## Servidores

| Alias | IP | User | Path | Rol |
|---|---|---|---|---|
| **prod (nuevo)** | `104.129.59.151` | `deploy` | `~/baqueano-natales` | Producci?n activa + dev |
| **viejo** | `161.118.240.229` | `ubuntu` | `~/superapp-natales` | A decommissionar (Fase 7) |

### Puertos abiertos (UFW)
- 22 (SSH), 80 (HTTP), 443 (HTTPS)

### Subdominios (Cloudflare proxied)
| Subdominio | Apunta a | Uso |
|---|---|---|
| `api.baqueanonatales.com` | Server viejo (`161.118.240.229`) | Producci?n actual (migrar en Fase 6) |
| `dev-api.baqueanonatales.com` | Server nuevo (`104.129.59.151`) | Dev + OAuth Facebook (SSL mode: full strict + Origin Cert) |

---

## Credenciales y d?nde viven

| Servicio | Variable | Ubicaci?n |
|---|---|---|
| Cloudflare (Global Key) | `CF_API_EMAIL`, `CF_API_KEY` | `~/.bashrc` ? tambi?n `~/.cf-env` |
| Backend (todos) | ver `.env` | `~/baqueano-natales/.env` |
| Firebase Service Account | JSON | `~/baqueano-natales/backend/secrets/` |
| GitHub CLI | ? | `~/.config/gh/` |
| Facebook / Meta | `FACEBOOK_APP_ID`, `FACEBOOK_APP_SECRET` | `~/baqueano-natales/.env` |

### Cargar credenciales Cloudflare

`.bashrc` tiene un guard que NO se ejecuta en shells no-interactivos. Por eso
existe `~/.cf-env`:

    . ~/.cf-env

Uso t?pico en un solo comando SSH:

    ssh deploy@104.129.59.151 ". ~/.cf-env && ~/go/bin/flarectl zone list"

### Cargar el `.env` del backend

    set -a; source ~/baqueano-natales/.env; set +a

### Cloudflare Zone ID

`baqueanonatales.com`: `9c45d549b5955a4ab18aee9ec9209de6`

---

## Docker compose

    # Estado
    ssh deploy@104.129.59.151 "cd ~/baqueano-natales && docker compose ps"

    # Logs
    ssh deploy@104.129.59.151 "cd ~/baqueano-natales && docker compose logs --tail=50 backend"

    # Restart (sin recargar .env)
    ssh deploy@104.129.59.151 "cd ~/baqueano-natales && docker compose restart backend"

    # Recrear (RECARGA .env)
    ssh deploy@104.129.59.151 "cd ~/baqueano-natales && docker compose up -d backend"

    # Rebuild completo
    ssh deploy@104.129.59.151 "cd ~/baqueano-natales && docker compose build backend && docker compose up -d"

### IMPORTANTE: recargar `.env`
`docker compose restart` **NO** recarga `.env`. Usar `up -d backend` (palabra
clave en el output: **"Recreated"**, no "Started").

### IMPORTANTE: `pip install` dentro del container
El container corre como `appuser`. `pip install` directo falla con
`Permission denied`. Alternativas:

1. **Correcto:** agregar a `requirements.txt` + rebuild
2. **R?pido (temporal):** `docker compose exec -T -u root backend pip install <pkg>`

---

## Base de datos

    # Query
    ssh deploy@104.129.59.151 "cd ~/baqueano-natales && docker compose exec -T db psql -U baqueano_user -d baqueano_natales -c 'SELECT id, email, rol FROM usuarios;'"

### DBs
| Nombre | Uso |
|---|---|
| `baqueano_natales` | Producci?n |
| `baqueano_test` | Tests (drop/create en cada sesi?n) |

---

## Tests

    # Local (solo unit, sin DB)
    cd backend
    .\.venv\Scripts\python.exe -m pytest tests/modules/social/ -q

    # Server (con DB)
    ssh deploy@104.129.59.151 "cd ~/baqueano-natales && docker compose exec -T backend python3 -m pytest tests/ -v"

    # Solo un modulo
    ssh deploy@104.129.59.151 "cd ~/baqueano-natales && docker compose exec -T backend python3 -m pytest tests/modules/social/test_oauth_state.py -v"

**Warning cosm?tico conocido:** `PytestCacheWarning: could not create cache path /app/.pytest_cache` ? el container corre como `appuser` y `/app` es de `root`. No afecta los tests.

---

## Alembic

    # Aplicar migraciones
    ssh deploy@104.129.59.151 "cd ~/baqueano-natales && docker compose exec -T backend alembic upgrade head"

    # Ver versi?n actual
    ssh deploy@104.129.59.151 "cd ~/baqueano-natales && docker compose exec -T backend alembic current"

    # Historial
    ssh deploy@104.129.59.151 "cd ~/baqueano-natales && docker compose exec -T backend alembic history"

### Gotcha: autogenerate
Detecta `server_default` falsos en `usuarios.*`. **Removerlos a mano** de cada
migraci?n generada.

---

## Cloudflare

    . ~/.cf-env

    # Zonas
    flarectl zone list

    # DNS
    flarectl dns list --zone baqueanonatales.com

    # Crear subdominio (ejemplo)
    flarectl dns create --zone baqueanonatales.com --name dev-api --type A --content 104.129.59.151 --proxy

    # SSL mode actual
    curl -s "https://api.cloudflare.com/client/v4/zones/9c45d549b5955a4ab18aee9ec9209de6/settings/ssl" \
      -H "X-Auth-Email: $CF_API_EMAIL" -H "X-Auth-Key: $CF_API_KEY"

**SSL mode actual:** `full (strict)` con Cloudflare Origin Certificate (`origin.crt`/`origin.key`, wildcard `*.baqueanonatales.com`, 15 anos). Cloudflare valida criptograficamente el cert del origen.

---

## Nginx

### Estructura
- `deploy/nginx/nginx.conf` ? config global (http, upstream, rate limits, gzip)
- `deploy/nginx/conf.d/default.conf` ? server blocks de producci?n
- `deploy/nginx/conf.d/dev-api.conf` ? server block del subdominio dev
- `deploy/nginx/certs/` ? self-signed (NO en repo, en `.gitignore`)

### Rate limits (en nginx.conf)
- `api_limit`: 60 r/m
- `auth_limit`: 5 r/m
- Upstream: `baqueano_backend` (backend:8000, keepalive 32)

### Verificar config sin aplicar

    docker compose exec -T nginx nginx -t

---

## PowerShell ? SSH: el patr?n can?nico

**Problema:** PowerShell manda `\r\n` (CRLF) y bash no los tolera en
comandos como `tail -20`, `head -c 300`, `wc -l`.

### Patr?n A ? Comando simple (un string)

    ssh deploy@104.129.59.151 "cd ~/baqueano-natales && docker compose ps"

### Patr?n B ? Script multi-l?nea (recomendado)

    $script = @'
    cd ~/baqueano-natales
    echo "linea 1"
    echo "linea 2"
    '@

    $script = $script -replace "`r`n", "`n"
    $script | ssh deploy@104.129.59.151 'bash -s'

### Patr?n C ? Script Python (para l?gica compleja)

    $py = @'
    import sys
    print("hola")
    '@

    $py = $py -replace "`r`n", "`n"
    $py | ssh deploy@104.129.59.151 "cd ~/baqueano-natales && python3 -"

**Por qu? el `-replace`:** convierte CRLF ? LF antes de enviar. Evita el bug
cl?sico `$'echo\r': command not found`.

---

## Firebase

| Item | Valor |
|---|---|
| Project ID | `baqueano-natales-prod` |
| Service account | `~/baqueano-natales/backend/secrets/firebase-service-account.json` |
| Web Client ID (serverClientId) | `1072830106109-c1b5cktisbj3khu8s9jmf7crn8ni0dh7.apps.googleusercontent.com` |

---

## Facebook / Meta

| Item | Valor |
|---|---|
| App name | Baqueano Automation |
| App ID | `2100947607174726` |
| Business ID | `1114191184614750` |
| Modo | Development (Sin publicar) |
| Redirect URI registrado | `https://dev-api.baqueanonatales.com/api/v1/admin/social/facebook/oauth/callback` |
| Graph API version | `v26.0` |
| Scopes solicitados | `pages_show_list,pages_read_engagement,pages_manage_posts` |

### Probar el flujo OAuth manualmente (sin Flutter)

    # 1. Generar JWT de admin (v?lido 30 min)
    ssh deploy@104.129.59.151 "cd ~/baqueano-natales && docker compose exec -T backend python3 - <<'PYEOF'
    import asyncio
    from datetime import timedelta
    from sqlalchemy import select
    from app.core.db import AsyncSessionLocal
    from app.core.security import create_access_token
    from app.modules.auth.models import Usuario, RolUsuario

    async def main():
        async with AsyncSessionLocal() as db:
            stmt = select(Usuario).where(Usuario.rol == RolUsuario.ADMIN).limit(1)
            admin = (await db.execute(stmt)).scalar_one_or_none()
            token = create_access_token(
                subject=str(admin.id),
                expires_delta=timedelta(minutes=30),
                extra_claims={'rol': admin.rol.value, 'email': admin.email},
            )
            print(token)

    asyncio.run(main())
    PYEOF"

    # 2. GET /oauth/url con el JWT
    curl -sS -H "Authorization: Bearer <JWT>" \
      https://dev-api.baqueanonatales.com/api/v1/admin/social/facebook/oauth/url

    # 3. Abrir el url que devuelve en el navegador
    # 4. Copiar el token_ref del HTML verde
    # 5. POST /facebook/pages con el token_ref
    # 6. POST /facebook/conectar con page_id elegido

**Nota:** el JWT del backend requiere el claim `iss: "baqueano-natales"` ?
usar `core.security.create_access_token()`, no armar el payload a mano.

---

## Gotchas acumulados

1. **`~/.bashrc` guard** ? los `export` no se cargan en shells no-interactivos. Usar `~/.cf-env`.
2. **`docker compose restart`** ? NO recarga `.env`. Usar `up -d` (busca "Recreated").
3. **Alembic autogenerate** ? falsos `server_default` en `usuarios.*`. Remover a mano.
4. **Postgres UNIQUE + NULL** ? `UNIQUE(a, b)` no bloquea duplicados si alg?n campo es NULL. Usar `NULLS NOT DISTINCT` (PG 15+).
5. **Fernet key inv?lida** ? el backend aborta en producci?n si `TOKEN_ENCRYPTION_KEY` falta. Es intencional.
6. **`pip install` en container** ? Permission denied. Usar `-u root` o rebuild.
7. **Emulador Android 17** ? bugs de IME y GPU. Usar Android 14 (`Pixel6_API34`).
8. **`google_sign_in` v7** ? bug con Credential Manager. Usar v6.
9. **PowerShell ? SSH CRLF** ? ver secci?n "PowerShell ? SSH: el patr?n can?nico".
10. **JWT backend requiere `iss`** ? usar `create_access_token()`, no payload manual.

---

## Deuda t?cnica pendiente

- **Rotar secretos expuestos** (ver `CONTEXTO_PROYECTO.md` ?Secretos expuestos):
  - `SECRET_KEY` (JWT), frase GPG de backups, GitHub PAT viejo, `POSTGRES_PASSWORD`
  - Prioridad alta: frase GPG + `SECRET_KEY`
- **Cloudflare Global API Key: DECISION CONSCIENTE (no es deuda tecnica)**
  Se mantiene la Global API Key en el server de forma deliberada para poder
  operar CUALQUIER proyecto/dominio de la cuenta Cloudflare desde este server
  sin crear/rotar tokens individuales por proyecto.
  Reglas no-negociables:
    1. NUNCA commitear, ni pegar en chats, ni loguear (evitar 'set -x').
    2. Vive solo en '~/.cf-env' y '~/.bashrc' del server (permisos 600).
    3. Si alguna vez se filtra: rotar YA + auditar accesos en Cloudflare.
- **Migrar SSL a Cloudflare Origin Certificate** (en vez de self-signed)
- **Fase 6 real** ? DNS cutover + Let's Encrypt en el server nuevo
- **Decommission server viejo** ? apagar tras 1 semana sin incidentes
- **`docs/SERVER_CHEATSHEET.md`** ? este archivo, mantener actualizado

---

## Comandos r?pidos (referencia)

    # SSH al server
    ssh deploy@104.129.59.151

    # Estado del proyecto
    ssh deploy@104.129.59.151 "cd ~/baqueano-natales && git log --oneline -5 && docker compose ps"

    # Health end-to-end
    curl https://dev-api.baqueanonatales.com/health

    # Correr tests
    ssh deploy@104.129.59.151 "cd ~/baqueano-natales && docker compose exec -T backend python3 -m pytest tests/ -q"

    # Ver logs del backend
    ssh deploy@104.129.59.151 "cd ~/baqueano-natales && docker compose logs --tail=50 backend"

    # Git status
    ssh deploy@104.129.59.151 "cd ~/baqueano-natales && git status"
11. **pip install manual se pierde al recrear el container** -> siempre va primero a requirements.txt y despues rebuild.


---

## Worker social (Etapa 3)

Worker in-process con APScheduler que procesa la cola publicaciones_sociales
cada 30s. Corre dentro del mismo proceso FastAPI (lifespan).

### Configuracion (.env)

    SOCIAL_WORKER_ENABLED=true
    SOCIAL_WORKER_INTERVAL_SEC=30

### Ver logs del worker

    ssh deploy@104.129.59.151 "cd ~/baqueano-natales && docker compose logs --tail=50 backend | grep -i worker"

Log esperado:
    Worker social: iniciado (intervalo=30s)
    Job "procesar_cola" executed successfully

### Forzar un ciclo ahora (sin esperar 30s)

Endpoint admin: POST /api/v1/admin/social/publicaciones/procesar-ahora
Requiere JWT de admin (ver seccion Facebook/Meta para generarlo).

### Backoff exponencial

    1er fallo -> 1 min
    2do fallo -> 5 min
    3er fallo -> 30 min
    4to fallo -> 2 h
    5to fallo -> AGOTADO (no reintenta)

### Deshabilitar temporalmente

Editar .env: SOCIAL_WORKER_ENABLED=false
Recrear: docker compose up -d backend

## Frontend admin de social (Etapa 6)

3 pantallas admin en Flutter (flavor admin):

| Pantalla | Ruta |
|---|---|
| Redes sociales | /admin/social/cuentas |
| Configuracion | /admin/social/config |
| Cola de publicaciones | /admin/social/publicaciones |

Pantalla dueno (Etapa 7):
| Mis publicaciones | /mis-prestadores/:id/publicaciones |

Repository + providers:
- lib/features/social/data/social_repository.dart
- lib/features/social/data/social_providers.dart

Endpoints backend consumidos:
- GET    /api/v1/admin/social/cuentas
- GET    /api/v1/admin/social/config
- PATCH  /api/v1/admin/social/config
- GET    /api/v1/admin/social/publicaciones    (?estado=&red=)
- PATCH  /api/v1/admin/social/publicaciones/{id}/reencolar
- POST   /api/v1/admin/social/publicaciones/procesar-ahora
- GET    /api/v1/mis-prestadores/{id}/publicaciones    (dueno o admin)
12. **Workflow dual-repo (backend + Flutter)**: cambios de backend por SSH (commit desde el server), cambios Flutter en Windows (commit desde Windows). pull --rebase antes de cada push.
13. **CRLF rompe git log -3**: usar 'git log --oneline' o Python via stdin.
14. **CRLF rompe git diff --cached --name-only**: usar 'git status' o 'git diff --cached' sin flags.
15. **Set-Content de PowerShell 5.1 escribe en Windows-1252**: rompe emojis y acentos al editar .md. Usar [System.IO.File]::WriteAllText con UTF8Encoding($false).

16. **`docker compose up -d backend` no siempre recrea el container**: si el
    hash del Dockerfile/compose no cambio y solo se edito un archivo montado
    como volumen, Docker deja el container como "Running" en vez de "Recreated"
    -> el codigo nuevo NO se carga. En ese caso usar
    `docker compose restart backend` (mata el proceso y lo reinicia limpio).
17. **`touch app/main.py` no siempre dispara hot reload de uvicorn**: aunque
    uvicorn corre con `--reload`, hay casos (mount de volumen + editor que
    escribe de forma atomica) en que inotify no detecta el cambio. No confiar
    en el hot reload: reiniciar el backend con `docker compose restart backend`.
18. **Editar archivos con acentos/emojis desde PowerShell: NO usar Python via
    stdin**: PowerShell 5.1 lee stdin en Windows-1252 y rompe los caracteres
    no-ASCII silenciosamente (el archivo queda con `?` en lugar de `á`, `é`,
    `ñ`, `📋`, etc.). El patron correcto es:
    1. Escribir el script Python a un archivo temporal con
       `[System.IO.File]::WriteAllText($path, $pyContent, (New-Object System.Text.UTF8Encoding($false)))`.
    2. Ejecutar `python archivo_temporal.py` (Python lee el archivo como UTF-8).
    3. Borrar el archivo temporal.
    Verificar SIEMPRE con `Select-String -Path archivo.md -Pattern 'acentuada'`
    despues de editar.


19. **`sdkmanager` CLI (version nueva) tiene bug silencioso**: el comando
    `android sdk install "<package>"` no descarga nada y no da error.
    **Usar Android Studio GUI** (SDK Manager -> SDK Platforms -> tildar
    "Show package details" -> buscar "Google Play Intel x86_64 Atom System
    Image" bajo la version de Android).

20. **Emulador con FCM requiere Play Store**: `tag.id=google_apis` NO tiene
    Play Services (FCM no funciona). Necesario `tag.id=google_apis_playstore`.
    Verificar con `Get-Content "$env:ANDROID_AVD_HOME\<nombre>.avd\config.ini"`.
    El AVD con Play Store requiere **~5 GB libres en la particion** para
    bootear (error `hasSufficientDiskSpace` si no alcanza).


21. **Emulador con `-gpu host` puede tener glitches visuales** (Intel UHD 630):
    warnings `Unable to match the desired swap behavior` + banners sin
    animacion. Fix: usar `-gpu swiftshader_indirect` (software rendering,
    mas lento pero estable visualmente). Alternar segun necesidad:
    - Desarrollo rapido -> `-gpu host`.
    - Screenshots / validacion visual -> `-gpu swiftshader_indirect`.

22. **`flutter_local_notifications` v22**: requiere
    `coreLibraryDesugaring` en `build.gradle.kts`:
    - En `compileOptions`: `isCoreLibraryDesugaringEnabled = true`.
    - En `dependencies`: `coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")`.
    Sin esto, el build falla con `requires core library desugaring`.
    Ademas, la API v22 usa **named params** en `initialize()` y `show()`:
    - `initialize({settings: ..., onDidReceiveNotificationResponse: ...})`.
    - `show({id:, title:, body:, notificationDetails:, payload:})`.
    (Los params `details:` y positional de v17 ya NO funcionan.)

23. **Banner en foreground**: por default Android NO muestra banner cuando
    la app esta abierta. Se resuelve con `flutter_local_notifications` +
    llamar `show()` desde `FirebaseMessaging.onMessage` (el listener del
    FCM). El payload (log_id) se pasa al plugin para poder reportar la
    apertura al tocar el banner (`onDidReceiveNotificationResponse`).

24. **`<<'SQL'` heredoc dentro de `bash -s` se come stdin**: cuando se manda
    un script multi-linea por `bash -s` que incluye `docker compose exec -T
    db psql ... <<'SQL'`, el heredoc NO cierra (Docker Compose se come el
    delimitador). Sintoma: `syntax error at or near "SQL"` + las queries
    corren a medias. Fix: usar `docker compose exec -T ... -c "..."` con
    comillas bash, o separar en llamadas SSH distintas.

25. **`docker compose exec -T` consume stdin dentro de `bash -s` multi-linea**:
    el resto del script NO se ejecuta despues del primer `docker exec`
    (Docker lee hasta EOF). Sintoma: solo corre el primer comando y el resto
    desaparece. Fix: separar cada `docker exec` en su propia llamada SSH.

26. **En Windows, `< /dev/null` se pierde al mandar por `bash -s`**: PowerShell/
    OpenSSH no interpretan la redireccion dentro del here-string.
    Sintoma: `: No such file or directory`. Fix: usar el patron de comando
    simple de una linea (SSH + string) cuando sea un solo `docker exec`.

27. **FCM + `flutter_local_notifications`: hot reload/restart no reciclan
    listeners**:
    - Hot reload **no** vuelve a ejecutar `inicializar()`, los listeners
      viejos de FCM quedan activos con el closure viejo.
    - Hot restart **no** destruye el plugin nativo de
      `flutter_local_notifications`: `getInitialMessage` sigue devolviendo
      el ultimo tap.
    - Por eso el estado in-session debe ser `static` (comparte entre
      instancias Dart vivas) y ademas persistir en disco (SecureStorage)
      con ventana temporal.
    - Para un estado 100% limpio, **cold start** (`q` + `flutter run`).


---

## Workflow dual-entorno (prod + dev) — ACTUALIZADO 2026-10-13

El server nuevo (`104.129.59.151`) corre **dos entornos aislados** en paralelo.

| Servicio | Container | Env file | DB | Volumen media |
|---|---|---|---|---|
| db | `baqueano_db` | `.env` (base) | multiples DBs | `postgres_data` |
| nginx | `baqueano_nginx` | — | — | `nginx_cache` |
| backend-prod | `baqueano_backend_prod` | `.env.prod` | `baqueano_natales_prod` | `media_data_prod` |
| backend-dev | `baqueano_backend_dev` | `.env.dev` | `baqueano_natales_dev` | `media_data_dev` |

Subdominios:
- `api.baqueanonatales.com` -> `backend-prod` (Cloudflare proxied)
- `api-dev.baqueanonatales.com` -> `backend-dev` (Cloudflare proxied)
- `dev-api.baqueanonatales.com` -> redirect 301 a `api-dev` (temporal, 30 dias)

### Comandos operativos (scripts)

    # Levantar prod
    scripts/prod-up.sh [--build]

    # Levantar dev
    scripts/dev-up.sh [--build]

    # Levantar ambos
    scripts/all-up.sh [--build]

    # Bajar solo prod (deja db + nginx + dev)
    scripts/prod-down.sh

    # Bajar solo dev (deja db + nginx + prod)
    scripts/dev-down.sh

    # Bajar TODO (incluye db + nginx)
    scripts/all-down.sh

    # Reiniciar sin recrear (rapido)
    scripts/prod-restart.sh
    scripts/dev-restart.sh

    # Logs en vivo
    scripts/prod-logs.sh [N]
    scripts/dev-logs.sh [N]

    # Estado consolidado (containers + health + recursos)
    scripts/status.sh

### Uso directo de docker compose

    # Prod
    docker compose -f docker-compose.yml -f docker-compose.prod.yml <cmd>

    # Dev
    docker compose -f docker-compose.yml -f docker-compose.dev.yml <cmd>

    # Ambos
    docker compose -f docker-compose.yml -f docker-compose.prod.yml -f docker-compose.dev.yml <cmd>

### Aplicar migraciones Alembic

    docker exec baqueano_backend_prod alembic upgrade head
    docker exec baqueano_backend_dev alembic upgrade head

### Usuarios Postgres (minimo privilegio)

| Usuario | Atributos | Acceso |
|---|---|---|
| `baqueano_user` | Superuser (bootstrap) | Todas las DBs (solo admin manual) |
| `baqueano_prod_user` | NOSUPERUSER | Solo `baqueano_natales_prod` |
| `baqueano_dev_user` | NOSUPERUSER | Solo `baqueano_natales_dev` |
| `baqueano_test_user` | NOSUPERUSER | Solo `baqueano_natales_test` |

Passwords guardadas en el gestor del owner. NO versionadas en el repo.

### Backups del server nuevo

Backups manuales en `~/backups/`:

    ssh deploy@104.129.59.151 "ls -lah ~/backups/"

Rclone remotes (pendiente de portar el script de backup del legacy):
- `b2:baqueano-natales-backups-prod`
- `b2:baqueano-natales-backups-dev`

---

## Gotchas nuevos (2026-10-13)

28. **Permisos de volumenes Docker nuevos**: cuando Docker crea un volumen vacio
    (ej. `media_data_prod`), lo monta con owner `root:root`. Si el container
    corre como `appuser` (uid 1000), falla con
    `PermissionError: [Errno 13] Permission denied: '/app/media/avatars'` y
    entra en restart loop.

    Fix (one-time por volumen):

        docker run --rm -v baqueano-natales_media_data_prod:/mnt alpine \
          sh -c "mkdir -p /mnt/avatars /mnt/afiches /mnt/audios /mnt/biblioteca /mnt/comercios /mnt/items /mnt/promociones /mnt/oficios && chown -R 1000:1000 /mnt && chmod -R 755 /mnt"

    Despues: `scripts/prod-restart.sh` (o el correspondiente).

29. **`docker compose config` imprime TODOS los secretos**: el comando resuelve
    las variables del `.env` y las muestra en el output. NUNCA correrlo sin
    censurar.

    Mal:  `docker compose config`
    Bien: `docker compose config --services`
    Bien: `docker compose config --volumes`
    Bien: `docker compose config | grep -vE "(SECRET|PASSWORD|TOKEN|KEY|PASSPHRASE|DATABASE_URL|APP_SECRET)"`

30. **`docker compose exec -T` consume stdin dentro de `bash -s` multi-linea**:
    cuando se invoca un `docker compose exec` en medio de un script enviado por
    `bash -s`, el resto del script se pierde porque Docker lee hasta EOF.

    Fix: separar en llamadas SSH distintas, o usar `docker exec <container>`
    (sin `compose`) que NO lee stdin.

31. **`docker exec` + `< /dev/null` + `docker cp`** es el patron canonico para
    `pg_dump` en Docker:

        # 1. Dump dentro del container (evita SIGPIPE)
        docker exec baqueano_db pg_dump -U baqueano_user -d baqueano_natales_prod -f /tmp/dump.sql < /dev/null

        # 2. Copiar al host
        docker cp baqueano_db:/tmp/dump.sql /tmp/dump.sql

        # 3. Comprimir
        gzip -c /tmp/dump.sql > backup.sql.gz

    NO usar `docker compose exec -T db pg_dump ... | gzip` porque:
    - El pipe puede cerrar temprano (SIGPIPE) y matar la sesion SSH.
    - El heredoc/pipe se trunca silenciosamente con contenido largo.

32. **`docker compose up -d` deja containers "orphan"** cuando se renombra un
    servicio en el compose base: los viejos siguen en `docker ps -a` pero no se
    recrean. Se puede limpiar con `docker compose up -d --remove-orphans` o
    borrarlos manualmente con `docker rm <container>`.


## Gotchas nuevos (2026-10-13 - Bloque 6: release signing + AAB)

33. **JDK 25 + locale español: `keytool -printcert` crashea**: con JDK 25
    y locale no-inglés, `keytool -printcert -file cert.pem` falla con
    `java.util.MissingFormatArgumentException: Format specifier '%2$s'`.
    Fix: forzar locale inglés con flags JVM:
    `keytool "-J-Duser.language=en" "-J-Duser.country=US" -printcert -file cert.pem`

34. **`keytool -printcert -jarfile` no funciona con AAB**: a diferencia del
    APK, el AAB usa un esquema de firma distinto. Para extraer el certificado
    hay que descomprimir el AAB (es un zip) y usar
    `keytool -printcert -file META-INF/BAQUEANO.RSA`.
    Alternativa robusta: `keytool -exportcert -rfc -alias <alias> -keystore <ks>
    -storepass <pass> -file cert.pem` + `keytool -printcert -file cert.pem`.

35. **`flutter build appbundle` sin `-t` falla con "Target file lib/main.dart
    not found"**: si el proyecto tiene entry points separados
    (`lib/main_client.dart`, `lib/main_admin.dart`), hay que pasar
    explícitamente el target. El default `lib/main.dart` no existe.
    Comando canónico:
    `flutter build appbundle --flavor clientProd --release -t lib/main_client.dart --dart-define-from-file=dart_defines/client_prod.json`

36. **Play App Signing cambia el SHA-1 de producción**: el APK que instalan
    los usuarios NO está firmado con tu upload key, sino con el **app signing
    key de Google**. Firebase necesita el SHA-1 del app signing key (no el
    tuyo). Síntoma: Google Sign-In funciona en local pero falla en producción
    con `ApiException: 10`.
    Fix: Play Console → Configuración → Integridad de la app → Firma de apps →
    copiar el SHA-1 → agregar a Firebase → descargar nuevo `google-services.json`
    → rebuild.

37. **`.jks` fuera del repo + `key.properties` gitignored**: el keystore de
    release vive en `D:\dev\baqueano-keys\baqueano-release.jks` (fuera del
    repo). El `key.properties` apunta a esa ruta con forward slashes
    (`D:/dev/baqueano-keys/baqueano-release.jks`).
    Backup obligatorio: 2 copias cifradas (gestor + B2/Drive).
---

## Rotacion de secretos pendiente (2026-10-13)

⚠️ **PENDIENTE — hacer al final de todo** (no bloquea el desarrollo actual).

| Secreto | Estado | Prioridad |
|---|---|---|
| `SECRET_KEY` (JWT) | filtrado en `.env` | Alta |
| `TOKEN_ENCRYPTION_KEY` | filtrado en docker compose config | **ALTA** (requiere re-cifrado de tokens FB) |
| `FACEBOOK_APP_SECRET` | filtrado en docker compose config | Media |
| Frase GPG de backups legacy | guardada en gestor, NO filtrada | Baja (solo rotar si se filtra) |
| GitHub PAT legacy | expuesto en git remote | Alta (revocar, no rotar) |
| `POSTGRES_PASSWORD` viejo | filtrado | ✅ Ya rotado en el swap |
| Cloudflare Global Key | decision consciente, no deuda | N/A |

Ver `CONTEXTO_PROYECTO.md` seccion "Secretos expuestos" para la lista completa.

---

**Fin del apendice.**


---

## Firebase CLI en el server (ACTUALIZADO 2026-10-13)

**Tenemos Firebase CLI instalado y logueado con permisos de admin desde el server nuevo.** Esto permite administrar apps, SHA, y descargar `google-services.json` sin abrir la consola web.

| Item | Valor |
|---|---|
| Binario | `/usr/local/bin/firebase` (v15.32.1) |
| Usuario logueado | `victorneyraars@gmail.com` |
| Project ID | `baqueano-natales-prod` |
| Project Number | `1072830106109` |
| Config del token | `~/.config/configstore/firebase-tools.json` (modo 600) |
| Node | v22.23.3 |
| npm | 10.9.9 |

### Apps Android registradas (estado 2026-10-13)

| Display Name | App ID | Package Name |
|---|---|---|
| (Not specified) | `1:1072830106109:android:fbc1b17131d59b0d133194` | `cl.baqueanonatales` |
| Baqueano Admin | `1:1072830106109:android:a1008d3e2715ec06133194` | `cl.baqueanonatales.admin` |

**Pendiente**: registrar `cl.baqueanonatales.dev` y `cl.baqueanonatales.admin.dev` para los flavors dev (Bloque 4).

### Comandos utiles

    # Listar apps
    firebase apps:list ANDROID --project baqueano-natales-prod

    # Crear app Android (NO acepta SHA-1, solo packageName)
    firebase apps:create ANDROID "Nombre visible" -a cl.paquete.app --project baqueano-natales-prod

    # Descargar google-services.json completo (todos los clientes)
    firebase apps:sdkconfig ANDROID --project baqueano-natales-prod --out /tmp/google-services.json

    # Descargar config de UNA app especifica
    firebase apps:sdkconfig ANDROID 1:1072830106109:android:fbc1b17131d59b0d133194 -o /tmp/config.json

### Agregar SHA-1/SHA-256 a una app

**Gotcha:** `firebase apps:create` **no acepta** flag de SHA-1. Hay que pegarle a la Management API despues de crear la app.

Obtener el access_token del configstore y usarlo:

    ACCESS_TOKEN=$(jq -r '.tokens.access_token' ~/.config/configstore/firebase-tools.json)

    # SHA-1 de debug actual
    SHA1="6E:0B:71:E0:63:01:E8:F7:CF:0E:3D:BC:1F:29:77:C8:D6:BE:63:3D"

    # Agregar SHA-1
    curl -sS -X POST \
      "https://firebase.googleapis.com/v1beta1/projects/baqueano-natales-prod/androidApps/<APP_ID>/sha" \
      -H "Authorization: Bearer $ACCESS_TOKEN" \
      -H "Content-Type: application/json" \
      -d "{\"shaHash\": \"$SHA1\", \"certType\": \"SHA_1\"}"

    # SHA-256 de debug actual
    SHA256="B2:A9:81:11:D4:55:81:B1:E8:5A:15:E7:6D:C1:5F:9E:20:0A:FE:72:FD:C5:EB:33:25:6E:97:82:B2:20:7C:BE"

    curl -sS -X POST \
      "https://firebase.googleapis.com/v1beta1/projects/baqueano-natales-prod/androidApps/<APP_ID>/sha" \
      -H "Authorization: Bearer $ACCESS_TOKEN" \
      -H "Content-Type: application/json" \
      -d "{\"shaHash\": \"$SHA256\", \"certType\": \"SHA_256\"}"

El access_token dura 1h. Si expira: `firebase login:ci` o re-loguearse.

### Regenerar google-services.json despues de cambios

    firebase apps:sdkconfig ANDROID --project baqueano-natales-prod -o ~/baqueano-natales/flutter/android/app/google-services.json

Despues commitear (el archivo va al repo, no es secreto — son API keys publicas).

### Riesgos / buenas practicas

- **NO loguearse con la Global API Key de Cloudflare ni credenciales compartidas.**
- El token de Firebase en `~/.config/configstore/firebase-tools.json` da acceso total al proyecto Firebase. Tratarlo como secreto.
- Si se revoca el login (`firebase logout`), todos los comandos de administracion fallan. Re-loguear con `firebase login:ci` (link interactivo).
- **Nunca** loguearse con una cuenta personal que no sea del proyecto.
