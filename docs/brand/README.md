# 🎨 Guía de marca — Baqueano Natales

Sistema de diseño unificado para todas las verticales de Baqueano Natales.
Fuente de verdad: flutter/lib/core/theme/.

**Última actualización:** 2026-10-29  
**Versión:** 1.0.0

---

## Filosofía

Baqueano Natales es una **super app regional** para Puerto Natales (Chile). Cada vertical (Oficios, Rent a Car, Hostales, Delivery, Taxis) tiene su propio **dominio + backend + web**, pero **comparte identidad visual** con el resto del ecosistema.

**Tres principios:**

1. **Unificado, no uniforme.** Todos los colores vienen del mismo sistema (verde Baqueano para la app madre, colores de accent por vertical), pero cada vertical puede tener personalidad.

2. **Mobile-first siempre.** El turista planifica desde el teléfono. El diseño funciona primero a 360px, después escala.

3. **Contraste WCAG AA.** Todo el sistema cumple 4.5:1 mínimo. El accent rentacar (#b45309) está testeado contra blanco y negro.

---

## Estructura del sistema

flutter/lib/core/theme/

- app_colors.dart — paleta + seeds + accent por vertical
- app_theme_extension.dart — tokens semánticos + estados + accent
- app_theme.dart — ThemeData light/dark + 15 roles + 17 themes
- app_breakpoints.dart — mobile/tablet/desktop + extension

**Regla de oro:** nunca usar valores hardcodeados (Color(0xFF...)) en widgets. Siempre consumir desde:

- theme.colorScheme.primary / surface (Material 3)
- ext.success / warning / reservaPendiente / rentacarAccent (AppThemeExtension)
- context.isMobile / isTablet / isDesktop (responsive)

---

## Secciones

- 01-colors.md — Paleta completa + semánticos + estados + contraste WCAG
- 02-typography.md — Los 15 roles con tabla de uso
- 03-components.md — Los 17 themes + snippets

---

**Mantenido por:** Víctor Neyra  
**Contacto:** contacto@baqueanonatales.com
