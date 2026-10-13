# Operativa de desarrollo — Baqueano Natales

> **Última actualización:** 2026-10-13
> **Propósito:** documentar la metodología de trabajo acordada, patrones
> canónicos de comandos, reglas por dominio y workflow dual-repo, para
> retomar el proyecto en cualquier chat nuevo sin perder rigor ni repetir
> bugs ya resueltos.

---

## 1. Principios generales

- **Paso a paso, un cambio por vez.** No aplicar 2 cambios sin verificar
  el primero. Menos debugging, más confianza.
- **Verificar cada paso antes de avanzar.** Esperar output esperado o
  inesperado y ajustar.
- **Archivos completos listos para Ctrl+A → Ctrl+V**, no fragmentos que
  el usuario tenga que ensamblar mentalmente.
- **Confirmar antes de acciones destructivas** (borrar, migrar, forzar).
- **Documentar la decisión** (ADR o changelog) cuando se toma un camino
  no obvio.
- **Nunca romper el estado actual** sin plan de rollback.

---

## 2. Workflow dual-repo

El proyecto tiene **dos entornos de edición** y **un solo repo GitHub**:

| Qué edito | Dónde edito | Dónde commiteo |
|---|---|---|
| Backend (backend/) | En el server via SSH | Desde el server via SSH |
| Flutter (flutter/) | En Windows | Desde Windows |
| Docs raíz | Windows | Windows |

### Regla de oro: pull --rebase antes de cada push

```
cd D:\dev\baqueano-natales    # o en el server
git pull --rebase origin main
git push origin main
```

Si el push es rechazado (`! [rejected]`), es porque el otro lado pusheó
antes. **No** forzar. Hacer pull --rebase y push de nuevo.

### Pitfall critico

**El repo de Flutter en el server (/home/deploy/baqueano-natales/flutter/)
NO es el mismo que el de Windows (D:\dev\baqueano-natales\flutter\).**

Si edito un archivo Flutter via ssh + python en el server y luego corro
flutter analyze en Windows, **el cambio no se ve** porque son dos copias
distintas.

**Regla:** para Flutter, SIEMPRE editar en Windows. Para backend, SIEMPRE
editar en el server.

### Servidor nuevo: 2 entornos aislados (prod + dev)

El server nuevo (`104.129.59.151`) corre **dos entornos productivos en
paralelo** (ver `SERVER_CHEATSHEET.md` para detalle completo).

| Container | Env file | DB | Subdominio |
|---|---|---|---|
| `baqueano_backend_prod` | `.env.prod` | `baqueano_natales_prod` | `api.baqueanonatales.com` |
| `baqueano_backend_dev` | `.env.dev` | `baqueano_natales_dev` | `api-dev.baqueanonatales.com` |

Comandos canonicos (usar los scripts, no `docker compose` directo):

    scripts/prod-up.sh [--build]      # levantar prod
    scripts/dev-up.sh [--build]       # levantar dev
    scripts/all-up.sh [--build]       # levantar ambos
    scripts/prod-down.sh              # bajar solo prod
    scripts/dev-down.sh               # bajar solo dev
    scripts/prod-restart.sh           # reiniciar sin recrear
    scripts/dev-restart.sh
    scripts/prod-logs.sh [N]          # logs en vivo
    scripts/dev-logs.sh [N]
    scripts/status.sh                 # estado consolidado

Migraciones Alembic:

    docker exec baqueano_backend_prod alembic upgrade head
    docker exec baqueano_backend_dev alembic upgrade head

**Regla:** siempre que se cambie codigo de backend, decidir explicitamente
si el cambio va a prod, a dev, o a ambos.

### Usuarios Postgres por entorno (minimo privilegio)

    baqueano_user         -> Superuser bootstrap (solo admin manual)
    baqueano_prod_user    -> Solo baqueano_natales_prod
    baqueano_dev_user     -> Solo baqueano_natales_dev
    baqueano_test_user    -> Solo baqueano_natales_test

