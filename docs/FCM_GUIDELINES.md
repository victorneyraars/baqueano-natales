# FCM Guidelines — Baqueano Natales

## Reglas de oro

### 1. Token FCM: un solo source of truth
- Tabla autoritativa: `fcm_tokens` (NO `usuarios.fcm_token`)
- `/me/fcm-token` DEBE hacer UPSERT en `fcm_tokens`
- Si FCM devuelve `UNREGISTERED`, marcar `activo=false`

### 2. Data-only SIEMPRE
- Nunca `messaging.Notification(title, body)` en payload
- Solo `data={titulo, body, ...}` + `AndroidConfig(priority='high')`
- La app construye la notificación con `fullScreenIntent: true`
- Motorola/Samsung/Xiaomi bloquean heads-up de notification-block en sideloaded

### 3. Canales inmutables
- Android NO permite cambiar importancia de un canal existente
- Si hay que cambiar: crear `vN+1` y borrar el viejo
- Crear el canal en `main()` ANTES de `runApp()`

### 4. Protocolo instalación limpia (dev)
1. Desinstalar app
2. Instalar APK nuevo
3. Abrir app, loguear, esperar 15s en home (crea canal)
4. Batería = Sin restricciones
5. Cerrar app
6. Recién ahora mandar push de prueba

### 5. Bump versionCode en cada cambio FCM
- Sin bump, Android instala el APK viejo silenciosamente

## QA Checklist antes de release
- [ ] Token en `fcm_tokens` = token en `usuarios.fcm_token`
- [ ] Backend manda data-only (no bloque `notification`)
- [ ] Handler con `fullScreenIntent: true`
- [ ] Canal vN creado antes de `runApp()`
- [ ] Test manual: push con app cerrada → banner visible
