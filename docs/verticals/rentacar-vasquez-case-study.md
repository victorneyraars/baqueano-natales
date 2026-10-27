# Caso de Estudio: Rent a Car Vásquez

> Primer caso real de una vertical completa en producción. Sirve como referencia para replicar el patrón en futuras verticales.

## Resumen ejecutivo

| Aspecto | Detalle |
|---|---|
| **Dominio** | `rentacarvasquez.com` |
| **Estado** | ✅ En producción desde 2026-10-27 |
| **Stack** | FastAPI + Next.js 16 + Docker + Nginx + Cloudflare |
| **Datos iniciales** | 1 prestador + 1 config + 3 vehículos |
| **Tiempo total** | ~10 horas (primera vertical, incluye debugging) |
| **Tiempo estimado réplica** | ~3-4 horas |

## Timeline real (2026-10-27)

| Hora UTC | Hito |
|---|---|
| 11:30 | Inicio: módulo backend `rentacar/` vacío |
| 11:45 | Modelos + schemas + services escritos |
| 12:00 | Migración aplicada (3 tablas creadas) |
| 12:15 | Endpoints admin + públicos registrados |
| 12:20 | Endpoints verificados con `curl` (200/401/304) |
| 12:30 | Proyecto Next.js 16 creado |
| 12:35 | Homepage + componentes escritos |
| 12:40 | Docker container + Nginx config |
| 12:50 | SSL emitido con acme.sh |
| 13:00 | DNS configurado en Cloudflare |
| 13:10 | Bug CSS encontrado (proxy_cache) |
| 13:20 | Bug CSS resuelto + sitio 100% funcional |
| 13:30 | Documentación completa |

## Stack técnico final

| Capa | Tecnología | Versión |
|---|---|---|
| **Backend** | FastAPI + SQLAlchemy 2.0 | Python 3.12 |
| **DB** | PostgreSQL | 16 |
| **Frontend** | Next.js (App Router) | 16.4.3 |
| **React** | Server Components | 19.3.0 |
| **CSS** | Tailwind (con `@theme`) | 4.3.3 |
| **TypeScript** | Estricto | 5.9.3 |
| **Package manager** | pnpm | 12.15.0 |
| **Container** | Node Alpine | 22 |
| **Reverse proxy** | Nginx | 1.27-alpine |
| **SSL** | Let's Encrypt (ZeroSSL) | EC-256 |
| **DNS** | Cloudflare (proxied=false) | - |

## Datos de referencia (UUIDs)

### Prestador creado

~~~text
Prestador ID:   c9aa7037-a4de-4217-b6dc-fa5893062657
Nombre:         Rent a Car Vásquez
Slug:           rentacar-vasquez
Usuario:        927f08e1-db1b-49d7-9fe1-039102239f72 (baqueano.qa.multi@gmail.com)
Categoría:      db5f037a-f6cf-4c57-a1c9-7d4d20cca067 (arriendo-vehiculos)
~~~

### Config rentacar

~~~text
Config ID:      7707fba0-c3a1-41f9-80a9-f8605a0e6c3f
Métodos pago:   mercadopago=true, transferencia=true, efectivo=true
Depósito:       porcentaje=20%
Conductor adicional: habilitado=true, tarifa=5000/día
Categorías:     SUV, SEDAN, PICKUP, FURGONETA
~~~

### Vehículos iniciales

| ID | Patente | Marca | Modelo | Año | Categoría | Precio/día |
|---|---|---|---|---|---|---|
| `6e67c9e2-9594-453e-9fab-e5163c26ab6f` | BBCC12 | Toyota | RAV4 | 2023 | SUV | $45.000 |
| `b75166c9-bf22-42d3-a5a9-72c4b3c4f0bf` | DDEE34 | Nissan | Versa | 2022 | SEDAN | $30.000 |
| `1dba46b0-d000-47a4-95ac-2319f25f8ae1` | FFGG56 | Mitsubishi | L200 | 2024 | PICKUP | $55.000 |

