# Convenciones de Codigo — Baqueano Natales / Rent a Car Vasquez

Aplicable a todo el codigo del ecosistema (backend FastAPI, frontend Next.js, app Flutter).

## 1. Regla de Oro

Todo codigo no obvio debe tener un comentario explicando POR QUE, no QUE.

El "que" se entiende leyendo el codigo. El "por que" es lo que se pierde con el tiempo y es lo que evita que alguien rompa el sistema sin saberlo.

MAL:
contador += 1  # incrementa el contador

BIEN:
Incrementamos antes del commit para que el listener de auditoria vea el valor final
contador += 1

## 2. Estandar Backend (Python / FastAPI)

### 2.1 Docstrings obligatorios en funciones publicas

async def crear_reserva_propietario(db, usuario, data) -> RentacarReserva:
    """
    Crea una reserva manual desde el panel del propietario (walk-in / WhatsApp).

    Diferencia con crear_reserva (publica):
    - NO envia OTP porque el admin valida la identidad presencialmente.
    - NO requiere email verificado.
    - El estado inicial es 'confirmada' (no 'pendiente').

    Args:
        db: Sesion async de SQLAlchemy.
        usuario: Propietario autenticado (JWT).
        data: Payload con fechas, cliente, vehiculo y precio.

    Returns:
        La reserva creada con estado 'confirmada'.

    Raises:
        ValueError: si el vehiculo no esta disponible en esas fechas.
        ValueError: si las fechas son invalidas (fin <= inicio).

    Efectos secundarios:
        - Crea bloqueo en rentacar_bloqueos tipo 'reserva'.
        - Dispara notificacion al cliente por email.
        - Dispara notificacion a colaboradores.
    """

### 2.2 Comentarios en bloques no triviales

Validacion de disponibilidad:
Usamos SELECT FOR UPDATE porque dos usuarios podrian reservar el mismo auto
simultaneamente (web + panel). Sin el lock, ambos pasan la validacion y uno
choca con el constraint de la DB despues. Preferimos fallar temprano.
stmt = select(RentacarBloqueo).where(...).with_for_update()

### 2.3 Separadores de secciones

# =========================================================
# Config propietario
# =========================================================

### 2.4 Endpoints con summary y description

@router_propietario.post(
    "/reservas",
    response_model=RentacarReservaDetalleOut,
    status_code=status.HTTP_201_CREATED,
    summary="Crear reserva manual (walk-in / WhatsApp)",
    description=(
        "Crea una reserva desde el panel sin flujo OTP. "
        "El estado inicial es 'confirmada' y se disparan notificaciones "
        "por email al cliente y a los colaboradores activos."
    ),
)

### 2.5 Modelos con docstring de clase

class RentacarInspeccion(TimestampMixin, Base):
    """
    Inspeccion vehicular de entrega o recepcion.

    Guarda el estado del vehiculo mediante fotos en Base64 (11 slots
    estandar de la industria) y firma del cliente.

    Ciclo de vida:
    - Se crea cuando el admin hace Check-out (tipo='entrega').
    - Se crea cuando el admin hace Check-in (tipo='recepcion').
    - fotos es un array JSONB con el orden de SLOTS_FOTOS.
    """

## 3. Estandar Frontend (TypeScript / React)

### 3.1 Comentario de cabecera de cada componente

/**
 * InspeccionModal — Wizard guiado de 11 pasos para Check-out/Check-in.
 *
 * Flujo:
 * 1. Cada paso muestra SVG referencial (FotoReferencia) + instrucciones.
 * 2. El operador toma la foto (input file con capture="environment").
 * 3. Al llegar al paso 12, se pide firma + km + combustible.
 * 4. Submit → crearInspeccion() en el backend.
 *
 * Estados:
 * - pasoActual: 0..11 (11 = firma final)
 * - fotos: Record<slotId, base64>
 * - firma: base64 | null
 * - kilometraje, combustible
 *
 * Validaciones:
 * - No avanza al siguiente paso sin foto tomada.
 * - No permite guardar sin las 11 fotos y la firma.
 *
 * Bloqueos:
 * - Bloquea scroll del body cuando showSignature esta abierto.
 */

### 3.2 Comentarios en hooks y logica compleja

Precarga las fotos adyacentes para evitar "flash" negro al hacer swipe.
Sin esto, en 4G inestable de la Patagonia cada swipe tarda 1-2s en cargar.
useEffect(() => {
  if (!lightbox) return;
  const prev = lightbox.fotos[lightbox.index - 1];
  const next = lightbox.fotos[lightbox.index + 1];
  if (prev) new Image().src = prev;
  if (next) new Image().src = next;
}, [lightbox]);

### 3.3 Props documentadas

interface Props {
  /** ID de la reserva asociada a la inspeccion */
  reservaId: string;
  /** Clave que fuerza refresh cuando se guarda nueva inspeccion */
  refreshKey?: number;
}

### 3.4 Funciones de servicios

/**
 * Crea una inspeccion vehicular (Check-out o Check-in).
 *
 * @param reservaId - UUID de la reserva
 * @param data - { tipo, kilometraje, nivel_combustible, fotos[], firma_cliente }
 * @throws Error si el backend devuelve != 2xx
 */
export async function crearInspeccion(reservaId, data) { ... }

## 4. Convenciones de Nombres

Archivos Python: snake_case (crear_reserva.py)
Archivos TS/React: PascalCase componentes (ReservaModal.tsx), kebab-case utilidades (admin-api.ts)
Variables: snake_case Python, camelCase TS
Constantes: UPPER_SNAKE_CASE (SLOTS_FOTOS)
Interfaces TS: PascalCase (AdminReserva)
Endpoints API: kebab-case (/mis-vehiculos-rentacar/reservas/{id})

## 5. Reglas de Comentado por Prioridad

SIEMPRE comentar:
- Queries con SELECT ... FOR UPDATE (locks)
- Uso de transacciones explicitas
- Manipulacion de fechas/zonas horarias
- Cualquier logica que involucre dinero
- Cualquier logica de auditoria (gestionado_por, firmado_at)
- Validaciones con reglas de negocio no obvias
- Bypass de validacion (con razon clara)
- Migraciones de datos

Comentar si el bloque supera 10 lineas:
- Funciones que transforman datos
- Bucles con logica condicional
- Manejo de errores custom

No es necesario comentar:
- Imports
- Funciones obvias de 3-5 lineas
- Return statements simples
- JSX/HTML donde la estructura habla sola

## 6. Anti-patrones prohibidos

- Codigo comentado sin contexto: // const oldValue = ...
- Comentarios que mienten
- TODOs sin dueno: usar // TODO(@username): ...
- Comentar codigo que esta en git (usar historial git)
- FIXMEs sin contexto

## 7. Changelog de Cambios Mayores

Cuando se modifique un modulo completo:

### 2026-11-07 — Modulo de Inspecciones
Autor: [Nombre]
Cambios:
- Wizard de 11 pasos con SVGs referenciales
- Comparador entrega vs devolucion
- Bloqueo de scroll en lightbox (iOS safe)
Motivo: Alinear con estandar de la industria (8-12 fotos).
Impacto en DB: Nueva tabla rentacar_inspecciones con columna updated_at.

## 8. Checklist antes de commitear

- Las funciones publicas tienen docstring
- Los endpoints tienen summary y description
- Los bloques no triviales tienen comentario explicativo
- No hay console.log de debug (solo console.error)
- No hay print() en produccion
- No hay credenciales hardcodeadas
- Los nombres siguen las convenciones
- El codigo paso next build sin errores TypeScript
- El backend arranca sin errores (Application startup complete)