Los backends usan su propio usuario via `DATABASE_URL` del `.env` correspondiente.
NUNCA usar `baqueano_user` desde la app.

---

## 3. Patrones canonicos de comandos

### 3.1. Comando simple de una linea (SSH)

    ssh deploy@104.129.59.151 "cd ~/baqueano-natales && git status"

### 3.2. Script multi-linea (here-string + replace CRLF)

**Regla:** SIEMPRE hacer `-replace CRLF por LF` antes de mandar por SSH.
Windows usa CRLF, bash usa LF. Sin el reemplazo, comandos como `git log -3`
o `head -20` fallan con `'3?': not a non-negative integer`.

Patron PowerShell:

    $script = here-string-single-quoted-inicio
    cd ~/baqueano-natales
    git log --oneline
    here-string-single-quoted-fin
    $script = $script -replace "`r`n", "`n"
    $script | ssh deploy@104.129.59.151 'bash -s'

(En la practica: usar el here-string literal de PowerShell. Ver ejemplo en
el archivo CONTEXTO_PROYECTO.md, que usa el patron correcto.)

### 3.3. Python via stdin (para edicion de archivos compleja)

Cuando hay que editar archivos en el server, usar Python via stdin (evita
here-doc anidado que rompe por CRLF):

    $py = here-string-python-inicio
    import pathlib
    path = pathlib.Path("/home/deploy/baqueano-natales/backend/app/main.py")
    content = path.read_text(encoding="utf-8")
    content = content.replace("viejo", "nuevo")
    path.write_text(content, encoding="utf-8")
    print("OK")
    here-string-python-fin
    $py = $py -replace "`r`n", "`n"
    $py | ssh deploy@104.129.59.151 "python3 -"

### 3.4. Escritura de archivos en Windows (UTF-8 sin BOM)

**NUNCA usar Set-Content** — PowerShell 5.1 escribe en Windows-1252 por
defecto y rompe emojis, acentos, enie.

    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($path, $content, $utf8NoBom)

Si hay que leer un archivo con posible BOM, usar `encoding="utf-8-sig"` en
Python, o `Get-Content -Encoding UTF8` en PowerShell.

### 3.5. Replace de string: SIN count

**.Replace(a, b, 1) NO existe en .NET.** Es 2-arg:

    $text = $text.Replace($old, $new)   # reemplaza TODAS las ocurrencias

Si hace falta reemplazar solo la primera, usar regex:

    $regex = [regex]::Escape($old)
    $text = [regex]::Replace($text, $regex, $new, 1)

### 3.6. Evitar here-strings que se cierran prematuramente

Un here-string `@'...'@` se cierra con `'@` al inicio de linea. Si el
CONTENIDO del here-string incluye un `'@` al inicio de linea (por ejemplo,
porque estas documentando otro here-string), el here-string se cierra ahi
y el resto se interpreta como comandos de PowerShell.

**Reglas para no romper:**
- Nunca poner `'@` al inicio de linea dentro del contenido.
- Si hay que mostrar un ejemplo de here-string, indentarlo o poner texto
  antes (`(aqui va un here-string)`).
- Alternativa: usar bloques de AppendAllText para escribir por partes.
---


### 3.7. Verificar SIEMPRE que la edicion se aplico

**Regla de oro:** despues de cualquier edicion por Python via stdin o por
`[System.IO.File]::WriteAllText`, **verificar con `grep -c`** que una marca
unica del nuevo contenido esta presente en el archivo.

**Por que:** el patron `$py = @'...'@ ; $py | ssh python3 -` puede fallar
**silenciosamente** con bloques largos (>100 lineas o >5 KB):

- Windows PowerShell 5.1 trunca heredocs largos en algunos casos.
- El heredoc se cierra prematuramente si el contenido tiene un `'@` al
  inicio de linea (ver seccion 3.6).
- La consola puede comerse parte del bloque al copiar/pegar.

