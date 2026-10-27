# 02 - Patrón Frontend (Next.js + Docker)

> Guía para crear la web pública premium de una nueva vertical.

## Stack confirmado

| Componente | Versión | Por qué |
|---|---|---|
| Next.js | 16.4.3 | App Router + Turbopack (dev) + standalone output |
| React | 19.3.0 | Server Components |
| TypeScript | 5.9.3 | Tipado estricto |
| Tailwind CSS | 4.3.3 | Utilidades, sin archivo de config |
| pnpm | 12.15.0 | Rápido, eficiente |
| Node | 22 Alpine | Container final ~150MB |

## Paso 1: Crear el proyecto

~~~bash
cd /home/deploy
corepack enable pnpm   # (con sudo si es la primera vez)
pnpm create next-app@latest <vertical>-web \
  --typescript --tailwind --app --no-src-dir \
  --import-alias "@/*" --use-pnpm --no-eslint \
  --turbopack --no-react-compiler \
  --no-cache-components --no-agents-md
~~~

## Paso 2: Instalar `@tailwindcss/postcss`

**CRÍTICO**: `create-next-app --turbopack` **NO crea** `postcss.config.mjs`. En `dev` funciona (Turbopack maneja Tailwind), pero en `build` el CSS queda **VACÍO** sin este archivo.

~~~bash
cd /home/deploy/<vertical>-web
pnpm add -D @tailwindcss/postcss
~~~

Y crear `postcss.config.mjs`:

~~~javascript
const config = {
  plugins: {
    "@tailwindcss/postcss": {},
  },
};
export default config;
~~~

## Paso 3: Estructura de carpetas

~~~text
<vertical>-web/
├── app/
│   ├── layout.tsx         # Metadata SEO + font Inter
│   ├── page.tsx           # Homepage (server component con ISR)
│   ├── globals.css        # Tailwind + colores de marca
│   └── vehiculos/[id]/    # Detalle (futuro)
├── components/
│   └── <Entidad>Card.tsx  # Card reutilizable
├── lib/
│   ├── types.ts           # Interfaces TypeScript
│   └── api.ts             # Cliente fetch con ISR
├── public/
├── .env.local             # (dev)
├── .env.production        # (prod)
├── .dockerignore
├── Dockerfile
├── docker-compose.rentacar.yml
├── next.config.ts         # standalone output
├── postcss.config.mjs     # REQUERIDO para Tailwind en build
└── tsconfig.json
~~~

## Paso 4: `lib/types.ts`

Interfaces que espejan los schemas de Pydantic:

~~~typescript
export interface Vehiculo {
  id: string;
  prestador_id: string;
  patente: string;
  marca: string;
  modelo: string;
  anio: number;
  categoria: string;
  precio_dia: number;
  disponible: boolean;
}
~~~

## Paso 5: `lib/api.ts` (cliente con ISR)

**Patrón obligatorio**: `next: { revalidate: 30 }` para que la web se regenere cada 30s sin perder el HTML estático.

~~~typescript
import type { Vehiculo } from './types';

const API_URL = process.env.NEXT_PUBLIC_API_URL ?? 'https://api-dev.baqueanonatales.com';
const PRESTADOR_ID = process.env.NEXT_PUBLIC_PRESTADOR_ID ?? '';
export const REVALIDATE_SECONDS = 30;

async function fetchJson<T>(path: string): Promise<T> {
  const res = await fetch(`${API_URL}${path}`, {
    next: { revalidate: REVALIDATE_SECONDS },
    headers: { Accept: 'application/json' },
  });
  if (!res.ok) throw new Error(`API error ${res.status}: ${path}`);
  return res.json() as Promise<T>;
}

export async function getVehiculosDelPrestador(): Promise<Vehiculo[]> {
  if (!PRESTADOR_ID) return [];
  return fetchJson<Vehiculo[]>(
    `/api/v1/public/rentacar/prestadores/${PRESTADOR_ID}/vehiculos`,
  );
}

export function formatCLP(value: number): string {
  return new Intl.NumberFormat('es-CL', {
    style: 'currency', currency: 'CLP', maximumFractionDigits: 0,
  }).format(value);
}
~~~

## Paso 6: `app/page.tsx` (homepage con ISR)

**Estructura recomendada**:

1. Hero con gradiente + título + CTAs.
2. Barra de features (4 íconos).
3. Catálogo de entidades (grid responsive).
4. Footer oscuro con contacto.

**Reglas**:

- `export const revalidate = 30` (coincide con `lib/api.ts`).
- `async function Home()` (Server Component, no `"use client"`).
- Los datos se cargan con `await getXxxDelPrestador()`.
- Nunca usar `"use client"` en la homepage (rompe ISR).

