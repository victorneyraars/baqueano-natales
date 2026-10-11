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
| `dev-api.baqueanonatales.com` | Server nuevo (`104.129.59.151`) | Dev + OAuth Facebook (SSL mode: full) |

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

**SSL mode actual:** `full` (Cloudflare habla HTTPS al origin pero no valida el cert ? self-signed alcanza).

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
- **Migrar Cloudflare Global Key ? API Token acotado** (m?s seguro, permisos m?nimos)
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