**Sintoma:** el comando termina sin error, pero el archivo NO cambio.

**Mitigacion (patron canonico - ACTUALIZADO 2026-10-12):**

**Regla de oro: para scripts Python > 1 KB, SIEMPRE usar base64.** El
pipe `$py | ssh "cat > /tmp/x.py"` se trunca silenciosamente con
contenido largo (>1 KB), y ademas puede romperse por CRLF o por
caracteres especiales. Base64 es a prueba de balas.

Patron canonico (Windows PowerShell):

    $py = @'
    # script python aqui
    '@
    $py = $py -replace "`r`n", "`n"
    $b64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($py))
    ssh deploy@104.129.59.151 "echo '$b64' | base64 -d > /tmp/m.py && python3 /tmp/m.py; rm -f /tmp/m.py"

Para correr **dentro del container** (con sus deps, ej. blurhash):

    ssh deploy@104.129.59.151 "echo '$b64' | base64 -d > /tmp/m.py && cd ~/baqueano-natales && docker compose exec -T backend python3 - < /tmp/m.py; rm -f /tmp/m.py"

Patron viejo (funcionaba solo con scripts cortos):

1. Escribir el script Python a un archivo temporal con
   `[System.IO.File]::WriteAllText($path, $pyContent, (New-Object System.Text.UTF8Encoding($false)))`.
2. Ejecutar `python archivo_temporal.py`.
3. **Verificar con `grep -c '<marca_unica>' archivo_editado'`** — debe
   devolver al menos `1`.
4. Borrar el temporal.

Si `grep -c` devuelve `0`, el bloque no se aplico: reejecutar.

---


### 3.8. `docker compose config` imprime TODOS los secretos

**Regla:** NUNCA correr `docker compose config` sin censurar. El comando
resuelve las variables del `.env` y las imprime en el output. Es un leak
silencioso de todos los secretos.

    # MAL: filtra todo
    docker compose config

    # BIEN: solo metadatos
    docker compose config --services
    docker compose config --volumes

    # BIEN: filtrar el output
    docker compose config | grep -vE "(SECRET|PASSWORD|TOKEN|KEY|PASSPHRASE|DATABASE_URL|APP_SECRET)"

### 3.9. `docker exec` vs `docker compose exec` en scripts `bash -s`

Cuando se manda un script multi-linea por SSH (`bash -s`), usar `docker exec <container>`
(sin `compose`). El `docker compose exec -T` consume stdin y bloquea el resto
del script. Ademas, agregar `< /dev/null` como cinturon de seguridad.

Patron canonico para `pg_dump`:

    # 1. Dump dentro del container (evita SIGPIPE)
    docker exec baqueano_db pg_dump -U <user> -d <db> -f /tmp/dump.sql < /dev/null

    # 2. Copiar al host
    docker cp baqueano_db:/tmp/dump.sql /tmp/dump.sql

    # 3. Comprimir
    gzip -c /tmp/dump.sql > backup.sql.gz

NO usar `docker compose exec -T db pg_dump ... | gzip` porque:
- El pipe puede cerrar temprano (SIGPIPE) y matar la sesion SSH.
- El pipe se trunca silenciosamente con contenido largo.

### 3.10. Permisos de volumenes Docker nuevos

Cuando Docker crea un volumen vacio (ej. `media_data_prod`), lo monta con
owner `root:root`. Si el container corre como `appuser` (uid 1000), falla
con `PermissionError` y entra en restart loop.

Fix one-time:

    docker run --rm -v baqueano-natales_media_data_prod:/mnt alpine \
      sh -c "mkdir -p /mnt/avatars /mnt/afiches && chown -R 1000:1000 /mnt && chmod -R 755 /mnt"

## 4. Reglas por dominio

### 4.1. Migraciones Alembic

**Siempre** los autogenerate detectan **server_default falsos** en
usuarios.* (rol, verificado, activo, tiene_google, tiene_whatsapp,
tiene_sms). **Removerlos a mano** de cada migracion generada antes de
aplicarla.

