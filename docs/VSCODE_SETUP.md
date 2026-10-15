# VS Code Setup - Baqueano Natales

Configuracion de VS Code versionada en `.vscode/` para garantizar un
entorno de desarrollo identico entre todos los devs.

## Como abrir el proyecto

1. Abrir VS Code.
2. `File -> Open Folder...` -> `D:\dev\baqueano-natales` -> Open.
3. Aceptar el popup de "Extensiones recomendadas" (instala las 11 de
   `.vscode/extensions.json` automaticamente).

## Extensiones incluidas

- **Dart-Code.dart-code** + **Dart-Code.flutter** - las oficiales.
- **usernamehw.errorlens** - errores inline.
- **eamodio.gitlens** - blame e historial sin salir del editor.
- **streetsidesoftware.code-spell-checker** + **-spanish** - spell check
  con diccionario en espanol.
- **jeroen-meijer.pubspec-assist** - ayuda al editar pubspec.yaml.
- **alexisvt.flutter-snippets** + **nash.awesome-flutter-snippets** -
  atajos de widgets.
- **pflannery.vscode-versionlens** - versiones de deps inline.
- **redhat.vscode-yaml** - lint + formato de YAML.

## Debug (F5)

Elegir el flavor en el dropdown de arriba:

| Config | Entry point | Flavor |
|---|---|---|
| Client Dev | lib/main_client.dart | clientDev |
| Client Prod (debug) | lib/main_client.dart | clientProd |
| Admin Dev | lib/main_admin.dart | adminDev |
| Admin Prod (debug) | lib/main_admin.dart | adminProd |

## Tareas (Ctrl+Shift+B o Ctrl+Shift+P -> "Tasks: Run Task")

- **Flutter: analyze** (default, Ctrl+Shift+B)
- **Flutter: analyze --fatal-infos** (para CI)
- **Flutter: pub get**
- **Flutter: clean**
- **Flutter: test**
- **Flutter: build APK (clientDev debug)**
- **Flutter: build AAB (adminProd release)**

## Formato automatico

Al guardar, VS Code:
- Formatea con `dart format` (line length 100).
- Organiza imports.
- Aplica fixes automaticos (`source.fixAll`).

## Lints

Reglas en `flutter/analysis_options.yaml`. Cambios afectan a todo el
equipo. Para proponer una regla nueva: PR + justificacion en el commit.

## Overrides personales

Cada dev puede crear `.vscode/settings.local.json` (gitignored) para
preferencias personales (fuente, tema, etc.) sin pisar la config del
equipo.

## Troubleshooting

**"dubious ownership in repository"** en la terminal de VS Code:
La terminal hereda variables de MobaXterm/MSYS que rompen Flutter. FIX:
cerrar VS Code, abrirlo desde el menu de Windows (no desde MobaXterm), o
borrar la variable `MSYSTEM` antes de abrir VS Code.

**"Unable to determine engine version"**:
Idem anterior. No usar MobaXterm para Flutter; solo para el server.

**`flutter: command not found`**:
Verificar que `D:\dev\flutter\bin` este en el PATH del sistema (User env
vars). Si no, agregarlo y reiniciar VS Code.