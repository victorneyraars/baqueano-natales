# Diseño del módulo `oficios` — Sistema de gestión de servicios

> **Última actualización:** 2026-10-11
> **Estado:** Diseño fundacional. Base para implementación por fases.

## Visión

Construir el **mejor sistema de gestión de oficios de Chile**, empezando por
**mecánica automotriz**, con arquitectura 80% reutilizable para el resto de
oficios (gasfitería, electricidad, jardinería, etc.).

### Diferenciadores reales

1. **Dos lados (B2C):** cliente + prestador en la misma plataforma.
2. **Historial del vehículo compartido en la red:** el auto lleva su historia,
   no el taller. Si el dueño cambia de taller dentro de la red, el nuevo
   mecánico ve TODO lo que se hizo antes. **Esto no existe hoy en Chile.**
3. **Recordatorios proactivos por km/tiempo:** el sistema avisa al cliente
   antes de que rompa el auto.
4. **Presupuesto digital con aprobación:** el cliente aprueba/rechaza items
   desde la app. Trazabilidad total.

## Arquitectura en 2 capas

Capa CORE (aplica a TODOS los oficios):
- objetos_servicio, ordenes_trabajo, orden_items, orden_historial,
  orden_fotos, turnos, garantias, recordatorios, catalogo_servicios_oficio,
  notificaciones.

Capa VERTICAL MECANICA (específico, se replica a otros):
- vehiculos, mecanica_categorias_servicio, mecanica_repuestos.

Capa EXISTENTE (se integra, no se toca):
- usuarios, prestadores, prestador_servicios, categorias_oficio.

**Regla de oro:** si es específico de mecánica (patente, VIN), va en la capa
vertical. Si es común (orden, presupuesto, garantía), va en la capa core.

## Modelo de datos (13 tablas nuevas)

### Capa CORE (11 tablas)

#### objetos_servicio — sujeto del servicio (polimórfico)
- id UUID PK
- tipo enum (vehiculo, propiedad, jardin, ...)
- propietario_id UUID FK usuarios
- alias varchar
- notas text
- metadata_extra JSONB
- activo bool default true
- created_at, updated_at

Índices: propietario_id, tipo.

#### vehiculos — satélite 1:1 con objetos_servicio
- id UUID PK
- objeto_servicio_id UUID FK unique
- patente varchar(10) unique not null
- vin varchar(17) nullable
- marca varchar(50) not null
- modelo varchar(50) not null
- anio int not null
- color varchar(30) nullable
- tipo_vehiculo enum (sedan, suv, camioneta, moto, camion, otro)
- kilometraje_actual int default 0
- fecha_ultima_revision date nullable
- created_at, updated_at

#### ordenes_trabajo — orden de servicio
- id UUID PK
- numero varchar(20) unique (OT-2026-0001)
- cliente_id FK usuarios
- prestador_id FK prestadores
- objeto_servicio_id FK objetos_servicio
- estado enum (ingresado, diagnosticando, presupuestado, aprobado,
  rechazado, en_proceso, listo, entregado, cancelado, garantia)
- prioridad enum (baja, normal, alta, urgente) default normal
- diagnostico_inicial text
- fecha_ingreso, fecha_estimada_entrega, fecha_entrega_real
- km_ingreso, km_salida
- notas_internas text (solo prestador)
- notas_cliente text
- total_presupuesto numeric(12,2), total_aprobado numeric(12,2)
- created_at, updated_at

#### orden_items — items del presupuesto
- id UUID PK
- orden_id FK ordenes_trabajo (cascade delete)
- tipo enum (servicio, repuesto, mano_obra, otro)
- descripcion varchar(255)
- cantidad numeric(10,2) default 1
- precio_unitario numeric(12,2), subtotal numeric(12,2)
- aprobado bool nullable (null=pendiente)
- orden_display int default 0
- created_at, updated_at

#### orden_historial — timeline inmutable (append-only)
- id UUID PK
- orden_id FK ordenes_trabajo
- tipo enum (estado_cambio, comentario, foto, presupuesto, aprobacion,
  rechazo, garantia)
- estado_anterior, estado_nuevo varchar(30) nullable
- usuario_id FK usuarios
- contenido JSONB
- created_at timestamp

NUNCA se modifica ni se borra. Fuente de verdad del timeline.