### Cloudflare

~~~text
Zone ID:        3dd2b73b92db1bdfec1ba7a7fc6dfd6f
Nameservers:    april.ns.cloudflare.com, simon.ns.cloudflare.com
Registros A:    @ → 104.129.59.151 (proxied=false)
                www → 104.129.59.151 (proxied=false)
~~~

## Commits clave

| SHA | Mensaje | Módulo |
|---|---|---|
| `68d7233` | `feat(rentacar): modelos, schemas y migración base` | Backend |
| `b8c000c` | `feat(rentacar): services con CRUD de config, vehículos y reservas` | Backend |
| `dab405f` | `feat(rentacar): endpoints admin (CRUD) y públicos (ETag) registrados` | Backend |
| `f0699a4` | `feat(oauth): inAppBrowserView primero + fix doble procesamiento` | Flutter |
| (varios) | Deploy web + Docker + Nginx + SSL | Deploy |

## Lecciones aprendidas

### 1. El autogenerate de Alembic no es confiable al 100%

**Problema**: Detectó schema drift en tablas existentes y generó DROP TABLE peligrosos.

**Lección**: Siempre revisar el archivo de migración generado antes de aplicar. Si tiene DROPs de tablas existentes, borrarlo y crear la migración manualmente.

**Impacto**: Evitó pérdida de datos en `media_assets`, `social_posts` y `configuraciones`.

### 2. `create-next-app --turbopack` no configura Tailwind para producción

**Problema**: `postcss.config.mjs` no se crea por defecto. En `dev` funciona, en `build` el CSS queda vacío.

**Lección**: Siempre agregar `pnpm add -D @tailwindcss/postcss` + crear `postcss.config.mjs` **antes del primer build de producción**.

**Impacto**: Sin esto, el sitio se veía con Times New Roman sin estilos.

### 3. Nginx `proxy_cache` puede servir respuestas vacías

**Problema**: Cacheó una respuesta vacía del CSS durante el build. El CSS roto se sirvió por 1 año.

**Lección**: Nunca cachear assets de Next.js con hash en nginx. Next.js ya envía `Cache-Control: immutable` en nombres con hash.

**Impacto**: Después de 2 horas de debugging (el CSS existía en el container pero llegaba vacío), se resolvió eliminando `proxy_cache_valid` de la config.

### 4. `wget --spider` falla en Alpine

**Problema**: El healthcheck del container siempre daba `unhealthy`.

**Lección**: Usar `wget -q -O /dev/null` (más robusto) o `node -e "require('http')..."`.

**Impacto**: Container `healthy` después del fix, y Docker puede reiniciar automáticamente si Next.js se cae.

### 5. El patrón híbrido (Core + Detalle) escala bien

**Problema**: ¿Cómo agregar verticales sin duplicar identidad (usuarios, prestadores, pagos)?

**Lección**: Usar tablas compartidas para identidad + tablas específicas por vertical con prefijo (`rentacar_vehiculos`, `hostales_habitaciones`).

**Impacto**: Nuevas verticales solo necesitan crear sus tablas específicas, no duplicar todo el modelo.

### 6. Documentar el patrón en el mismo PR/commit

**Problema**: Sin documentación, replicar el proceso implicaría re-descubrir todos los bugs.

**Lección**: Documentar los patrones (backend, frontend, deploy) **junto con el código**, en la misma sesión.

**Impacto**: Futuras verticales se pueden construir en ~4 horas en lugar de ~10.

## Checklist para replicar en la próxima vertical

### Backend (2-4 horas)