Patron (Python):

    import re
    content = path.read_text()
    upgrade_pattern = "\\n    op\\.alter_column\\('usuarios', 'rol',.*?existing_nullable=False\\)\\n..."
    content = re.sub(upgrade_pattern, "\\n", content, count=1, flags=re.DOTALL)

Verificar al final: `content.count("op.create_table")` debe ser la cantidad
de tablas nuevas + `content.count("'usuarios'")` debe ser 0.

### 4.2. SQLAlchemy: populate_existing en obtener_orden

Cuando se devuelve una orden con items + historial y esa orden ya estaba
en el identity map (por un flush reciente), los selectinload NO refrescan
la instancia. **Aplicar .execution_options(populate_existing=True)** al
statement:

    stmt = (
        select(OrdenTrabajo)
        .where(OrdenTrabajo.id == orden_id)
        .options(
            selectinload(OrdenTrabajo.items),
            selectinload(OrdenTrabajo.historial),
        )
        .execution_options(populate_existing=True)
    )

Bug clasico (ya arreglado en M2): aprobar_presupuesto veia items=[] stale

**Refresh post-flush (bug detectado 2026-10-12):** despues de
`await db.flush()` en un service, los objetos ORM quedan **expirados**.
Cualquier acceso a un atributo (incluido `updated_at`, `created_at`, o
relaciones lazy) dispara IO sincronico -> `MissingGreenlet`.

Fix: `await db.refresh(obj)` antes de serializar.

Patron:

    async def actualizar_vehiculo(db, usuario, objeto_id, data):
        obj, veh = await _obtener_objeto_propietario(db, usuario, objeto_id)
        # ... modificar campos ...
        await db.flush()
        # Refrescar antes de serializar (evita MissingGreenlet)
        await db.refresh(obj)
        await db.refresh(veh)
        return _vehiculo_a_response(obj, veh)

Detectado por `test_routes_vehiculos.py::test_actualizar_vehiculo` (PATCH
/mis-vehiculos fallaba con 500 en produccion).


**REGLA GENERAL (auditoria 2026-10-12):** en el modulo oficios, **TODO
endpoint** que serialice una entidad ORM despues de un service mutador
(`crear_*`, `actualizar_*`, `cambiar_*`, `rechazar_*`, `cancelar_*`,
`agregar_*`) DEBE hacer `await db.refresh(entidad)` antes de
`Model.model_validate(entidad)` o `_serializar_*`. Sin el refresh, el
objeto queda expirado post-flush y cualquier acceso a `created_at`,
`updated_at` o relaciones lazy dispara `MissingGreenlet`.

**Excepcion segura:** si el service devuelve la entidad recargada con
`selectinload + populate_existing` (patron de `obtener_orden`), o si el
route handler vuelve a llamar a un `services.obtener_*` despues del
mutador, no hace falta el refresh explicito.

**Auditoria 2026-10-12:** se encontraron 14 endpoints con el patron
riesgoso en `routes.py`. Todos corregidos. Si agregas un endpoint nuevo,
agrega el `await db.refresh` si sigue este patron.

**AUDITORIA CROSS-MODULO (2026-10-12):** el mismo patron aparecio en
**7 endpoints mas** de otros modulos (comercios, prestadores, social).
Todos corregidos en commit `6800704`. Los mas criticos eran
`actualizar_cuenta` y `actualizar_config` (social), porque son UPDATE
(no zafan con RETURNING). Los `crear_*` los cubrimos defensivamente.

**Regla global del proyecto (aplica a TODOS los modulos):**
despues de un service mutador (`crear_*`, `actualizar_*`, `cambiar_*`,
`rechazar_*`, `cancelar_*`, `agregar_*`), si el route handler va a
serializar la entidad con `Model.model_validate(obj)` o un
`_serializar_*(obj)`, **SIEMPRE** hacer `await db.refresh(obj)` antes.
El refresh es no-op si el objeto ya esta cargado, asi que no rompe nada.

