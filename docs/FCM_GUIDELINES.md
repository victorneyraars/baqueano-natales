# FCM Guidelines — Baqueano Natales

## Reglas de oro

### 1. Un solo source of truth para tokens
- Tabla autoritativa: `fcm_tokens` (NO `usuarios.fcm_token`)
- El endpoint `/me/fcm-token` DEBE hacer UPSERT en `fcm_tokens`
- Si FCM devuelve `UNREGISTERED`, marcar `activo=false` (no borrar)

### 2. Data-only SIEMPRE
- Nunca usar `messaging.Notification(title, body)` en el payload
- Solo `data={titulo, body, ...}` + `AndroidConfig(priority='high')`
- La app construye la notificación local con `fullScreenIntent: true`
- Razón: Motorola/Samsung/Xiaomi bloquean heads-up de notification-block en sideloaded

### 3. Canales inmutables
- Android NO permite cambiar importancia de un canal existente
- Si hay que cambiar: crear `vN+1` y borrar el viejo
- Protocolo: `baqueano_turnos_v6` → `v7` → `v8`
- Crear el canal en `main()` ANTES de `runApp()`

### 4. Protocolo de instalación limpia (dev)
1. Desinstalar app
2. Instalar APK nuevo
3. Abrir app, loguear, esperar 15s en home (crea canal)
4. Batería = Sin restricciones
5. Cerrar app
6. Recién ahora mandar push de prueba

### 5. Bump version en cada cambio FCM
- Cambiar `pubspec.yaml` versionCode para forzar reinstall
- Sin bump, Android instala el APK viejo silenciosamente

## QA Checklist antes de release
- [ ] Token en `fcm_tokens` = token en `usuarios.fcm_token`
- [ ] Endpoint `/me/fcm-token` hace UPSERT (no solo UPDATE legacy)
- [ ] Backend manda data-only (verificar `notification` no existe en payload)
- [ ] Handler con `fullScreenIntent: true`
- [ ] Canal vN creado antes de `runApp()`
- [ ] Test manual: push con app cerrada → banner visible
