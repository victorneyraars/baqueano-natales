# HANDOFF — Portal Cliente Web (Sesion 2026-11-08)

## CONTEXTO
Se construyo el primer Portal Cliente web del ecosistema Baqueano, en un
monorepo industrial con Turborepo. Convive en paralelo con las webs
existentes (se-alquila-marido, rentacarvasquez) sin tocarlas.

## INFRAESTRUCTURA
- Monorepo: /home/deploy/baqueano-ecosystem
- Turborepo + pnpm
- Apps: apps/portal (Next.js 16), apps/admin (Next.js, vacio), apps/landings (Astro, vacio)
- Packages: ui, api-client, auth, types (compartidos)
- Deploy: Cloudflare Pages (baqueano-portal.pages.dev)
- Node 22.23.4 via fnm (.nvmrc en la raiz)

## PORTAL CLIENTE FUNCIONAL
- https://baqueano-portal.pages.dev/login (Google Auth)
- https://baqueano-portal.pages.dev/mi-cuenta (Dashboard)
- https://baqueano-portal.pages.dev/mi-cuenta/reservas (Rent a Car)
- https://baqueano-portal.pages.dev/mi-cuenta/ordenes (Mecanica)

## BACKEND
- Nuevo endpoint: GET /api/v1/mis-reservas (para clientes Rent a Car)
- CORS: agregado https://baqueano-portal.pages.dev a .env.prod
- Bug fix: _serializar_orden movido a _serializers.py compartido
  (antes vivia en prestador_routes.py, cliente_routes.py fallaba con NameError)

## DEPLOY DEL PORTAL
cd /home/deploy/baqueano-ecosystem/apps/portal
rm -rf .next out
pnpm run build
npx -y wrangler pages deploy out --project-name=baqueano-portal --branch=main

## DEPLOY DEL BACKEND
cd /home/deploy/baqueano-natales
bash scripts/deploy-prod.sh

## GCLOUD INSTALADO
- Google Cloud SDK 592.0.0 en /usr/bin/gcloud
- Auth: victorneyraars@gmail.com (owner)
- Service Account: seo-bot@baqueano-natales-prod.iam.gserviceaccount.com
- Rol: roles/firebase.admin
- Para agregar dominios nuevos a Firebase: script de Python con API admin/v2

## PROXIMOS PASOS
1. Completar "Mis Vehiculos" (/mi-cuenta/vehiculos)
2. Construir Panel Admin Web (apps/admin) con dashboard, prestadores, oficios
3. Migrar se-alquila-marido y rentacarvasquez a apps/landings (Astro multi-tenant)
4. Real-time: SSE para refrescar datos en vivo

## REGLAS
- Nunca tocar rentacarvasquez-web (Next.js) ni se-alquila-marido-web (Astro)
  hasta que el monorepo tenga paridad funcional.
- Todo cambio en packages/ se refleja automaticamente en las 3 apps.
- Para Firebase: usar gcloud en vez de la consola web.
