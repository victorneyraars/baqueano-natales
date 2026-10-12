# Operativa de desarrollo — Baqueano Natales

> **Última actualización:** 2026-10-12
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
8. **Tests con DB:** importar modelos relacionados antes.
9. **Flutter:** flutter analyze despues de cada cambio.
10. **Cierre de sesion:** actualizar CONTEXTO_PROYECTO.md.
11. **Here-strings:** no poner el cierre al inicio de linea dentro del contenido.

---

**Fin del documento.**