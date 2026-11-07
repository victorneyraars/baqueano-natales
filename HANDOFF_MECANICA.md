# HANDOFF — Mecánica (Oficios)

Sesión cerrada: 2026-11-07
Estado: Flujo E2E (Cliente-Prestador) operativo al 100% en producción.

## CONTEXTO RÁPIDO

El vertical de Mecánica (Oficios) está validado de punta a punta en producción.
La app Flutter (v1.0.22) y el backend FastAPI están desplegados, funcionando y comunicándose sin errores.

Lo que se validó hoy (Ciclo Completo):
1. Cliente (María QA) reservó un turno (08/11 13:00).
2. Prestador (Pedro QA) lo confirmó.
3. Prestador lo completó.
4. Cliente dejó una review de 5 estrellas (id: 4bbf1e75-4c51-4eb1-a49d-9f8fa60fc75e).

## CAMBIOS ARQUITECTÓNICOS REALIZADOS (SESIÓN 2026-11-07)

1. **Fix Auth (Flutter)**: Se eliminó la race condition en el logout (ahora cierra al primer toque).
2. **Fix Modo Prestador (Flutter)**: Se eliminó la restricción de "vehículo de cliente" para que Rent a Car pueda operar.
3. **Core Flutter**: Se movieron `ReviewCard` y `PhotoViewer` a `lib/shared/widgets/` para ser reutilizados por todos los verticales.
4. **Core Backend (Refactor)**: Se dividió el monolito `oficios/routes.py` en 4 archivos limpios:
   - `public_routes.py`
   - `admin_routes.py`
   - `cliente_routes.py`
   - `prestador_routes.py`
   El archivo `routes.py` ahora es solo un HUB de imports. (Commit: `2b0a56f`)
5. **Base de Datos**: 
   - Se agregó la columna `servicio_id` a la tabla `turnos` (migración `c7b6a5d4e3f2`).
   - Se creó un nuevo estado en Alembic (se aplicó vía SQL directo para destrabar prod, pero la migración quedó commiteada).
6. **Fix FCM Token (Backend)**: 
   - Se corrigió un bug donde un token FCM duplicado provocaba un `UniqueViolation` y rompía la sesión SQLAlchemy (PendingRollbackError).
   - Ahora `_get_tokens_activos` hace SELECT antes del INSERT.
   - Se aisló la notificación push en un `savepoint` (`db.begin_nested()`) en `oficios/services.py` para que, si falla el envío, no tumbe la creación del turno. (Commit: `021f656`).

## PENDIENTES / PRÓXIMOS PASOS

1. **Migración de Alembic Rota**: Quedó un archivo de migración duplicado (`a1b2c3d4e5f6` vs `c7b6a5d4e3f2`). El de la DB es `c7b6a5d4e3f2`. Hay que limpiar el archivo `a1b2c3d4e5f6` del repo para que el historial de Alembic no marque ciclos.
2. **WIP de Rent a Car**: Hay una rama congelada `feat/rentacar-documents-wip` con mejoras de la sesión anterior (módulo `documents`, auth, analytics). Habrá que mergearla a `main` en la próxima sesión.
3. **Tests E2E adicionales**: Probar el flujo con el módulo de Rent a Car usando las nuevas utilidades compartidas (`PhotoViewer` para las inspecciones del auto).

## REGLAS DE TRABAJO
- Nunca duplicar código. Usar `lib/shared/` para Flutter y verificar si el endpoint ya existe en el backend.
- Para deployar, usar siempre `bash scripts/deploy-prod.sh`.
- Si se toca el modelo de DB, SIEMPRE crear la migración de Alembic correspondiente.