#### orden_fotos — fotos del trabajo
- id UUID PK
- orden_id FK ordenes_trabajo
- momento enum (ingreso, diagnostico, en_proceso, entrega)
- url varchar(500), descripcion varchar(255)
- created_at

#### turnos — agenda cliente-prestador
- id UUID PK
- cliente_id FK usuarios
- prestador_id FK prestadores
- objeto_servicio_id FK objetos_servicio
- fecha_inicio timestamp not null
- duracion_min int default 30
- estado enum (pendiente, confirmado, en_curso, completado, cancelado,
  no_asistio)
- motivo varchar(255)
- notas_cliente, notas_prestador text
- orden_id FK ordenes_trabajo nullable
- created_at, updated_at

#### garantias — garantía por trabajo
- id UUID PK
- orden_id FK ordenes_trabajo
- tipo enum (mano_obra, repuesto, completo)
- duracion_dias int not null
- fecha_inicio, fecha_fin date
- cobertura text, condiciones text
- activa bool default true
- created_at, updated_at

#### recordatorios — recordatorios automáticos
- id UUID PK
- objeto_servicio_id FK objetos_servicio
- tipo enum (km, fecha, evento)
- condicion JSONB ({km_umbral: 5000} o {fecha: "2027-03-15"})
- mensaje varchar(255)
- enviado bool default false
- fecha_envio timestamp nullable
- created_at, updated_at

#### catalogo_servicios_oficio — catálogo multi-oficio
- id UUID PK
- oficio enum (mecanica, gasfiteria, electricidad, ...)
- nombre varchar(100)
- descripcion text
- precio_base numeric(12,2) nullable (referencial)
- duracion_min int nullable
- categoria varchar(50)
- activo bool default true
- created_at, updated_at

#### notificaciones — notificaciones in-app
- id UUID PK
- usuario_id FK usuarios
- tipo varchar(50), titulo varchar(200), mensaje text
- payload JSONB (datos para deep-link)
- leida bool default false
- created_at

### Capa VERTICAL Mecánica (2 tablas)

#### mecanica_categorias_servicio
- id, nombre, slug, descripcion, icono, color, orden, activo, timestamps
- Seed: Frenos, Motor, Suspensión, Transmisión, Eléctrico, Aire acondicionado,
  Neumáticos, Dirección, Escape, Carrocería, Diagnóstico.

#### mecanica_repuestos
- id, nombre, marca, codigo_oem, categoria_id, precio_referencia,
  unidad, activo, timestamps

## API Endpoints (~45 nuevos)

### Público
- GET /api/v1/oficios/mecanica/categorias
- GET /api/v1/oficios/mecanica/servicios-populares
- GET /api/v1/oficios/mecanica/marcas

### Cliente
- GET/POST /api/v1/mis-vehiculos
- GET/PATCH/DELETE /api/v1/mis-vehiculos/{id}
- GET /api/v1/mis-vehiculos/{id}/historial
- GET /api/v1/mis-vehiculos/{id}/recordatorios
- GET/POST /api/v1/mis-turnos
- DELETE /api/v1/mis-turnos/{id}
- GET /api/v1/mis-ordenes
- GET /api/v1/mis-ordenes/{id}
- POST /api/v1/mis-ordenes/{id}/aprobar
- POST /api/v1/mis-ordenes/{id}/rechazar

### Prestador
- GET/POST /api/v1/mis-talleres/{id}/ordenes
- GET /api/v1/mis-talleres/{id}/ordenes/{oid}
- POST/PATCH/DELETE /api/v1/mis-talleres/{id}/ordenes/{oid}/items
- POST /api/v1/mis-talleres/{id}/ordenes/{oid}/enviar-presupuesto
- POST /api/v1/mis-talleres/{id}/ordenes/{oid}/estado
- POST /api/v1/mis-talleres/{id}/ordenes/{oid}/fotos
- GET /api/v1/mis-talleres/{id}/agenda
- POST /api/v1/mis-talleres/{id}/turnos/{tid}/confirmar
- POST /api/v1/mis-talleres/{id}/turnos/{tid}/rechazar
- GET /api/v1/mis-talleres/{id}/clientes
- GET /api/v1/mis-talleres/{id}/vehiculos
- GET /api/v1/mis-talleres/{id}/reportes

### Admin
- GET /api/v1/admin/oficios/ordenes
- GET /api/v1/admin/oficios/estadisticas

