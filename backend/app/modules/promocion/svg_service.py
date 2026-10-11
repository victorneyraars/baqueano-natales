"""Helpers de generacion SVG para afiches promocionales.

Usamos svgwrite que escapa automaticamente el contenido XML, evitando
inyeccion. Todo texto pasa por svgwrite.text.Text().

Diseno:
- Funciones puras que devuelven elementos svgwrite.
- Coordenadas absolutas (el caller sabe el tamano del canvas).
- Nada de estado global: cada afiche se construye desde cero.
"""
from typing import Iterable

import svgwrite
from svgwrite import Drawing

from app.modules.promocion import brand_kit as bk


# =========================================================
# Canvas
# =========================================================

def canvas(tamano: str, bg_color: str = bk.BLANCO) -> Drawing:
    """Crea un canvas SVG del tamano pedido.

    Args:
        tamano: clave de brand_kit.TAMANOS ('ig_feed', 'ig_story', etc).
        bg_color: color de fondo (hex).

    Returns:
        Drawing de svgwrite listo para agregar elementos.
    """
    if tamano not in bk.TAMANOS:
        raise ValueError(f"Tamano desconocido: {tamano}")
    w, h = bk.TAMANOS[tamano]
    dwg = Drawing(
        size=(w, h),
        profile="full",
    )
    dwg.add(dwg.rect(insert=(0, 0), size=(w, h), fill=bg_color))
    return dwg


# =========================================================
# Formas decorativas
# =========================================================

def gradiente_linear(
    dwg: Drawing,
    id_: str,
    desde: str,
    hasta: str,
    x1: str = "0%",
    y1: str = "0%",
    x2: str = "100%",
    y2: str = "100%",
) -> None:
    """Define un gradiente lineal reusable."""
    grad = dwg.defs.add(dwg.linearGradient(id=id_, x1=x1, y1=y1, x2=x2, y2=y2))
    grad.add_stop_color(offset="0%", color=desde)
    grad.add_stop_color(offset="100%", color=hasta)


def circulo_decorativo(
    dwg: Drawing, cx: int, cy: int, r: int, color: str, opacity: float = 0.15,
) -> None:
    """Circulo decorativo con opacidad (efecto blob)."""
    dwg.add(dwg.circle(center=(cx, cy), r=r, fill=color, opacity=opacity))


def rect_redondeado(
    dwg: Drawing,
    x: int,
    y: int,
    w: int,
    h: int,
    rx: int,
    fill: str,
    opacity: float = 1.0,
) -> None:
    """Rectangulo con esquinas redondeadas."""
    dwg.add(dwg.rect(
        insert=(x, y), size=(w, h), rx=rx, ry=rx,
        fill=fill, opacity=opacity,
    ))


# =========================================================
# Texto
# =========================================================

def texto(
    dwg: Drawing,
    x: int,
    y: int,
    contenido: str,
    *,
    size: int = bk.FS_CUERPO,
    weight: str = bk.FW_REGULAR,
    color: str = bk.NEGRO,
    anchor: str = "start",
    family: str = bk.FONT_FAMILY,
    letter_spacing: float | None = None,
    line_height: float | None = None,
) -> None:
    """Agrega texto al canvas. svgwrite escapa el contenido automaticamente."""
    attrs = {
        "x": [x],
        "y": [y],
        "font-family": family,
        "font-size": size,
        "font-weight": weight,
        "fill": color,
        "text-anchor": anchor,
    }
    if letter_spacing is not None:
        attrs["letter-spacing"] = letter_spacing
    if line_height is not None:
        attrs["line-height"] = line_height
    dwg.add(dwg.text(contenido, **attrs))


def texto_multilinea(
    dwg: Drawing,
    x: int,
    y: int,
    lineas: Iterable[str],
    *,
    size: int = bk.FS_CUERPO,
    weight: str = bk.FW_REGULAR,
    color: str = bk.NEGRO,
    line_height_px: int | None = None,
    anchor: str = "start",
    max_chars: int = 40,
) -> int:
    """Escribe varias lineas. Devuelve la Y final (util para stacking).

    Args:
        line_height_px: altura entre lineas. Default: size * 1.2.
        max_chars: para partir lineas largas automaticamente.
    """
    if line_height_px is None:
        line_height_px = int(size * 1.2)

    y_actual = y
    for linea in lineas:
        # Partir lineas largas por palabras
        while len(linea) > max_chars:
            corte = linea.rfind(" ", 0, max_chars)
            if corte <= 0:
                corte = max_chars
            texto(dwg, x, y_actual, linea[:corte].strip(),
                  size=size, weight=weight, color=color, anchor=anchor)
            linea = linea[corte:].strip()
            y_actual += line_height_px
        if linea:
            texto(dwg, x, y_actual, linea,
                  size=size, weight=weight, color=color, anchor=anchor)
            y_actual += line_height_px
    return y_actual


# =========================================================
# Utilidades
# =========================================================

def to_string(dwg: Drawing) -> str:
    """Serializa el Drawing a string XML."""
    return dwg.tostring()
