# Convención de Roles y Permisos - Baqueano Natales

## Roles del sistema

| Rol | Descripción | Asignado por |
|-----|-------------|-------------|
| cliente | Usuario final | sistema |
| prestador | Dueño de un servicio | sistema |
| comercio | Dueño de comercio | sistema |
| admin | Admin del ecosistema | solo super_admin |

## Tipos de admin

### 1. Super Admin del ecosistema
- Identificación: usuarios.es_super_admin = TRUE
- Permisos: ve TODO (todos los prestadores) 
- Puede asignar: roles de admin, admins a prestadores
- Actualën: victorneyraars@gmail.com

### 2. Admin de servicio
- Identificación: es_super_admin = FALSE + filas en admin_prestadores
- Permisos: ve SOLO los prestadores asignados
- Ejemplo: admin de Rentacar Vásquez

### 3. Admin sin asignaciones
- Identificación: es_super_admin = FALSE + sin filas en admin_prestadores
- Permisos: NINGUNO

## Reglas

1. Solo el super admin puede:
   - Promover usuarios a admin
   - Asignar admins a prestadores
   - Revocar admins de prestadores
   - Crear/eliminar prestadores
   - Marcar a alm admin como super admin

2. Un admin de servicio puede:
   - Ver/editar los prestadores asignados
   - Gestionar reservas y vehículos de esos
   - NO ver otros prestadores
   - NO puede promover otros usuarios a admin

3. Relación many-to-many en admin_prestadores
4. Un prestador puede tener N admins

## Base de datos

Tabla usuarios: columna es_super_admin BOOLEAN

Tabla admin_prestadores

admin_id UUID REFERENCES usuarios(id)
prestador_id UUID REFERENCES prestadores(id)
created_at TIMESTAMPTZ

PRIMARY KEY (admin_id, prestador_id)

## Ownership de BD

Regla: todas las tablas son propiedad de baqueano_prod_user

- baqueano_user (superuser) => solo infraestructura
- baqueano_prod_user => app production (corre migraciones)
- baqueano_dev_user => app development
- baqueano_test_user => app testing

Fix de fragmentación si aparece outra diferencia de dueños.

ALERO SOLO DEL_PERMISO_ADHMIN
