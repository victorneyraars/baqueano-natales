# Inventario del Backend - MVP Mecánica

**Última actualización:** 2026-10-19

> **Documentación Absoluta:** Este documento debe mantenerse sincronizado con el código. Todo endpoint nuevo debe registrarse aquí.

## 🏗️ Arquitectura
- **Framework:** FastAPI
- **ORM:** SQLAlchemy 2.0 (async con `asyncpg`)
- **Base de Datos:** PostgreSQL (`baqueano_natales_dev`, `baqueano_natales_prod`)
- **Patrón:** Monolito modular (1 carpeta por dominio en `backend/app/modules/`)

## 📦 Módulos Existentes

### `oficios` (Mecánica, Vehículos, Turnos)
Contiene toda la lógica de negocio del vertical de mecánica.

**Routers registrados:**
- `/api/v1/oficios/mecanica` (público — catálogo de mecánica)
- `/api/v1/mis-vehiculos` (propietario — CRUD de vehículos)
- `/api/v1/oficios/admin/categorias` (admin — categorías de servicios)
- `/api/v1/oficios/admin/repuestos` (admin — repuestos)
- `/api/v1/oficios/mis-ordenes` (cliente/prestador — órdenes de trabajo)
- `/api/v1/oficios/prestador/utilidades` (prestador — herramientas)
- `/api/v1/oficios/turnos-cliente` (cliente — ver/crear turnos)
- `/api/v1/oficios/turnos-prestador` (prestador — gestionar turnos)

**Modelos principales:**
- `Vehiculo` (marca, modelo, año)
- `MecanicaCategoriaServicio`
- `MecanicaRepuesto`
- `OrdenTrabajo` + `OrdenItem` + `OrdenHistorial`
- `Turno` (sistema de reservas)
- `Garantia` + `Recordatorio`
- `OrdenFoto`

### `prestadores` (Perfiles, Servicios, Reviews)
Contiene el perfil de los prestadores (en MVP, solo Se Alquila Marido) y sus servicios.

**Routers registrados:**
- `/api/v1/prestadores` (público — info del prestador)
- `/api/v1/prestadores/propietario` (propietario — gestión del perfil)
- `/api/v1/prestadores/admin/categorias` (admin — categorías de oficios)
- `/api/v1/prestadores/admin` (admin — CRUD de prestadores)
- `/api/v1/prestadores/reviews/cliente` (cliente — crear review)
- `/api/v1/prestadores/reviews/prestador` (prestador — gestionar reviews)
- `/api/v1/prestadores/reviews/publico` (público — ver reviews)

**Modelos principales:**
- `CategoriaOficio`
- `Prestador` (perfil del mecánico)
- `PrestadorServicio` (relación prestador-servicio con precios)
- `FotoTrabajo` (portafolio)
- `Review` (calificaciones)

### `pedidos` (Futuro E-commerce)
Reservado para futuros envíos de productos/comidas. **No se toca en el MVP de mecánica.**

## 🎯 Gaps del MVP (Qué falta)

Basado en el análisis del backend y el scope del MVP:

### Backend: Probablemente completo
- El backend parece tener todo lo necesario. Falta testear el flujo completo.

### Frontend Web (Astro - se-alquila-marido-web)
- [ ] Conectar la landing con `/api/v1/oficios/mecanica`.
- [ ] Crear la página de servicios conectada al backend.
- [ ] Crear el formulario de reserva conectado a `/api/v1/oficios/turnos-cliente`.
- [ ] Implementar la confirmación de reserva por email.

### Frontend App (Flutter - Client y Admin)
- [ ] App Client: pantalla para ver turnos, calificar servicios.
- [ ] App Admin (Prestador): pantalla para gestionar turnos, órdenes y garantías.
- [ ] App Admin: configurar servicios y precios.

## 🚀 Próximos Pasos
1. Testear el backend con `curl` para verificar que los endpoints responden.
2. Conectar la web Astro al catálogo de mecánica.
3. Implementar el formulario de reserva en Astro.
4. Conectar la App Flutter Admin a los turnos.

---
**Mantenido por:** Víctor Neyra