**Excepcion:** si el service devuelve la entidad recargada con
`selectinload + populate_existing`, o si el route handler vuelve a
pedirla con un `services.obtener_*`, no hace falta el refresh explicito.

Patron canonico:

    @router_algo.patch("/{id}")
    async def actualizar_x(id, data, user, db):
        obj = await services.actualizar_x(db, id, user, data)
        await db.refresh(obj)   # <-- evita MissingGreenlet
        return XResponse.model_validate(obj)
y marcaba la orden como RECHAZADA. Los tests lo detectaron.

### 4.3. Tests con DB (pytest)

- Los tests corren contra baqueano_test (DB separada).
- conftest.py raiz: drop_all + create_all al inicio de cada sesion.
- conftest.py raiz: TRUNCATE de tablas de social + oficios antes de cada test.
- **IMPORTANTE:** al crear instancias de modelos con relaciones (ej:
  OrdenTrabajo tiene FK a Usuario y Prestador), hay que importar TODOS los
  modelos relacionados antes de crear la primera instancia. Sin eso,
  SQLAlchemy tira InvalidRequestError: ... failed to locate a name 'X'.

Importar en este orden:

    from app.modules.auth.models import Usuario
    from app.modules.prestadores.models import Prestador
    from app.modules.oficios.models import OrdenTrabajo

### 4.4. Flutter

- **Editar solo en Windows.** Nunca en el server.
- Despues de cada edicion: flutter analyze (siempre).
- Despues de cambios de deps: flutter pub get + flutter build apk --debug
  --flavor client.
- Si dart fix esta disponible: dart fix --apply para warnings auto-fixables
  (unnecessary_underscores, use_null_aware_elements).
- Al agregar imports con Replace, usar anchors que sean unicos en el archivo.
- Cuando un widget interno (ej _Contenido) necesita un callback del State
  padre, **pasarlo por constructor** (no usar widget. dentro del widget
  privado). El widget no tiene acceso a widget.<padre> porque es Stateless.

### 4.5. Workers (APScheduler)

- Workers in-process, mismo event loop que FastAPI (lifespan).
- Siempre try/except en el ciclo: nunca crashear el scheduler.
- Settings pattern: NOMBRE_WORKER_ENABLED (bool) + NOMBRE_WORKER_INTERVAL_SEC (int).
- Wire en main.py lifespan: start_worker() + stop_worker().
- Si el worker tiene una tabla de "pendientes", incluir funcion
  buscar_X_pendientes para tests + endpoint manual.



### 4.9. Firebase CLI disponible desde el server

**Tenemos Firebase CLI logueado con admin en el server nuevo.** Cualquier operacion
de administracion de Firebase (crear apps, SHA, descargar `google-services.json`)
se puede hacer via SSH sin abrir la consola web.

    ssh deploy@104.129.59.151 "firebase <comando> --project baqueano-natales-prod"

Ver `SERVER_CHEATSHEET.md` -> "Firebase CLI en el server" para comandos completos.

**Regla:** si hay que crear una app Firebase nueva, hacerlo desde el server
(no desde la consola web), asi queda documentado en el historial de bash.

### 4.7. FCM (push notifications)

**Servicio transversal:** `app/core/push.py`.

**API:**
- `enviar_push(fcm_token, titulo, body, data=None) -> bool`
- `enviar_push_a_usuario(user_id, titulo, body, data=None, db=None) -> bool`

**Reglas:**
- **Nunca propaga excepciones.** Devuelve `True`/`False`. El caller no
  debe crashear por un push fallido.
- El SDK de FCM es sincrono -> corre con `asyncio.to_thread` para no
  bloquear el event loop.
- Si `FCM_ENABLED=False` (en `Settings`) -> no-op que devuelve `False`.
  Util para tests + fallback si FCM esta caido en produccion.