Esqueleto:

~~~typescript
import { getVehiculosDelPrestador, PRESTADOR } from "@/lib/api";

export const revalidate = 30;

export default async function Home() {
  const vehiculos = await getVehiculosDelPrestador();
  return (
    <main>
      <section className="hero-gradient">{/* hero */}</section>
      <section>{/* features */}</section>
      <section id="flota">{/* catálogo */}</section>
      <footer>{/* contacto */}</footer>
    </main>
  );
}
~~~

## Paso 7: `components/<Entidad>Card.tsx`

Componente cliente-friendly (Server Component que es `Link` a detalle).

**Reglas**:

1. Acepta `vehiculo: Vehiculo` y opcional `index` (para animación).
2. Usa `<Link href={/vehiculos/${vehiculo.id}}>` de `next/link`.
3. Placeholder de imagen por categoría (hasta que haya fotos reales).
4. Usa `formatCLP` para precios.

Ver ejemplo completo en: `components/VehiculoCard.tsx`

## Paso 8: `app/layout.tsx` (SEO)

**Reglas**:

1. `metadata` con `title`, `description`, `openGraph`, `keywords`.
2. Font `Inter` de Google Fonts via `next/font/google`.
3. `lang="es"` en `<html>`.
4. `metadataBase: new URL(SITE_URL)` para OG images.

Ver ejemplo: `app/layout.tsx`

## Paso 9: `app/globals.css` (tema de marca)

**Tailwind 4 usa `@theme`** en lugar de `tailwind.config.js`.

~~~css
@import "tailwindcss";

@theme {
  --color-brand-500: #3b82f6;
  --color-brand-600: #2563eb;
  --color-brand-900: #1e3a8a;
  --color-accent-500: #f59e0b;
}

.hero-gradient {
  background: linear-gradient(135deg, #1e3a8a 0%, #1d4ed8 50%, #3b82f6 100%);
}

.card-hover {
  transition: transform 0.3s, box-shadow 0.3s;
}
.card-hover:hover {
  transform: translateY(-4px);
  box-shadow: 0 20px 40px rgba(0,0,0,0.15);
}
~~~

## Paso 10: `next.config.ts` (standalone)

~~~typescript
import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  output: "standalone",
  images: {
    remotePatterns: [
      { protocol: "https", hostname: "images.unsplash.com" },
    ],
  },
  poweredByHeader: false,
  reactStrictMode: true,
};

export default nextConfig;
~~~

## Paso 11: `.env.local` (dev) y `.env.production`

Mismas variables en ambos archivos:

~~~text
NEXT_PUBLIC_API_URL=https://api-dev.baqueanonatales.com
NEXT_PUBLIC_PRESTADOR_ID=<uuid-del-prestador>
NEXT_PUBLIC_PRESTADOR_SLUG=<slug-del-prestador>
NEXT_PUBLIC_SITE_NAME=<Nombre Comercial>
NEXT_PUBLIC_SITE_URL=https://<dominio>.com
NEXT_PUBLIC_SITE_PHONE=+56912345678
NEXT_PUBLIC_SITE_EMAIL=contacto@<dominio>.com
NEXT_PUBLIC_SITE_CITY=Puerto Natales
~~~

## Paso 12: Verificar build local

~~~bash
cd /home/deploy/<vertical>-web
pnpm build
~~~

**Chequeos críticos:**

- Debe decir `Compiled successfully`.
- Debe mostrar `Route (app)  Revalidate 30s` (ISR activo).
- **Si el CSS pesa < 1000 bytes**: falta `postcss.config.mjs` (ver Paso 2).

~~~bash
# Verificar tamaño del CSS compilado
ls -la .next/static/chunks/*.css
# Debe ser > 10.000 bytes
~~~

## Paso 13: Verificar en dev

~~~bash
pnpm dev &
curl -s http://localhost:3000 | grep -oE "<title>[^<]+</title>"
curl -s http://localhost:3000 | grep -oE "(<Nombre>|<Precio>)" | sort -u
~~~

Debe mostrar los datos reales desde la API.

## Referencias del caso real

- **Homepage**: `/home/deploy/rentacarvasquez-web/app/page.tsx`
- **Card**: `/home/deploy/rentacarvasquez-web/components/VehiculoCard.tsx`
- **API client**: `/home/deploy/rentacarvasquez-web/lib/api.ts`
- **Layout SEO**: `/home/deploy/rentacarvasquez-web/app/layout.tsx`
- **Tema**: `/home/deploy/rentacarvasquez-web/app/globals.css`

## Commit

~~~bash
cd /home/deploy/<vertical>-web
git init
git add -A
git commit -m "feat: <Nombre> - sitio web premium Next.js 16 + ISR"
~~~
