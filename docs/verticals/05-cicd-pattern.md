# 05 - Patron CI/CD Normalizado y Reusable

> Arquitectura de CI/CD para las webs del ecosistema Baqueano Natales.

## Filosofia: Best-of-breed con reglas claras

No forzamos a todas las webs a la misma plataforma. Cada stack usa la plataforma optima:

- Astro (SSG/SSR): Cloudflare Pages (CDN edge global, gratis)
- Next.js (ISR/Node): Docker self-hosted (ISR requiere Node)
- Flutter (APK): GitHub Releases + SCP (distribucion directa)

Normalizacion significa que el PROCESO es identico (push -> build -> deploy), aunque la PLATAFORMA sea distinta segun el stack.

## Arquitectura de 3 capas

Capa 3 - Orquestadores (por repo):
  .github/workflows/deploy.yml
  ~17 lineas, solo llama al reusable

Capa 2 - Reusable Workflows (centralizado en baqueano-natales):
  deploy-astro.yml, deploy-docker.yml, dev-build.yml

Capa 1 - Composite Actions (reutilizables):
  setup-node/action.yml

## Reglas de seguridad 2026

1. SHAs pinned: usar SHA completo, no @v4
2. Secretos explicitos: pasar uno por uno, nunca inherit
3. Permisos minimos: contents: read por defecto
4. Concurrencia: cancel-in-progress: false en produccion

## Secrets globales

| Secret | Usado por | Proposito |
|---|---|---|
| CLOUDFLARE_API_TOKEN | Astro | Token limitado a Pages:Edit |
| CLOUDFLARE_ACCOUNT_ID | Astro | ID de la cuenta |
| SERVER_HOST | Docker | IP del servidor |
| SERVER_USER | Docker | Usuario SSH (deploy) |
| SERVER_SSH_KEY | Docker | Llave privada SSH |

Configurar: gh secret set NOMBRE --body "valor" --repo org/repo

## Workflow deploy-astro.yml

Despliega Astro a Cloudflare Pages. Autodetecta npm/pnpm.
Ejecuta astro check si el script existe. Inyecta build-env.

Uso desde un repo:

jobs:
  deploy:
    uses: victorneyraars/baqueano-natales/.github/workflows/deploy-astro.yml@SHA
    with:
      project-name: mi-proyecto
      environment: production
      cloudflare-branch: main
      build-env: |
        PUBLIC_API_URL=https://api.baqueanonatales.com
    secrets:
      CLOUDFLARE_API_TOKEN: ${{ secrets.CLOUDFLARE_API_TOKEN }}
      CLOUDFLARE_ACCOUNT_ID: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}

## Workflow deploy-docker.yml

Despliega Next.js/Docker con rollback automatico si healthcheck falla.

Uso desde un repo:

jobs:
  deploy:
    uses: victorneyraars/baqueano-natales/.github/workflows/deploy-docker.yml@SHA
    with:
      deploy-path: /home/deploy/mi-app
      compose-file: docker-compose.yml
      healthcheck-url: https://mi-app.com/
      branch: main
    secrets:
      SSH_HOST: ${{ secrets.SERVER_HOST }}
      SSH_USER: ${{ secrets.SERVER_USER }}
      SSH_KEY: ${{ secrets.SERVER_SSH_KEY }}

## Convenciones por repositorio

| Aspecto | Regla |
|---|---|
| Branch produccion | main |
| Branch staging | dev |
| Package manager | npm (package-lock) o pnpm (pnpm-lock) |
| Workflow | .github/workflows/deploy.yml |
| Trigger | push: branches: [main] + workflow_dispatch |

## Flujo de trabajo tipico

1. Desarrollo:
   git checkout -b feat/mi-feature
   git commit -am "feat: mi cambio"
   git push origin feat/mi-feature
   (CF Pages no deploya, solo escucha main)

2. Staging:
   git checkout dev
   git merge feat/mi-feature
   git push origin dev
   (CF Pages deploya a .pages.dev preview)

3. Produccion:
   git checkout main
   git merge dev
   git push origin main
   (GitHub Actions -> CF Pages -> dominio)

## Sitios activos en produccion

| Web | Stack | Plataforma | Deploy | SSL |
|---|---|---|---|---|
| rentacarvasquez.com | Next.js | Docker | deploy-docker.yml | Let's Encrypt |
| baqueanonatales.com | Astro | CF Pages | deploy-astro.yml | Cloudflare |
| sealquilamarido.com | Astro | CF Pages | deploy-astro.yml | Cloudflare |

## Nombres de repos

- victorneyraars/baqueano-natales (monorepo backend + Flutter + CI/CD)
- victorneyraars/rentacarvasquez-web (Next.js + Docker)
- victorneyraars/baqueano-natales-web (Astro)
- victorneyraars/se-alquila-marido-web (Astro)

## Troubleshooting

### workflow not found
Causa: SHA invalido o repo baqueano-natales privado.
Fix: verificar visibilidad + actualizar SHA.

### missing secret
Causa: falta configurar el secret en el repo.
Fix: gh secret set NOMBRE --body "valor" --repo org/repo

### sitio no actualizado tras deploy success
Causa: cache de CF Pages (~30s).
Fix: esperar 30s + hard refresh.

### Healthcheck FALLO en Docker
Causa: contenedor no responde.
Fix: rollback automatico, revisar docker logs.

### CORS error
Causa: dominio no esta en CORS_ORIGINS del backend.
Fix: agregar a .env.dev y .env.prod + recrear container.

## Proximos pasos

- [ ] Agregar actionlint como quality gate
- [ ] Agregar zizmor (auditoria seguridad)
- [ ] Configurar GitHub Environments con approval
- [ ] Migrar dev-build.yml (Flutter) al patron reusable
- [ ] Documentar rotacion de secrets

## Como agregar una nueva web

1. Crear repo con .github/workflows/deploy.yml (17 lineas)
2. Elegir reusable segun stack (astro o docker)
3. Configurar secrets (CLOUDFLARE_* o SERVER_*)
4. Push a main -> primer deploy automatico

---

Ultima actualizacion: 2026-10-28
Responsable: Equipo Baqueano Natales
