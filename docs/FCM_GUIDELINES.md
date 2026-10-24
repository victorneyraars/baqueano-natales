# FCM Guidelines — Baqueano Natales

## Estado: Fase 4 cerrada 2026-10-24

Sistema de notificaciones push premium funcionando end-to-end:
- Foto del actor (cliente o prestador) como `largeIcon`
- BigTextStyle expandible con detalle completo
- Botones Aceptar/Rechazar que confirman turnos sin abrir la app
- Deduplicación por `messageId` determinístico
- Flujo: cliente reserva con servicio → push prestador (foto cliente + servicio + botones) → acepta → push cliente (foto prestador + confirmacion)

## Reglas de oro

### 1. Token FCM: un solo source of truth
- Tabla autoritativa: `fcm_tokens` (NO `usuarios.fcm_token`)
- `/me/fcm-token` DEBE hacer UPSERT en `fcm_tokens`
- Si FCM devuelve `UNREGISTERED`, marcar `activo=false`

### 2. Data-only SIEMPRE
- Backend manda solo `data={titulo, body, ...}` + `AndroidConfig(priority='high')`
- La app construye la notificación local con `fullScreenIntent: true`
- Razón: Motorola/Samsung/Xiaomi bloquean heads-up de notification-block en sideloaded

### 3. Canales inmutables
- Android NO permite cambiar importancia de un canal existente
- Si hay que cambiar: crear `vN+1` y borrar el viejo
- Crear el canal en `main()` ANTES de `runApp()`

### 4. showsUserInterface true (decision pragmatica)
- Se intentó `false` (background isolate) → callback no dispara en Motorola sideloaded
- Solución: `true` (isolate principal, app abre brevemente)
- Trade-off aceptable para MVP. Reintentar `false` en producción con Play Store.

### 5. Deduplicación por messageId
- `id: message.messageId?.hashCode ?? (titulo|body).hashCode`
- Usar el mismo ID en foreground y background para evitar duplicados

### 6. Detalle dinámico según tipo
- `tipo == 'turno_nuevo'` → usar `cliente_nombre` + `cliente_foto_url`
- `tipo == 'turno_estado'` → usar `prestador_nombre` + `prestador_foto_url`
- Servicio: preferir `servicio_nombre` (catálogo), fallback a `servicio_alias`

### 7. Protocolo de test (dev)
1. Desinstalar app
2. Instalar APK nuevo
3. Abrir app, loguear, esperar 15s (crea canal)
4. Batería = Sin restricciones
5. Botón Home (NO force-stop, NO swipe)
6. Esperar 30s
7. Disparar push
8. Verificar banner + botones + SQL

## QA Checklist antes de release
- [ ] Token en `fcm_tokens` = token en `usuarios.fcm_token`
- [ ] Backend manda data-only
- [ ] Handler con `fullScreenIntent: true` + `showWhenLocked` + `turnScreenOn`
- [ ] Canal vN creado antes de `runApp()`
- [ ] `keep.xml` protege recursos de R8
- [ ] Test manual: push con app cerrada → banner + botones funcionan

## Historial de fixes
- 2026-10-23: canal v4/v5/v6 (evolución por inmutabilidad)
- 2026-10-23: data-only + fullScreenIntent (Motorola sideloaded)
- 2026-10-23: UPSERT en `fcm_tokens` (token unico)
- 2026-10-23: botones Aceptar/Rechazar sin abrir app
- 2026-10-23: `showsUserInterface: true` (background isolate no dispara en Motorola)
- 2026-10-23: deduplicación por messageId (no duplicados)
- 2026-10-23: detalle dinámico cliente/prestador + servicio_nombre
- 2026-10-24: servicio_nombre en push de confirmación (no más "Toyota Corolla")
