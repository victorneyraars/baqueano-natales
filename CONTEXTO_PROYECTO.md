# Baqueano Natales — Contexto Completo del Proyecto

> **Última actualización:** 2026-10-12
> **Propósito:** Documento maestro que resume el estado completo del proyecto para retomar el trabajo en cualquier momento sin perder contexto.

> **Ver también:**
> - `docs/OPERATIVA_DEV.md` — metodología de trabajo, patrones canónicos de comandos, reglas por dominio, workflow dual-repo y reglas de oro.
> - `docs/SERVER_CHEATSHEET.md` — comandos rápidos, credenciales, gotchas del server.

---

## 📋 Changelog reciente

### 2026-10-12 (cont. 26) - M5.3 reportes del taller (frontend) - **M5 COMPLETO**

**Modulo oficios M5 cerrado al 100% (backend + frontend + tests).**

- **Frontend**:
  - Modelo `ReportePrestador` + 4 sub-modelos (`ReporteKPIs`, `ReporteSerieMes`, `ReporteTopServicio`, `ReporteTopCliente`).
  - `OficiosRepository`: 2 metodos nuevos (`obtenerReporte` JSON, `descargarReporteCsv` bytes).
  - Provider family `reportePrestadorProvider` con params inmutables (prestadorId + desde + hasta).
  - Pantalla `ReportesTallerScreen`:
    - Selector de rango: chips 30d / 90d / 12m.
    - KPIs en cards 2x2 (icono + label + valor).
    - Chart de barras con `CustomPaint` (sin `fl_chart`).
    - Top 10 servicios + Top 10 clientes.
    - Boton de descarga CSV (share sheet via `share_plus` + `path_provider`).
  - Wire: boton `bar_chart_outlined` en AppBar de `detalle_mi_prestador`.
  - Ruta nueva: `/mis-prestadores/:id/reportes`.
- **Bug critico detectado en el smoke test (y arreglado)**: `_desde`/`_hasta` se calculaban con getters llamando `DateTime.now()` en cada build -> Riverpod family veia params distintos (microsegundos) -> fetch infinito. Fix: guardar como campos de estado (`late DateTime`) y recalcular solo en `initState` / `onChanged` del preset. **Aprendizaje general para Riverpod family: los params deben ser inmutables y deterministas.**
- **Validado end-to-end** en emulador:
  - KPIs correctos: 2 ordenes, $87.000, ticket $87.000, tasa 100%, duracion 2.0 d.
  - Chart de barras con 1 barra (oct).
  - Top 3 servicios + Top 1 cliente.
  - Cambio de chips: refetch correcto, sin loop.
- **Flutter analyze: No issues found!**

**Estado del modulo oficios (M5):**
- M5.1 (fotos): backend + frontend + tests OK
- M5.2 (notifs in-app): backend + frontend + tests OK
- M5.3 (reportes): backend + frontend + tests OK
- **M5 COMPLETO.**

**Backlog del proyecto (fuera de M5):**
- Cosmeticos de notifs (`android:label`, `ic_notification` monocromatico, card -> detalle).
- Rotar secretos expuestos (pendiente desde oct-08).
- M6 hipotetico: chat cliente-prestador, pagos, etc.

### 2026-10-12 (cont. 25) - M5.3 reportes del taller (backend completo)

**Ultimo slice de M5 backend. Metricas de industria basadas en Jobber / ServiceTitan / TallerPro.**

- **Nuevos modulos**:
  - `schemas_reportes.py`: ReportePrestador + ReporteKPIs + ReporteSerieMes + ReporteTopServicio + ReporteTopCliente.
  - `services_reportes.py`: SQL agregado directo (GROUP BY + func.sum/count/avg) sin vistas materializadas (optimizar cuando haya volumen real >10k ordenes/taller).
  - `routes_reportes.py`: 2 endpoints.
- **Metricas** (KPIs + rankings):
  - KPIs: total_ordenes, ordenes_por_estado, ingresos_totales (solo ENTREGADO), ticket_promedio, tasa_aprobacion_items, duracion_promedio_dias (ingreso -> entrega_real).
  - Serie mensual (12 meses): ordenes + ingresos por mes (YYYY-MM).
  - Top 10 servicios: agrupado por `descripcion` del item, ordenado por cantidad.
  - Top 10 clientes: agrupado por `cliente_id`, con nombre resuelto en 1 query IN.
- **Endpoints**:
  - `GET /api/v1/mis-prestadores/{pid}/reportes` (JSON).
  - `GET /api/v1/mis-prestadores/{pid}/reportes.csv` (descarga con `Content-Disposition`).
  - Filtros `desde` / `hasta` (defaults a ultimos 12 meses).
  - Ownership: 403 si no eres dueno del prestador (o admin).
- **6 tests HTTP** (`test_routes_reportes.py`): reporte con datos, reporte vacio, filtro de fechas, CSV con headers, ownership (403), prestador inexistente (404).
- **Smoke test manual**: reporte del Taller Mecanico del Sur -> 2 ordenes, $87.000 ingresos, ticket $87.000, tasa 100%, duracion 1.96 dias. CSV completo.
- **Suite total: 396 passed, 0 warnings.**

**Pendiente de M5:**
- **M5.3 frontend Flutter**: pantalla de reportes del taller (graficos + descarga CSV). Es la ultima pieza del modulo oficios M5.

### 2026-10-12 (cont. 24) - M5.2 tests HTTP del wire de notificaciones in-app

**Deuda de tests de M5.2 cerrada.**

- **5 tests nuevos** (`tests/modules/oficios/test_notificaciones_in_app.py`) que validan los 3 flujos wire:
  - `crear_orden` -> notif IN_APP al cliente con `data.tipo=orden` + `orden_id` + `estado`.
  - `cambiar_estado` (prestador) -> notif al cliente con `estado_anterior` + `estado`.
  - `cambiar_estado` (cliente, rechazar) -> notif al prestador dueno.
  - `aprobar_presupuesto` -> notif al prestador con `total_aprobado`.
  - `enviar_in_app()` funciona sin tokens FCM activos (canal=IN_APP).
- **Decision de diseno del test**: llaman a los services directamente (no HTTP) porque el wire esta en el service y asi evitamos la cadena HTTP completa. Los tests HTTP ya existen para los endpoints en si.
- **Transiciones validas del cliente** (descubierto en el proceso): solo `presupuestado -> aprobado|rechazado` y `rechazado -> cancelado`. El test usa `rechazado` porque es la transicion "del cliente" que dispara notif al prestador.
- **Suite total: 390 passed, 0 warnings.**

**Estado del modulo oficios (M5):**
- M5.1 (fotos): backend + frontend OK
- M5.2 (notifs in-app): backend + frontend + tests OK
- M5.3 (reportes taller): pendiente

### 2026-10-12 (cont. 23) - M5.2 notificaciones in-app en cambios de estado

**Slice M5.2 cerrado end-to-end (backend + frontend).**

- **Backend** (`app/core/notifications/service.py`):
  - `enviar_in_app()`: pipeline completo (preferencias + quiet hours + rate limit) pero **sin tokens FCM**. El log queda `estado=ENVIADA` directo con `canal=IN_APP`.
  - `_log_skipped()` ahora acepta `canal` (default FCM, retrocompatible).
- **Wire** en `oficios/services.py` con helper `_notificar_orden()` (best-effort, try/except que nunca rompe el flujo):
  - `crear_orden` -> notifica al cliente.
  - `cambiar_estado` -> notifica al "otro lado" (si cambio prestador -> cliente; si cambio cliente -> prestador dueno).
  - `aprobar_presupuesto` -> notifica al prestador con el resultado.
- **Payload del deep link**: `data = {"tipo": "orden", "orden_id": str(uuid), "estado": "..."}` para que el frontend navegue.
- **Frontend** (`mis_notificaciones_screen.dart`):
  - Helper `_resolverRuta()` que mapea `data.tipo` + id a la ruta GoRouter.
  - Soporta `orden` / `turno` / `recordatorio`. Sin tipo conocido -> solo marca como leida + SnackBar.
  - Tap navega con `GoRouter.of(context).push()` (apila, preserva el back).
- **`FcmService._resolverRuta()`** ya mapeaba `case 'campana'` con `orden_id` -> `/mis-ordenes/{id}` desde la sesion anterior, sin cambios.
- **Validado end-to-end** en emulador:
  - Crear orden real via SQL -> notif in-app "Nueva orden OT-2026-0002".
  - `cambiar_estado` a `diagnosticando` -> notif "Orden OT-2026-0002: diagnosticando".
  - Tap en la campanita del Home -> aparecen las 2 notifs con badge `campana`.
  - Tap en cualquiera -> navega al detalle de la orden (badge baja a 0).
  - Tap en notif de recordatorio (`sistema`) -> NO navega, solo marca leida + SnackBar.
- **Suite total: 385 passed, 0 warnings.**
- **Tests HTTP del backend de M5.2**: pendiente (solo smoke manual por SQL). Deuda: agregar tests que validen que `crear_orden` / `cambiar_estado` / `aprobar_presupuesto` generan un log con `canal=IN_APP`.

**Estado del modulo oficios (M5):**
- M5.1 (fotos): backend + frontend OK
- M5.2 (notifs in-app en cambio de estado): backend + frontend OK
- M5.3 (reportes taller): pendiente

### 2026-10-12 (cont. 22) - M5.1 fotos frontend (Flutter)

**Slice M5.1 cerrado end-to-end (backend + frontend).**

- **Modelo `OrdenFoto`** (Dart) + `MomentoFoto` enum (ingreso/diagnostico/en_proceso/entrega/reclamo/otro) + `FotoVariante`.
- **`AuthedImage`** (`core/network/authed_image_provider.dart`): `ImageProvider` custom que usa `DioClient` singleton para bajar bytes con `Authorization: Bearer` automatico. **Reusable en cualquier feature** que necesite servir imagenes privadas.
- **Repository**: 5 metodos nuevos (`subirFoto`, `subirFotoPrestador`, `listarFotosDeMiOrden`, `listarFotosDeOrdenPrestador`, `eliminarFotoDeMiOrden`, `eliminarFotoDeOrdenPrestador`). Multipart con `FormData` + `MultipartFile.fromBytes`.
- **Providers**: `fotosDeMiOrdenProvider` + `fotosDeOrdenPrestadorProvider` (family con params inmutables).
- **Widgets reusables**:
  - `FotoThumb`: thumbnail con `AuthedImage`, variante configurable (`thumb`/`medium`/`original`), placeholder, `onTap` + `onLongPress`.
  - `GaleriaFotos`: grid reusable con `maxFotos`, `onVerTodas`, `onFotoTap`.
- **Pantalla `GaleriaFotosScreen`**:
  - FAB upload con `image_picker` (camara/galeria + momento).
  - Filtro por momento (bottom sheet + badge en el icono).
  - Long-press para eliminar (dialogo de confirmacion).
  - Visor fullscreen con `PageView` + `InteractiveViewer` (pinch zoom 1-5x) + boton delete en AppBar.
- **Wire**: boton de fotos en AppBars de `detalle_mi_orden_screen` y `detalle_orden_taller_screen`. 2 rutas nuevas en `app_router.dart`.
- **Dep**: `image_picker ^1.1.2`.
- **Validado end-to-end en emulador Android 14**:
  - Upload PNG/JPEG desde camara y galeria -> 201 + grid actualiza.
  - `AuthedImage` -> GET con JWT a `/api/v1/ordenes/fotos/{id}/archivo/thumb` -> 200.
  - Filtro `?momento=` -> 200.
  - DELETE -> 204 + grid refresca.
- **Bugs encontrados y arreglados en el camino**:
  1. `FotoThumb` con `width/height: null` colapsaba a 0x0 en grid -> default `double.infinity`.
  2. Visor usaba variante `thumb` (256px borroso) -> ahora `original` (2048px).
  3. `BoxFit.cover` recortaba la imagen -> `contain` en visor.
  4. Long-press competia en gesture arena con `onTap` del `FotoThumb` -> ambos en el mismo widget.
- **Gotcha del emulador**: el AVD genera una escena sintetica de baja resolucion para la camara -> la foto se ve borrosa pero es la fuente, no el pipeline. Probar con device fisico o subir imagen desde la galeria (drag&drop de un PNG/JPG a la ventana del emulador).

**Estado del modulo oficios (M5):**
- M5.1 (fotos): backend + frontend OK
- M5.2 (notifs in-app en cambio de estado): pendiente
- M5.3 (reportes taller): pendiente
### 2026-10-12 (cont. 21) - M5.1 fotos de ordenes (backend completo)

**Primer slice de M5 del modulo oficios: fotos con estandares de industria.**

- **Modelo `OrdenFoto`** content-addressable (SHA-256 del contenido):
  - 3 variantes server-side: `original` (2048px), `medium` (1024px), `thumb` (256px).
  - `blurhash` (placeholder visual en cliente).
  - `storage_backend` + `storage_key` (forward compat S3/R2 sin migrar).
  - `subido_por_id` + `subido_por_rol` (snapshot).
  - `item_id` opcional (foto asociada a un item del presupuesto).
  - `fecha_captura` (EXIF) + `metadata_extra` JSONB.
  - Soft delete + GC futuro.
- **Storage abstracto** `FotoStorage` (ABC) + `LocalFotoStorage`:
  - Mismo patron que `AvatarStorage`.
  - Reusa las excepciones de `base.py` (evita duplicacion que rompia el `except`).
  - EXIF stripping + orientation transpose.
  - MIME por magic bytes (`filetype`), no por extension.
  - MAX_SIZE: 15 MB. Formatos: JPEG, PNG, WebP.
- **Service** (`services_fotos.py`):
  - `subir_foto`: valida ownership + rate limit + procesa + dedup logico por hash (misma orden) + inserta + registra en historial.
  - Rate limit: 30/h por orden + 100/h por usuario (SQL directo, sin slowapi).
  - `listar_fotos`, `obtener_foto_para_servir`, `leer_variante`, `eliminar_foto`.
- **Endpoints** (5):
  - `POST /api/v1/mis-ordenes/{oid}/fotos` (cliente)
  - `GET  /api/v1/mis-ordenes/{oid}/fotos?momento=...` (cliente)
  - `DELETE /api/v1/mis-ordenes/{oid}/fotos/{fid}` (cliente)
  - `POST/GET/DELETE /api/v1/mis-prestadores/{pid}/ordenes/{oid}/fotos` (prestador)
  - `GET /api/v1/ordenes/fotos/{fid}/archivo/{variante}` (autenticado, valida ownership)
  - **NO se sirve por nginx** (privacidad): todo pasa por endpoint autenticado.
- **Migraciones**: `ee4752206777` (tabla + enum `momento_foto`) + `a1b2c3d4e5f6` (drop unique constraint redundante que impedia subir la misma foto a 2 ordenes).
- **Fix critico `env.py`**: faltaba import de `app.core.notifications.models` -> Alembic queria dropear `fcm_tokens`, `notification_logs`, `preferencias_notificacion`, `rate_limit_config` en cada autogenerate. Ahora importa.
- **12 tests HTTP** (`test_routes_fotos.py`):
  - Upload png/jpeg OK, MIME invalido, momento invalido, sin archivo.
  - Dedup por hash (mismo contenido -> mismo row).
  - Listar con/sin filtro por momento.
  - Servir variante thumb (verifica magic bytes JPEG) + variante invalida + foto inexistente.
  - Tercero no sube a orden ajena (403).
- **Bug real detectado por tests**: dos definiciones de `StorageError` (en `base.py` y `foto_base.py`) -> el `except StorageError` no capturaba. Fix: `foto_base.py` reusa de `base.py`.
- **Suite total: 385 passed, 0 warnings.**

**Pendiente de M5:**
- M5.1 frontend Flutter: galeria + upload (`image_picker`).
- M5.2: notificaciones in-app en cambio de estado (reusar `NotificationService` con `canal=in_app`).
- M5.3: reportes del taller.

**Gotchas nuevos documentados:**
- `$py | ssh "cat > /tmp/file.py"` en PowerShell 5.1 **no es confiable** para contenido > 1 KB (se trunca silenciosamente). **Fix: base64**. Documentado en OPERATIVA_DEV 3.7.
- Alembic autogenerate: si un modulo nuevo no esta importado en `env.py`, va a querer dropear sus tablas. **Siempre verificar que no aparezca `Detected removed` antes de aplicar**.



### 2026-10-12 (cont. 20) - Cierre WIP deep linking: dedup FCM + back button

**Los 3 bugs del WIP de deep linking resueltos + 4 gotchas nuevos.**

- **Back button en deep link** (`main_client.dart`): `router.go(pending)` reemplazaba el stack -> no habia flecha atras. Cambiado a `router.push(pending)` (apila, preserva el back).
- **Dedup FCM con 3 capas** (`fcm_service.dart`):
  - **Capa 1**: `_procesadosEnSesion` como **`static final Set<String>`** (sobrevive hot restart, comparte estado entre instancias de FcmService).
  - **Capa 2**: check + add **sincrono** (`_registrarEnSesionSync`) sin `await` intermedio para eliminar el race entre `onMessageOpenedApp` y `getInitialMessage`.
  - **Capa 3**: persistencia en `SecureStorageService` (nuevos metodos `saveFcmTap`/`getFcmTap`) con ventana de 30s. Cubre **hot restart** (el plugin nativo cachea `getInitialMessage` y Dart pierde su estado).
  - **Key canonica**: `log:<notification_log_id>` (identifica univocamente cada envio y esta disponible en los 3 paths). Fallback a `messageId` y luego a `tipo|sentTimeMs`.
- **Bug real**: el callback de `flutter_local_notifications` (`onDidReceiveNotificationResponse`) llamaba directo a `_reportarAperturaPorId` sin pasar por el dedup. Ahora todos los paths (banner local + `onMessageOpenedApp` + `getInitialMessage`) convergen a `_yaProcesado('log:<uuid>')`. **El doble POST /abierta era 2 paths distintos, no 2 eventos del mismo path.**
- **Validado end-to-end** en emulador Android 14 (cold start):
  - `[FCM] dedup in-session: log:cae07c80-...` -> 2do path bloqueado.
  - `[Dio] POST .../abierta` -> **1 sola** (antes: 2).
  - `[DeepLink] navegando a: /mis-notificaciones` -> 1 sola.
  - Flecha atras visible en `/mis-notificaciones`.
  - Badge baja de 8 -> 6 despues del tap.
