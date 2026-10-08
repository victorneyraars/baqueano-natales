# Legacy Analysis — Sistema Anterior

> **Última actualización:** 2026-10-08
> **Fuente:** Repo `baqueano-natales-legacy` (rama `main`, commit `fa265086`)
> **Propósito:** Conservar el conocimiento del sistema anterior. Sirve como referencia de diseño y para migrar conceptos, no código.

---

## 📌 Contexto

El sistema anterior (`superapp-natales-backend`) fue una primera versión funcional de la plataforma. Se archivó en agosto 2026 y se reescribió desde cero con arquitectura moderna.

**Lo que se conserva:** conceptos de negocio, diseño de entidades, principios operativos.
**Lo que se descarta:** el código (migra a UUID, enums tipados, modular estricto).
**Lo que se mejora:** todo lo que en el legacy era texto libre, JSON strings o inconsistencias.

---

## 🎭 Los 4 actores del legacy

El legacy tenía 4 tipos de actores claramente diferenciados:

| Actor | Tabla | Concepto | Ubicación |
|---|---|---|---|
| **Usuario** | `usuarios` | Cliente (pide viajes/delivery/servicios) | — |
| **Socio** | `socios` | Conductor/repartidor | 📍 Mapa en vivo |
| **Prestador** | `prestadores` | Profesional de oficios (gasfiter, mecánico) | 🏠 Vitrina por categoría |
| **Local** | `locales` | Comercio (restaurante, farmacia) | 🏪 Catálogo |

**Diferencia clave:**
- **Socio** → opera en tiempo real, con vehículo, ubicación, tarifas, matching
- **Prestador** → opera async, vitrina por categoría, contacto por chat

---

## 🚗 Socio — Los 4 ejes de verificación

El legacy modelaba **4 ejes independientes** para un socio. Diseño muy maduro, se conserva casi tal cual:

| Eje | Campo | Fuente | Valores |
|---|---|---|---|
| **1. Operativo** | `estado` | El socio | `desconectado / conectado / ...` |
| **2. Vehicular** | `verificacion_estado` | Boostr (Registro Civil) | `no_aplica / en_cola / verificado / discrepancia` |
| **3. Identidad** | `nivel_identidad` | Didit (KYC biométrico) | `declarado / autocompletado / verificado / revision` |
| **4. RNSTP (MTT)** | `rnstp_estado` | MTT vía RNSTP | `no_aplica / sin_datos / habilitado / no_habilitado / revision` |

**Más:** `suspendido` (decisión admin, ortogonal a los 4 anteriores).

**Principio fundamental (conservar):**
> Los estados automáticos son **insumos** para decisión humana. Nunca se suspende a un socio automáticamente — el admin decide con el detalle a la vista.

### Tipos de vehículo del socio

```
taxi | colectivo | auto | moto | bicicleta | a_pie
```

En Puerto Natales:
- **Taxis y colectivos** son negros por reglamentación municipal, se identifican por patente
- **Autos y motos** particulares para delivery
- **Bicicletas y a_pie** para delivery sin motor

---

## 🏠 Prestador (oficios) — Diseño del legacy

Un particular o empresa que ofrece un oficio. **NO opera en tiempo real.**

**Características:**
- Pertenece a una **categoría** (gasfitería, electricidad, mecánica, etc.)
- **Zona de cobertura** (texto libre en legacy → área estructurada en el nuevo)
- **Fotos de trabajos** (JSON string en legacy → tabla relacional en el nuevo)
- **Estado:** `pendiente / aprobado / rechazado` (mismo flujo que comercios)
- **Verificado** (sello de confianza: KYC aprobado)
- **Reviews** con calificación promedio + conteo

### Categorías de oficio

Tabla `categorias_oficio` — editable por admin (no hardcodeada).

**Campos:** `nombre`, `slug`, `icono`, `activa`, `orden`.

---

## 📞 Solicitud de Servicio (cliente → prestador)

Modelo `SolicitudServicio` — el "contacto" cliente→prestador.

**Flujo:** `abierta → cotizada → aceptada/rechazada → cerrada`

**Campos clave:**
- `usuario_id` (cliente)
- `prestador_id` (oficio contactado)
- `descripcion` (qué necesita)
- `monto_acordado` (si hay cotización)
- `datos_extra` (JSON en legacy → estructura por especialidad en el nuevo)

