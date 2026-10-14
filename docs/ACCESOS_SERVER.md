# Accesos y credenciales del server — Baqueano Natales

> **Proposito**: referencia rapida de todos los accesos, credenciales y herramientas disponibles en el server productivo.

**Ultima actualizacion:** 2026-10-14

---

## Server principal

| Item | Valor |
|---|---|
| **Host** | `104.129.59.151` |
| **User SSH** | `deploy` |
| **Path del proyecto** | `/home/deploy/baqueano-natales` |
| **OS** | Ubuntu 24.04.5 LTS |
| **Proveedor** | RackNerd |

---

## GitHub CLI (`gh`)

| Item | Valor |
|---|---|
| **Binario** | `/usr/bin/gh` |
| **Version** | 2.45.0 |
| **Auth** | Logged in como `victorneyraars` |
| **Config** | `~/.config/gh/hosts.yml` (600) |
| **Scopes** | `admin:public_key`, `gist`, `read:org`, `repo` |

**Uso**:

    gh secret list --repo victorneyraars/baqueano-natales
    gh secret set NOMBRE --repo victorneyraars/baqueano-natales --body "valor"
    gh secret set NOMBRE --repo victorneyraars/baqueano-natales --body-file /tmp/archivo
    gh run list --repo victorneyraars/baqueano-natales
    gh workflow list --repo victorneyraars/baqueano-natales

---

## Firebase CLI

| Item | Valor |
|---|---|
| **Binario** | `/usr/local/bin/firebase` |
| **Version** | 15.32.1 |
| **Auth** | `victorneyraars@gmail.com` |
| **Config** | `~/.config/configstore/firebase-tools.json` (600) |
| **Project activo** | `baqueano-natales-prod` (Number: `1072830106109`) |

**Uso**:

    firebase apps:list ANDROID --project baqueano-natales-prod
    firebase apps:sdkconfig ANDROID --project baqueano-natales-prod
    firebase apps:create ANDROID "Nombre" -a cl.package.name --project baqueano-natales-prod

---

## Cloudflare

| Item | Valor |
|---|---|
| **Global API Key** | Configurado en `~/.cf-env` y `~/.bashrc` |
| **`~/.cf-env`** | `CF_API_EMAIL` + `CF_API_KEY` (600) |
| **`flarectl`** | NO en PATH — revisar (probablemente `~/go/bin/`) |
| **Zone ID** | `9c45d549b5955a4ab18aee9ec9209de6` |

**Cargar credenciales**:

    . ~/.cf-env

**Uso directo**:

    curl -s "https://api.cloudflare.com/client/v4/zones/9c45d549b5955a4ab18aee9ec9209de6/dns_records" \
      -H "X-Auth-Email: \" -H "X-Auth-Key: \"

**Nota**: la Global API Key es decision consciente (operar cualquier proyecto/dominio desde este server).

---

## Docker

| Item | Valor |
|---|---|
| **Docker** | 29.8.2 |
| **Compose** | v5.6.0 |

**Volumenes**:
- `baqueano-natales_postgres_data` — DB
- `baqueano-natales_media_data` — legacy
- `baqueano-natales_media_data_prod` — media prod
- `baqueano-natales_media_data_dev` — media dev
- `baqueano-natales_nginx_cache` — cache nginx

**Containers activos**: `baqueano_db`, `baqueano_nginx`, `baqueano_backend_prod`, `baqueano_backend_dev`.

---

## SSH

| Archivo | Uso |
|---|---|
| `~/.ssh/authorized_keys` | Login con llave |
| `~/.ssh/github_deploy` (600) | Key privada GitHub |
| `~/.ssh/github_deploy.pub` | Key publica |
| `~/.ssh/config` | Host `github.com` -> `github_deploy` |

---

## Node.js / npm

| Item | Valor |
|---|---|
| **Node** | v22.23.3 |
| **npm** | 10.9.9 |

**Global packages**: `firebase-tools` (15.32.1), `vercel` (62.2.0).

---

## Python

| Item | Valor |
|---|---|
| **Python** | 3.12.3 |
| **pip** | Disponible |

**Dentro del container** (`baqueano_backend_prod`):
- `google-api-python-client==2.149.0`
- `google-auth==2.36.0`
- `google-auth-httplib2==0.2.0`

---

## CLIs adicionales

| Tool | Version |
|---|---|
| **Vercel** | 62.2.0 |
| **jq** | 1.7 |

**NO instalados**: aws, gcloud, az, heroku, netlify, rclone, restic.

---

## Secretos en el server

| Archivo | Permisos |
|---|---|
| `~/baqueano-natales/backend/secrets/firebase-service-account.json` | 600 |
| `~/baqueano-natales/backend/secrets/play-publisher.json` | 600 |
| `~/baqueano-natales/.env` | 600 |
| `~/baqueano-natales/.env.prod` | 600 |
| `~/baqueano-natales/.env.dev` | 600 |
| `~/.cf-env` | 600 |
| `~/.config/gh/hosts.yml` | 600 |
| `~/.config/configstore/firebase-tools.json` | 600 |

---

## Backups

Directorio: `~/backups/`

**Backups actuales** (13 oct 2026):
- `baqueano_natales_PRE-RENAME_2026-10-13_03-12-57.sql.gz`
- `baqueano_natales_PRE-RENAME_2026-10-13_03-16-20.sql.gz`
- `baqueano_natales_PRE-SWAP_2026-10-13_04-03-54.sql.gz`

**Pendiente**: backups automaticos con rclone a B2.

---

## Puertos abiertos (UFW)

| Puerto | Servicio |
|---|---|
| 22 | SSH |
| 80 | HTTP |
| 443 | HTTPS |

**Nota**: `ufw status` requiere sudo password. Configurado asi desde la provision inicial.

---

## Cron jobs

| Item | Estado |
|---|---|
| `crontab -l` (deploy) | Sin cron jobs |
| `/etc/cron.d/` | Requiere sudo |

**Nota**: Los workers de Baqueano corren in-process (APScheduler en FastAPI). No hay cron del sistema.

---

## Como actualizar este doc

1. Correr el comando para verificar el acceso.
2. Agregar la fila en la seccion correspondiente.
3. Commit: `docs(accesos): agregar X`.

---

## Pendientes de investigar

- [ ] `flarectl` no esta en PATH. Revisar `~/go/bin/`.
- [ ] `ufw status` sin sudo — configurar NOPASSWD (opcional).
- [ ] `/etc/cron.d/` sin sudo — NOPASSWD (opcional).

---

**Fin del documento.**