# FASE 6 — MVP Mecánica Automotriz (Se Alquila Marido)

**Estado:** 🟡 En diseño
**Fecha inicio:** 2026-10-19
**Prestador único:** Se Alquila Marido (Víctor Neyra)
**Admin único:** Víctor Neyra

## 🎯 Objetivo

Lanzar el MVP del vertical **mecánica automotriz** bajo la marca Se Alquila Marido, validando el flujo completo (descubrir → reservar → confirmar → completar → calificar) con un solo prestador. Una vez validado, replicar el modelo a los demás oficios.

## 👥 Alcance (Scope)

### ✅ In-Scope (MVP v1.0)
- Catálogo público de servicios de mecánica (con precios fijo/desde).
- Página de detalle de cada servicio.
- Formulario de reserva con datos del vehículo y síntomas.
- Panel Admin para gestionar reservas (confirmar/rechazar/completar).
- Configuración de cada servicio desde el panel (precio, duración, políticas).
- Notificaciones por email (Resend ya integrado).
- Reviews post-servicio (con estrellas + comentario).
- Portafolio de trabajos realizados (galería de fotos).

### ❌ Out-of-Scope (Fase 7+)
- Multi-prestador / marketplace.
- Multi-admin / roles.
- Chat en vivo.
- Pagos in-app (MercadoPago/Stripe).
- Geolocalización avanzada.
- App móvil nativa para clientes (solo web responsive).
- Suscripciones recurrentes.

## 🏗️ Modelo de datos

### Prestador (1 sola instancia en MVP)
id, nombre_comercial, descripcion, telefono, email, direccion, horario_atencion, logo_url, activo

### Oficio
id, nombre, slug, descripcion, icono, activo
Ejemplos: mecanica-automotriz, electricidad, plomeria, pintura, carpinteria, etc.

### Servicio (por oficio)
id, oficio_id, nombre, slug, descripcion, 
precio_tipo (fijo|desde|a_cotizar),
precio_valor (nullable),
duracion_estimada_min,
modalidad (domicilio|taller|ambas),
anticipacion_minima_horas (default 2),
costo_reserva (default 0),
politica_cancelacion,
formulario_previo (json con campos custom),
imagen_url,
activo

### Reserva
id, servicio_id, cliente_nombre, cliente_email, cliente_telefono,
vehiculo_marca, vehiculo_modelo, vehiculo_anio,
fecha_deseada, hora_deseada,
estado (pendiente|confirmada|completada|cancelada|rechazada),
notas_cliente, notas_admin,
creado_en, confirmado_en, completado_en,
review_id (nullable, FK a Review)

### Review
id, reserva_id (unique), calificacion (1-5), comentario, cliente_nombre, creado_en, publicado (bool)

## 🎨 Modelo de precios (híbrido)

El MVP soporta 3 tipos de precio por servicio:
1. **fijo** → Precio exacto. Ej: "Cambio de aceite: $25.000".
2. **desde** → Precio mínimo que puede variar. Ej: "Reparación de frenos: Desde $20.000".
3. **a_cotizar** → Solo se muestra "Consultar". Ej: "Diagnóstico computarizado: A cotizar".

### Ejemplo de catálogo MVP (Mecánica):
| Servicio | Tipo | Precio | Duración | Modalidad |
|---|---|---|---|---|
| Cambio de aceite y filtro | Fijo | $25.000 | 45 min | Taller/Domicilio |
| Diagnóstico computarizado | Fijo (simbólico) | $15.000 | 30 min | Taller |
| Reparación de frenos | Desde | $20.000 | 2h | Taller |
| Cambio de correa de distribución | Desde | $80.000 | 4h | Taller |
| Revisión general pre-viaje | Fijo | $35.000 | 1h | Taller |

## ⚙️ Configuración de reservas (desde panel admin)

Cada servicio tiene configuración independiente:
- **Costo de reserva:** $0 por defecto (el cobro se hace presencial). Se puede configurar una seña en el futuro.
- **Anticipación mínima:** 2 horas (configurable).
- **Modalidad:** domicilio / taller / ambas.
- **Duración estimada:** para bloquear el calendario.
- **Política de cancelación:** texto libre.
- **Formulario previo:** campos custom según el servicio (ej. "Marca y modelo del vehículo", "Síntomas", etc.).

## 🔌 Endpoints del Backend (MVP)

### Públicos
- GET /api/v1/prestadores/se-alquila-marido — Info del prestador
- GET /api/v1/oficios — Lista de oficios activos
- GET /api/v1/oficios/{slug}/servicios — Servicios de un oficio
- GET /api/v1/servicios/{slug} — Detalle de un servicio
- POST /api/v1/reservas — Crear reserva
- GET /api/v1/reviews — Reviews públicas
- GET /api/v1/portafolio — Trabajos realizados

### Admin (requieren JWT admin)
- GET /api/v1/admin/reservas — Lista de reservas (filtros por estado/fecha)
- PATCH /api/v1/admin/reservas/{id} — Actualizar estado (confirmar/rechazar/completar)
- GET/POST/PATCH /api/v1/admin/servicios — CRUD servicios
- GET/POST/PATCH /api/v1/admin/oficios — CRUD oficios
- PATCH /api/v1/admin/reviews/{id} — Aprobar/ocultar review

## 📱 Pantallas Flutter

### App Client (Web Astro primero, App después)
1. Home: listado de oficios con iconos.
2. Detalle Oficio: lista de servicios con precios.
3. Detalle Servicio: descripción, precio, formulario de reserva.
4. Confirmación de Reserva: resumen + email enviado.
5. Reviews: página de reviews públicas.
6. Portafolio: galería de trabajos.

### App Admin
1. Reservas Pendientes: lista con acciones rápidas (confirmar/rechazar).
2. Calendario: vista semanal de reservas confirmadas.
3. Config Servicios: CRUD de servicios con precios y políticas.
4. Config Oficios: CRUD de oficios.
5. Reviews Pendientes: moderación.
6. Portafolio: subir fotos de trabajos.

## 🚀 Orden de implementación (Sprints)

- **Sprint 1:** Base de datos y backend (migraciones + endpoints + seed).
- **Sprint 2:** Web Astro — Landing + Catálogo + Formulario de reserva.
- **Sprint 3:** Panel Admin Flutter — Reservas + Config Servicios.
- **Sprint 4:** Reviews + Portafolio (flujo completo end-to-end).
- **Sprint 5:** Polish + Deploy prod.

## 📊 Métricas de éxito del MVP

- Tasa de conversión: visitas → reservas (target: >5%).
- Tasa de confirmación: pendientes → confirmadas (target: >80%).
- NPS: calificación promedio (target: >4.5/5).
- Retención: clientes que reservan 2+ veces (target: >30%).

**Documento vivo.**