**Registrar token de un dispositivo:**
- Endpoint `POST /api/v1/usuarios/me/fcm-token` (body `{token: str}`).
- Modelo **single-device**: el token se sobreescribe en cada login. Si en
  el futuro hace falta multi-device, migrar a tabla `fcm_tokens`.

**Tests:**
- Unitarios: mock de `messaging.send` con `unittest.mock.patch`.
  Ejemplo: `with patch("app.core.push.messaging.send", return_value="id"):`
- Integracion: mock de `enviar_push_a_usuario` con `AsyncMock`. Ejemplo:
  `patch("app.core.push.enviar_push_a_usuario", new=AsyncMock(return_value=True))`.

**Deshabilitar globalmente:** `FCM_ENABLED=false` en `.env` + recrear container.

**Gotcha:** el worker marca `enviado=True` ANTES de mandar el push. La
marca es la fuente de verdad. Si el push falla, el recordatorio no se
re-dispara. Esto es intencional: mejor perder 1 push que spamear al user.


**Frontend Flutter:**
- Servicio en `lib/core/fcm/fcm_service.dart` (transversal).
- `main_client.dart` inicializa FCM al arranque (listeners).
- `auth_notifier._registrarFcmAsync()` post-login pide permiso + registra
  token (fire-and-forget, best-effort).
- **Emulador con Play Store obligatorio.** Crear AVD con
  `system-images;android-34;google_apis_playstore;x86_64` via Android
  Studio SDK Manager (el CLI `sdkmanager` falla silenciosamente en la
  version nueva).
- El AVD `Pixel6_API34_Play` requiere **~5 GB libres en D:** para bootear.

**Gotchas conocidos:**
- Los pushes a app en **foreground** NO muestran banner del sistema. El
  listener `onMessage` los captura. Para banner en foreground se necesita
  `flutter_local_notifications` (no implementado).
- Warning `Unable to log event: analytics library is missing` es cosmetico
  (falta `firebase_analytics`, no lo necesitamos).
- Los scripts ad-hoc que usan `AsyncSessionLocal` en un proceso nuevo
  necesitan importar todos los modelos relacionados (gotcha 4.3), o falla
  con `InvalidRequestError: ... failed to locate a name 'Prestador'`.

### 4.8. Arquitectura de notificaciones (app/core/notifications)

**Estructura:**

    app/core/notifications/
    ├── models.py            # FcmToken, PreferenciaNotificacion, NotificationLog
    ├── service.py           # NotificationService (orquestador)
    └── providers/
        ├── base.py          # ABC NotificationProvider + SendResult
        └── fcm.py           # FcmProvider (send + send_batch)

**Como agregar un provider nuevo (APNs, SMS, email):**

1. Crear `providers/<nombre>.py` que herede de `NotificationProvider`.
2. Implementar `send` y `send_batch` devolviendo `SendResult`.
3. Registrar en `providers/__init__.py`.
4. Inyectar en `NotificationService.__init__(provider=TuProvider())`.

Cero cambios al service ni a los callers.

**Pipeline de `enviar_a_usuario`:**

1. Chequea preferencias del usuario (`PreferenciaNotificacion`).
2. Chequea quiet hours (con timezone del usuario).
3. Busca tokens activos (con auto-migracion legacy).
4. Crea `NotificationLog` en estado PENDIENTE.
5. Envia via provider.
6. Actualiza log (enviada/fallida) + limpia tokens invalidos.

**API principal:**
- `service.enviar_a_usuario(db, usuario_id, titulo, body, tipo, ...)` -
  pipeline completo. Usar para notificaciones nuevas.
- `service.enviar_legacy(usuario_id, titulo, body, data, db)` -
  wrapper sin chequeos. Usado por `push.py` (worker).

**Feature flags:**
- `FCM_ENABLED=false` desactiva todo el envio (util en tests + fallback).

**Reglas de diseno:**
- **Nunca propaga excepciones** desde el provider. Siempre devuelve
  `SendResult`.
