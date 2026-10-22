# Integrations API

API de validacion de RUT y Patentes (Boostr) con cache TTL 24h y telemetria.

Base URL: https://api-dev.baqueanonatales.com/api/v1/integrations

## Autenticacion

| Modo | Header | Uso |
|------|--------|-----|
| API Key | X-API-Key: sk_dev_xxx | Server-to-server, scripts, microservicios |
| JWT admin | Authorization: Bearer <jwt> | App Admin (Google login) |
| Publica | (ninguno) | /rut/{rut} y /patente/{patente} |

## Endpoints

| Metodo | Path | Auth | Descripcion |
|--------|------|------|-------------|
| GET | /rut/{rut} | Publica | Consulta RUT (cache 24h) |
| GET | /patente/{patente} | Publica | Consulta Patente (cache 24h) |
| GET | /stats | API Key o JWT | Snapshot de rate limit |
| GET | /stats/history | API Key o JWT | Historial paginado con filtros |
| GET | /stats/analytics | API Key o JWT | Agregados (ultimos N dias) |

## Ejemplo con API Key

curl -H "X-API-Key: sk_dev_..." https://api-dev.baqueanonatales.com/api/v1/integrations/rut/16163631-2

## Parametros de /stats/history

api (rut|patente), was_cached (bool), q (texto), remaining_min, remaining_max, duration_min, duration_max, has_error (bool), date_from, date_to (ISO 8601), sort_by (created_at|duration_ms|remaining), sort_order (asc|desc), limit (1-500), offset.

## Codigos de error

- 200 OK
- 400 Input invalido (RUT no encontrado, patente invalida)
- 401 Falta auth o API Key invalida
- 429 Rate limit Boostr excedido
- 500 Error interno

## Rate limit Boostr

5 requests / 10 segundos. Headers ratelimit-limit, ratelimit-remaining, ratelimit-reset expuestos via /stats. Cache TTL 24h reduce consumo real a 0 en hit.

## Rotacion de API Key

Variable INTEGRATIONS_API_KEYS (comma-separated). Proceso:
1. Generar nueva: python3 -c "import secrets; print('sk_live_' + secrets.token_urlsafe(32))"
2. Agregar al .env: INTEGRATIONS_API_KEYS=sk_old,sk_new
3. Deploy backend.
4. Migrar consumidores.
5. Remover la vieja.
6. Deploy backend.