### Integración con prestadores
Se agregan 3 campos a la tabla prestadores:
- acepta_turnos bool default false
- duracion_turno_default_min int default 30
- oficio_principal enum nullable (mecanica, gasfiteria, ...)

## Flujos principales

1. Cliente registra vehículo: Home → Mis vehículos → + Agregar → POST.
2. Cliente agenda turno: Ver taller → Agendar → fecha/hora/motivo/vehículo.
3. Mecánico crea orden: Nueva orden → cliente + vehículo + diagnóstico → items.
4. Cliente aprueba presupuesto: Notificación → ve items → Aprobar.
5. Mecánico ejecuta: sube fotos → cambia estado → listo.
6. Cliente retira: confirma → entregado → se genera garantía.
7. Recordatorio automático: worker diario → revisa → notifica → cliente agenda.

## State machine de ordenes_trabajo

ingresado -> diagnosticando -> presupuestado -> aprobado -> en_proceso -> listo -> entregado

Ramas alternativas: presupuestado -> rechazado, cualquier estado inicial -> cancelado,
entregado -> garantia (si el cliente reclama dentro del período).

Reglas:
- Solo prestador: ingresado→diagnosticando, diagnosticando→presupuestado,
  aprobado→en_proceso, en_proceso→listo, listo→entregado.
- Solo cliente: presupuestado→aprobado, presupuestado→rechazado.
- Cualquiera puede cancelar en estados iniciales.

## Matriz de reutilización

| Componente | Reutilizable | Cambios para otros oficios |
|---|---|---|
| objetos_servicio | 100% | Nuevo tipo en enum |
| ordenes_trabajo | 95% | Ninguno |
| orden_items | 100% | Ninguno |
| orden_historial | 100% | Ninguno |
| orden_fotos | 100% | Ninguno |
| turnos | 100% | Ninguno |
| garantias | 100% | Ninguno |
| recordatorios | 90% | Ajustar condicion por tipo |
| catalogo_servicios_oficio | 100% | Agregar servicios |
| vehiculos (satélite) | 0% | Crear propiedades o similar |
| mecanica_categorias | 0% | Crear categorías específicas |
| mecanica_repuestos | 0% | Crear catálogo específico |

Resultado: 80% reutilizable. Agregar gasfitería = ~2 sesiones.

## Roadmap de implementación

| Fase | Alcance | Sesiones |
|---|---|---|
| M1 | objetos_servicio + vehiculos + CRUD. Backend + frontend cliente + dueño. | 2-3 |
| M2 | ordenes_trabajo + orden_items + orden_historial + state machine. | 2-3 |
| M3 | turnos + calendario frontend. | 1-2 |
| M4 | garantias + recordatorios + worker cron. | 1-2 |
| M5 | orden_fotos + notificaciones + reportes taller. | 2 |

Total: ~10 sesiones para el mejor sistema de gestión de talleres de Chile.

## Decisiones de diseño (ADRs)

### ADR-0001: Arquitectura en 2 capas (core + vertical)
Separar lo común (core) de lo específico (vertical). objetos_servicio es
el punto de extensión polimórfico. Trade-off: más tablas, mejor reutilización.

### ADR-0002: Historial del vehículo es del vehículo
El historial se vincula al objeto_servicio (vehículo) y es visible para el
dueño actual. En v2 se agrega transferencia de vehículo entre usuarios.

### ADR-0003: orden_historial es append-only
Nunca se modifica ni se borra. Fuente de verdad del timeline.

### ADR-0004: Presupuesto con aprobación por item
El cliente puede aprobar/rechazar items individuales, no solo el total.

### ADR-0005: Notificaciones in-app primero
MVP sin FCM. Solo notificaciones in-app + email. Push en Fase M5.

### ADR-0006: Multi-taller desde el principio
Un usuario puede ser dueño de N talleres.

## Integración con módulos existentes

- usuarios: los clientes son usuarios normales.
- prestadores: los talleres son prestadores con oficio_principal = mecanica.
- categorias_oficio: "Mecánica automotriz" ya existe (seed).
- social: publicación al aprobar orden nueva (integración futura).
- promocion: afiches del taller con plantilla nuevo_servicio (futura).

## Notas finales

- Nombre del módulo: oficios (genérico, escalable).
- No se toca ningún módulo existente hasta Fase M2.
- Documentación viva: se actualiza al final de cada fase.