- [ ] Crear `backend/app/modules/<vertical>/`
- [ ] Modelos con UUID + `TimestampMixin` + prefijo en tabla
- [ ] Schemas `Base` / `Create` / `Out`
- [ ] Services async con `AsyncSession`
- [ ] Routes admin con `AdminUser`
- [ ] Public routes con ETag + `Cache-Control`
- [ ] Registro en `main.py`
- [ ] Migración **manual** (no confiar en autogenerate)
- [ ] Datos de prueba (prestador + config + items)
- [ ] Verificar endpoints con `curl`

### Frontend (3-5 horas)

- [ ] `pnpm create next-app@latest`
- [ ] `pnpm add -D @tailwindcss/postcss` + `postcss.config.mjs`
- [ ] `lib/types.ts` con interfaces
- [ ] `lib/api.ts` con ISR (`revalidate: 30`)
- [ ] `app/layout.tsx` con metadata SEO
- [ ] `app/globals.css` con `@theme` de marca
- [ ] `app/page.tsx` (homepage premium)
- [ ] `components/<Entidad>Card.tsx`
- [ ] `next.config.ts` con `output: "standalone"`
- [ ] `pnpm build` exitoso + CSS >10KB
- [ ] Verificar con `curl localhost:3000`

### Deploy (1 hora)

- [ ] `Dockerfile` multi-stage
- [ ] `.dockerignore`
- [ ] `docker-compose.<vertical>.yml` en red `baqueano_net`
- [ ] Build + up del container
- [ ] `nginx/conf.d/<dominio>.conf` (sin proxy_cache)
- [ ] Cert SSL con acme.sh + Cloudflare
- [ ] DNS apex + www en Cloudflare
- [ ] Verificar apex + www + CSS + SSL

### Cierre

- [ ] Commit del código backend al repo principal
- [ ] Commit del frontend al repo de la web
- [ ] Documentar en `docs/verticals/`
- [ ] Actualizar README principal con la nueva vertical

## Consideraciones futuras

### Página de detalle del vehículo

Actualmente el sitio solo tiene catálogo. Falta:

- `app/vehiculos/[id]/page.tsx` con galería de fotos.
- Formulario de reserva (fecha inicio, fecha fin, método de pago).
- POST a `/api/v1/public/rentacar/reservas` (o `/admin` con auth).

### Panel admin Flutter

Falta una pantalla en la app Admin de Flutter para que Vásquez pueda:

- Subir vehículos (con fotos).
- Configurar métodos de pago.
- Ver reservas.
- Gestionar disponibilidad.

### Fotos reales

Los 3 vehículos usan placeholders de Unsplash. Cambiar por fotos reales cuando estén disponibles:

- Agregar campo `imagen_url` a `rentacar_vehiculos`.
- Actualizar `VehiculoCard.tsx` para usar `next/image` con `remotePatterns` configurado.

### Pasarela de pagos

Actualmente `metodos_pago` es JSONB configurable, pero no hay integración real. Cuando se active:

- MercadoPago SDK en backend.
- Webhook para confirmar reservas.
- Estado `pagado` en `rentacar_reservas`.

### Activar Cloudflare Proxy