- **Reset de notifs en la DB**: todas estaban en `abierta` tras el smoke anterior -> UPDATE a `enviada` + `abierto_en = NULL` para volver al estado base.
- **Gotchas nuevos documentados** (cheatsheet #24-27):
  1. `<<'SQL'` heredoc dentro de `bash -s` se come stdin de `docker compose exec -T` -> `syntax error at or near "SQL"`. Usar `-c "..."` o llamadas SSH separadas.
  2. `docker compose exec -T` consume stdin cuando se usa dentro de `bash -s` multi-linea -> el resto del script no se ejecuta. Fix: separar en llamadas SSH distintas.
  3. En Windows, `< /dev/null` en el contenido de un here-string enviado por `bash -s` **se pierde** (PowerShell no lo interpreta). Usar comandos de una linea por SSH.
  4. Hot reload NO recicla los listeners de FCM (`onMessageOpenedApp` queda registrado con el closure viejo). Hot restart tampoco recicla el plugin nativo de `flutter_local_notifications` -> requiere **cold start** (`q` + `flutter run`) para estado limpio.

### 2026-10-12 (cont. 3) - M4 frontend verificado end-to-end + fix crítico ObjetoServicio

**Smoke test visual de M4 + bug encontrado en producción.**

- **Bug crítico encontrado y arreglado** (`3a5941b`):
  - `routes.py` usaba `ObjetoServicio` en `_validar_objeto_del_usuario` sin
    importarlo -> los 3 endpoints de recordatorios (GET x2 + POST) fallaban
    con `NameError`.
  - Fix: agregar `ObjetoServicio` al import de `models`.
  - **No lo detectaron los 272 tests** porque no hay tests HTTP que ejerciten
    `routes._validar_objeto_del_usuario`. Deuda: agregar tests de integración.

- **Smoke test M4 verificado visualmente en emulador Android 14**:
  - `MisRecordatoriosScreen` carga correctamente (GET sin filtro y con
    `incluir_enviados=true`).
  - Crear recordatorio desde el FAB -> 201 -> aparece en la lista con
    SnackBar "Recordatorio creado".
  - Badge "Enviado 12/10/2026" se muestra en el recordatorio procesado por
    el worker APScheduler -> **worker M4 end-to-end funcionando** (no solo
    loguea: persiste `enviado=True` + `fecha_envio`).
  - `GarantiaCard` renderiza perfecto en el detalle de la orden entregada
    (tipo, vigencia, duración, cobertura, condiciones).
  - `DetalleMiOrdenScreen` con 3 items + totales ($87.000) + timeline de
    8 eventos, todo OK.

- **Seed de smoke test en DB de producción** (para retomar):
  - ObjetoServicio `74ae2fcb-4e9d-42b1-a04f-6d92f34a3af7` (alias
    "Auto de prueba smoke M4").
  - Vehiculo `b408e708-5a27-4812-bdd2-e5e4fd74e23a` (patente SMOKE01).
  - Orden `494b063f-99fc-424c-a6df-87689fcc0c45` / `OT-2026-9999` en
    estado `entregado` (3 items + 8 eventos de historial + garantía).
  - 2 recordatorios (uno ya procesado por el worker, uno nuevo de prueba).

- **Gotcha nuevo documentado**: `docker compose restart backend` es más
  confiable que `docker compose up -d backend` cuando el hash del container
  no cambia (el `up -d` muestra "Running" en vez de "Recreated" y no recarga
  el código). El `touch app/main.py` **tampoco** disparó hot reload de
  uvicorn en este caso.

- **Estado final del módulo oficios**:
  - M1, M2, M3: completas (backend + frontend + tests)
  - M4: **backend + frontend + worker, todos verificados end-to-end**
  - M5: fotos + notificaciones in-app + reportes
  - **Deuda pendiente de M4**: push FCM real (hoy el worker marca
    `enviado=True` y loguea, pero no manda push al usuario).

### 2026-10-12 (cont. 19) - Deep linking + badge + filtro (WIP, cierre de sesion)

**Deep linking desde notifs funcionando end-to-end + 2 mejoras UX. Pendiente: deduplicacion de taps en hot restart.**

- **Deep linking** (commits `ded9c5e` + `7ca5e60`):
  - Backend: `service.py` agrega `"tipo": tipo.value` al payload del push.
  - Flutter: `FcmService._resolverRuta()` mapea tipo + data a ruta GoRouter.
  - `main_client.dart` escucha `pendingNavigationProvider` y navega
    post-auth (con guard para no disparar antes de que el JWT este listo).
  - `pendingNavigationProvider` (Riverpod 3 `NotifierProvider`) para la
    ruta pendiente. Migrado desde `StateProvider` (deprecado en v3).
  - **Validado end-to-end** (log confirmado):
    `[DeepLink] navegando a: /mis-vehiculos/74ae2fcb-.../recordatorios`

- **Badge de no leidas en el Home**: card "Mis notificaciones" pasa a
  `ConsumerWidget`. Badge numerico con count de estados
  `{'enviada', 'entregada', 'impresa'}` (excluye `skipped` y `fallida`).

- **Filtro "Solo no leidas"** en la lista (`FilterChip` en la AppBar).
  La pantalla pasa de `ConsumerWidget` a `ConsumerStatefulWidget`.

- **Suite backend: 373 passed, 0 warnings.**

- **Pendiente para proxima sesion (WIP)**:
  1. Deduplicar taps por `messageId` en `fcm_service.dart`.
  2. Reset de notifs en la DB (todas quedaron en `abierta` tras las pruebas).
  3. Re-test del deep link end-to-end sin hot restart.
  4. Commit de esos fixes.
### 2026-10-12 (cont. 18) - Rate Limiting / Frequency Capping (S8) - sistema 8/8 features

**Feature #8 de la industria. Sistema de notificaciones: 8/8 features nivel industria.**

- **Tabla `rate_limit_config`** (migracion `b9c0d1e2f3a4`):
  - Limites configurables por tipo: `max_por_hora`, `max_por_dia`,
    `max_por_semana`, `min_intervalo_seg`, `strict`.
  - 5 configs seedeadas:
    - `sistema` / `confirmaciones`: sin limite (criticos).
    - `recordatorio`: 2/h, 3/d, 7/sem, min 1h.
    - `promocion`: 1/h, 1/d, 2/sem.
    - `campana`: 1/h, 1/d, 3/sem.

- **Logica en `NotificationService._check_rate_limit()`**:
  - Se ejecuta ANTES de crear el log (despues de preferencias + quiet hours).
  - Si excede: registra `SKIPPED` con `razon=rate_limit:X`.
  - Tipos criticos (`sistema`, `campana`) bypassan el limite salvo `strict=True`.
  - Los logs `SKIPPED` NO cuentan para el conteo (solo los enviados).

- **2 endpoints admin**:
  - `GET  /api/v1/admin/notificaciones/rate-limits`.
  - `PATCH /api/v1/admin/notificaciones/rate-limits/{tipo}`.

- **9 tests nuevos** (7 de logica + 2 de endpoints).
- **Suite total: 373 passed, 0 warnings.**

- **Sistema de notificaciones 8/8 features**:
  1. Multi-device + limpieza automatica OK
  2. Prioridad + TTL + collapse_key OK
  3. Analytics end-to-end (enviada -> entregada -> abierta) OK
  4. Preferencias por tipo + quiet hours OK
  5. Panel admin (composer + historial + stats) OK
  6. Centro de notificaciones del usuario OK
  7. **Frequency capping / rate limiting OK**
  8. Arquitectura extensible (ABC provider) OK

### 2026-10-12 (cont. 17) - Centro de notificaciones del usuario (S7) - sistema 100% end-to-end

**Sistema de notificaciones nivel industria: 100% completo (backend + admin + usuario).**

- **S7 - Centro de notificaciones del usuario** (commits `f60a745` + `ca46767`):
  - `MisNotificacionesScreen`: lista con marcar-abierta al tocar + SnackBar de feedback.
  - `PreferenciasNotificacionScreen`: toggles por tipo + quiet hours con timepicker.
  - Modelo `PreferenciaNotificacion` + 4 metodos nuevos en el repository
    (misNotificaciones, marcarAbierta, misPreferencias, actualizarPreferencias).
  - 2 rutas nuevas: `/mis-notificaciones` + `/mis-notificaciones/preferencias`.
  - Card "Mis notificaciones" en el Home del cliente.
- **Fix de UX** (`ca46767`): el SnackBar no se veia porque el `context`
  original quedaba unmounted post `ref.invalidate()`. Fix: capturar el
  `ScaffoldMessenger` antes del await.
- **Fix del emulador** (sesion):
  - 5 adb zombies acumulados -> matar todo + adb start-server.
  - `-gpu host` con Intel UHD 630 -> warnings visuales.
    `-gpu swiftshader_indirect` es mas estable.

- **Estado final del sistema de notificaciones (100% end-to-end)**:
  - S1 (modelo multi-device) OK
  - S2 (refactor push batch + limpieza tokens) OK
  - S3 (tracking entrega/apertura) OK
  - S4 (preferencias + quiet hours) OK
  - S5 (panel admin backend) OK
  - S6 (panel admin Flutter) OK
  - S7 (centro de notificaciones del usuario) OK
  - Analytics end-to-end OK
  - Banner en foreground OK

- **Suite total: 364 tests verdes, 0 warnings.**

- **Backlog (no bloqueante)**:
  - Card -> detalle de notificacion (pantalla con body completo + data JSON).
  - Filtro "solo no leidas" en la AppBar.
  - Badge de no leidas en la Home.
  - `android:label` de la notif (mostrar "Baqueano Natales").
  - Icono monocromatico de notificacion (`ic_notification` vectorial).
  - M5 del modulo oficios: fotos + reportes.

### 2026-10-12 (cont. 16) - Panel admin Flutter (S6) - sistema de notificaciones 100% completo

**Sistema de notificaciones nivel industria: 100% completo (backend + frontend + admin panel).**

- **Panel admin Flutter** (commit `d1b5fd2`):
  - `lib/features/notificaciones/` nueva:
    - `domain/`: `NotificacionAdmin`, `Segmento` (+ `TipoSegmento`), `StatsNotificacion`.
    - `data/`: `NotificacionesRepository` (enviar + listar + stats) + providers Riverpod.
    - `presentation/screens/`:
      - `admin_notificaciones_composer_screen.dart`: envio a segmentos con resultado en dialogo.
      - `admin_notificaciones_historial_screen.dart`: filtros tipo/estado + cards coloreadas.
      - `admin_notificaciones_stats_screen.dart`: dashboard (metricas + por estado/tipo + top 5).
  - 3 rutas nuevas: `/admin/notificaciones{,/historial,/stats}`.
  - 3 cards nuevas en AdminHome.
- **Migraciones UI necesarias**:
  - `RadioGroup` en vez de `groupValue`/`onChanged` (deprecado en Flutter 3.32+).
  - `use_null_aware_elements` (Dart 3.8+): `'key': ?value` en vez de `if (v != null) 'key': v`.
  - `flutter_local_notifications v22`: `initialize({settings: ...})` + `show({id:, ..., notificationDetails: ...})`.

- **Validado end-to-end en emulador (flavor admin)**:
  - Composer: `POST /enviar` -> 200 + dialogo con Total/Enviados/Fallidos/Skipped.
  - Historial: multiples GETs con filtros tipo/estado -> todos 200.
  - Stats: `GET /stats` -> 200.

- **Gotcha nuevo (fix del emulador)**:
  - 5 procesos `adb` zombies acumulados de sesiones anteriores causaban
    timeouts y glitches. Fix: matar todo (emulator + qemu + adb),
    limpiar locks, `adb start-server`.
  - GPU `host` con Intel UHD 630 causa `Unable to match the desired
    swap behavior`. Fix: `-gpu swiftshader_indirect` (mas lento pero
    estable visualmente).

- **Estado final del sistema de notificaciones (100%)**:
  - S1 (modelo multi-device) OK
  - S2 (refactor push batch + limpieza tokens) OK
  - S3 (tracking entrega/apertura) OK
  - S4 (preferencias + quiet hours) OK
  - S5 (panel admin backend) OK
  - S6 (panel admin Flutter) OK
  - Analytics end-to-end OK (backend + Flutter)
  - Banner en foreground OK

- **Suite total: 364 tests verdes, 0 warnings.**

- **Pendiente para sesion futura**:
  - S7: centro de notificaciones Flutter (vista del usuario: lista + preferencias).
  - Deuda cosmetica: `android:label` de la notif + icono monocromatico.
  - M5 modulo oficios: fotos + reportes.

### 2026-10-12 (cont. 15) - Banner en foreground + sistema de notificaciones 100%

**Sistema de notificaciones COMPLETO end-to-end (S1-S5 + analytics + foreground banner).**

- **Banner en foreground** (commit `ebdfb90`):
  - `flutter_local_notifications ^22.3.2` agregado.
  - `coreLibraryDesugaring` habilitado en `build.gradle.kts` + dep
    `desugar_jdk_libs:2.1.4` (requerido por el plugin).
  - `FcmService` muestra el banner a mano desde `onMessage` (Android por
    default NO muestra notifs con la app en foreground).
  - `onDidReceiveNotificationResponse` reporta la apertura al backend.
  - Canal Android `baqueano_default` (matchea el meta-data del manifest).

- **API v22 de flutter_local_notifications**:
  - `initialize({settings: ...})` (named param, no positional).
  - `show({id:, title:, body:, notificationDetails:, payload:})`
    (todos named).
  - Gotcha documentado en CHEATSHEET #22.

- **Validado end-to-end**:
  - Push llegado al emulador con la app en foreground.
  - Banner visible con titulo + body.
  - Tap -> `[FCM] tap (background)` + `[FCM] tap (terminated)`.
  - POST `/notificaciones/{id}/abierta` -> 200.
  - DB: `estado=abierta, abierto_en=2026-10-12 13:42:59`.

- **Deuda cosmetica menor (backlog)**:
  - El titulo de la notif muestra `baqueano_natales` en vez de
    `Baqueano Natales`. Fix en `AndroidManifest` (`android:label`).
  - Icono cuadrado en vez de icono monocromatico. Fix con
    `ic_notification` vectorial.

- **Estado del sistema de notificaciones**:
  - S1 (modelo multi-device) OK
  - S2 (refactor push batch) OK
  - S3 (tracking entrega/apertura) OK
  - S4 (preferencias + quiet hours) OK
  - S5 (panel admin backend) OK
  - Analytics end-to-end OK (backend + Flutter)
  - Banner en foreground OK
  - S6 (panel admin Flutter) PENDIENTE
  - S7 (notificaciones in-app Flutter) PENDIENTE

- **Suite total: 364 passed, 0 warnings.**

### 2026-10-12 (cont. 14) - Pipeline de analytics cerrado end-to-end

**El ciclo enviada -> entregada -> abierta funciona completo (backend + Flutter).**

- **Backend** (commit `d3452a9`):
  - `NotificationService.enviar_a_usuario()` inyecta el `notification_log_id`
    en el payload del push FCM.
  - La app Flutter lo recibe en `message.data["notification_log_id"]`.
- **Flutter** (commit `db4a324`):
  - `FcmService` reporta la apertura al tocar la notificacion
    (`onMessageOpenedApp` para background + `getInitialMessage` para terminated).
  - POST a `/api/v1/notificaciones/{id}/abierta` (best-effort, no rompe el flujo).

- **Validado end-to-end**:
  - Worker dispara push con `notification_log_id: 98a11412-...`.
  - App Flutter lo recibe (`[FCM] foreground: ... notification_log_id: ...`).
  - `marcar_abierta` persiste: `estado=abierta, abierto_en=2026-10-12 13:15:26`.
  - Confirmado con `CHECK: estado=abierta abierto_en=...` en la DB.

- **Suite total: 364 passed, 0 warnings.**

### 2026-10-12 (cont. 13) - Panel admin de notificaciones (S5) - backend completo

**Backend del sistema de notificaciones 100% completo. Solo queda Flutter.**

- **S5 - Panel admin backend** (commit `7e81e6f`):
  - `POST /api/v1/admin/notificaciones/enviar` - envio masivo con segmentos:
    `{"tipo": "todos"}` | `{"tipo": "rol", "valor": "cliente"}` |
    `{"tipo": "usuarios", "valor": [uuid, ...]}`.
  - `GET /api/v1/admin/notificaciones` - historial con filtros
    (tipo, estado, desde, hasta) + paginacion.
  - `GET /api/v1/admin/notificaciones/stats` - dashboard con:
    total/enviadas/entregadas/abiertas/fallidas/skipped,
    delivery_rate, open_rate, por estado, por tipo, top 5.
  - El envio masivo **respeta preferencias del usuario y quiet hours**
    (los broadcasts no spamean a quien hizo opt-out).

- **Fixes de la sesion**:
  - `Field` import en `schemas.py` (crash al arrancar).
  - `conftest.py` TRUNCATE: agregadas `notification_logs`, `fcm_tokens`,
    `preferencias_notificacion` (aislamiento entre tests).

- **Suite total: 364 passed, 0 warnings** (351 + 13 nuevos).

- **Estado del sistema de notificaciones**:
  - S1 (modelo multi-device) OK
  - S2 (refactor push batch) OK
  - S3 (tracking entrega/apertura) OK
  - S4 (preferencias + quiet hours) OK
  - S5 (panel admin backend) OK
  - S6 (panel admin Flutter) PENDIENTE
  - S7 (notificaciones in-app Flutter) PENDIENTE
  - Flutter: centro de notificaciones + pantalla de preferencias PENDIENTE

- **Pendiente para sesion futura**:
  - Flutter: las 3 pantallas admin del panel (composer + historial + stats).
  - Flutter: centro de notificaciones del usuario + pantalla de preferencias.
  - Flutter: reporte de apertura al tocar notificacion push.

### 2026-10-12 (cont. 12) - Notificaciones: preferencias + tracking (S3+S4)

**Backend del sistema de notificaciones: 100% completo.**

- **S4 - Preferencias del usuario** (commit `644feae`):
  - `GET /api/v1/usuarios/me/preferencias-notificacion` (crea defaults).
  - `PUT /api/v1/usuarios/me/preferencias-notificacion` (parcial).
  - Schemas: `PreferenciaNotificacionResponse` + `PreferenciaNotificacionUpdate`.
  - Validacion de `quiet_hours_*` con regex `HH:MM`.
  - 7 tests.
- **S3 - Tracking de entrega/apertura** (misma commit):
  - Modulo nuevo `app/modules/notificaciones/`.
  - `GET /api/v1/notificaciones` (historial del usuario).
  - `POST /api/v1/notificaciones/{id}/recibida` (device confirma entrega).
  - `POST /api/v1/notificaciones/{id}/abierta` (idempotente).
  - Ownership validado (404 si notif ajena).
  - `ORDER BY creado_en DESC, id DESC` (tie-breaker estable).
  - 7 tests.
- **Fix de deuda** (commit `38840d5`): mocks de `test_push_service.py`
  actualizados al wrapper (los mocks viejos apuntaban a `app.core.push.messaging.send`,
  ahora viven en `app.core.notifications.providers.fcm`).

- **Suite total: 351 passed, 0 warnings** (337 + 14 nuevos).

- **Roadmap pendiente del sistema**:
  - S5-S6: panel admin (composer + historial + stats).
  - S7: notificaciones in-app (centro de notificaciones en la app Flutter).
  - Flutter: pantalla de preferencias (usa el endpoint ya listo).
  - Flutter: reporte de apertura desde el tap de la notificacion.

### 2026-10-12 (cont. 11) - Sistema de notificaciones nivel industria

**Base arquitectonica completa para FCM + futuros providers (APNs/SMS/email).**

- **Modulo nuevo** `app/core/notifications/` (commit `944d989`):
  - `models.py`: `FcmToken` (multi-device + limpieza automatica),
    `PreferenciaNotificacion` (opt-in/out por tipo + quiet hours),
    `NotificationLog` (historial + analytics).
  - `providers/base.py`: ABC `NotificationProvider` + `SendResult`.
  - `providers/fcm.py`: `FcmProvider` con `send` y `send_batch`
    (`send_each_for_multicast`), prioridad, TTL, collapse_key,
    analytics_label.
  - `service.py`: `NotificationService` con pipeline completo
    (preferencias -> quiet hours -> tokens -> provider -> log).
    Auto-migracion on-the-fly de tokens legacy.
    Limpieza automatica de tokens `UNREGISTERED`.
  - `push.py` refactorizado como **thin wrapper** -> worker no cambio.

- **Migracion `a8b9c0d1e2f3`**: 3 tablas + 4 enums + backfill de
  `usuarios.fcm_token` -> `fcm_tokens` (1 token migrado en prod).

- **Validado end-to-end**: `STATS: pushes: 1` + `LOG: estado=enviada`
  + notificacion recibida por el listener Flutter.

- **Roadmap pendiente**:
  - S3: analytics (tracking de apertura desde Flutter -> backend).
  - S4: endpoints de preferencias + UI Flutter.
  - S5-S6: panel admin (composer + historial + stats).
  - S7: notificaciones in-app (centro de notificaciones en la app).

### 2026-10-12 (cont. 10) - FCM frontend Flutter + validacion end-to-end

**FCM completo: backend + frontend, validado con push real en emulador.**

- **Slice Flutter (commit `861702b`)**:
  - `firebase_messaging: ^15.1.5` en `pubspec.yaml`.
  - `AndroidManifest.xml`: permiso `POST_NOTIFICATIONS` + meta-data del canal
    default `baqueano_default`.
  - `lib/core/fcm/fcm_service.dart`: servicio transversal con
    `inicializar()` (listeners foreground + background) y
    `solicitarPermisoYObtenerToken()`.
  - `lib/core/fcm/fcm_providers.dart`: provider Riverpod del servicio.
  - `auth_repository.registrarFcmToken()`: POST al backend.
  - `auth_notifier._registrarFcmAsync()`: fire-and-forget post-login y en
    restoreSession.
  - `main_client.dart`: inicializa FCM al arranque (listeners).

- **Validacion end-to-end en emulador Pixel6_API34_Play**:
  - Login Google OK -> token FCM obtenido -> POST `/usuarios/me/fcm-token`
    -> 200.
  - Worker de recordatorios disparado manualmente -> `pushes: 1`.
  - **Notificacion recibida por el listener Flutter:**
    `[FCM] foreground: title=Recordatorio de mantenimiento data={...}`

- **Herramienta nueva: AVD `Pixel6_API34_Play`**:
  - Imagen `system-images;android-34;google_apis_playstore;x86_64`.
  - **Necesario para FCM** (sin Play Store, FCM no funciona).
  - Arrancar con: `emulator -avd Pixel6_API34_Play -no-snapshot-load -gpu host`.
  - Gotcha: requiere **~5 GB libres en D:** para arrancar (el error
    `hasSufficientDiskSpace` bloquea el boot).

- **Aprendizajes**:
  - El SDK Manager CLI (`android sdk install`) tiene un bug en la version
    nueva: no descarga nada silenciosamente. **Usar Android Studio GUI**
    (SDK Manager -> SDK Platforms -> Show package details -> Google Play
    Intel x86_64 Atom System Image).
  - Los scripts ad-hoc con `AsyncSessionLocal` en un proceso Python nuevo
    necesitan importar TODOS los modelos relacionados (gotcha 4.3). El
    worker de produccion corre dentro del lifespan de FastAPI y ya los
    tiene cargados, pero un `python -c` ad-hoc falla con
    `InvalidRequestError: Mapper[...] failed to locate a name 'Prestador'`.
  - Los pushes a una app en **foreground** NO muestran banner del sistema;
    el listener `onMessage` los captura. Para banner en foreground se
    necesita `flutter_local_notifications` (nice-to-have futuro).

- **Suite backend: 337 tests verdes, 0 warnings.**
- **M4 (garantias + recordatorios + worker + FCM) cerrado 100%.**

### 2026-10-12 (cont. 9) - Backend de FCM (push notifications) completo

**Worker de recordatorios ahora manda push real. Cierra M4 al 100% (backend).**

- **Slice 1 (commit `770fbae`)** - Registro de token:
  - Columna `usuarios.fcm_token VARCHAR(500) NULL` (modelo single-device).
  - Migracion `f1a2b3c4d5e6`.
  - Endpoint `POST /api/v1/usuarios/me/fcm-token` con schema `FcmTokenUpdate`.
  - 4 tests HTTP: ok, sobreescribe, token > 500 chars (422), sin auth (401).
- **Slice 2 (commit `40af0bf`)** - Servicio de push:
  - `app/core/push.py` transversal con `enviar_push(token, ...)` y
    `enviar_push_a_usuario(user_id, ..., db=None)`.
  - El SDK de FCM (sincrono) se corre con `asyncio.to_thread` para no
    bloquear el event loop.
  - **Nunca propaga excepciones** (best-effort): devuelve True/False.
  - `FCM_ENABLED` en `Settings` para desactivar globalmente (tests, fallback).
  - 7 tests unitarios con mock de `messaging.send`.
- **Slice 3 (misma commit `40af0bf`)** - Wire en worker:
  - `worker.py` reemplaza el `# TODO M5` por `_enviar_push_recordatorio`.
  - Stats del worker ahora incluye counter `pushes`.
  - El push se manda **despues** de marcar el recordatorio como enviado
    (la marca es la fuente de verdad; si el push falla, no se re-dispara).
  - 2 tests de integracion: push ok → stats.pushes=1; push falla →
    recordatorio igual marcado enviado, stats.errores=0.

- **Cleanup de warnings** (commit `83cab05`):
  - `pytest.ini`: `cache_dir = /tmp/.pytest_cache` (elimina los 2
    PytestCacheWarning por permisos en Docker).
  - `logging.py`: migrado a `from pythonjsonlogger.json import JsonFormatter`
    con try/except para v2 (elimina el DeprecationWarning).
  - **Suite: 0 warnings.**

- **Suite total: 337 tests verdes** (328 + 7 push service + 2 worker push).
- **Pendiente de FCM:** frontend Flutter (`firebase_messaging`, permiso
  POST_NOTIFICATIONS, registrar token post-login). Proxima sesion.
- **Como deshabilitar FCM en produccion:** `FCM_ENABLED=false` en `.env` +
  recrear el container.

### 2026-10-12 (cont. 8) - Auditoria cross-modulo del patron MissingGreenlet

**El bug MissingGreenlet no era solo de oficios: 7 endpoints mas en 3 modulos.**

- **Auditoria cross-modulo** (commit `6800704`):
  - El patron `await services.crear_*/actualizar_*` seguido de
    `Model.model_validate(obj)` sin `await db.refresh(obj)` apareció en:
    - `comercios/routes.py`: `crear_comercio`, `crear_categoria` (2)
    - `prestadores/routes.py`: `crear_prestador`, `crear_categoria` (2)
    - `social/routes.py`: `crear_cuenta`, `actualizar_cuenta`,
      `actualizar_config` (3)
  - Los mas criticos: `actualizar_cuenta` y `actualizar_config` (UPDATE,
    no zafan con RETURNING).
  - Fix: `await db.refresh(obj)` defensivo en los 7. Es no-op si el
    objeto ya esta cargado, asi que no rompe nada.
- **Regla global documentada** en OPERATIVA_DEV.md 4.2: aplica a TODOS
  los modulos del proyecto.
- **Total endpoints con refresh post-service:** 14 (oficios) + 7 (otros) = **21**.
- **Suite total: 324 tests verdes** (sin cambios — el refresh es no-op
  donde no hacia falta).

### 2026-10-12 (cont. 7) - Cobertura HTTP completa de M1-M4 + cierre de sesion

**4to y ultimo archivo de tests HTTP de oficios. Cobertura M1-M4 al 100%.**

- **Test file nuevo** `backend/tests/modules/oficios/test_routes_garantias.py`
  (commit `fc2d48f`): 6 tests HTTP.
  - GET cliente (con/sin garantia).
  - **Test de integracion del wire** `cambiar_estado -> generar_garantia_automatica`
    al pasar a ENTREGADO (nada mas cubria este wire end-to-end).
  - GET/POST prestador.
  - Ownership (cliente y prestador ajenos).
- **Sin bugs nuevos** — garantias ya validaba ownership correctamente.

**Suite total del proyecto: 324 tests verdes** (era 272 al inicio de la sesion).

**Estado final de tests HTTP por modulo:**
| Modulo | Archivo | Tests |
|---|---|---|
| Recordatorios | test_routes_recordatorios.py | 5 |
| Vehiculos | test_routes_vehiculos.py | 10 |
| Ordenes | test_routes_ordenes.py | 18 |
| Turnos | test_routes_turnos.py | 13 |
| Garantias | test_routes_garantias.py | 6 |
| **Total oficios** | | **52** |

**Bugs reales encontrados en la sesion (4):**
1. `NameError: ObjetoServicio` (3 endpoints de recordatorios) - 3a5941b
2. `MissingGreenlet` en actualizar_vehiculo - 58f94a1
3. **Bug de seguridad**: 6 endpoints de ordenes sin validar owner - 238bfb8
4. `MissingGreenlet` en 4 endpoints de turnos + 10 endpoints mas con el
   mismo riesgo (auditoria) - ba1d185

**Cobertura HTTP de M1-M4 del modulo oficios: CERRADA.**
- M5 (fotos + notificaciones + reportes) queda pendiente, con su propia
  tanda de tests HTTP al cerrarse.

**Proximos pasos:**
1. Push FCM real en worker de recordatorios (hoy solo loguea).
2. M5: fotos + notificaciones in-app + reportes.

### 2026-10-12 (cont. 6) - Tests HTTP de turnos + auditoria MissingGreenlet

**3er archivo de tests HTTP de oficios. Bug real + auditoria defensiva.**

- **Test file nuevo** `backend/tests/modules/oficios/test_routes_turnos.py`
  (commit `99830a8`): 13 tests HTTP.
  - State machine (pendiente -> confirmado valido, pendiente -> completado
    invalido 409).
  - Editar/cancelar por cliente.
  - Agenda del taller.
  - Cambiar estado/rechazar por prestador.
  - Ownership en 4 endpoints.
- **Bug real** `MissingGreenlet` en 4 endpoints de turnos (commit `ba1d185`):
  - `PATCH /mis-turnos/{id}`, `POST /mis-turnos/{id}/cancelar`,
    `POST /mis-prestadores/{pid}/turnos/{id}/estado`,
    `POST /mis-prestadores/{pid}/turnos/{id}/rechazar`.
  - Causa: el service hacia `db.flush()` y despues el route handler hacia
    `TurnoResponse.model_validate(turno)` sin `await db.refresh(turno)`.
    Post-flush, `turno.updated_at` dispara IO lazy -> MissingGreenlet.
  - **Impacto en produccion**: 500 en cualquier edicion/cancelacion de turno.
- **Auditoria del patron** (misma commit): 10 endpoints mas tenian el mismo
  riesgo. Agregado `await db.refresh(obj)` en:
  - `crear_categoria_mecanica`, `actualizar_categoria_mecanica`
  - `crear_repuesto`, `actualizar_repuesto`
  - `agregar_item`, `actualizar_item`
  - `crear_turno`
  - `actualizar_garantia`, `crear_garantia`
  - `crear_recordatorio`
- **Patron seguro confirmado:** los endpoints de ordenes que ya usan
  `orden = await services.obtener_orden(db, orden.id)` despues de cada
  mutacion estan bien (porque `obtener_orden` usa `selectinload` +
  `populate_existing`).

- **Suite total: 318 tests verdes** (305 + 13).
- **3 archivos de tests HTTP agregados hoy**, **4 bugs reales encontrados**:
  1. `NameError: ObjetoServicio` (recordatorios) - 3a5941b
  2. `MissingGreenlet` en actualizar_vehiculo - 58f94a1
  3. Bug de seguridad: 6 endpoints de ordenes sin validar owner - 238bfb8
  4. `MissingGreenlet` en 4 endpoints de turnos + 10 endpoints mas con el
     mismo riesgo - ba1d185

### 2026-10-12 (cont. 5) - BUG DE SEGURIDAD en endpoints de ordenes + tests HTTP

**Hallazgo critico: bug de autorizacion en 6 endpoints de ordenes.**

- **Test file nuevo** `backend/tests/modules/oficios/test_routes_ordenes.py`
  (commit `fa0df3d`):
  - 18 tests HTTP: state machine (transiciones validas/invalidas), aprobacion
    total/parcial/rechazo, historial, ownership en los 6 endpoints del router
    de prestador.
- **Bug CRITICO de autorizacion** (commit `238bfb8`):
  - Los 6 endpoints de `/mis-prestadores/{pid}/ordenes` (detalle, actualizar,
    agregar_item, editar_item, eliminar_item, cambiar_estado) validaban que
    `orden.prestador_id == prestador_id` pero **NO que el usuario fuera dueno
    del prestador**.
  - Cualquier usuario autenticado podia cambiar el estado de cualquier orden
    conociendo los IDs (cambiar a entregado, agregar items, etc).
  - Fix: llamar `_validar_prestador_del_usuario` (que ya existia) al inicio
    de los 6 endpoints. Devuelve 403 si no es dueno ni admin.
  - **Impacto en produccion**: alto. Bug de seguridad real.
- **Test file nuevo** `backend/tests/modules/oficios/test_routes_vehiculos.py`
  (commit `dbeb062`): 10 tests HTTP.
- **Bug real** `MissingGreenlet` en `actualizar_vehiculo` (commit `58f94a1`):
  - `services.actualizar_vehiculo` hacia `db.flush()` y despues
    `_vehiculo_a_response(obj, veh)`, que accede a `obj.updated_at`. Post-flush
    el objeto queda expirado -> acceso lazy dispara IO sincronico ->
    `MissingGreenlet`.
  - Fix: `await db.refresh(obj)` + `await db.refresh(veh)` antes de serializar.
  - **Impacto en produccion**: PATCH /mis-vehiculos fallaba con 500.

- **Suite total: 305 tests verdes** (272 + 5 + 10 + 18).
- **Leccion**: los smoke tests visuales NO detectan bugs de autorizacion ni
  errores de serializacion. Los tests HTTP los detectaron en el primer intento.
  Los 3 archivos de tests HTTP agregados hoy encontraron **3 bugs reales**
  (2 de produccion + 1 de seguridad).

- **Aprendizajes operativos**:
  - Bloque `$py | ssh python3 -` con contenido largo puede fallar
    silenciosamente. Verificar SIEMPRE con `grep -c`. Ya documentado en
    OPERATIVA_DEV.md 3.7.
  - Los tests HTTP con `ASGITransport` requieren override de `get_db`
    ademas de `get_current_user`. Ya documentado en OPERATIVA_DEV.md 4.3.
  - **Nuevo**: en oficios, `ObjetoServicio` es base y `Vehiculo` extiende.
    Los services que devuelven "vehiculo completo" esperan ambos. Usar
    fixture `vehiculo_test` (crea ambos), no `objeto_servicio_test`.
  - **Nuevo**: SQLAlchemy post-flush deja objetos expirados. Antes de
    serializar con acceso a `updated_at`/`created_at`, hacer
    `await db.refresh(obj)` o usar `populate_existing`.

### 2026-10-12 (cont. 4) - Tests HTTP de oficios + suite 277 + aprendizajes

**Paso B: cerrado el gap que dejo pasar el bug ObjetoServicio.**

- **Test file nuevo** `backend/tests/modules/oficios/test_routes_recordatorios.py`
  (commit `368b11e`):
  - 5 tests HTTP que ejercitan los endpoints de recordatorios (GET vacio,
    GET con enviados, POST km, POST validacion, POST objeto ajeno).
  - Override de `get_current_user` Y `get_db` para compartir la sesion async
    del fixture (sin esto: `RuntimeError: Event loop is closed`).
  - **Hubieran detectado el bug `3a5941b`** al primer request.
- **Suite total: 277 tests verdes** (272 previos + 5 nuevos).
- **Aprendizajes de la sesion**:
  - Los tests HTTP con `ASGITransport` requieren override de `get_db`
    ademas de `get_current_user`. Documentado en `OPERATIVA_DEV.md` 4.3.
  - El patron `$py | ssh python3 -` con bloques largos puede fallar
    **silenciosamente** (el archivo no cambia y no hay error). Verificar
    SIEMPRE con `grep -c`. Documentado en `OPERATIVA_DEV.md` 3.7.
  - `docker compose up -d backend` no recrea el container si el hash no
    cambio -> usar `restart`. Documentado en `SERVER_CHEATSHEET.md` 16.
  - `touch app/main.py` no siempre dispara hot reload de uvicorn.
    Documentado en `SERVER_CHEATSHEET.md` 17.
  - Editar archivos con acentos/emojis: **NO** usar Python via stdin en
    Windows (rompe encoding). Usar `[System.IO.File]::WriteAllText` a un
    temporal. Documentado en `SERVER_CHEATSHEET.md` 18.

### 2026-10-11 (cont.) - Etapa 9b: Publicar afiches SVG end-to-end
- Backend completo para generar PNG + publicar afiches en redes:
  - svg_service.svg_a_png() via cairosvg (libs de sistema: libcairo2, libpango)
  - services.publicar_afiche() + _guardar_png() en /app/media/promociones/
  - Endpoints nuevos: POST /generar-png (image/png) y POST /publicar (201)
  - Nginx dev-api.conf: location /media/ (Meta descarga PNG por HTTPS)
  - Dockerfile: agregadas libcairo2-dev, libpango1.0-dev, libgdk-pixbuf (builder + runtime)
  - cairosvg==2.7.1 en requirements
- Frontend Flutter:
  - 3 botones en el editor: Descargar / Compartir / Publicar en redes
  - Modal de publicacion: checkboxes por red + caption editable
  - Deps: path_provider + share_plus
- Smoke test end-to-end en produccion:
  - Generar afiche -> PNG accesible por HTTPS publico
  - POST /publicar -> 201 -> worker publico en Facebook
- RESUELTO (2026-10-11): share_plus upgraded a 13.3.1 (ver changelog arriba).

### 2026-10-12 (cont. 2) - M4 worker de recordatorios (APScheduler) + M4 backend 100%

**M4 backend completo: garantias + recordatorios + worker automatico.**

- **Worker in-process** (`oficios/worker.py`) con APScheduler (mismo patron
  que el social worker):
  - Revisa la tabla `recordatorios` cada 1 hora (configurable).
  - Evalua condiciones:
    - **KM**: compara `Vehiculo.kilometraje_actual` >= `km_umbral` (solo vehiculos).
    - **FECHA**: compara `date.today()` >= `fecha`.
    - **EVENTO**: siempre se envia (el evento lo dispara el sistema).
  - Marca enviados los que cumplen; deja pendientes los que no.
  - Nunca crashea el scheduler: cada error se loggea y aisla.
- **2 settings nuevas** en `config.py`:
  - `RECORDATORIOS_WORKER_ENABLED: bool = True`
  - `RECORDATORIOS_WORKER_INTERVAL_SEC: int = 3600`
- **Wire en `main.py` lifespan**: arranca/detiene junto al worker social.
- **Test manual end-to-end validado**: 4 escenarios (KM sobre/bajo umbral,
  fecha pasada/futura) -> 2 ENVIADOS + 2 PENDIENTES, sin errores.
- **Commit** `822e145`.

**Estado final del modulo oficios:**
- M1 (objetos_servicio + vehiculos): ✅ COMPLETA (backend + frontend + tests)
- M2 (ordenes + state machine): ✅ COMPLETA (backend + frontend + tests)
- M3 (turnos + agenda): ✅ COMPLETA (backend + frontend + tests)
- M4 (garantias + recordatorios + worker): ✅ **Backend completo** — frontend pendiente
- M5 (fotos + notificaciones + reportes): ⏳

**Pendiente para proxima sesion:**
1. Frontend de M4 (garantias + recordatorios): ~4 pantallas + integraciones.
2. Notificaciones push (FCM) para el worker de recordatorios (hoy solo loggea).
3. Smoke test visual completo de M3 (reservar turno -> confirmar -> completar)
   en emulador.
4. M5 del roadmap: fotos + notificaciones + reportes.
### 2026-10-12 (cont.) - Modulo oficios Fase M4 backend (garantias + recordatorios)

**Backend M4 completo. Total oficios: 131 tests verdes.**

- **Tabla `garantias`**: tipo (mano_obra/repuesto/completo), duracion_dias,
  fecha_inicio/fin, cobertura, condiciones. Asociada a orden entregada.
- **Tabla `recordatorios`**: tipo (km/fecha/evento), condicion JSONB, mensaje,
  enviado, fecha_envio. Asociada a objeto_servicio (vehiculo).
- **Auto-generacion de garantia al entregar orden**: wired en
  `services.cambiar_estado()`. Cuando la orden pasa a ENTREGADO, se genera
  automaticamente una garantia COMPLETO de 30 dias. Idempotente (si ya existe,
  la retorna). Configurable a futuro (por categoria de servicio).
- **6 services de garantias**: crear, obtener por orden (activa), actualizar
  (con recalculo de fecha_fin), generar_garantia_automatica (idempotente).
- **6 services de recordatorios**: crear, listar por objeto, eliminar (soft),
  marcar como enviado, buscar pendientes (para worker), crear batch.
- **Endpoints (~9 nuevos)**:
  - Cliente: `GET /mis-ordenes/{id}/garantia`,
    CRUD `/mis-vehiculos/{oid}/recordatorios` (listar, crear, actualizar,
    eliminar).
  - Prestador: `GET /mis-prestadores/{id}/ordenes/{oid}/garantia`,
    `POST .../garantia` (crear/actualizar garantia manual).
- **Migracion** `de89315a2610`.
- **12 tests nuevos** (`test_services_garantias.py`): auto-generacion,
  idempotencia, 409 en no-entregada, actualizacion con recalculo, CRUD
  recordatorios, busqueda de pendientes.
- **Pendiente M4**: worker APScheduler que revisa recordatorios cada X horas
  y los envia (no implementado aun), frontend de garantias + recordatorios.

**Roadmap del modulo oficios:**
- M1 (objetos_servicio + vehiculos): ✅ COMPLETA
- M2 (ordenes + state machine): ✅ COMPLETA
- M3 (turnos + agenda): ✅ COMPLETA
- M4 (garantias + recordatorios): ✅ Backend completo — worker + frontend pendientes
- M5 (fotos + notificaciones + reportes): ⏳

**Commits recientes:**
- `6a2b7eb` feat(oficios): M4 backend - garantias + recordatorios
- `b4288cf` test: conftest actualizado con turnos + garantias + recordatorios
### 2026-10-12 - Modulo oficios Fases M3 (turnos) + mejora UX formulario de ordenes

**Estado del modulo oficios: M1 + M2 + M3 completas (backend + frontend + tests).**

- **Mejora UX formulario crear orden** (commit `57e0d5d` + `88de440`):
  - Backend: 2 endpoints nuevos (`GET /mis-prestadores/{id}/clientes?q=...`
    para buscar clientes, `GET .../clientes/{cid}/vehiculos` para listar
    vehiculos del cliente). Service `buscar_clientes` (busca por email,
    nombre o apellido con min 2 chars) + `listar_vehiculos_de_cliente`.
  - Frontend: `FormularioOrdenScreen` reescrito. Ya NO pide UUIDs manuales.
    Ahora tiene buscador de cliente con debounce 400ms + dropdown de
    resultados + chip del cliente + selector de vehiculo del cliente.
  - 8 tests nuevos en `test_services_busqueda.py`.

- **Fase M3 backend - turnos + agenda** (commit `13b7d8f`):
  - Tabla `turnos`: cliente + prestador + objeto_servicio + fecha_inicio +
    duracion_min + motivo + notas + orden_id (opcional para vincular).
  - State machine de 7 estados: `pendiente -> confirmado -> en_curso ->
    completado`. Ramas: `pendiente -> rechazado`, `pendiente|confirmado ->
    cancelado`, `confirmado -> no_asistio`.
  - Transiciones por rol (prestador mueve operativos, cliente cancela).
  - 9 services: crear_turno, listar_turnos_cliente/prestador, obtener_turno,
    actualizar_turno, cambiar_estado_turno, rechazar_turno, cancelar_turno,
    vincular_orden_a_turno.
  - 10 endpoints: 5 cliente (`/mis-turnos` CRUD + cancelar) + 5 prestador
    (`/mis-prestadores/{id}/turnos` listar/detalle/estado/rechazar/vincular).
  - Migracion `3fa886c2e6d7`.
  - 34 tests nuevos: state machine (19) + services (15).

- **Fase M3 frontend** (commit `b7053ef`):
  - Domain: `Turno` + `EstadoTurno` enum (7 valores con colorHex).
  - Repository: 8 metodos M3 (4 cliente, 4 prestador + vincular).
  - Providers: 4 providers family con params inmutables.
  - 5 pantallas nuevas:
    - `MisTurnosScreen` (cliente): lista con filtros por estado.
    - `DetalleMiTurnoScreen` (cliente): detalle + cancelar con motivo.
    - `AgendaTallerScreen` (prestador): agenda con filtros.
    - `DetalleTurnoTallerScreen` (prestador): acciones contextuales segun
      estado (confirmar / rechazar / en_curso / completar / no_asistio).
    - `ReservarTurnoScreen` (cliente): selector de vehiculo + date picker +
      time picker + duracion configurable + motivo + notas.
  - Router: 5 rutas nuevas.
  - Home: card "Mis turnos" en Mi actividad.
  - Detalle publico del prestador: boton "Reservar turno" (CTA principal).
  - Detalle mi prestador: boton "Agenda del taller".

- **Estado del proyecto**:
  - Suite de tests del backend: **218 + 34 = 252 tests verdes** aproximadamente.
  - `flutter analyze`: limpio en cada paso.
  - Builds OK.

**Roadmap del modulo oficios:**
- M1 (objetos_servicio + vehiculos): ✅ COMPLETA
- M2 (ordenes + state machine): ✅ COMPLETA
- M3 (turnos + agenda): ✅ COMPLETA
- M4 (garantias + recordatorios + worker): ⏳ proxima
- M5 (fotos + notificaciones + reportes): ⏳
### 2026-10-11 (cont. 10) - Modulo oficios: tests automatizados M1+M2 (77 tests) + fix populate_existing

**Deuda tecnica cerrada. Suite completa del proyecto: 218 tests verdes.**

- **Bug critico encontrado por tests en `services.obtener_orden`**:
  - Sintoma: `aprobar_presupuesto` veia `orden.items = []` aunque hubiera items en la DB -> el
    cliente que aprobaba todos los items terminaba viendo la orden como RECHAZADA.
  - Causa: SQLAlchemy identity map devolvia la instancia cacheada sin refrescar la relacion
    `items` (los `selectinload` no aplican sobre objetos ya cargados en la sesion).
  - Fix: `.execution_options(populate_existing=True)` en el statement (SQLAlchemy 2.0).
    Fuerza refresco de la instancia desde la DB (y re-aplica los selectinload).
  - Impacto: **bug en produccion** — los tests lo detectaron antes que un cliente real.
- **Suite de tests nueva (77 tests)** en `backend/tests/modules/oficios/`:
  - `test_state_machine.py` (26): transiciones validas/invalidas por rol + completitud.
  - `test_schemas.py` (11): validaciones Pydantic (rangos, requeridos, defaults).
  - `test_models.py` (11): enums + creacion + relaciones ORM.
  - `test_services_vehiculos.py` (10): CRUD completo + patente unica + permisos (403).
  - `test_services_ordenes.py` (19): crear orden + items + cambiar estado + aprobar/rechazar
    + workflow end-to-end completo (crear -> items -> presupuestar -> aprobar -> ejecutar).
- **`conftest.py` raiz actualizado**: import de oficios + TRUNCATE de las 7 tablas de oficios.
- **`conftest.py` de oficios** con fixtures: `usuario_cliente`, `categoria_oficio`,
  `prestador_test`, `objeto_servicio_test`, `vehiculo_test`, `categoria_mecanica`.
- **`test_promocion.py` actualizado**: pasa a esperar 6 plantillas (agrega `lanzamiento`).
- **Suite completa del proyecto**: 218 passed en 86s (antes: 141).
- **Commits**: `c8bcc01` + `e313f0f` (rebased).

**Estado del modulo oficios:**
- M1 backend + frontend + tests ✅
- M2 backend + frontend + tests ✅
- Suite de tests: 77 tests propios + integracion con la suite global.
### 2026-10-11 (cont. 9) - Modulo oficios Fase M2 frontend completa (pantallas de ordenes)

**Frontend Flutter del ciclo completo de ordenes. M2 cerrada end-to-end.**

- **Domain (3 archivos nuevos)**:
  - `orden_trabajo.dart`: clase `OrdenTrabajo` con `EstadoOrden` (10 estados
    con `colorHex` por estado) y `PrioridadOrden` (4 niveles con color).
  - `orden_item.dart`: `OrdenItem` con `TipoItemOrden` (servicio, repuesto,
    mano_obra, otro). Estado `aprobado` nullable (pendiente/aprobado/rechazado).
  - `orden_historial.dart`: `OrdenHistorialEvento` con `TipoEventoHistorial`
    (7 tipos). Getters `descripcion` y helpers de formato.
- **Data extendida**:
  - `oficios_repository.dart`: +9 metodos M2 (listarOrdenesPrestador,
    crearOrden, detalleOrdenPrestador, agregarItem, eliminarItem,
    cambiarEstado, listarMisOrdenes, detalleMiOrden, aprobarPresupuesto).
  - `oficios_providers.dart`: +4 providers family (`ordenesPrestadorProvider`,
    `ordenPrestadorDetalleProvider`, `misOrdenesProvider`, `miOrdenDetalleProvider`)
    con params inmutables (`==`/`hashCode` para cache correcto).
- **5 pantallas nuevas**:
  - `MisOrdenesScreen` (cliente): lista con filtros por estado + badges.
  - `DetalleMiOrdenScreen` (cliente): items con **checkbox para aprobacion
    parcial**, timeline del historial, boton "Enviar respuesta".
  - `OrdenesTallerScreen` (prestador): lista con filtros + FAB "Nueva orden".
  - `DetalleOrdenTallerScreen` (prestador): editor de items (modal bottom
    sheet), acciones de cambio de estado contextuales (segun el estado actual),
    timeline, overlay de carga durante operaciones.
  - `FormularioOrdenScreen` (prestador): MVP con inputs manuales de UUIDs
    (busqueda de clientes/vehiculos es mejora futura).
- **Router**: +5 rutas (`/mis-ordenes`, `/mis-ordenes/:id`,
  `/mis-prestadores/:id/ordenes`, `/ordenes/nueva`, `/ordenes/:oid`).
- **Home**: card "Mis ordenes" en "Mi actividad" (icono recibo).
- **Detalle prestador**: boton "Ordenes del taller" junto a "Publicaciones".
- **Validado en emulador Android 14**:
  - Card "Mis ordenes" visible y navegable.
  - Pantalla de ordenes carga con empty state + filtros.
  - Formulario de nueva orden carga con todos los campos.
  - Filtros por estado disparan queries correctas (`?estado=...`).
  - Validacion del backend responde 422 en UUIDs invalidos (correcto).
- **`flutter analyze`**: No issues found.
- **Build apk client**: OK.
- **Commits**: `296a0f1` (M2 frontend).

**Deuda tecnica pendiente para M2:**
- Tests automatizados de oficios (pytest) — no existen aun.
- Formulario de nueva orden: reemplazar UUIDs manuales por busqueda.
- Notificaciones in-app cuando el cliente aprueba.
### 2026-10-11 (cont. 8) - Modulo oficios Fase M2 backend completa (ordenes de trabajo)

**Corazon del MVP de mecanica: ciclo completo de orden con state machine.**

- **3 tablas nuevas** (migracion `8597373be79b`):
  - `ordenes_trabajo`: numero OT-YYYY-NNNN, 10 estados, prioridad, cliente,
    prestador, objeto_servicio, totales, fechas, notas internas/cliente.
  - `orden_items`: items del presupuesto (servicio, repuesto, mano_obra, otro)
    con aprobacion por item individual (None=pendiente, True/False=decision).
  - `orden_historial`: timeline **append-only** con estado_anterior/nuevo,
    usuario_id y contenido JSONB. Fuente de verdad del ciclo de vida.
- **State machine de 10 estados**:
  `ingresado -> diagnosticando -> presupuestado -> aprobado -> en_proceso
   -> listo -> entregado -> garantia`.
  Ramas: `presupuestado -> rechazado`, cualquier estado inicial `-> cancelado`.
  Validacion por rol (prestador vs cliente) con retorno 409 en transicion invalida.
- **Numeracion automatica** de ordenes con formato `OT-2026-0001`.
- **Presupuesto con aprobacion parcial**: el cliente puede aprobar/rechazar
  items individualmente. Si aprueba todos -> estado `aprobado`. Si aprueba
  parcial -> sigue en `presupuestado`. Si rechaza todos -> `rechazado`.
- **Eventos registrados en `orden_historial`** para cada cambio de estado,
  aprobacion, rechazo. Con `usuario_id` y `contenido` (motivo, total, etc.).
- **Fix critico `MissingGreenlet`**: en endpoints que devuelven `OrdenTrabajo`
  serializada se recarga con `selectinload(items, historial)` antes de responder.
  Los listados tambien usan `selectinload(items)` en la query.
- **~20 endpoints nuevos**:
  - Prestador: `GET/POST /mis-prestadores/{id}/ordenes`,
    `GET/PATCH /mis-prestadores/{id}/ordenes/{oid}`,
    `POST/PATCH/DELETE .../items`, `POST .../estado`.
  - Cliente: `GET /mis-ordenes`, `GET /mis-ordenes/{id}`,
    `POST /mis-ordenes/{id}/aprobar`.
- **Validado end-to-end: 10/10 tests HTTP**:
  - Crear orden -> numero OT-2026-0001 en estado `ingresado`.
  - Agregar 3 items -> total $295.000.
  - Transiciones: `ingresado -> diagnosticando -> presupuestado`.
  - Aprobacion parcial (2/3 items) -> total aprobado $260.000, estado sigue
    en `presupuestado`.
  - Aprobacion total -> estado `aprobado`.
  - Ejecucion: `aprobado -> en_proceso -> listo -> entregado`.
  - Historial: 8 eventos registrados en orden correcto.
  - Transicion invalida `entregado -> ingresado` -> **409**.
  - Listados de taller + cliente funcionando.
- **Pendiente**: frontend Flutter de M2 (pantallas de ordenes).
- **Commits**: `a93904c` (M1 backend), `da1923d` (M1 frontend),
  `f17119a`/`280f136` (M2 backend).
### 2026-10-11 (cont. 7) - Modulo oficios Fase M1 completa (backend + frontend)

**Arranque del MVP de mecanica con arquitectura reutilizable al resto de oficios.**

- **Diseno fundacional** (`docs/oficios/DISENO.md`, 311 lineas):
  - Arquitectura en 2 capas: CORE (aplica a TODOS los oficios) + VERTICAL (mecanica).
  - `objetos_servicio` como punto de extension polimorfico (vehiculo, propiedad, jardin).
  - 13 tablas disenadas, ~45 endpoints, state machine de 10 estados, 7 flujos, 6 ADRs.
  - 80% del codigo reutilizable. Agregar gasfiteria = ~2 sesiones.
- **Fase M1 backend** (commit `a93904c`):
  - 4 tablas nuevas: `objetos_servicio`, `vehiculos`, `mecanica_categorias_servicio`,
    `mecanica_repuestos`.
  - Migracion `4db12ad04733` aplicada (Alembic autogenerate limpio).
  - 6 archivos: models, schemas, services, deps, routes, seed.
  - 4 routers nuevos: publico (categorias/repuestos), propietario (mis-vehiculos CRUD),
    admin categorias, admin repuestos.
  - 11 categorias mecanica seedeadas (Mantenimiento, Frenos, Motor, etc.).
  - 10/10 tests HTTP end-to-end verdes.
- **Fase M1 frontend** (commit `da1923d`):
  - Feature `oficios/` en Flutter: domain (Vehiculo + MecanicaCategoria),
    data (OficiosRepository + providers Riverpod 3), presentation (2 pantallas).
  - Pantalla "Mis vehiculos" (lista + empty state + refresh + delete).
  - Formulario crear/editar vehiculo con validaciones.
  - Card "Mis vehiculos" en el Home cliente.
  - 3 rutas: `/mis-vehiculos`, `/mis-vehiculos/nuevo`, `/mis-vehiculos/:id/editar`.
  - Validado end-to-end en emulador Android 14: POST/GET/PATCH/DELETE funcionando.
  - `flutter analyze` limpio + build apk client OK.
- **Estado del roadmap del modulo oficios**:
  - M1: objetos_servicio + vehiculos + CRUD ✅ COMPLETA
  - M2: ordenes_trabajo + items + presupuesto + state machine (proxima)
  - M3: turnos + agenda
  - M4: garantias + recordatorios + worker
  - M5: fotos + notificaciones + reportes
### 2026-10-11 (cont. 6) - Riverpod 3.4.3 (deuda tecnica #7 cerrada)
- **Migracion completa a Riverpod 3.4.3** (estaba en 2.6.1).
  Estrategia en 2 fases para cero downtime:
  - **Fase 1 (compatible con v2)**: migrar los 4 `StateNotifierProvider` a
    `NotifierProvider` (API moderna disponible desde Riverpod 2):
    - `auth_notifier.dart`: `AuthNotifier extends Notifier<AuthState>` con
      `build()` y `late final _repository = ref.read(...)`.
    - `comercio_providers.dart`: `ComerciosFiltrosNotifier`.
    - `prestador_providers.dart`: `PrestadoresFiltrosNotifier`.
    - `promocion_providers.dart`: `EditorAficheNotifier`.
  - **Fase 2**: bump `flutter_riverpod ^2.6.1 -> ^3.0.0` (resolvio 3.4.3).
    Dependencias: `flutter_riverpod 3.4.3`, `riverpod 3.4.3`, `+listen 1.0.1`.
- **Cero breaking changes en el codigo**: la migracion previa de providers dejo
  el proyecto sin deuda de API (`flutter analyze` = No issues found).
- **Validado end-to-end en emulador Android 14**: home admin, afiches (preview
  SVG con gradientes), filtros de prestadores y comercios, logout + re-login
  con Google -> todo OK.
- Beneficios habilitados para el futuro: reintento automatico de providers,
  persistencia offline (experimental), mutaciones (experimental).
- Sin cambios necesarios por auto-pause de `ref.watch` ni `UnmountedRefException`
  en los flujos actuales.
### 2026-10-11 (cont. 5) - Cloudflare Origin Certificate + SSL Full (Strict) + Cloudflare Global Key decisión
- **Deuda tecnica #3 resuelta**: SSL del server ahora usa Cloudflare Origin Certificate
  (reemplaza self-signed). Cloudflare SSL mode cambiado de `Full` a **`Full (strict)`**.
  Cloudflare ahora valida criptograficamente el cert del origen -> elimina riesgo MITM
  entre Cloudflare y el server.
  - Cert generado en Cloudflare (wildcard `*.baqueanonatales.com`, RSA 2048, 15 anos).
  - Instalado en `~/baqueano-natales/deploy/nginx/certs/origin.crt` + `origin.key` (600).
  - `deploy/nginx/conf.d/dev-api.conf` actualizado (rutas + comentario).
  - Certs viejos (`dev-api.crt/key`) y `authenticated_origin_pull_ca.pem` eliminados.
  - Health check HTTPS post-migracion: 200 OK.
- **Cloudflare Global API Key: DECISION CONSCIENTE (no es deuda tecnica)**.
  Se mantiene a proposito en el server para poder operar CUALQUIER proyecto/dominio
  de la cuenta desde este server sin crear/rotar tokens individuales. Reglas:
  nunca commitear ni pegar en chats/logs, permisos 600, rotar si se filtra.
  Documentado en `CONTEXTO_PROYECTO.md` (seccion nueva "Credenciales del server")
  y en `SERVER_CHEATSHEET.md`.
- **Gotcha nuevo documentado (cheatsheet #15)**: `Set-Content` de PowerShell 5.1
  escribe en Windows-1252 y rompe emojis/acentos al editar `.md`. Usar
  `[System.IO.File]::WriteAllText($path, $text, (New-Object System.Text.UTF8Encoding($false)))`.
### 2026-10-11 (cont. 4) - Flutter deps upgrade: secure_storage v11 + share_plus v13 + plantilla lanzamiento
- **Deuda tecnica #1 resuelta**: conflicto `win32` entre `flutter_secure_storage` y `share_plus`.
  Ahora ambos usan `win32 ^6.4.0`. Warning KGP de `share_plus` eliminado de paso.
- **`share_plus` 10.1.4 -> 13.3.1**:
  - Migracion de API: `Share.shareXFiles` -> `SharePlus.instance.share(ShareParams(...))`
    en las 2 llamadas del editor de promociones (descargar PNG + compartir PNG).
  - Se paso por 11.1.0 intermedio por conflicto con secure_storage 9.x.
- **`flutter_secure_storage` 9.2.2 -> 11.2.0**:
  - Migracion en 2 fases (9 -> 10.3.4 -> 11.2.0) para preservar los datos.
  - v10 migra el cifrado automaticamente; el log confirma:
    `Migration complete: 3 items migrated from EncryptedSharedPreferences to custom cipher storage`.
  - v11 elimina `encryptedSharedPreferences` de AndroidOptions (ya removido).
  - **JWT preservado sin re-login** (verificado: `auth/me 200` directo).
- **Plantilla `lanzamiento` nueva** en modulo promocion:
  - Backend: `render_lanzamiento` con hero diagonal (verde -> morado) + caja info
    con gradiente horizontal (verde claro -> blanco). Usa `svg_service.gradiente_linear`
    (helper que estaba sin uso).
  - Frontend: case visual en la galeria (icono cohete, fondo morado).
  - Validado end-to-end en emulador Android 14: SVG 3193 chars, PNG 200KB,
    cero warnings de flutter_svg.
- **Warning `<defs/>` flutter_svg**: descartado. No aplicaba - ninguna plantilla
  emitia `<defs>` antes. La nueva `lanzamiento` si lo hace, y **flutter_svg lo renderiza
  sin warnings** siempre que `<defs>` vaya antes de las formas.
- 5 commits nuevos en `origin/main` (116ac45 -> 1cd9036). Working tree limpio.
### 2026-10-11 - Modulo promocion Etapa 9: generador de afiches SVG (completo)
- Modulo backend/app/modules/promocion/ completo:
  - brand_kit.py: paleta Baqueano, fuentes web-safe, baseline grid, 5 tamanos industria
  - svg_service.py: helpers puros (canvas, texto, formas, gradientes). svgwrite escapa XML
  - templates.py: 5 plantillas ricas (nuevo_servicio, oferta, destacado, evento, profesional)
  - services.py: validacion anti-abuso (30 params, 2000 chars, 200KB SVG)
  - routes.py: 3 endpoints admin (plantillas, generar JSON, generar-svg directo)
  - 16 tests - 140 verdes totales
- Frontend Flutter (flavor admin):
  - domain/afiche.dart: modelos + TamanoAfiche enum
  - data/promocion_repository.dart + providers con editor state
  - Galeria: grid de 5 plantillas con preview visual
  - Editor con preview SVG en vivo (flutter_svg), debounce 400ms
  - Card nueva en AdminHome + 2 rutas (/admin/promocion + /editor/:id)
  - flutter_svg 2.3.0 agregado
- Etapa 9 completa. Modulo social cerrado: 9/9 etapas

### 2026-10-11 - Modulo social Etapa 8: Google Business Profile (codigo listo, gateado)
- Backend completo para publicar en GBP, esperando aprobacion de la API de Google:
  - google_business_service.py: cliente REST con httpx (sin SDK de Google).
    publicar_post_en_gbp() respeta el feature flag GOOGLE_BUSINESS_ENABLED.
  - 5 vars en Settings: GOOGLE_BUSINESS_ENABLED (default false), ACCOUNT_NAME,
    CLIENT_ID, CLIENT_SECRET, API_VERSION
  - services.obtener_google_business_ids_de_cuenta: resuelve account_name +
    location_id desde metadata_extra (cache) o fallback a settings
  - worker dispatch: GOOGLE_BUSINESS -> _publicar_en_google()
  - eventos_prestadores: al aprobar prestador o agregar servicio, encola
    tambien GBP si config.publicar_en_google=true
  - 10 tests nuevos (8 google_business_service + 2 worker) - 124 verdes totales
- Cuando Google apruebe la API, activar es solo:
  1. GOOGLE_BUSINESS_ENABLED=true en .env
  2. Cargar credenciales OAuth + account_name + location_id
  3. ConfigSocial.publicar_en_google=true en la DB

### 2026-10-11 - Modulo social Etapa 7: frontend propietario + endpoint reencolar
- Backend:
  - services.reencolar_publicacion: resetea estado a PENDIENTE, limpia
    intentos + error. Rechaza (409) si esta en PUBLICANDO.
  - PATCH /admin/social/publicaciones/{id}/reencolar
  - services.listar_publicaciones_de_prestador: publicaciones del prestador
    + publicaciones de sus servicios
  - GET /api/v1/mis-prestadores/{id}/publicaciones (dueno o admin)
- Frontend Flutter:
  - Boton Reencolar en las cards de la cola (solo estados fallado/agotado)
  - Pantalla MisPublicacionesScreen (read-only, vista del dueno)
  - Boton 'Publicaciones en redes' en DetalleMiPrestadorScreen
  - Ruta /mis-prestadores/:id/publicaciones
- 5 archivos backend + 5 archivos Flutter modificados/creados

### 2026-10-10 (cont. 7) - Frontend admin del modulo social (Etapa 6)
- 3 pantallas nuevas en el flavor admin (Flutter):
  - Redes sociales: lista cuentas conectadas (FB + IG) con badges por red,
    propietario, activa/manual
  - Configuracion: toggles auto-publish + FB/IG, radios de destino,
    boton "Procesar cola ahora"
  - Cola de publicaciones: filtros por estado + red, cards con preview,
    intentos, error, proximo intento, empty state
- Feature completa en Flutter:
  - domain/cuenta_social.dart + domain/publicacion_social.dart
  - data/social_repository.dart (listarCuentas, obtenerConfig,
    actualizarConfig, listarPublicaciones, procesarColaAhora)
  - data/social_providers.dart (5 providers)
  - 3 screens en presentation/screens/
- AdminHome: 3 cards nuevas (Redes sociales, Configuracion, Cola)
- 3 rutas nuevas: /admin/social/cuentas, /admin/social/config,
  /admin/social/publicaciones
- 7 archivos nuevos/modificados en Flutter (1800+ lineas)
- Backend fix: endpoint GET /publicaciones ignoraba query param red.
  Se agrego red: Red | None en routes + services (5 lineas)
- Verificado en emulador Android 14 end-to-end: filtros funcionando con
  los 3 posts reales de los smoke tests previos

### 2026-10-10 (cont. 6) - Modulo social Etapa 5: integracion con prestadores
- eventos_prestadores.py: al aprobar prestador o agregar servicio, encola
  publicaciones en FB + IG automaticamente:
  - encolar_prestador_nuevo(db, prestador)
  - encolar_servicio_nuevo(db, prestador, servicio)
- Respeta config_social: auto_publish + publicar_en_facebook/instagram
- Best-effort: nunca rompe el flujo del caller
- IG skip si no hay imagen (requisito Meta)
- Solo publica en la cuenta central de Baqueano
- config.py: PUBLIC_WEB_URL para links de los posts
- prestadores/routes.py: wire en admin_verificar_prestador + agregar_servicio
- 7 tests nuevos - 114 verdes totales
- Smoke test end-to-end: "Taller Mecanico del Sur" (sin fotos) -> pub FB ok

### 2026-10-10 (cont. 5) - Modulo social Etapa 4: Instagram via Facebook
- instagram_service.py: publicar_post_en_instagram con flujo de 2 pasos:
  - POST /{ig-user-id}/media (crear container)
  - POST /{ig-user-id}/media_publish (publicar)
  - Reintentos cortos (2s/4s/8s) para container asincronico
- services.obtener_instagram_id_de_cuenta: busca IG ID en metadata_extra
  (cache), si no esta lo consulta a Meta y lo guarda
- worker: dispatch por red (FACEBOOK | INSTAGRAM)
  - _publicar_en_instagram exige image_url (IG no acepta solo texto)
- 9 tests nuevos (7 instagram_service + 2 worker) - 107 verdes totales
- Smoke test end-to-end: post real publicado en @baqueanonatales
  (external_post_id=18131824649504757)

### 2026-10-10 (cont. 4) - Modulo social Etapa 3: worker de publicacion
- Worker in-process con APScheduler que procesa la cola publicaciones_sociales cada 30s:
  - facebook_service.publicar_post_en_pagina: POST a /feed (texto) o /photos (con imagen)
  - services: 5 funciones del worker (obtener pendientes, token vigente, marcar publicando/publicada/fallada)
  - Backoff exponencial: 1min -> 5min -> 30min -> 2h -> AGOTADO (5 intentos max)
  - worker.py: procesar_cola + start/stop + ejecutar_ciclo_manual (acepta db opcional)
  - Endpoint admin POST /publicaciones/procesar-ahora
  - main.py lifespan: arranca/detiene el scheduler automaticamente
  - config: SOCIAL_WORKER_ENABLED + SOCIAL_WORKER_INTERVAL_SEC
  - apscheduler==3.10.4 en requirements
  - 12 tests nuevos (6 publicar_post + 6 worker) - 98 verdes totales
- Smoke test end-to-end: post real publicado en la pagina Baqueano Natales
  (external_post_id=1319567627902106_122120360697479454)
- Aprendizaje: pip install manual se pierde al recrear el container -> siempre
  va primero a requirements.txt + docker compose build

### 2026-10-10 (cont. 3) - Modulo social Etapa 2: OAuth Facebook completo
- Backend OAuth Facebook end-to-end funcionando en produccion:
  - oauth_state.py - JWT firmados (state CSRF + token_ref stateless)
  - facebook_service.py - cliente Graph API v26.0 con httpx async
  - 4 endpoints admin: GET /facebook/oauth/url, GET /facebook/oauth/callback (sin auth, el state firmado prueba identidad), POST /facebook/pages, POST /facebook/conectar
  - 5 vars en Settings: FACEBOOK_APP_ID, FACEBOOK_APP_SECRET, FACEBOOK_OAUTH_REDIRECT_URI, FACEBOOK_GRAPH_API_VERSION, FACEBOOK_OAUTH_SCOPES
  - 6 schemas Pydantic para OAuth
  - 21 tests nuevos (7 oauth_state + 14 facebook_service) - 86 tests verdes en total
  - respx==0.22.0 en requirements para mockear httpx
- Infra HTTPS para OAuth (Facebook exige HTTPS en redirect URI):
  - Subdominio dev-api.baqueanonatales.com proxied por Cloudflare
  - SSL mode: full -> self-signed alcanza
  - deploy/nginx/conf.d/dev-api.conf (server block nuevo)
  - deploy/nginx/certs/ (self-signed 10 anos, fuera del repo via .gitignore)
  - docker-compose.yml monta los certs en /etc/nginx/certs:ro
- Smoke test end-to-end exitoso en produccion:
  - Admin autorizo la app en Facebook (flujo OAuth real)
  - Backend recibio callback HTTPS en dev-api.baqueanonatales.com
  - Intercambio code -> short token -> long token (60 dias)
  - Cifro el page token con Fernet
  - Listo las 3 paginas del usuario
  - Conecto "Baqueano Natales" (external_id=1319567627902106) como cuenta central
  - Verificado en DB: cuentas_sociales + tokens_sociales con access_token = enc:gAAAAAB... (cifrado, nunca en claro)
- Gotchas descubiertos (documentar en futuro docs/SERVER_CHEATSHEET.md):
  - PowerShell -> SSH manda CRLF -> tail -20, head -c 300, wc -l fallan. Fix: replace + bash -s.
  - Heredoc anidado dentro de SSH falla por CRLF en el marcador. Fix: Python via stdin directo.
  - JWT del backend requiere claim iss: "baqueano-natales" - usar core.security.create_access_token() en vez de armar el payload a mano.
  - pip install manual en el container falla con Permission denied -> usar docker compose exec -T -u root backend pip install ...
  - El backend aborta en produccion si falta TOKEN_ENCRYPTION_KEY - comportamiento intencional del modulo crypto.

### 2026-10-10 (cont. 2) — Módulo social Etapa 1 (esqueleto) + Infra de tests
- ✅ **Módulo `social/` completo (Etapa 1: esqueleto)** — base para publicar en Facebook, Instagram y Google Business desde el admin:
  - **4 tablas**: `cuentas_sociales`, `tokens_sociales`, `publicaciones_sociales`, `config_social`
  - **4 enums de Postgres**: `red_social`, `propietario_tipo_social`, `destino_publicacion`, `estado_publicacion`
  - **Multi-tenant** vía `(propietario_tipo, propietario_id)`: cuenta central (Baqueano), por prestador, o por comercio
  - **Índice único parcial** con `NULLS NOT DISTINCT` para garantizar UNA sola config global
  - **Tokens cifrados** con Fernet (`app/core/crypto.py` + `TOKEN_ENCRYPTION_KEY` en `.env`)
- ✅ **Backend del módulo** (arquitectura modular, alineada con `prestadores/`):
  - `models.py` — 4 tablas + 4 enums + `TimestampMixin` / `SoftDeleteMixin`
  - `schemas.py` — 11 clases Pydantic
  - `deps.py` — `AdminUser`, `CurrentUser`, `CuentaDelPropietario`
  - `services.py` — 14 funciones async (CRUD de cuentas, tokens, config, publicaciones)
  - `routes.py` — router admin con 10 endpoints
  - `README.md` — doc del módulo + roadmap de 9 etapas
- ✅ **Crypto transversal** (`app/core/crypto.py`):
  - Fernet (AES-128 + HMAC-SHA256)
  - Fallback a texto plano en dev, **aborta en producción** si falta la clave
  - `TOKEN_ENCRYPTION_KEY` agregada a `Settings` + `.env` del server
- ✅ **Infraestructura de tests** (primera vez en el proyecto):
  - `backend/pytest.ini` + `backend/tests/conftest.py`
  - Tests con DB corren contra `baqueano_test` (DB separada, no toca producción)
  - **65 tests** en total (29 unit + 36 con DB)
  - `drop_all + create_all` al inicio de cada sesión para que el schema de test siempre refleje el código
- 🐛 **Fixes de infraestructura Docker**:
  - Montar `alembic/` + `alembic.ini` en el container (los archivos se quedaban "atrapados" dentro de la imagen)
  - Montar `tests/` + `pytest.ini` en el container
  - Estos fixes son **estructurales**: a partir de ahora las migraciones y tests nuevos se ven sin rebuild
- 🐛 **Fix alembic autogenerate**: detecta `server_default` falsos en `usuarios.*` en cada `--autogenerate`. Hay que removerlos a mano de cada migración (documentado en los docstrings de las migraciones del módulo social).
- 🐛 **Fix índice único**: en Postgres, `UNIQUE(a, b)` **no** bloquea duplicados cuando uno es NULL. Se agregó `NULLS NOT DISTINCT` (Postgres 15+) al índice parcial de config global.

### 2026-10-10 (cont.) — Editor de horarios de comercios
- ✅ **`EditorHorariosScreen`** para dueños:
  - Configuración de los 7 días con **multi-franja** (horario partido: 12-15 + 19-23)
  - Time picker nativo por franja
  - Toggle "Abierto/Cerrado" por día
  - Botón "Agregar franja" (para horario partido)
  - Botón "Copiar a todos los días" (útil para configurar rápido)
  - Validación: si está abierto, requiere abre y cierra
- ✅ **Integración en el detalle del comercio**:
  - Link "Gestionar" junto al título "Horarios"
  - Botón "Gestionar horarios" en la zona de acciones
- ✅ **Ruta** `/mis-comercios/:id/horarios` en el router
- ✅ **Verificado end-to-end** en emulador: `PUT /mis-comercios/{id}/horarios → 200`
- 🎉 **Módulo comercios 100% cerrado** (cliente + dueño + admin)

### 2026-10-10 — Admin de Comercios + Fix crítico del diálogo
- ✅ **Admin de comercios completo** (paralelo al de prestadores):
  - `AdminComerciosScreen`: listado con filtros por estado (Pendientes/Verificados/Rechazados/Suspendidos/Borradores)
  - `AdminDetalleComercioScreen`: verificar/rechazar/suspender/destacar
  - `AdminCategoriasComercioScreen`: CRUD completo de categorías con vista previa
  - Integración en AdminHome con badge de pendientes
- ✅ **3 rutas nuevas** en el router: `/admin/comercios`, `/admin/comercios/:id`, `/admin/categorias-comercio`
- ✅ **Provider** `adminComercioDetalleProvider` agregado
- 🐛 **Fix crítico**: el diálogo de motivo (rechazar/suspender) ahora usa `StatefulWidget`
  con `dispose()` correcto. Antes crasheaba con `TextEditingController was used after being disposed`
- ✅ **Verificado en emulador** end-to-end (suspender / re-verificar / destacar)

### 2026-10-09 (cont.) — Panel admin operativo (flavor admin)
- ✅ **Panel de administración** en flavor `admin` con Home diferenciado:
  - Sección **Gestión**: Prestadores (con badge de pendientes), Comercios (próx.), Usuarios (próx.)
  - Sección **Configuración**: Categorías de oficio (CRUD), Categorías de comercio (próx.)
  - Sección **Análisis**: Estadísticas globales (próx.)
- ✅ **Gestión de prestadores** (admin):
  - Listado con filtros por estado (Pendientes/Verificados/Rechazados/Suspendidos/Borradores)
  - Detalle con acciones: Verificar / Rechazar / Suspender / Destacar
  - Diálogos con motivo para rechazo/suspensión
- ✅ **CRUD de categorías de oficio** (admin):
  - Listar todas (activas + inactivas) con toggle activa/inactiva
  - Crear/editar con modal bottom sheet (nombre, slug auto, descripción, ícono, color, orden)
  - Vista previa en vivo
- ✅ **Router detecta `AppConfig.appType`**:
  - Flavor `admin` → arranca en `/admin/home` (panel morado)
  - Flavor `client` → arranca en `/home` (Home normal)
- ✅ **Verificado end-to-end** en emulador:
  - Login con Google en flavor admin → 200
  - `GET /admin/prestadores?estado=pendiente` → 200

### 2026-10-09 (cont.) — Prestadores: formulario + editor de servicios
- ✅ **Formulario real de crear/editar prestador** (dueño):
  - Información básica: nombre, categoría (dropdown con 11 categorías), descripción, años experiencia
  - Contacto: teléfono, WhatsApp, mensaje pre-armado, email, sitio web
  - Ubicación: dirección
  - Modalidad: 3 switches (domicilio/local/emergencias) + horario
  - Especialidades: chips dinámicos (agregar/eliminar)
  - Redes sociales: Instagram, Facebook, TikTok, YouTube
- ✅ **Editor de servicios real** (dueño):
  - Listado con precios, duración, garantía
  - Modal bottom sheet para agregar/editar
  - Categorías sugeridas: Mantenimiento, Frenos, Motor, Suspensión, Eléctrico, Emergencias, Instalaciones, Reparaciones
  - Eliminar con confirmación
- ✅ **Flujo CRUD completo verificado** end-to-end en emulador:
  - POST/GET/PATCH/DELETE a `/mis-prestadores` y `/mis-prestadores/{id}/servicios`

### 2026-10-09 (cont.) — Prestadores: pantallas dueño + entorno dev optimizado
- ✅ **Pantallas dueño de prestadores**:
  - `MisPrestadoresScreen` (listado con estados + rechazo visible)
  - `DetalleMiPrestadorScreen` (con acciones: enviar a revisión, editar, gestionar servicios, eliminar)
  - `FormularioPrestadorScreen` (placeholder — próxima iteración)
  - `EditorServiciosScreen` (placeholder — próxima iteración)
- ✅ 5 rutas nuevas integradas en `app_router.dart`
- ✅ Home actualizado con card **"Mis oficios"** en sección "Mi actividad"
- ✅ **Entorno de desarrollo optimizado**:
  - Emulador migrado de Android 17 → **Android 14** (estable)
  - GPU cambiada de `swiftshader_indirect` → **`host`** (1.200x más rápido)
  - RAM del AVD subida de 2 GB → **4 GB**
  - Frame time promedio: de **36.000 ms** a **28 ms**
- ✅ **Deep links seguros**: `canLaunchUrl` + fallback SnackBar (ya no crashea sin WhatsApp)

### 2026-10-09 — Módulo prestadores v2 (servicios + perfil industrial)
- ✅ **Backend v2 completo**:
  - Tabla nueva `prestador_servicios` (catálogo con precios/duración/garantía)
  - 4 columnas nuevas en `prestadores`: `anios_experiencia`, `whatsapp_mensaje`, `foto_portada_url`, `redes_sociales` (JSONB)
  - 4 endpoints nuevos: `PUT/POST/PATCH/DELETE /mis-prestadores/{id}/servicios`
  - 64 rutas totales en la API
- ✅ **Prestador modelo cargado en producción**: "Taller Mecánico del Sur"
  - 15 años experiencia, 12 servicios, 7 especialidades, 3 redes sociales
- ✅ **Frontend v2 completo**:
  - Modelo `PrestadorServicio` (Dart)
  - Modelo `Prestador` extendido con campos v2
  - `PrestadorRepository` con métodos de catálogo
  - **`DetallePrestadorScreen` industrial**: banner + avatar overlap, servicios agrupados con precios, redes sociales clickeables, FAB de WhatsApp
  - Deep links seguros con `canLaunchUrl` + fallback SnackBar (evita crashes)
- ✅ `url_launcher ^6.3.1` agregado

### 2026-10-09 — Módulo prestadores: backend completo
- ✅ **Backend completo** del módulo `prestadores` (schemas, services, deps, routers, seed)
- ✅ **4 routers registrados**: público, dueño, admin categorías, admin prestadores
- ✅ **11 categorías base** seedeadas en producción (mecánica, electricidad, gasfitería, etc.)
- ✅ **20 endpoints nuevos** respondiendo (`/prestadores`, `/mis-prestadores`, `/admin/categorias-oficio`, `/admin/prestadores`)
- ✅ Verificado end-to-end con `curl` en producción
- ⏳ Pendiente: frontend Flutter del módulo prestadores

### 2026-10-08 (cont.) — Módulo prestadores: modelos + migración
- ✅ **Capa reutilizable**: `core/mixins.py` (Timestamp + SoftDelete) + `shared/utils/slug.py` (slug único genérico)
- ✅ **Modelos `prestadores`**: `CategoriaOficio`, `Prestador`, `FotoTrabajo`
- ✅ **Migración aplicada** en producción (`ca0aef61fba0`)
- ✅ **3 tablas nuevas** en la DB (`categorias_oficio`, `prestadores`, `fotos_trabajo`)
- 🎯 **Pivote estratégico**: empezamos por **Oficios (mecánica primero)**, después Movilidad
- 📌 Decisiones arquitectónicas documentadas en `docs/VISION.md` y `docs/ARCHITECTURE.md`

### 2026-10-08 (cont.) — Documentación fundacional
- ✅ **`docs/VISION.md`** creado: visión de superapp multi-vertical, principios de arquitectura
- ✅ **`docs/ARCHITECTURE.md`** reescrito: monolito modular, transversal vs vertical, cómo agregar un módulo
- ✅ **`docs/LEGACY_ANALYSIS.md`** creado: análisis del sistema anterior (4 actores, 4 ejes de verificación, zonas por cuadrícula, sistema tarifario)
- 🎯 **Pivote estratégico**: empezamos por **Oficios (mecánica de autos)**, después Movilidad, después el resto
- 📌 Decisión: **monolito modular** ahora, microservicios solo cuando haga falta

### 2026-10-08 — Fix login con Google (end-to-end)
- ✅ **Login con Google funcional end-to-end** (Google → Firebase → Backend → JWT → Home)
- ✅ **Persistencia de sesión funcional** (sobrevive al cierre de la app)
- 🔧 Migración de `google_sign_in` **v7 → v6** (v7 tenía bug conocido con Credential Manager)
- 🔧 Agregado `serverClientId` al constructor de `GoogleSignIn` (obligatorio para `idToken` en Android)
- 🔧 Deshabilitado Credential Manager vía `meta-data` en AndroidManifest
- 🔧 Agregado `network_security_config.xml` para permitir HTTP en dev
- 🔧 Cambio de `https://` a `http://` en `AppConfig.dev` (server no tiene SSL aún)
- ⚠️ **SHA-1 de debug cambió** (ver sección Firebase)
- ✅ **App admin verificada** (login + persistencia funcional en `flutter run --flavor admin`)

### 2026-10-08 (cont.) — Módulo comercios (backend)
- ✅ **Nuevo módulo `comercios`** con 3 tablas (categorias_comercio, comercios, horarios_comercio)
- ✅ Migración Alembic aplicada en producción (`d6654af1dbf2`)
- ✅ 20 endpoints nuevos (público, propietario, admin)
- ✅ 9 categorías base seedeadas en la DB
- ✅ Endpoint público `/api/v1/comercios/categorias` funcionando
- ⏳ Pendiente: frontend Flutter del módulo

### 2026-10-08 (cont.) — Fixes críticos y migración de emulador
- ✅ **Fix `DioClient.validateStatus`**: 4xx ahora se mapean a `ApiException` (antes intentaban parsear el body como modelo)
- ✅ **`Comercio.fromJson` defensivo**: parseo robusto con logging de campos null
- ✅ **Migración de emulador Android 17 → Android 14** (`Pixel6_API34`)
  - Motivo: Android 17 (API 37) tiene bugs sin resolver de IME (teclado virtual no se despliega) y OpenGL (crash con `swiftshader_indirect`)
  - Android 14 funciona perfecto: teclado físico Y virtual OK
- 📌 Tip de emulador: usar `-gpu swiftshader_indirect` en el launch

### 2026-10-08 (cont.) — Frontend comercios (cliente)
- ✅ Modelos Dart: `Categoria`, `Horario`, `Comercio` (+ enum `EstadoComercio`)
- ✅ Repositorio `ComercioRepository` con 20+ métodos (público, dueño, admin)
- ✅ Providers Riverpod (categorías, listado con filtros, detalle, admin)
- ✅ Widget `ComercioCard` reutilizable
- ✅ Pantalla lista de comercios (búsqueda + chips categorías + filtros destacados/delivery)
- ✅ Pantalla detalle (portada, logo, contacto, ubicación, horarios multi-franja)
- ✅ Router corregido (permite rutas autenticadas fuera de `/home`)
- ✅ Home linkeado a Comercios
- ✅ **Flujo end-to-end verificado en emulador** con comercio de prueba
- ⏳ Pendiente: pantallas dueño (mis comercios, crear/editar, horarios)
- ⏳ Pendiente: pantallas admin (verificar/rechazar, CRUD categorías)

### 2026-10-08 (cont.) — App admin verificada
- ✅ Login con Google funcional en flavor admin
- ✅ Home admin con tema morado + badge ADMIN
- ✅ SHA-1 nuevo registrado en Firebase para `cl.baqueanonatales.admin`

---

## 📌 Resumen ejecutivo

**Baqueano Natales** es una superapp regional para Puerto Natales, Chile (movilidad, delivery, comercio local). Actualmente en desarrollo activo con backend desplegado y app Flutter con login funcional completo.

**Estado actual:**
- ✅ Backend desplegado en producción (server nuevo)
- ✅ 5 módulos backend completos (auth, usuarios, admin, comercios, prestadores)
- Modulo social (Etapas 1-6) - OAuth FB + worker + IG + integracion prestadores + frontend admin, 114 tests
- ✅ **Infraestructura de tests** (pytest + DB de test aislada)
- ✅ 3 módulos backend completos (auth, usuarios, admin)
- ✅ App Flutter con flavors (client + admin)
- ✅ Login con Google funcional **end-to-end**
- ✅ Persistencia de sesión funcional
- ✅ App admin verificada (login + Home con badge ADMIN)
- ✅ **Backend módulo comercios** (modelos, migración, endpoints, seed)
- ⏳ Pendiente: frontend Flutter del módulo comercios
- ⏳ Pendiente: features core restantes (mapa, delivery, carta QR, recompensas)

---

## 🖥️ Servidores

### Server nuevo (producción activa)
| Item | Valor |
|---|---|
| **Hostname** | `baqueano-natales-prod` |
| **IP pública** | `104.129.59.151` |
| **Proveedor** | RackNerd |
| **Panel** | `ctrl.racknerd.com` |
| **OS** | Ubuntu 24.04.5 LTS |
| **Hardware** | 3 vCPU / 4 GB RAM / 60 GB disco |
| **Acceso** | `ssh deploy@104.129.59.151` (clave SSH) |
| **Usuario** | `deploy` (sudo configurado) |

**Puertos abiertos (UFW):** 22 (SSH), 80 (HTTP), 443 (HTTPS).

**Subdominios (Cloudflare, proxied):**
| Subdominio | Apunta a | Uso |
|---|---|---|
| `api.baqueanonatales.com` | Server viejo (`161.118.240.229`) | Producci?n actual (a migrar en Fase 6) |
| `dev-api.baqueanonatales.com` | **Server nuevo** (`104.129.59.151`) | Dev + OAuth Facebook (SSL mode: full) |

**Estado actual del server:**
- ✅ HTTP (puerto 80) responde OK: `curl http://104.129.59.151/health` → `{"status":"ok"}`
- ❌ HTTPS (puerto 443) **no configurado** (Let's Encrypt es Fase 6)

**Servicios corriendo (Docker):**
- `baqueano_backend` — FastAPI en `127.0.0.1:8000`
- `baqueano_db` — PostgreSQL 16 en `127.0.0.1:5432`
- `baqueano_nginx` — Reverse proxy en `0.0.0.0:80,443`

**Path del proyecto:** `/home/deploy/baqueano-natales/`

### 🔐 Credenciales del server (decisiones conscientes)

**Cloudflare Global API Key** — se mantiene **a propósito** en el server
(`~/.cf-env` + `~/.bashrc`) para poder operar CUALQUIER proyecto/dominio
de la cuenta Cloudflare desde este server, sin crear/rotar tokens por
proyecto. **No es deuda técnica.** Reglas: nunca commitear, nunca pegar
en chats/logs, permisos 600, y si se filtra → rotar YA + auditar en
Cloudflare.

### Server viejo (a decommissionar)
| Item | Valor |
|---|---|
| **Hostname** | `superapp-natales-backend` |
| **IP pública** | `161.118.240.229` |
| **IP privada** | `10.0.0.236` |
| **Proveedor** | Oracle Cloud |
| **OS** | Ubuntu 22.04.5 LTS |
| **Acceso** | `ssh ubuntu@161.118.240.229` |

**Estado:** corriendo el sistema viejo. **Será apagado** cuando la migración esté completa y validada.

---

## 📦 Repositorios GitHub

**Cuenta:** `victorneyraars`

| Repo | Descripción | Estado |
|---|---|---|
| `baqueano-natales` | Monorepo (backend + flutter + deploy + docs) | ✅ Activo |
| `baqueano-natales-legacy` | Repo viejo (build 400 del 24 agosto) | 📦 Archivado |
| `rnstp-service` | Microservicio RNSTP | ⏳ Vacío (a poblar) |
| `studiodigital360` | Otro proyecto (Next.js) | ✅ |
| `sealquilamarido-web` | Otro proyecto (Astro en Vercel) | ✅ |

**Rama principal:** `main`.

---

## 🏗️ Stack del backend

### Tecnologías
| Capa | Tecnología | Versión |
|---|---|---|
| **Lenguaje** | Python | 3.12 |
| **Framework** | FastAPI | 0.115.6 |
| **ORM** | SQLAlchemy | 2.0.36 (async) |
| **Migraciones** | Alembic | 1.14.0 |
| **BD** | PostgreSQL | 16 (contenedor) |
| **Driver async** | asyncpg | 0.30.0 |
| **Driver sync** | psycopg2-binary | 2.9.10 |
| **Validación** | Pydantic | 2.10.4 |
| **Firebase** | firebase-admin | 6.6.0 |
| **HTTP client** | httpx | 0.28.1 |
| **Rate limiting** | slowapi | 0.1.9 |
| **Procesamiento imágenes** | Pillow | 11.0.0 |
| **Validación archivos** | filetype | 1.2.0 |
| **Contenedores** | Docker | 29.8.2 |
| **Orquestación** | Docker Compose | 5.6.0 |
| **Reverse proxy** | Nginx | 1.27 (alpine) |

### Estructura del proyecto
```
backend/
├── app/
│   ├── core/                    # Configuración transversal
│   │   ├── config.py            # Pydantic Settings
│   │   ├── db.py                # SQLAlchemy async
│   │   ├── firebase.py          # Firebase Admin SDK
│   │   ├── logging.py           # Logs JSON
│   │   └── security.py          # JWT propio
│   ├── modules/                 # Por dominio de negocio
│   │   ├── auth/
│   │   │   ├── models.py        # Usuario + RolUsuario (enum)
│   │   │   ├── schemas.py
│   │   │   ├── deps.py          # get_current_user, require_admin
│   │   │   ├── services.py      # login con Google
│   │   │   └── routes.py
│   │   ├── usuarios/
│   │   │   ├── schemas.py
│   │   │   ├── services.py
│   │   │   └── routes.py
│   │   └── admin/
│   │       ├── schemas.py
│   │       ├── services.py
│   │       ├── routes.py
│   │       └── seed.py          # Promover admin
│   ├── shared/
│   │   └── storage/
│   │       ├── base.py          # Interfaz AvatarStorage (ABC)
│   │       └── local.py         # Implementación local
│   └── main.py
├── alembic/                     # Migraciones
├── secrets/                     # ⚠️ NO commitear
│   └── firebase-service-account.json
├── .dockerignore
├── .env.example
├── Dockerfile
└── requirements.txt
```

### Modelo de datos (actual)

**Tabla `usuarios`:**
```
id (UUID, PK)
firebase_uid (varchar 128, unique, not null)
email (varchar 255, unique, nullable)
phone (varchar 20, unique, nullable)
nombre (varchar 100, nullable)
apellido (varchar 100, nullable)
avatar_url (varchar 500, nullable)
rol (enum: cliente, comercio, prestador, admin)
verificado (bool, default false)
activo (bool, default true)
tiene_google (bool, default false)
tiene_whatsapp (bool, default false)
tiene_sms (bool, default false)
created_at (timestamp tz)
updated_at (timestamp tz)
ultimo_login (timestamp tz, nullable)

Índices: email, phone, firebase_uid, rol
```

### Endpoints activos

**Sistema:**
- `GET /health`
- `GET /`

**Auth:**
- `POST /api/v1/auth/google` — Login con Google (recibe id_token de Firebase)
- `GET /api/v1/auth/me` — Datos del usuario autenticado

**Usuarios:**
- `GET /api/v1/usuarios/me` — Perfil completo
- `PATCH /api/v1/usuarios/me` — Editar nombre/apellido
- `POST /api/v1/usuarios/me/avatar` — Subir avatar (multipart)
- `DELETE /api/v1/usuarios/me` — Desactivar cuenta (soft delete)
- `GET /api/v1/usuarios/{id}` — Perfil público

**Admin (requieren rol admin):**
- `GET /api/v1/admin/usuarios` — Listar con filtros + paginación
- `GET /api/v1/admin/usuarios/{id}` — Detalle
- `PATCH /api/v1/admin/usuarios/{id}/rol` — Cambiar rol
- `PATCH /api/v1/admin/usuarios/{id}/verificar` — Verificar/desverificar
- `PATCH /api/v1/admin/usuarios/{id}/reactivar` — Reactivar
- `DELETE /api/v1/admin/usuarios/{id}` — Desactivar
- `GET /api/v1/admin/estadisticas` — Métricas globales

---

## 📱 Stack de Flutter (PC Windows)

### Entorno de desarrollo
| Item | Valor |
|---|---|
| **Flutter SDK** | 3.47.6 (stable) |
| **Dart** | 3.13.5 |
| **DevTools** | 2.60.0 |
| **Flutter path** | `D:\dev\flutter` |
| **Android Studio** | 2026.2.1 Rabbit |
| **Android SDK** | API 37, build-tools 36.0.0 |
| **NDK** | 28.2.13676358 |
| **JDK** | 25 (bundled con Android Studio) |
| **VS Code** | 1.140.0 + extensión Flutter |
| **Emulador** | `Pixel6_API34` (Android 14 — RECOMENDADO) |
| **Emulador viejo** | `Pixel6_API37` (Android 17 — deprecado, tiene bugs de IME/GPU) |
| **PUB_CACHE** | `D:\DartCache` |

### Configuración crítica del PC
**Variable de entorno (User):**
```
PUB_CACHE=D:\DartCache
```

**`android/gradle.properties`:**
```
org.gradle.jvmargs=-Xmx8G -XX:MaxMetaspaceSize=4G -XX:ReservedCodeCacheSize=512m -XX:+HeapDumpOnOutOfMemoryError
android.useAndroidX=true
android.newDsl=false
android.builtInKotlin=false
kotlin.incremental=false
org.gradle.daemon=false
org.gradle.parallel=false
```

**Razón:** evitar el error de Kotlin daemon "different roots" entre `D:\` (proyecto) y `C:\` (pub-cache original). Trade-off: builds más lentos pero estables.

### Estructura del proyecto Flutter
```
flutter/
├── lib/
│   ├── main_client.dart             # Entry point cliente
│   ├── main_admin.dart              # Entry point admin
│   ├── core/
│   │   ├── config/
│   │   │   └── app_config.dart      # AppConfig + enum AppType/Environment
│   │   ├── network/
│   │   │   ├── api_exceptions.dart  # ApiException + variantes
│   │   │   └── dio_client.dart      # Dio con interceptores JWT
│   │   ├── storage/
│   │   │   └── secure_storage.dart  # flutter_secure_storage wrapper
│   │   └── theme/
│   │       └── app_theme.dart       # Verde (client) / morado (admin)
│   ├── features/
│   │   ├── auth/
│   │   │   ├── domain/
│   │   │   │   └── user.dart        # Modelo User
│   │   │   ├── data/
│   │   │   │   ├── auth_repository.dart
│   │   │   │   └── auth_notifier.dart
│   │   │   └── presentation/
│   │   │       ├── splash_screen.dart
│   │   │       └── login_screen.dart
│   │   └── home/
│   │       └── presentation/
│   │           └── home_screen.dart
│   └── shared/
│       └── router/
│           └── app_router.dart      # GoRouter + auto-redirect
├── android/
│   ├── app/
│   │   ├── build.gradle.kts         # Flavors client + admin + deps Credential Manager
│   │   ├── google-services.json     # Firebase (SÍ va al repo)
│   │   └── src/main/
│   │       ├── AndroidManifest.xml  # Con meta-data + networkSecurityConfig
│   │       ├── kotlin/cl/baqueanonatales/
│   │       │   └── MainActivity.kt
│   │       └── res/xml/
│   │           └── network_security_config.xml  # Permite HTTP solo a 104.129.59.151
│   └── gradle.properties
├── ios/
├── pubspec.yaml
└── README.md
```

### Dependencias Flutter
```yaml
dependencies:
  flutter: sdk: flutter
  cupertino_icons: ^1.0.8
  firebase_core: ^3.8.0
  firebase_auth: ^5.3.3
  google_sign_in: ^6.2.0    # v6 (v7 tiene bug con Credential Manager)
  dio: ^5.7.0
  flutter_secure_storage: ^11.2.0
  go_router: ^14.6.2
  flutter_riverpod: ^2.6.1
  share_plus: ^13.3.1

dev_dependencies:
  flutter_test: sdk: flutter
  flutter_lints: ^5.0.0
```

**Notas sobre versiones resueltas:**
- `firebase_core: 3.15.2` (resolvió más nueva)
- `firebase_auth: 5.7.0` (resolvió más nueva)
- `google_sign_in: 6.3.0` (API v6, estable)
- `dio: 5.11.1`
- `flutter_riverpod: 2.6.1`
- `flutter_secure_storage: 11.2.0` (upgrade v9 -> v11 en 2 fases)
- `share_plus: 13.3.1` (upgrade v10 -> v13)

### ⚠️ Configuración nativa Android (CRÍTICA para login con Google)

**1. `android/app/build.gradle.kts` — bloque `dependencies` obligatorio:**
```kotlin
dependencies {
    // Credential Manager (requerido por google_sign_in v7)
    implementation("androidx.credentials:credentials:1.3.0")
    implementation("androidx.credentials:credentials-play-services-auth:1.3.0")
    implementation("com.google.android.libraries.identity.googleid:googleid:1.1.1")
}
```
> Nota: aunque usamos v6, estas deps se dejaron por si se migra a v7 en el futuro. No molestan.

**2. `AndroidManifest.xml` — dos elementos obligatorios:**
```xml
<application
    android:networkSecurityConfig="@xml/network_security_config"
    ...>
    <!-- Deshabilitar Credential Manager para forzar el flujo clásico -->
    <meta-data
        android:name="com.google.android.gms.credentials.API_ENABLED"
        android:value="false" />
</application>
```

**3. `res/xml/network_security_config.xml`:**
```xml
<?xml version="1.0" encoding="utf-8"?>
<network-security-config>
    <!-- Permitir HTTP sin cifrar SOLO para el server de desarrollo -->
    <domain-config cleartextTrafficPermitted="true">
        <domain includeSubdomains="true">104.129.59.151</domain>
    </domain-config>
</network-security-config>
```

**Razón:** Android 9+ bloquea HTTP en claro por defecto. Esta config permite HTTP **solo** al server de dev, manteniendo HTTPS como requerido para todo el resto.

### Arquitectura Flutter

**State management:** Riverpod 2.6.1 (StateNotifier + Provider).

**Navegación:** GoRouter 14.8.1 con auto-redirect según `authNotifierProvider`.

**HTTP:** Dio 5.11.1 con 2 interceptores:
1. **Request:** agrega `Authorization: Bearer <jwt>` si hay token guardado.
2. **Error:** mapea DioException a ApiException tipada.

**Storage:** `flutter_secure_storage` 11.2.0 con custom cipher storage (RSA OAEP + AES-GCM, Android Keystore). Nota: `encryptedSharedPreferences` fue deprecado en v10 y eliminado en v11.

**Config central:** `AppConfig` con `AppType` (client/admin) y `Environment` (dev/prod).

**API en dev:** `http://104.129.59.151` (HTTP, sin SSL — el server aún no tiene cert).
**API en prod:** `https://api.baqueanonatales.com` (cuando se haga el cutover DNS).

**AuthRepository — Google Sign-In v6:**
- `GoogleSignIn(scopes: [...], serverClientId: AppConfig.googleServerClientId)`
- `signIn()` → `GoogleSignInAccount`
- `googleUser.authentication` → `idToken` + `accessToken`
- **`serverClientId` es OBLIGATORIO** para obtener `idToken` en Android.

---

## 🔥 Firebase

### Proyecto Firebase
| Item | Valor |
|---|---|
| **Project ID** | `baqueano-natales-prod` |
| **Project Number** | `1072830106109` |
| **Plan** | Spark (gratuito) |

### Apps Android registradas
| Package | Rol | Client ID (Android) |
|---|---|---|
| `cl.baqueanonatales` | Cliente | `1072830106109-rb18p4oksc8607kr9c80i6mv92112kf5` (SHA-1 viejo) |
| `cl.baqueanonatales` | Cliente | `1072830106109-eh5i191lkg7d6185fr45c1difjvsqj66` (SHA-1 nuevo) |
| `cl.baqueanonatales.admin` | Admin | `1072830106109-0dao16e11pjkg0pnrnejpn3abumenfhv` (SHA-1 viejo) |

**Web Client ID (para serverClientId):**
```
1072830106109-c1b5cktisbj3khu8s9jmf7crn8ni0dh7.apps.googleusercontent.com
```

### ⚠️ Huellas SHA (CAMBIARON el 2026-10-08)

**SHA-1 de debug (ACTUAL):**
```
6E:0B:71:E0:63:01:E8:F7:CF:0E:3D:BC:1F:29:77:C8:D6:BE:63:3D
```

**SHA-256 de debug (ACTUAL):**
```
B2:A9:81:11:D4:55:81:B1:E8:5A:15:E7:6D:C1:5F:9E:20:0A:FE:72:FD:C5:EB:33:25:6E:97:82:B2:20:7C:BE
```

**SHA-1 viejo (ya no válido, pero registrado en Firebase):**
```
5C:1E:05:A3:10:92:65:4B:C7:7C:85:60:D7:F2:FB:6B:33:E0:B9:F5
```

**✅ Actualización 2026-10-08:** La app **`cl.baqueanonatales.admin`** ya tiene el SHA-1 nuevo registrado en Firebase. Se generó un client_id nuevo (`1072830106109-nv8q2jjt7kateq7cmqesg383entpu2sb`) que ya está en el `google-services.json` del repo.

**Nota:** El `debug.keystore` cambió (probablemente por reinstalación de Android Studio o cambio de PC). El SHA-1 viejo está en el doc antiguo y **ya no aplica**.

### Firebase Console
- URL: `https://console.firebase.google.com/project/baqueano-natales-prod`
- Authentication → Google habilitado
- OAuth consent screen: configurado (External, "Baqueano Natales")

### Service Account (backend)
- **Path en server:** `/home/deploy/baqueano-natales/backend/secrets/firebase-service-account.json`
- **Client email:** `firebase-adminsdk-fbsvc@baqueano-natales-prod.iam.gserviceaccount.com`
- **Mount en Docker:** `/app/secrets/firebase-service-account.json:ro`

---

## 🌐 Dominios y DNS

### Cloudflare
**Nameservers:**
- `april.ns.cloudflare.com`
- `simon.ns.cloudflare.com`

**Registros DNS actuales:**
| Dominio | Tipo | Apunta a | Estado |
|---|---|---|---|
| `api.baqueanonatales.com` | A | `161.118.240.229` (server viejo) | ⏳ Pendiente migrar a `104.129.59.151` |
| `baqueanonatales.com` | A | Vercel (`76.76.21.21`) | ✅ |
| `www.baqueanonatales.com` | CNAME | Vercel | ✅ |

**Estado:** el DNS de `api.baqueanonatales.com` **aún apunta al server viejo**. El cutover se hará cuando la migración esté validada.

### Vercel
- **Team:** `studio-digital-360`
- **Proyecto:** `baqueano-natales-web` (Astro)
- **URL producción:** `https://www.baqueanonatales.com`
- **Estado:** activo, sin tocar durante la migración

---

## 🔧 Fases del proyecto

### ✅ Fase 1 — Infraestructura (completada)
- Server nuevo provisionado y hardened
- Docker + Compose
- Backend FastAPI + Postgres + Nginx
- Healthchecks, logs JSON
- Documentación inicial (`docs/`)

### ✅ Fase 2 — Auth con Google (completada)
- Firebase Admin SDK integrado
- Endpoint `POST /api/v1/auth/google`
- Verificación de tokens
- JWT propio con roles
- Middleware `get_current_user` + `require_admin`

### ✅ Fase 3.1 — Módulo usuarios (completada)
- Modelo `Usuario` + migración
- CRUD de perfil
- Avatares con `LocalAvatarStorage` (interfaz ABC migrable a S3/Firebase)
- Nginx sirviendo `/media/` con caché 30d

### ✅ Fase 3.2 — Módulo admin (completada)
- 7 endpoints de gestión
- Filtros, paginación, validaciones
- Auto-admin por email (`ADMIN_EMAILS` en `.env`)
- Script de seed
- Fix crítico: `values_callable` en ENUM RolUsuario

### ✅ Fase 3.3 — Flutter base + login con Google (COMPLETADA 2026-10-08)
- Proyecto Flutter con estructura feature-first
- Flavors `client` (verde) + `admin` (morado)
- Router GoRouter con auto-redirect
- Splash + Login + Home
- **Login con Google funcional end-to-end** (Google → Firebase → Backend → JWT → Home)
- **Persistencia de sesión funcional** (sobrevive al cierre de la app)
- JWT guardado en secure storage
- Migración `google_sign_in` v7 → v6
- Configuración nativa Android completa (Credential Manager off, network security config)
- HTTP en dev (SSL pendiente para Fase 6)

### ✅ Fase 3.4 — Commit del código Flutter (COMPLETADA 2026-10-08)
- Todo el código Flutter commiteado y pusheado
- `CONTEXTO_PROYECTO.md` commiteado
- Fix del login commiteado

### ✅ Fase 3.5 — App admin con login (COMPLETADA 2026-10-08)
- ✅ SHA-1 nuevo registrado en `cl.baqueanonatales.admin` en Firebase Console
- ✅ `google-services.json` actualizado y commiteado
- ✅ Login con Google funcional end-to-end en flavor admin
- ✅ Home admin con tema morado + badge ADMIN
- ✅ Misma arquitectura que client (comparte `home_screen.dart` por ahora)

### ⏳ Fase 3.6 — Features core (pendiente)
- Mapa en vivo (Google Maps + WebSocket)
- Delivery (flujo de pedidos)
- Carta QR (menús interactivos)
- Recompensas (puntos por compras)

### ⏳ Fase 4 — CI/CD con GitHub Actions (pendiente)
- Tests en cada push
- Build APK automático
- Deploy backend automático vía SSH

### ⏳ Fase 5 — Play Store (pendiente)
- Crear keystore nuevo
- Activar Play App Signing
- Subir AAB a Play Console
- Completar metadata

### ⏳ Fase 6 — Cutover DNS + SSL (pendiente)
- Bajar TTL en Cloudflare
- Cambiar A record de `api.baqueanonatales.com` a `104.129.59.151`
- **Emitir certificado Let's Encrypt en el server nuevo**
- **Cambiar `AppConfig.dev` de `http://` a `https://`** (o dejar que prod lo use)
- Verificar HTTPS

### ⏳ Fase 7 — Decommission server viejo (pendiente)
- Apagar server viejo después de 1 semana sin incidentes
- Archivar repos viejos

---

## 🔍 Temas pendientes de análisis (no deuda técnica activa)

### Fase 6 — DNS cutover + SSL del server nuevo (PENDIENTE DE ANALIZAR)

**Contexto (2026-10-11):** se posterga hasta tener claridad sobre el modelo
final. No es deuda técnica activa porque hay decisiones estratégicas sin tomar.

**Estado actual:**
- `api.baqueanonatales.com` → server viejo (sistema legacy en producción).
- `dev-api.baqueanonatales.com` → server nuevo (proyecto nuevo + OAuth FB).
- SSL del server nuevo: Cloudflare Origin Certificate + modo `Full (strict)`.

**Por qué se posterga:**
1. El server nuevo aún no tiene paridad de features con el viejo.
2. Sin usuarios reales, no hay urgencia de consolidar.
3. **Decisión estratégica abierta:** Cloudflare proxied vs directo.
   - Si se mantiene **Cloudflare proxied** → el Origin Certificate es suficiente,
     **Let's Encrypt no aporta valor** (el usuario final ve el cert Edge de CF,
     nunca el del server).
   - Si se saca Cloudflare del medio (proxied=off) → ahí sí Let's Encrypt es
     la solución correcta.
4. Antes de decidir hay que definir el modelo de despliegue final del MVP.

**Antes de ejecutar hay que definir:**
- ¿Cloudflare queda proxied en producción final o no?
- ¿Cuándo el proyecto nuevo reemplaza al legacy (paridad de features)?
- ¿Se consolida en 1 solo server o se mantienen 2?

**Estimación tentativa cuando se decida:** ~1.5 horas (DNS cutover + SSL + AppConfig Flutter + validación).
## 🚨 Secretos expuestos (pendientes rotar)

**Durante el desarrollo, quedaron expuestos en chats/logs:**

| Secreto | Estado | Acción pendiente |
|---|---|---|
| `SECRET_KEY` (JWT) | ⚠️ Expuesto | Rotar en `.env` del server nuevo |
| `BOOSTR_API_KEY` | ⚠️ Expuesto | Regenerar desde Boostr |
| `RUTIFICADOR_API_KEY` | ⚠️ Expuesto | Regenerar desde Rutificador |
| `DIDIT_API_KEY` + `DIDIT_WEBHOOK_SECRET` | ⚠️ Expuesto | Regenerar en Didit |
| `RNSTP_API_KEY` | ⚠️ Expuesto | Regenerar |
| `FACEBOOK_PAGE_ACCESS_TOKEN` (x2) | ⚠️ Expuesto | Revocar en Meta + regenerar |
| `FACEBOOK_TOKEN_KEY` | ⚠️ Expuesto | Rotar |
| `GOOGLE_CLIENT_SECRET` | ⚠️ Expuesto | Regenerar en Google Cloud |
| `VERCEL_DEPLOY_HOOK_URL` | ⚠️ Expuesto | Regenerar en Vercel |
| `CLAVE_PRUEBAS`, `CLAVE_TAREAS` | ⚠️ Expuesto | Cambiar |
| Frase GPG de backups | 🚨 **MÁS CRÍTICO** | Rotar YA |
| GitHub PAT viejo | ⚠️ Expuesto | Revocar en GitHub |
| DuckDNS token | ⚠️ Expuesto | Descartado (no se usa DuckDNS) |
| Facebook token en `/root/main.py` del server nuevo | ⚠️ Expuesto | Revocar |

**⚠️ Rotación pendiente completa.** No se ha hecho todavía.

---

## 🧪 Infraestructura de tests

**Primera vez que el proyecto tiene tests automatizados.**

### Estructura
```nbackend/
├── pytest.ini
└── tests/
    ├── conftest.py        # fixtures: test_engine, db
    └── modules/
        └── social/
            ├── test_crypto.py      # 13 tests (unit)
            ├── test_schemas.py     # 16 tests (unit)
            ├── test_models.py      # 12 tests (con DB)
            └── test_services.py    # 24 tests (con DB)
```

### Cómo correr los tests

**Local (solo unit, sin DB):**
``powershell
cd backend
.\.venv\Scripts\python.exe -m pytest tests/modules/social/ -q
``
→ 29 passed, 36 skipped (los con DB se saltan sin `POSTGRES_PASSWORD` local)

**Server (con DB de test):**
``powershell
ssh deploy@104.129.59.151 "cd ~/baqueano-natales && docker compose exec -T backend pytest tests/ -q"
``
→ 65 passed

### DB de test

- Nombre: `baqueano_test` (en el Postgres del server)
- **NO toca producción** (`baqueano_natales`)
- El `conftest.py` hace `drop_all + create_all` al inicio de cada sesión
- TRUNCATE de las tablas del módulo antes de cada test

### Warning cosmético conocido

`PytestCacheWarning: could not create cache path /app/.pytest_cache` —
el container corre como `appuser` y `/app` es de `root`. No afecta los tests.

## 🗂️ Configuración crítica del server nuevo

### `docker-compose.yml`
3 servicios: `db`, `backend`, `nginx`.

**Volúmenes:**
- `postgres_data` — persistencia de DB
- `media_data` — avatares subidos
- `nginx_cache` — caché de Nginx

**Mounts del backend:**
- `./backend/app:/app/app` — hot reload en dev
- `./backend/secrets:/app/secrets:ro` — service account (read-only)
- `media_data:/app/media` — avatares

### `.env` (backend)
Variables clave:
```
ENVIRONMENT=production
DEBUG=false
POSTGRES_USER=baqueano_user
POSTGRES_PASSWORD=<ROTAR>
POSTGRES_DB=baqueano_natales
DATABASE_URL=postgresql://...
SECRET_KEY=<ROTAR>
FIREBASE_PROJECT_ID=baqueano-natales-prod
FIREBASE_SERVICE_ACCOUNT_PATH=/app/secrets/firebase-service-account.json
ADMIN_EMAILS=victorneyraars@gmail.com
PUBLIC_API_URL=https://api.baqueanonatales.com
AVATAR_STORAGE_PATH=/app/media/avatars
MAX_AVATAR_SIZE_BYTES=5242880
```

### Nginx
- Proxy reverso a `backend:8000`
- Rate limiting: 60/min general, 5/min en `/api/v1/auth/`
- Security headers (X-Content-Type-Options, X-Frame-Options, Referrer-Policy)
- Sirve `/media/` con caché 30d
- `server_tokens off`
- Upstream con `keepalive 32`

---

## 🛠️ Comandos rápidos

### Correr app Flutter (client)
```powershell
cd D:\dev\baqueano-natales\flutter
flutter run --flavor client -t lib/main_client.dart -d emulator-5554
```

### Correr app Flutter (admin)
```powershell
cd D:\dev\baqueano-natales\flutter
flutter run --flavor admin -t lib/main_admin.dart -d emulator-5554
```

### Rebuild limpio (cuando hay cambios nativos)
```powershell
cd D:\dev\baqueano-natales\flutter
flutter clean
flutter pub get
flutter run --flavor client -t lib/main_client.dart -d emulator-5554
```

### Matar procesos Flutter bloqueados
```powershell
Get-Process | Where-Object { $_.ProcessName -match "flutter|dart" } | Stop-Process -Force -ErrorAction SilentlyContinue
```

### Ver SHA-1 debug actual (¡cambió!)
```powershell
cd D:\dev\baqueano-natales\flutter\android
./gradlew signingReport
```

### Emulador Android 14 (recomendado)
```powershell
& "D:\Android\Sdk\emulator\emulator.exe" -avd Pixel6_API34 -no-snapshot-load -gpu swiftshader_indirect
```powershell
Get-Process | Where-Object { $_.ProcessName -match "emulator|qemu|adb" } | Stop-Process -Force -ErrorAction SilentlyContinue
& "D:\Android\Sdk\emulator\emulator.exe" -avd Pixel6_API37 -no-snapshot-load -wipe-data -gpu swiftshader_indirect
```

### Ver logs del backend (server)
```bash
ssh deploy@104.129.59.151 "cd baqueano-natales && docker compose logs --tail=50 backend"
```

### Rebuild backend (server)
```bash
ssh deploy@104.129.59.151 "cd baqueano-natales && docker compose build backend && docker compose up -d"
```

### Query DB (server)
```bash
ssh deploy@104.129.59.151 "cd baqueano-natales && docker compose exec -T db psql -U baqueano_user -d baqueano_natales -c 'SELECT id, email, rol FROM usuarios;'"
```

### Verificar salud del backend (HTTP dev)
```bash
curl http://104.129.59.151/health
```

---

### Recargar cambios del `.env` en el backend

⚠️ **`docker compose restart backend` NO recarga el `.env`.** Recrear el container:

``bash
ssh deploy@104.129.59.151 "cd ~/baqueano-natales && docker compose up -d backend"
``

(Palabra clave en el output: **"Recreated"**, no "Started".)

### Correr tests local (unit, sin DB)

``powershell
cd D:\dev\baqueano-natales\backend
.\.venv\Scripts\python.exe -m pytest tests/modules/social/ -q
``

### Correr tests completos (server, con DB)

``powershell
ssh deploy@104.129.59.151 "cd ~/baqueano-natales && docker compose exec -T backend pytest tests/ -q"
``

### Aplicar migraciones en el server

``powershell
ssh deploy@104.129.59.151 "cd ~/baqueano-natales && docker compose exec -T backend alembic upgrade head"
``

### Ver migraciones aplicadas

``powershell
ssh deploy@104.129.59.151 "cd ~/baqueano-natales && docker compose exec -T backend alembic current"
``

## 📚 Documentación existente

**En el repo `baqueano-natales`:**

| Archivo | Contenido |
|---|---|
| `README.md` | Intro + estructura + stack |
| `docs/VISION.md` | 🎯 Visión de superapp multi-vertical + cómo crece |
| `docs/ARCHITECTURE.md` | Arquitectura técnica + modular estricta |
| `docs/LEGACY_ANALYSIS.md` | 📚 Análisis del sistema anterior (4 actores, verificación, zonas) |
| `docs/DEPLOYMENT.md` | Guía de deploy paso a paso |
| `docs/DEVELOPMENT.md` | Convenciones + setup dev |
| `docs/DECISIONS/0001-docker-compose.md` | ADR inicial |
| `backend/app/modules/social/README.md` | Doc del módulo social + roadmap de 9 etapas |
| `CONTEXTO_PROYECTO.md` | Este archivo |

---

## 🎯 Estado exacto al retomar

**Lo que está funcionando:**
- Server nuevo con backend corriendo en `104.129.59.151` (HTTP)
- Postgres 16 con 13 tablas (usuarios, comercios, prestadores, social)
- 5 módulos backend completos (auth, usuarios, admin, comercios, prestadores) + social (Etapa 1)
- App Flutter client con **login funcional end-to-end**
- App Flutter client con **persistencia de sesión funcional**
- Home con datos reales (nombre, email, rol ADMIN)
- Flujo verificado: Google Sign-In → Firebase → backend → JWT → Home
- **114 tests automatizados** (78 unit + 36 con DB) - todos verdes
- **Modulo social (Etapas 1-6)** desplegado: OAuth FB + worker + IG + prestadores + admin frontend

**Lo que queda pendiente inmediato:**
1. **Rotar secretos expuestos** (pendiente desde 2026-10-08)
2. 🚨 **Rotar secretos expuestos** (ver sección "Secretos expuestos") — CRÍTICO
   - Prioridad alta: `SECRET_KEY` (JWT), frase GPG de backups, GitHub PAT viejo
   - **Nuevo:** `POSTGRES_PASSWORD` expuesto en chat 2026-10-08
3. **Features core restantes**: mapa, delivery, carta QR, recompensas
4. **Diferenciar Home admin** del Home client (ahora comparten `home_screen.dart`)

**Lo que falta por construir:**
- Features core (mapa, delivery, carta QR, recompensas) — Fase 3.6
- CI/CD (GitHub Actions) — Fase 4
- Play Store setup — Fase 5
- DNS cutover + SSL — Fase 6
- Decommission server viejo — Fase 7

---

## 🚀 Cómo retomar en un chat nuevo

**Al inicio del nuevo chat, pegar este documento completo.**

Luego, los primeros comandos a correr son:

1. **Verificar estado del repo:**
   ```powershell
   cd D:\dev\baqueano-natales
   git status
   git log --oneline -5
   ```

2. **Verificar server:**
   ```bash
   curl http://104.129.59.151/health
   ```

3. **Verificar emulador (si aplica):**
   ```powershell
   cd D:\dev\baqueano-natales\flutter
   flutter devices
   ```

**Con esto, se retoma el trabajo exactamente donde quedó.**

---

## 📝 Convenciones de código

**Backend (Python):**
- Estructura por módulos de dominio
- Async/await en todo
- Pydantic para validación
- SQLAlchemy 2.0 style (Mapped, mapped_column)
- Logs JSON estructurados

**Flutter (Dart):**
- Feature-first
- Riverpod para state
- GoRouter para navegación
- Nombres: `snake_case` archivos, `PascalCase` clases
- Lints: `flutter_lints: ^5.0.0`

**Commits Git:**
- `feat:` nueva feature
- `fix:` corrección
- `docs:` documentación
- `refactor:` sin cambio funcional
- `test:` tests
- `chore:` tareas varias

**Regla de oro de secretos:**
- `.env` → NUNCA al repo
- `secrets/` → NUNCA al repo
- `*.jks`, `*.keystore` → NUNCA al repo
- `google-services.json` → **SÍ va al repo** (es config pública)

---

## 🔨 Módulo `prestadores` — estado actual (v2 + pantallas dueño)

| Componente | Estado |
|---|---|
| Backend (modelos + migración) | ✅ |
| Backend (schemas + services + routes) | ✅ |
| Backend (seed + prestador modelo) | ✅ |
| Frontend (modelos + repo + providers) | ✅ |
| Frontend (lista cliente + detalle industrial) | ✅ |
| Fix deep links (WhatsApp, redes) | ✅ |
| Prestador modelo cargado | ✅ "Taller Mecánico del Sur" |
| Pantallas dueño (crear/editar mis prestadores) | ⏳ |
| Pantallas admin (verificar/rechazar + CRUD catálogo) | ⏳ |
| Editor de servicios en frontend (dueño) | ⏳ |
| Upload de portada + galería | ⏳ |
| **Pantallas dueño (listar + detalle)** | ✅ |
| **Formulario crear/editar** | ⏳ placeholder |
| **Editor de servicios** | ⏳ placeholder |

**Ruta del módulo:** `backend/app/modules/prestadores/` y `flutter/lib/features/prestadores/`
**Tablas:** `categorias_oficio`, `prestadores`, `prestador_servicios`, `fotos_trabajo`
**Prestador modelo:** `taller-mecanico-del-sur` (accesible en `GET /api/v1/prestadores/taller-mecanico-del-sur`)

| Componente | Estado |
|---|---|
| Capa reutilizable (`mixins` + `slug`) | ✅ |
| Modelos SQLAlchemy | ✅ |
| Migración aplicada en producción | ✅ |
| Schemas Pydantic | ✅ |
| Services | ✅ |
| Deps | ✅ |
| Routers | ✅ |
| Seed de categorías base | ✅ |
| Integración `main.py` | ✅ |
| Deploy + verificación en producción | ✅ |
| Frontend Flutter (cliente + dueño + admin) | ⏳ Próxima sesión |

**Ruta del módulo:** `backend/app/modules/prestadores/`
**Tablas:** `categorias_oficio`, `prestadores`, `fotos_trabajo`
**Categorías base seedeadas:** 11 (Mecánica automotriz, Electricidad, Gasfitería, Carpintería, Albañilería, Pintura, Cerrajería, Jardinería, Limpieza, Fletes y mudanzas, Otros oficios)

**Endpoints activos:**
- Público: `GET /api/v1/prestadores`, `/prestadores/categorias`, `/prestadores/{slug}`
- Dueño: `POST/GET/PATCH/DELETE /api/v1/mis-prestadores`, `/mis-prestadores/{id}/fotos`, `/mis-prestadores/{id}/enviar-revision`
- Admin: `GET/POST/PATCH/DELETE /api/v1/admin/categorias-oficio`, `/admin/prestadores/{id}/verificar|rechazar|suspender|destacar`

---

---

## Modulo `social` - estado actual (9/9 etapas completas)

Publicación en redes sociales (Facebook, Instagram, Google Business) con
multi-tenant por recurso y tokens cifrados.

| Componente | Estado |
|---|---|
| Backend (modelos + migración) | ✅ |
| Backend (crypto Fernet) | ✅ |
| Backend (schemas + services + deps) | ✅ |
| Backend (router admin + 15 endpoints) | OK |
| Backend (README del módulo) | ✅ |
| Tests (114: 78 unit + 36 con DB) | OK |
| Deploy en producción | ✅ |
| **Etapa 2 (OAuth Facebook)** | backend + smoke test end-to-end OK |
| Etapa 3 (publicacion FB con worker) | worker in-process + smoke test real OK |
| Etapa 4 (Instagram via FB) | instagram_service + smoke test real OK |
| Etapa 5 (integracion con prestadores) | eventos + smoke test real OK |
| Etapa 6 (frontend admin) | 3 pantallas Flutter + filtros OK |
| Etapa 8 (Google Business Profile) | codigo listo, gateado por flag (espera aprobacion API) |
| Etapa 9 (modulo promocion) | 5 plantillas SVG + editor + preview OK |

**Ruta:** `backend/app/modules/social/` y `backend/app/core/crypto.py`

**Tablas:** `cuentas_sociales`, `tokens_sociales`, `publicaciones_sociales`, `config_social`

**Enums de Postgres:** `red_social`, `propietario_tipo_social`, `destino_publicacion`, `estado_publicacion`

**Endpoints (admin, 10 total):**
```nGET/POST         /api/v1/admin/social/cuentas
GET/PATCH/DELETE /api/v1/admin/social/cuentas/{id}
GET/PATCH        /api/v1/admin/social/config
GET/POST         /api/v1/admin/social/publicaciones
GET              /api/v1/admin/social/publicaciones/{id}
```

**Migraciones aplicadas:**
- `3a833c2fff44` — tablas del módulo social
- `d16ad0e2b9dc` — índice único parcial de config global
- `3baba5a761b4` — recrear índice con `NULLS NOT DISTINCT`

**Variable crítica:** `TOKEN_ENCRYPTION_KEY` (clave Fernet, 44 caracteres)
en `~/baqueano-natales/.env` del server. Sin ella el backend **no arranca
en producción**.

---

**Fin del documento de contexto.**