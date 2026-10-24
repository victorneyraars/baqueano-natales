# Boostr - Integracion de RUT y Patentes

## Estado del plan

- Plan actual: PRO (confirmado 2026-10-24)
- RUT: servicio habilitado
- Patentes: servicio habilitado
- Rate limit: el plan PRO no aplica el limite de 5 req/10s del freemium.
- Creditos: pool mensual. Errores de validacion NO consumen creditos (changelog Boostr 2026-09-28).

## Endpoints

### RUT
GET https://api.boostr.cl/rut/{rut}.json
Header: X-API-KEY: BOOSTR_RUT_API_KEY

### Patentes
GET https://api.boostr.cl/vehicle/{patente}.json
Header: X-API-KEY: BOOSTR_PATENTE_API_KEY

Las API keys se cargan por variable de entorno en app/core/config.py:
- BOOSTR_RUT_API_KEY
- BOOSTR_PATENTE_API_KEY

Nunca commitear las keys. Rotar cada 6 meses o ante sospecha de filtracion.

## Validacion de patentes

Backend (app/modules/integrations/routes.py) valida estructura antes de Boostr:

- Longitud: 6 caracteres (despues de normalizar puntos/guiones/espacios)
- Formatos aceptados:
  - Antiguo (pre-2007): 2 letras + 4 numeros, ejemplo AB1234
  - 2007-2026: 4 letras + 2 numeros, ejemplo ABCD12
  - 2026+ (Decreto 114): 5 letras + 1 numero, ejemplo BBBBB0
- Se normaliza a mayusculas y se eliminan puntos/guiones/espacios.

NO se valida que letras especificas (vocales, M, N, N-tilde, Q). Las fuentes oficiales no coinciden y el Decreto 53 no las lista. Boostr hace esa validacion fina con el codigo V-04.

### Codigos de error de Boostr

- V-04: Patente invalida (DV incorrecto o no existe en el registro)
- HTTP 429: Rate limit excedido (reintentar con backoff)
- HTTP 5xx: Error temporal (reintentar; cachear si es posible)

## Cache

- En memoria por proceso (cache_patente / cache_rut).
- TTL: hasta reinicio. En produccion considerar Redis con TTL 24h.
- No se cachean respuestas de error.

## Observabilidad

Cada llamada a Boostr loguea: patente/RUT, status HTTP, headers de cuota/rate-limit (si vienen), primeros 200 chars del body.

Buscar en logs con:
docker logs --tail 100 baqueano_backend_dev 2>&1 | grep -i "Boostr patente"

## Changelog relevante de Boostr

- 2026-09-28: Errores de validacion (patente/RUT invalido, parametros faltantes) dejan de consumir creditos.
- 2026: Nuevo formato de patentes chilenas (Decreto 114): autos pasan a 5 letras + 1 digito desde julio 2026.

## Pendientes

- [ ] Confirmar limites exactos del plan PRO en dashboard Boostr.
- [ ] Alerta si X-RateLimit-Remaining cae bajo 20%.
- [ ] Evaluar migrar cache en memoria a Redis.
