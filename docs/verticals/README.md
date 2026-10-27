# Verticales de Baqueano Natales

> Baqueano Natales crece por **verticales** independientes. Cada una tiene su propio dominio, backend y web premium, pero todas comparten identidad (usuarios, prestadores, pagos).

## Verticales en producción

| Vertical | Dominio | Backend | Estado |
|---|---|---|---|
| Oficios | `sealquilamarido.cl` | `backend/app/modules/oficios/` | ✅ Producción |
| Rent a Car Vásquez | `rentacarvasquez.com` | `backend/app/modules/rentacar/` | ✅ Producción (Oct 2026) |

## Verticales planeadas

| Vertical | Backend previsto | Prioridad |
|---|---|---|
| Hostales | `backend/app/modules/hostales/` | Media |
| Delivery | `backend/app/modules/delivery/` | Media |
| Taxis | `backend/app/modules/taxis/` | Baja |

## Documentación

| Documento | Cuándo leerlo |
|---|---|
| **[01 - Patrón Backend](01-backend-pattern.md)** | Agregar una nueva vertical o modificar el backend de una existente |
| **[02 - Patrón Frontend](02-frontend-pattern.md)** | Crear la web pública de una vertical |
| **[03 - Patrón Deploy](03-deploy-pattern.md)** | Deployar una nueva web, configurar SSL o DNS |
| **[04 - Troubleshooting](04-troubleshooting.md)** | Bugs conocidos y sus soluciones |
| **[Caso: Rent a Car Vásquez](rentacar-vasquez-case-study.md)** | Referencia completa del primer caso real |

## Principios de diseño

1. **Aislamiento por vertical**: tablas propias (`rentacar_vehiculos`, `oficios_vehiculos`) para evitar acoplamiento.
2. **Identidad compartida**: usuarios, prestadores y pagos son comunes a todas las verticales.
3. **API pública con ETag**: `/api/v1/public/<vertical>/*` con `Cache-Control` + `ETag` para polling eficiente.
4. **Web premium independiente**: dominio propio, deploy en Docker, diseño adaptado al público.
5. **SSL automático**: Let's Encrypt via `acme.sh` + Cloudflare DNS-01, renovación cada 60 días.
6. **Sin desinstalación de app**: builds usan `--build-number=${{ github.run_number }}` para auto-update in-app.
7. **Imágenes en Cloudflare R2**: todas las fotos (vehículos, productos, habitaciones) viven en R2 con presigned URLs. Cero carga en el backend, CDN global de Cloudflare, cache 1 año.

## Flujo estándar para agregar una nueva vertical

~~~text
1. Backend (2-4 horas)
   - Crear modulo backend/app/modules/<vertical>/
   - Modelos + schemas + services + rutas
   - Migracion Alembic (manual si hay schema drift)

2. Datos de prueba (30 min)
   - INSERT prestador + config
   - INSERT items de ejemplo

3. Frontend Next.js (4-8 horas)
   - pnpm create next-app@latest <vertical>-web
   - lib/api.ts + lib/types.ts
   - app/page.tsx (homepage)
   - components/<Componente>Card.tsx

4. Deploy (1 hora)
   - next.config.ts (standalone)
   - Dockerfile + docker-compose.yml
   - nginx/conf.d/<dominio>.conf
   - cert SSL con acme.sh
   - DNS en Cloudflare

Total: 8-14 horas por vertical completa
~~~

## Convenciones de nombres

| Contexto | Convención | Ejemplo |
|---|---|---|
| Módulo backend | `snake_case` | `rentacar`, `hostales` |
| Tabla de BD | `snake_case` con prefijo del vertical | `rentacar_vehiculos`, `hostales_habitaciones` |
| Container Docker | `snake_case` | `rentacarvasquez_web` |
| Router FastAPI | `router_admin` / `router_publico` | `rentacar.routes.router_admin` |
| Dominio | `snake_case` sin guiones | `rentacarvasquez.com` |

## Contacto y mantenimiento

- **Repo principal**: github.com/victorneyraars/baqueano-natales
- **Servidor**: `deploy@baqueano-natales-prod` (IP: 104.129.59.151)
- **Cloudflare**: cuenta de Víctor (zone IDs en `docs/verticals/03-deploy-pattern.md`)

---

**Última actualización**: 2026-10-27
**Responsable**: Equipo Baqueano Natales