- Los `NotificationLog` con `estado=SKIPPED` documentan por que no se
  envio (preferencia/quiet_hours/sin_tokens).
- La limpieza de tokens es automatica: `UNREGISTERED`, `SENDER_ID_MISMATCH`
  y `INVALID_ARGUMENT` marcan `FcmToken.activo=False`.

**Roadmap pendiente del sistema:**
- Analytics: tracking de apertura desde Flutter (`POST /notificaciones/{id}/abierta`).
- Preferencias: endpoints `GET/PUT /usuarios/me/preferencias-notificacion`.
- Panel admin: composer + historial + stats.
- Notificaciones in-app: `canal=in_app` ya esta en el enum.

### 4.6. Commits

- Formato: `<tipo>(<scope>): <descripcion corta>` en el primer -m.
- Cuerpo multi-linea con multiples -m (no saltos de linea dentro de un -m).
- Tipos: feat, fix, docs, test, refactor, chore.
- Al commitear backend desde el server, siempre terminar con
  git pull --rebase origin main && git push origin main.
---

## 5. Estructura de una respuesta del asistente

Cuando el usuario pide un cambio, el asistente responde con:

1. **Contexto breve** (que se va a hacer y por que).
2. **Un bloque unico de PowerShell/SSH** listo para copiar y pegar
   (here-string simple, o comando de una linea).
3. **Output esperado** anotado como bloque de codigo.
4. **Instruccion de verificacion** si algo falla ("si ves X, revisa Y").

**No fragmentar** en varios bloques cuando uno solo alcanza. El usuario
hace Ctrl+A -> Ctrl+V -> pega -> output.

---

## 6. Cierre de cada sesion

Al final de una sesion con avances significativos:

1. **Actualizar CONTEXTO_PROYECTO.md** con un nuevo changelog entry
   (formato: `### <fecha> - <titulo corto>` + bullets + commit hashes).
2. **Actualizar docs/SERVER_CHEATSHEET.md** si aparecieron gotchas nuevos.
3. **Actualizar docs/OPERATIVA_DEV.md** (este archivo) si la metodologia
   cambio.
4. **Commit + push** de los docs.
5. **Verificar working tree limpio** al final.

El usuario luego pega el CONTEXTO_PROYECTO.md completo en el proximo chat.

---

## 7. Como retomar en un chat nuevo

**El usuario pega:**
- CONTEXTO_PROYECTO.md (estado completo del proyecto).
- docs/SERVER_CHEATSHEET.md (comandos + credenciales + gotchas).
- docs/OPERATIVA_DEV.md (este archivo).
- Output de 2-3 comandos de verificacion:
  - ssh deploy@... "cd ~/baqueano-natales && git log --oneline -3 && docker compose ps"
  - curl https://dev-api.baqueanonatales.com/health
  - cd D:\dev\baqueano-natales && git log --oneline -3 && git status --short

**El asistente:**
1. Confirma entendimiento del estado.
2. Propone plan por prioridad.
3. Arranca con el primer paso, siempre como bloque listo para copiar.

---

## 8. Archivos clave del repo

| Archivo | Que contiene |
|---|---|
| CONTEXTO_PROYECTO.md | Estado completo (se actualiza cada sesion) |
| docs/SERVER_CHEATSHEET.md | Comandos rapidos, credenciales, gotchas del server |
| docs/OPERATIVA_DEV.md | Este archivo — metodologia + patrones |
| docs/oficios/DISENO.md | Diseno del modulo oficios (5 fases) |
| docs/VISION.md | Vision de superapp multi-vertical |
| docs/ARCHITECTURE.md | Arquitectura tecnica (monolito modular) |
| backend/app/modules/<x>/README.md | Doc por modulo |

---

## 9. Reglas de oro (resumen)

