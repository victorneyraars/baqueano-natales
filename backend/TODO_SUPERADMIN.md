# TODO: Superadmin multi-tenant

## Estado actual (funciona para 1 prestador)
- Víctor (admin) puede gestionar Vásquez (el único rentacar hoy).
- `_resolver_prestador_rentacar` devuelve el primer prestador de rentacar si es admin.
- `listar_prestadores_mios` devuelve todos los prestadores si es admin.

## Deuda técnica a resolver cuando haya 2+ prestadores
- [ ] Cambiar `es_owner` a `puede_gestionar` en `PrestadorPrivadoResponse`.
- [ ] Implementar selector de prestador con header `X-Prestador-Id`.
- [ ] Modificar `_resolver_prestador_rentacar` para usar el prestador del header.
- [ ] Auditar `oficios` y `comercios` con el mismo patrón.
- [ ] Frontend: dropdown de prestador arriba del menú (solo visible para admins).
- [ ] Usar el helper `es_admin(user)` de `auth/deps.py` en todos los chequeos.