Cambiar `proxied: false` a `proxied: true` + Cloudflare Origin cert (en lugar de Let's Encrypt directo). Beneficios:

- DDoS protection.
- CDN global.
- IP del servidor oculta.

## Contacto

- **Dueño de la vertical**: Vásquez (contacto: `contacto@rentacarvasquez.com`)
- **Mantenimiento técnico**: Equipo Baqueano Natales
- **Repositorio**: `github.com/victorneyraars/baqueano-natales`

---

**Última actualización**: 2026-10-27
**Estado**: ✅ Producción

---

## Actualización 2026-10-27 (tarde): Completado del corto plazo

Después de la primera sesión, se completaron los 3 ítems del corto plazo:

### ✅ Página de detalle de vehículo

- Ruta: `/vehiculos/[id]`
- Componente: Server Component con `revalidate: 30`
- Layout: 2 columnas en desktop (`md:grid-cols-5`, 3 para imágenes, 2 para formulario sticky), 1 en móvil.
- Incluye: foto grande, specs en cards (año, categoría, seguro, soporte), formulario de reserva.

### ✅ Formulario de reserva funcional

- Componente: `components/ReservaForm.tsx` (Client Component).
- Cálculo dinámico de días + precio total en vivo.
- POST a `/api/v1/public/rentacar/reservas` (público, sin auth).
- Crea reserva en PostgreSQL con estado `pendiente`.
- Soporta cliente invitado: `nombre_cliente`, `email_cliente`, `telefono_cliente`, `metodo_pago`.
- Migración `manual_rentacar_002`: `cliente_id` nullable + datos de contacto.

### ✅ Fotos reales con Cloudflare R2

- Bucket: `baqueano-public` (creado vía API).
- URL pública: `https://pub-26428d066b4c4eeab91fc8fedf8c036c.r2.dev`.
- Helper reutilizable: `backend/app/core/storage.py`.
- Endpoints presigned:
  - `POST /admin/rentacar/vehiculos/{id}/imagen/presigned`
  - `POST /admin/rentacar/vehiculos/{id}/imagen/confirmar`
- Frontend: `VehiculoCard.tsx` y `[id]/page.tsx` usan `imagen_url || CATEGORIA_IMAGEN[...] || DEFAULT_IMG`.
- 3 fotos subidas:
  - BBCC12 (Toyota RAV4): `rentacar/vehiculos/bbcc12/e9d4beee...jpg`
  - DDEE34 (Nissan Versa): `rentacar/vehiculos/ddee34/e6761d7d...jpg`
  - FFGG56 (Mitsubishi L200): `rentacar/vehiculos/ffgg56/26c7d03a...jpg`

### ✅ Bugs adicionales resueltos

| # | Bug | Fix |
|---|---|---|
| 13 | CORS `Failed to fetch` | Agregar `rentacarvasquez.com` a `CORS_ORIGINS` + `--force-recreate` |
| 14 | R2 `pub-xxxx.r2.dev` placeholder | Habilitar public access vía API + copiar URL real |
| 15 | `create-next-app --turbopack` sin `postcss.config.mjs` | Agregar `@tailwindcss/postcss` + `postcss.config.mjs` |
| 16 | Nginx `proxy_cache` cachea CSS vacío | Eliminar `proxy_cache_valid` de `/_next/static/` |
| 17 | `docker restart` no recarga env vars | Usar `docker compose up -d --force-recreate` |

### 📊 Estado final del proyecto

| Componente | Estado |
|---|---|
| Homepage con catálogo | ✅ |
| Página de detalle | ✅ |
| Formulario de reserva | ✅ |
| Fotos reales en R2 | ✅ |
| Reservas en PostgreSQL | ✅ |
| CORS configurado | ✅ |
| SSL + DNS + Docker + Nginx | ✅ |
| Repo backend (`baqueano-natales`) | ✅ Pusheado a GitHub |
| Repo frontend (`rentacarvasquez-web`) | ✅ Pusheado a GitHub |

### 🔮 Próximos pasos (mediano plazo)

1. **Panel admin Flutter**: subir fotos desde la app (usa los presigned URLs ya listos).
2. **Integración de pagos**: MercadoPago / Transbank con webhooks.
3. **Sistema de reservas completo**: estados `pendiente` → `confirmada` → `completada`, con notificaciones.
4. **Notificaciones push**: al confirmar reservas, al admin de Vásquez.
5. **CI/CD al frontend**: workflow de GitHub Actions para auto-deploy en push a `main`.
6. **Custom domain para R2**: `media.rentacarvasquez.com` (CNAME a R2) en lugar de `pub-xxx.r2.dev`.
7. **Replicar a nueva vertical**: Hostales, Delivery o Taxis (usar `docs/verticals/` como guía).

---

**Última actualización**: 2026-10-27 17:00 UTC
**Estado**: ✅ Producción completa (corto plazo)
