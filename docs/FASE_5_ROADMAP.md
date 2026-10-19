# Fase 5 — Roadmap de Mejoras (Release Hub v2)

**Estado:** Pendiente de inicio (priorizado por valor/esfuerzo).

## 🎯 Mejoras priorizadas

### 🥇 1. Validación SHA-256 en el cliente (SEGURIDAD — 2h)
**Estado:** 🔴 Pendiente
**Objetivo:** El cliente calcula el SHA-256 del APK descargado y lo compara con el del `version.json` antes de instalar.
**Impacto:** Estándar de oro de Play Store/F-Droid. Previene APKs corruptos o manipulados.
**Archivos a tocar:** `app_update_service.dart` (agregar `crypto`, calcular hash, comparar, abortar si difiere).

### 🥈 2. Historial de builds + Rollback (OPS — 4h)
**Estado:** 🔴 Pendiente
**Objetivo:** Endpoint `/apks-history` que lista APKs del `archive/`. Pantalla en Ops Admin con botón "Instalar" por versión.
**Impacto:** Si un build rompe algo, rollback en 2 toques sin SSH.
**Archivos a tocar:** Backend (`routes.py`), Flutter (`ops_admin/presentation/screens/`), nuevo `apks_history_screen.dart`.

### 🥉 3. URL corta para compartir (UX — 1h)
**Estado:** 🟢 En Sesión 1
**Objetivo:** `sealquilamarido.com/app` → APK. `baqueanonatales.com/app` → APK.
**Impacto:** Link memorable, profesional, intercambiable sin cambiar el link.
**Archivos a tocar:** `se-alquila-marido-web/src/pages/app.astro` + equivalente en baqueanonatales web.

### 🏅 4. Página pública /descargar con detección de SO (MARKETING — 4h)
**Estado:** 🔴 Pendiente
**Objetivo:** Landing que detecta Android/iOS/Desktop y ofrece la opción correcta.
**Impacto:** Landing de app indexada por Google.
**Archivos a tocar:** `se-alquila-marido-web/src/pages/descargar.astro`.

### 🎖️ 5. Stats de descargas (ANALYTICS — 2h)
**Estado:** 🔴 Pendiente
**Objetivo:** Contador de descargas del APK (nginx log o endpoint `/apks/download`).
**Impacto:** Saber cuántas instalaciones reales existen.
**Archivos a tocar:** Backend o nginx config.

### 🎗️ 6. Notificaciones Push al terminar build (OPS — 1 día)
**Estado:** 🔴 Pendiente
**Objetivo:** Workflow GitHub → push FCM al admin al terminar (success/failure).
**Impacto:** Disparar build y cerrar el celular, sin `gh run watch`.
**Archivos a tocar:** `dev-build.yml` (último step), backend, `main_admin.dart` (FCM listener).

### 🛡️ 7. Verificación de firma APK (SEGURIDAD AVANZADA — 3h)
**Estado:** 🔴 Pendiente
**Objetivo:** Comparar el certificado de firma del APK con el fingerprint del keystore de Play Store.
**Impacto:** Última línea de defensa, incluso si el servidor es comprometido.
**Archivos a tocar:** `app_update_service.dart`, backend (fingerprint en env).

---

## 🚀 Sesión 1 (a ejecutar hoy)

1. **Validación SHA-256 en cliente** (`app_update_service.dart`).
2. **URL corta `/app`** en sealquilamarido.com y baqueanonatales.com.

## 📅 Sesión 2 (próxima)

3. **Historial de builds con rollback**.

## 📅 Sesión 3 (opcional)

4. **Página pública `/descargar`**.

---

**Doc generado 2026-10-19.** Próximo paso: validar build #37, luego Sesión 1.
