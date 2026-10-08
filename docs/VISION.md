# Visión — Baqueano Natales

> **Última actualización:** 2026-10-08
> **Estado:** Documento vivo. Se actualiza a medida que la plataforma crece.

---

## 🎯 Qué es Baqueano Natales

Una **superapp regional** para Puerto Natales, Chile. No es "una app de movilidad", es una **plataforma multi-vertical** que cubre las necesidades locales a medida que aparecen.

**Filosofía:**
> Cada vez que se presenta una necesidad concreta en Puerto Natales, la intentamos cubrir con la app. Los verticales se suman de forma **modular**, sin romper lo existente.

---

## 🧭 Tipos de verticales

| Tipo | Ejemplos | Actor del lado oferta |
|---|---|---|
| **B2C** | Comercios, farmacias, restaurantes | Comercio |
| **Servicios** | Gasfitería, electricidad, mecánica | Prestador (oficio) |
| **Movilidad** | Taxi, colectivo, delivery | Socio (conductor) |
| **Alojamiento** | Hospedajes, cabañas, hostales | Anfitrión |
| **Arriendos** | Autos, equipos, herramientas | Arrendador |
| **C2C** | Compra-venta de nuevos y usados | Usuario-vendedor |
| **...** | (futuros) | (futuros) |

---

## 📦 Verticales actuales

| Vertical | Estado | Módulo backend |
|---|---|---|
| **Comercios** | ✅ Producción | `modules/comercios/` |
| **Oficios** | 🎯 En desarrollo (mecánica primero) | `modules/prestadores/` |
| **Movilidad** | ⏳ Diseño | `modules/socios/` + `modules/solicitudes/` |
| **Recompensas** | ⏳ Futuro | `modules/recompensas/` |
| **Hospedajes** | ⏳ Futuro | `modules/alojamientos/` |
| **Arriendos** | ⏳ Futuro | `modules/arriendos/` |
| **Marketplace C2C** | ⏳ Futuro | `modules/marketplace/` |

### 🎯 Prioridad actual

**Fase 1 (ahora):** Oficios — empezando por **mecánica de autos**, totalmente operativa.
- Clientes pueden buscar mecánicos, ver perfiles, contactar, dejar reviews
- Mecánicos pueden registrarse, publicar perfil, gestionar solicitudes
- Admin verifica/rechaza
- Usuarios pueden registrar sus vehículos (garage)

**Fase 2:** Movilidad (socios + viajes + mapa en vivo + zonas + tarifas)

**Fase 3:** Resto del ecosistema (hospedajes, arriendos, marketplace)

---

## 🏗️ Principio fundamental: Transversal vs. Vertical

**Toda feature se clasifica en una de dos categorías:**

### Transversal (se construye UNA vez, lo usan TODOS los verticales)

| Transversal | Sirve para |
|---|---|
| **Auth + Usuarios** | Todos |
| **Chat** | Movilidad, hospedaje, marketplace, oficios |
| **Reviews / Ratings** | Conductores, comercios, hospedajes, vendedores |
| **Notificaciones (FCM)** | Todos |
| **Geo / Mapa** | Movilidad, hospedaje, delivery |
| **Pagos / Comprobantes** | Todos |
| **Verificación (KYC, RUT, patente)** | Conductores, vendedores, anfitriones |
| **Media / Archivos** | Todos |
| **Reportes / Moderación** | Todos |

### Vertical (uno por dominio de negocio)

Cada vertical tiene:
- Sus **modelos** propios
- Sus **endpoints** propios (bajo `/api/v1/{vertical}/...`)
- Sus **flujos** propios
- Puede **usar** transversal, pero NO otro vertical

---

## 🚦 Cómo se agrega un vertical nuevo

**Regla de oro:** un vertical nuevo NO se mete dentro de otro módulo. Se crea como módulo nuevo.

**Checklist para agregar un vertical:**

1. **Nombrar el módulo** (ej: `alojamientos`)
2. **Definir el actor de oferta** (¿es un usuario con rol nuevo? ¿un perfil sobre `usuarios`?)
3. **Diseñar el modelo de datos** (siguiendo el patrón `comercios`/`prestadores`)
4. **Identificar qué transversales reutiliza** (chat, reviews, media, etc.)
5. **Construir en 4 capas**: `models → schemas → services → routes`
6. **Integrar en `main.py`** con su `prefix` y `tags`
7. **Documentar en `CONTEXTO_PROYECTO.md`**

---

## 🎨 Principios de diseño

### 1. Modularidad estricta
- Un módulo **NO importa modelos de otro módulo**
- Si necesita datos de otro, usa **schemas/servicios** (contrato, no implementación)
- Los transversales viven en `app/shared/` o `app/core/`

### 2. API-first
- Todo módulo expone endpoints REST versionados (`/api/v1/...`)
- OpenAPI auto-generado (FastAPI)
- Si otro proyecto nuestro necesita consumir → usa la misma API

### 3. Humano en el loop
- Las decisiones críticas (suspender, rechazar, verificar) las toma un admin
- Los estados automáticos son **insumos**, no decisiones finales

### 4. Idempotencia
- Seeds, migraciones y operaciones de setup deben poder correrse N veces sin romper

### 5. Preparado para escalar, sin sobre-ingeniería
- Monolito modular **ahora**
- Si un módulo necesita su propio servicio → se extrae **después**
- No anticipar problemas que no existen

---

## 🔌 Consumo por otros proyectos

**A futuro**, la plataforma puede exponer APIs consumibles por otros proyectos del studio:

| Tipo de consumo | Ejemplo |
|---|---|
| **API pública** | Otro proyecto lee categorías de comercios |
| **Auth delegado** | Otro proyecto usa nuestro sistema de usuarios |
| **Webhooks** | Notificar eventos (nuevo comercio verificado, viaje completado) |
| **SDKs** | Auto-generados desde OpenAPI |

**Decisión actual:** la API ya está versionada (`/api/v1/`), el OpenAPI ya está disponible. Los SDKs y webhooks se suman **cuando haya un consumidor real**.

---

## 🚫 Anti-patrones prohibidos

| Anti-patrón | Por qué está prohibido |
|---|---|
| Meter feature de movilidad dentro de `comercios` | Rompe la modularidad |
| Importar `models.Comercio` desde `modules.prestadores` | Acoplamiento entre verticales |
| Duplicar chat/reviews en cada vertical | Ignora lo transversal |
| Microservicios antes de tener escala | Sobre-ingeniería |
| Enum de roles que crece sin control | Migrar a tabla relacional cuando llegue a 6+ roles |
| Cambiar el diseño de un vertical ya en producción sin migración | Rompe usuarios activos |

---

## 🔗 Dependencias transversales por fase

**Fase 1 (Oficios) construye y deja listos para reuso:**
- ✅ `reviews` (transversal)
- ✅ `media` extendido (fotos de trabajos)
- ✅ `verificacion` (KYC Didit aplicable a cualquier actor)
- ✅ `ubicacion` (geo para mostrar dónde opera)

Estos transversales serán reutilizados por movilidad, hospedajes, marketplace **sin reescribir nada**.

---

## 📌 Referencias

- **Arquitectura técnica:** `docs/ARCHITECTURE.md`
- **Análisis del sistema anterior:** `docs/LEGACY_ANALYSIS.md`
- **Estado del proyecto:** `CONTEXTO_PROYECTO.md`

---

**Fin del documento.**