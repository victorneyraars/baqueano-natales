# 🧩 Componentes

17 themes configurados en AppTheme. Todos respetan colorScheme + AppThemeExtension.

---

## Navigation

- appBarTheme — AppBar plana, scrolledUnderElevation 1
- tabBarTheme — Indicator bajo el texto, primary color
- floatingActionButtonTheme — primaryContainer, radius 12

## Buttons

- elevatedButtonTheme — primary + onPrimary, min 64x48
- outlinedButtonTheme — border outline, min 64x48
- textButtonTheme — primary
- iconButtonTheme — onSurface, highlight primaryContainer
- segmentedButtonTheme — primaryContainer cuando seleccionado

## Inputs

- inputDecorationTheme — filled, radius 12, focused primary
- switchTheme — track primary / thumb onPrimary
- listTileTheme — padding 16, bodyLarge + bodySmall

## Display

- cardTheme — radius 16, elevation 0, border sutil
- chipTheme — radius 8, labelSmall
- dialogTheme — insetPadding 16/24
- progressIndicatorTheme — primary
- dividerTheme — outlineVariant 50%
- snackBarTheme — floating, radius 12

## PageTransitions

- Android/Linux/Windows: ZoomPageTransitionsBuilder
- iOS/macOS: CupertinoPageTransitionsBuilder

---

## Uso

Nunca configurar estilo en widgets. Confiar en el theme.

Bien: FilledButton(onPressed: ..., child: Text(Guardar))

Mal: FilledButton(style: FilledButton.styleFrom(backgroundColor: ...))

---

## Responsive

- context.isMobile (menor a 600)
- context.isTablet (600 a 900)
- context.isDesktop (mayor o igual a 900)
- context.valueFor(mobile: 1, tablet: 2, desktop: 3)

---

**Referencia:** flutter/lib/core/theme/app_theme.dart + app_breakpoints.dart
