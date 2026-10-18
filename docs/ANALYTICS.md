# Módulo Analytics (Cloudflare Web Analytics)

## Ubicación
- **Módulo:** `backend/app/modules/analytics/`
- **Endpoints:**
  - `GET /api/v1/analytics/stats?days=N&hostname=X` (admin)
  - `GET /api/v1/analytics/mi-prestador/stats?days=N` (prestador)
- **Configuración (.env):**
  - `CLOUDFLARE_API_EMAIL`
  - `CLOUDFLARE_API_KEY`
  - `CLOUDFLARE_ACCOUNT_ID=37959226fabd04f973ea41c91f200fad`

## Gotchas Críticos
1. El field de query es `rumPageloadEventsAdaptiveGroups` (SIN prefijo Account).
2. El type del filter es `AccountRumPageloadEventsAdaptiveGroupsFilter_InputObject` (CON prefijo Account).
3. Fechas en ISO 8601 completo (ej: `2026-10-18T00:00:00Z`).
4. Usar `filter: {...}` directo, NO `filters: [...]`.
5. Múltiples prestadores: usar `scalars().first()`.

## Datos de Producción (2026-10-18)
- 8 visitas a sealquilamarido.com.
- 4 visitas desde Google (SEO funcionando).

## Próximos Pasos
1. App Flutter Admin (mostrar gráficos).
2. Agregar campo `hostname` al modelo Prestador.