**Nota:** el chat interno cuelga de acá (modelo `MensajeServicio`).

---

## 🚗 Solicitud (movilidad y delivery)

Modelo `Solicitud` — el "corazón del sistema" del legacy.

**Unifica viaje + delivery** con campo `tipo`.

**Campos clave:**
- `tipo` (viaje | delivery)
- `usuario_id`, `socio_id`, `local_id`
- `origen_lat/lng`, `destino_lat/lng`
- `origen_texto`, `destino_texto` (para aprender de la operación)
- `estado` (`pendiente / aceptada / en_curso / completada / cancelada`)
- `tarifa_estimada`, `tarifa_final`, `tarifa_id`
- `zona_origen_id`, `zona_destino_id`
- `medio_preferido` (el "tipo de medio a usar")
- `fecha_creacion`, `fecha_aceptacion`, `fecha_completado`

---

## 🗺️ Zonas y Tarifas — Sistema por cuadrícula

Sistema original y bien pensado para Natales.

### Zonas

En Puerto Natales las tarifas de viaje son **fijas por zona**:
- Zona urbana → un valor
- Zona extra-urbana → otro valor
- Zonas alejadas → otras

**Cómo funciona:**
- Admin **pinta celdas** de una cuadrícula sobre el mapa
- Cada celda `(fila,columna)` siempre es el mismo lugar geográfico
- Cada zona tiene **tarifa fija**, color, orden
- **Variación nocturna y festiva** (`tarifa_nocturna`, `tarifa_festiva`)
- Prioridad por `orden` cuando dos zonas comparten celda

**Por qué cuadrícula y no círculos:** la cuadrícula sigue la forma real de la ciudad. Los círculos no.

### Tarifas

Sistema multicapa con fallback:

1. Busca específica: `(tipo_servicio, tipo_vehiculo, zona_origen, zona_destino)`
2. Si no: genérica `(tipo_servicio, tipo_vehiculo)`
3. Si no: base `(tipo_servicio)`
4. Si no: `tarifa_estimada = null`

**Campos:** `precio_base`, `precio_por_km`, `precio_minimo`, `precio_maximo`, `vigente_desde`, `vigente_hasta`.

---

## 🔧 Análisis: Conservar / Mejorar / Descartar

### ✅ CONSERVAR (conceptos, no código)

| Concepto | Por qué |
|---|---|
| 4 actores diferenciados | Modelo mental claro y probado |
| 4 ejes de verificación del socio | Muy maduro, ortogonal, auditable |
| Zonas por cuadrícula | Solución real al problema de tarifas fijas |
| Sistema multicapa de tarifas | Escala de MVP a producción sin migrar |
| `SocioServicio` como tabla | Escala sin migraciones cuando se suman servicios |
| Principio "humano en el loop" | Decisiones críticas nunca automáticas |
| Categorías editables (no hardcoded) | Admin puede sumar rubros sin release |
| Solicitud unificada viaje+delivery | Menos código, más consistencia |

### 🔧 MEJORAR (mismo concepto, mejor implementación)

| Legacy | Nuevo |
|---|---|
| PKs `Integer` | **UUIDs** (multi-cliente, no secuencial) |
| Enums como `String` | **Enums tipados** (`EstadoComercio`, `EstadoSocio`) |
| JSON como `Text` | **JSONB nativo** de Postgres |
| Timestamps inconsistentes (`fecha_creacion`, `creado_en`) | **`created_at` / `updated_at` unificados** |
| `datos_extra` (JSON string) | **Columnas reales** o JSONB con schema |
| `fotos_trabajos` (JSON string) | **Tabla relacional** de fotos |
| `permisos_reportados` (JSON string) | **JSONB con schema Pydantic** |
| Modelos en archivos planos | **Módulos autocontenidos** (`modules/prestadores/`) |
| `suspender` en varios lugares | **State machine única** por entidad |
| Comentarios en código sobre reglas | **Docstrings + tests** |

### ❌ DESCARTAR

| Cosa | Por qué |
|---|---|
| Código mismo | Reescritura completa por arquitectura nueva |
| `metodo_pago_local` (en `Local`) | Se integra en módulo `pagos` transversal futuro |
| `demo_acceso`, `configuracion` | Features específicas que no van al MVP |
| `admin_dispositivo`, `consumo_api` | Módulos internos del panel legacy |

