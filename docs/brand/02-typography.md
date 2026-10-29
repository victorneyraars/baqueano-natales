# 🔤 Tipografía

Inter (Google Fonts). Mobile-first, legibilidad alta a 360px.

---

## Los 15 roles

| Rol | Tamaño | Peso | Uso |
|---|---|---|---|
| displayLarge | 32 | 700 | Precio grande, hero |
| displayMedium | 28 | 600 | KPIs grandes |
| displaySmall | 24 | 600 | Heading secundario |
| headlineLarge | 28 | 700 | Título de pantalla |
| headlineMedium | 22 | 600 | Título de sección |
| headlineSmall | 20 | 600 | Subtítulo |
| titleLarge | 18 | 600 | Card title principal |
| titleMedium | 16 | 600 | Card title secundario |
| titleSmall | 14 | 600 | Label destacado |
| bodyLarge | 16 | 400 | Texto principal |
| bodyMedium | 14 | 400 | Texto secundario |
| bodySmall | 12 | 400 | Metadata |
| labelLarge | 16 | 600 | Botones |
| labelMedium | 14 | 500 | Chips, badges |
| labelSmall | 12 | 500 | Caption, pills |

---

## Uso

- theme.textTheme.displayLarge
- theme.textTheme.titleLarge
- theme.textTheme.bodyMedium

---

## Reglas

1. Nunca hardcodear fontSize o fontWeight
2. Usar textTheme.rol o TextStyle heredando
3. textScaler limitado a 1.3x (WCAG)
4. Inter se carga via google_fonts (runtime cache)

---

**Referencia:** flutter/lib/core/theme/app_theme.dart (_textTheme)
