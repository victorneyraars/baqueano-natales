# 🎨 Colores

**Última actualización:** 2026-10-29

---

## Paleta

### Seeds por flavor

| Flavor | Color | Hex |
|---|---|---|
| client | Verde Patagonia | #2E7D32 |
| admin | Morado interno | #6A1B9A |

### Accent por vertical

| Vertical | Color | Hex |
|---|---|---|
| Rent a Car | Ámbar atardecer | #B45309 |

### Anclas culturales

| Rol | Hex |
|---|---|
| Secondary (cielo nocturno) | #1E3A5F |
| Tertiary (bosque nativo) | #4A7C59 |

### Superficies

| Contexto | Hex |
|---|---|
| Surface light | #F8F7F5 |
| Surface dark | #121212 |
| OnSurface light | #1A1A1A |

### Semánticos

| Token | Light | Dark |
|---|---|---|
| success | #16A34A | #4ADE80 |
| warning | #D97706 | #FBBF24 |
| info | #2563EB | #60A5FA |
| error | #DC2626 | #F87171 |

### Estados de reserva

| Estado | Light | Dark |
|---|---|---|
| pendiente | #D97706 | #FBBF24 |
| confirmada | #2563EB | #60A5FA |
| en_curso | #9333EA | #C084FC |
| completada | #16A34A | #4ADE80 |
| cancelada | #DC2626 | #F87171 |

---

## Contraste WCAG

El accent #B45309 (Amber-700) cumple AA sobre blanco con ratio 4.7:1.

Todos los colores de estado cumplen AA sobre fondo surface light (#F8F7F5).

---

## Uso

No usar hex directo. Consumir tokens:

- theme.colorScheme.primary
- theme.colorScheme.surface
- ext.success / warning / info / error
- ext.reservaPendiente / Confirmada / EnCurso / Completada / Cancelada
- ext.rentacarAccent

---

**Referencia:** flutter/lib/core/theme/app_colors.dart + app_theme_extension.dart