---

## 🗺️ Mapeo legacy → proyecto nuevo

| Legacy | Nuevo | Estado |
|---|---|---|
| `local` + `metodo_pago_local` | `modules/comercios/` | ✅ **Hecho** |
| `local.catalogo` + `producto` | `modules/comercios/` (carta) | ⏳ Fase 3.6.1 |
| `pedido` + `pedido_item` | `modules/delivery/` | ⏳ Fase 3.6.2 |
| `puntos` | `modules/recompensas/` | ⏳ Fase 3.6.4 |
| `usuarios` (con Didit) | `modules/auth/` + KYC transversal | 🔧 Refactor |
| `socios` | `modules/socios/` | 🎯 **Fase 2** |
| `prestadores` + `categorias_oficio` | `modules/prestadores/` | 🎯 **Fase 1 (ahora)** |
| `solicitud_servicio` | `modules/prestadores/solicitudes` | 🎯 Fase 1 |
| `solicitud` (viajes/delivery) | `modules/solicitudes/` | ⏳ Fase 2 |
| `zonas` + `tarifas` | `modules/movilidad/` | ⏳ Fase 2 |
| `vehiculos` (usuario) | `modules/vehiculos/` | 🎯 Fase 1 (garage) |
| `registro_vehiculo` (historial) | `modules/vehiculos/historial` | 🎯 Fase 1 |
| Didit / Boostr / RNSTP | `shared/verificacion/` | ⏳ Futuro |

---

## 📊 Diff de arquitectura: legacy vs. nuevo

| Aspecto | Legacy | Nuevo |
|---|---|---|
| **Backend** | FastAPI + SQLAlchemy 1.x | FastAPI + SQLAlchemy 2.0 async |
| **Arquitectura** | Por capas (`models/`, `schemas/`, `services/`) | Por módulos de dominio |
| **PKs** | Integer autoincremental | UUID |
| **Enums** | String libre | Enum tipados con `values_callable` |
| **JSON** | `Text` con JSON embebido | JSONB nativo (a futuro) |
| **Auth** | JWT simple | JWT + Firebase + rol |
| **Frontend** | React Native / Otro (desconocido) | Flutter (client + admin flavors) |
| **Deploy** | Desconocido | Docker Compose + Nginx |
| **Docs** | `OPERATIVA.md` (390 KB) | `docs/` estructurado |

---

## 📚 Documentación legacy (referencia)

- **`OPERATIVA.md`** (390 KB) — contiene TODO el detalle operativo, con secciones numeradas (§116, §129, §158, §163, §168...). Consultar cuando surjan dudas de negocio.
- **`DISENO_SIMULACION.md`** — centro de simulación (pasajeros-bot, socios-bot, motor de estrés). Concepto avanzado, no aplica a Fase 1, considerar a futuro.
- **`backend/app/models/`** — 38 modelos SQLAlchemy. Fuente para nombres y conceptos.

---

## 🎯 Prioridades derivadas del análisis

### Fase 1 (ahora): Oficios (mecánica primero)

Del legacy reusamos:
- ✅ Concepto de `Prestador` + `CategoriaOficio`
- ✅ Flujo `SolicitudServicio` (abierta → cotizada → aceptada → cerrada)
- ✅ Reviews (transversal)
- ✅ Verificación KYC Didit (transversal)
- ✅ Garage del usuario (`Vehiculo` + `RegistroVehiculo`)

### Fase 2: Movilidad

Del legacy reusamos:
- ✅ Concepto de `Socio` con 4 ejes de verificación
- ✅ Zonas por cuadrícula + tarifas multicapa
- ✅ `Solicitud` unificada (viaje + delivery)
- ✅ Matching y tracking (concepto, no código)
- ✅ RNSTP / Boostr / Didit

### Fase 3: Resto

- Hospedajes, arriendos, marketplace C2C

---

## Referencias

- **Visión de producto:** `docs/VISION.md`
- **Arquitectura técnica:** `docs/ARCHITECTURE.md`
- **Estado del proyecto:** `CONTEXTO_PROYECTO.md`

---

**Fin del documento.**