1. **Backend por SSH, Flutter en Windows.** No mezclar.
2. **pull --rebase antes de cada push.**
3. **Nunca Set-Content.** Usar [System.IO.File]::WriteAllText con UTF8 sin BOM.
4. **Nunca .Replace(a, b, 1).** Es 2-arg o usar regex.
5. **Siempre reemplazar CRLF por LF en here-strings SSH.**
6. **Migraciones Alembic:** limpiar los usuarios.* a mano.
7. **SQLAlchemy con relaciones:** .execution_options(populate_existing=True).
8. 
- **Tests HTTP con `ASGITransport`:** ademas de overridear
  `get_current_user`, **SIEMPRE overridear `get_db`** para que la app use
  la MISMA sesion async que el fixture. Sin el override, la app abre su
  propia sesion en otro event loop y SQLAlchemy/asyncpg falla con
  `RuntimeError: Event loop is closed`.

  Patron:

      from app.core.db import get_db

      @pytest_asyncio.fixture
      async def client(db, usuario_cliente):
          async def _override_user():
              return usuario_cliente
          async def _override_db():
              yield db
          app.dependency_overrides[get_current_user] = _override_user
          app.dependency_overrides[get_db] = _override_db
          async with AsyncClient(
              transport=ASGITransport(app=app), base_url="http://test"
          ) as c:
              yield c
          app.dependency_overrides.clear()

  **Ojo:** el `RecordatorioCreate` del modulo oficios requiere
  `objeto_servicio_id` en el body (aunque tambien este en el path). Los
  tests deben mandarlo.

- **Fixture hierarchy en oficios:** `ObjetoServicio` es la tabla base y
  `Vehiculo` extiende (FK a `objeto_servicio_id`). Los services que
  devuelven "vehiculo completo" (detalle, actualizar, eliminar) llaman a
  `_obtener_objeto_propietario`, que espera que existan **ambos**.

  Regla:
  - Tests que solo tocan el `ObjetoServicio` -> usar fixture
    `objeto_servicio_test`.
  - Tests que tocan el "vehiculo completo" -> usar fixture `vehiculo_test`
    (que crea ambos) y pasar `vehiculo_test.objeto_servicio_id` al endpoint.

  Mira el service antes de elegir el fixture. Si llama a
  `_obtener_objeto_propietario` (devuelve tupla `(obj, veh)`), necesita
  `vehiculo_test`.

**Tests con DB:** importar modelos relacionados antes.
9. **Flutter:** flutter analyze despues de cada cambio.
10. **Cierre de sesion:** actualizar CONTEXTO_PROYECTO.md.
11. **Here-strings:** no poner el cierre al inicio de linea dentro del contenido.
---

## 10. Reglas de oro del workflow dual-entorno (resumen)

1. **Backend por SSH, Flutter en Windows.** No mezclar.
2. **`pull --rebase` antes de cada push.**
3. **Un cambio por vez, verificar antes de avanzar.**
4. **Nunca `Set-Content`.** Usar `[System.IO.File]::WriteAllText` con UTF8 sin BOM.
5. **Nunca `.Replace(a, b, 1)`.** Es 2-arg o usar regex.
6. **Siempre reemplazar CRLF por LF en here-strings SSH.**
7. **Scripts Python > 1 KB via SSH: usar base64.**
8. **Migraciones Alembic: limpiar los `usuarios.*` falsos a mano.**
9. **SQLAlchemy post-flush: `await db.refresh(obj)` antes de serializar.**
10. **Tests HTTP con `ASGITransport`: override de `get_db` + `get_current_user`.**
11. **Docker: `docker exec <container>` (no `compose`) dentro de `bash -s`.**
12. **`docker compose config` filtra secretos: censurar SIEMPRE.**
13. **Volumenes nuevos: `chown 1000:1000` antes de levantar el container.**
14. **Prod y dev son entornos separados: usar los scripts `prod-*` / `dev-*`.**
15. **Nunca editar el `.env` viejo. Solo `.env.prod` y `.env.dev`.**
16. **Cierre de sesion: actualizar CONTEXTO_PROYECTO.md + CHEATSHEET + OPERATIVA.**

---

**Fin del documento.**
