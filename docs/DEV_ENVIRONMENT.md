# Entorno de desarrollo - Baqueano Natales

> **Última actualización:** 2026-10-15
> **Propósito:** documentar el hardware, software y optimizaciones del
> entorno de desarrollo en Windows. Sirve para:
> - Retomar el proyecto en otra PC.
> - Diagnosticar lentitud inesperada.
> - Replicar el setup en un dev nuevo.
> - Saber qué está excluido de Defender y por qué.

---

## Hardware

| Componente | Valor |
|---|---|
| **CPU** | Intel Core i5-9300H @ 2.40 GHz (4 cores / 8 threads) |
| **RAM** | 19.84 GB |
| **Disco C:** | 237 GB (SSD del sistema, Windows + apps) |
| **Disco D:** | 222 GB (proyecto + Flutter SDK + caches) |
| **GPU 1** | Intel UHD Graphics 630 (integrada) |
| **GPU 2** | NVIDIA GeForce GTX 1050 (3 GB dedicada) |

**Nota:** la GTX 1050 ayuda al emulador de Android (si se usa `-gpu host`),
pero en este proyecto preferimos `-gpu swiftshader_indirect` por
estabilidad visual.

---

## Software

| Herramienta | Versión | Ubicación |
|---|---|---|
| **Flutter SDK** | 3.47.6 (stable) | `D:\dev\flutter` |
| **Dart** | 3.13.5 | (bundleado con Flutter) |
| **PUB_CACHE** | - | `D:\DartCache` (via env var) |
| **Git** | 2.56.0.windows.2 | - |
| **Java (JDK)** | 25.0.2 LTS | Android Studio bundleado |
| **Android SDK** | API 37, build-tools 36.0.0 | `D:\Android\Sdk` |
| **Android Studio** | 2026.2.1 Rabbit | - |
| **VS Code** | 1.140.0 | + extensiones del workspace (ver `VSCODE_SETUP.md`) |
| **Docker** | No instalado en Windows | (backend usa el del server via SSH) |
| **MobaXterm** | 26.0 | Solo para SSH al server |

**Nota sobre Docker:** no instalamos Docker Desktop en Windows porque
el backend corre íntegramente en el server (`104.129.59.151`). Ahorra
~4 GB de RAM y ~10 GB de disco en la PC.

---

## Reglas de uso del entorno

### Flutter → VS Code (nunca MobaXterm)

**Nunca** correr Flutter desde MobaXterm. La terminal de MobaXterm hereda
variables MSYS (`/drives/d/...`) que rompen el script interno
`update_engine_version.ps1` con `Unable to determine engine version`.

**Siempre** usar la terminal integrada de VS Code (PowerShell nativo).

### Backend → MobaXterm (SSH al server)

Todo el backend se edita por SSH (MobaXterm o terminal de Windows con ssh).
**Nunca** clonar backend en Windows para desarrollo.

### Regla de oro

> Backend por SSH, Flutter en Windows. **No mezclar.**

---

## Optimizaciones aplicadas (2026-10-15)

### 1. Windows Defender — Exclusiones

**Problema:** Defender escaneaba cada archivo que Flutter/Dart/Gradle escribían
(miles por segundo durante builds). Impacto medido:
- `MsMpEng` acumuló **~2400s de CPU** en una sesión de trabajo.
- `flutter analyze` tardaba entre **10s y 266s** según la corrida.

**Fix aplicado:** exclusiones de Defender (PowerShell como admin).

    Add-MpPreference -ExclusionPath 'D:\dev'
    Add-MpPreference -ExclusionPath 'D:\DartCache'
    Add-MpPreference -ExclusionPath 'D:\Android'
    Add-MpPreference -ExclusionPath "$env:USERPROFILE\.gradle"
    Add-MpPreference -ExclusionPath "$env:USERPROFILE\.android"
    Add-MpPreference -ExclusionPath "$env:LOCALAPPDATA\Google\AndroidStudio*"

    # Procesos
    Add-MpPreference -ExclusionProcess 'dart.exe'
    Add-MpPreference -ExclusionProcess 'flutter.exe'
    Add-MpPreference -ExclusionProcess 'java.exe'
    Add-MpPreference -ExclusionProcess 'gradle.exe'
    Add-MpPreference -ExclusionProcess 'emulator.exe'
    Add-MpPreference -ExclusionProcess 'qemu-system-x86_64.exe'
    Add-MpPreference -ExclusionProcess 'adb.exe'

**Verificar exclusiones:**

    (Get-MpPreference).ExclusionPath
    (Get-MpPreference).ExclusionProcess

**Impacto medido:** `flutter analyze` pasó de 10-266s a **4,87s**.

### 2. VS Code — settings.json

Optimizaciones aplicadas en `.vscode/settings.json` (versionado):

- `files.exclude`: oculta `.dart_tool`, `build`, `.flutter-plugins`.
- `search.exclude`: busca sin escanear `build/` ni `*.g.dart`.
- `dart.analysisExcludedFolders`: analyzer no escanea android/ios/web.
- `explorer.fileNesting`: agrupa archivos generados con su padre.
- `terminal.integrated.scrollback`: 10000 (antes 1000).
- `editor.formatOnSave`: formatea y organiza imports al guardar.

### 3. Limpieza de disco C:

El disco C: estaba al 14% libre (crítico, Windows se ralentiza).
Se liberaron **20,8 GB**:

| Acción | GB liberados |
|---|---|
| Downloads (instaladores ya usados) | 6,74 |
| Downloads (Mitchell OnDemand → D:) | 4,09 |
| VirtualBox VM Win10_ATorch (borrada) | 12,2 |

Estado final: C: pasó de **33,4 GB → 54,2 GB libres** (14% → 22,8%).

---

## Troubleshooting

### PC se pone pesada de repente

Verificar procesos del emulador colgados:

    Get-Process | Where-Object { $_.ProcessName -match 'emulator|qemu|adb|crashpad' }

Si hay un `qemu-system-x86_64` con CPU acumulada alta (>500s) → está colgado.
Matar todo:

    Get-Process -Name 'qemu-system-x86_64','emulator','crashpad_handler','adb' -ErrorAction SilentlyContinue | Stop-Process -Force

### flutter analyze muy lento (>30s)

1. Verificar que las exclusiones de Defender siguen activas (ver arriba).
2. Verificar que no hay procesos zombis del analysis server:

       Get-Process | Where-Object { $_.ProcessName -match 'dart' }

3. Reiniciar VS Code si persiste.

### Emulador Android no bootea / se queda en el logo

- El AVD `Pixel6_API34_Play` puede tener snapshot corrupto.
- Probar con `-wipe-data -gpu host` (arranque limpio, GPU nativa).
- Si persiste, recrear el AVD desde Android Studio.
- **Regla:** antes de lanzar el emulador, verificar que no haya uno colgado.

### "Unable to determine engine version" al correr flutter

Estás corriendo Flutter desde MobaXterm o una terminal con variables MSYS.
**Fix:** usar la terminal integrada de VS Code (PowerShell nativo).

---

## Changelog de este documento

- **2026-10-15**: creación inicial. Diagnóstico + exclusiones Defender +
  limpieza C: + reglas de uso.
