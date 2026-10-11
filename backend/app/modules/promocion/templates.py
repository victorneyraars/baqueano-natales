"""Catalogo de plantillas SVG para afiches promocionales.

Cada plantilla es una funcion `render_<nombre>(params, tamano) -> Drawing`.
Devuelven un Drawing listo para serializar con svg_service.to_string().

Todas las plantillas:
- Reciben un dict `params` con los datos del negocio/servicio.
- Reciben un `tamano` (clave de brand_kit.TAMANOS).
- Son puras: sin efectos secundarios, sin estado global.
- Usan svg_service helpers (no svgwrite directo).

Plantillas disponibles (5):
    1. nuevo_servicio    - Anunciar un servicio nuevo
    2. oferta            - Promo con descuento + fecha limite
    3. destacado         - Perfil/negocio destacado (branding)
    4. evento            - Evento con fecha, hora y ubicacion
    5. profesional       - Cita/frase + datos de contacto (branding puro)
"""
import logging
from typing import Callable

from svgwrite import Drawing

from app.modules.promocion import brand_kit as bk
from app.modules.promocion import svg_service as svg

logger = logging.getLogger(__name__)


# =========================================================
# Helpers comunes
# =========================================================

def _footer_marca(dwg: Drawing, tamano: str) -> None:
    """Pie de marca comun a todas las plantillas."""
    w, h = bk.TAMANOS[tamano]
    y = h - bk.SP_XL

    # Linea separadora
    dwg.add(dwg.line(
        start=(bk.SP_XL, y - bk.SP_MD),
        end=(w - bk.SP_XL, y - bk.SP_MD),
        stroke=bk.GRIS_300,
        stroke_width=2,
    ))

    # Handle a la izquierda
    svg.texto(
        dwg, bk.SP_XL, y,
        bk.MARCA_HANDLE,
        size=bk.FS_PIE,
        weight=bk.FW_SEMIBOLD,
        color=bk.VERDE_PRIMARIO,
    )

    # Sitio a la derecha
    svg.texto(
        dwg, w - bk.SP_XL, y,
        bk.MARCA_SITIO,
        size=bk.FS_PIE,
        weight=bk.FW_REGULAR,
        color=bk.GRIS_500,
        anchor="end",
    )


def _titulo_marca(dwg: Drawing, color: str = bk.VERDE_PRIMARIO) -> None:
    """Titulo 'Baqueano Natales' arriba."""
    svg.texto(
        dwg, bk.SP_XL, bk.SP_XXL,
        bk.MARCA_NOMBRE,
        size=bk.FS_SUBTITULO,
        weight=bk.FW_BOLD,
        color=color,
        letter_spacing=1,
    )


# =========================================================
# Plantilla 1: nuevo_servicio
# =========================================================

def render_nuevo_servicio(params: dict, tamano: str = "ig_feed") -> Drawing:
    """Afiche: 'Nuevo servicio de <prestador>'.

    params:
        prestador (str): nombre del prestador.
        servicio (str): nombre del servicio.
        categoria (str, opcional): categoria del servicio.
        precio_desde (int, opcional): precio en CLP.
        descripcion (str, opcional): descripcion corta.
        foto_url (str, opcional): URL de imagen de fondo.
    """
    w, h = bk.TAMANOS[tamano]
    dwg = svg.canvas(tamano, bg_color=bk.VERDE_CLARO)

    # Blobs decorativos
    svg.circulo_decorativo(dwg, w + 100, -100, 400, bk.VERDE_ACENTO, 0.25)
    svg.circulo_decorativo(dwg, -150, h + 150, 500, bk.VERDE_PRIMARIO, 0.10)

    # Barra superior
    svg.rect_redondeado(
        dwg, bk.SP_XL, bk.SP_LG, w - 2 * bk.SP_XL, 8, 4,
        bk.VERDE_PRIMARIO,
    )

    # Titulo marca
    _titulo_marca(dwg)

    # Tag "NUEVO SERVICIO"
    tag_y = bk.SP_XXL + bk.SP_XXL
    tag_w = 380
    svg.rect_redondeado(
        dwg, bk.SP_XL, tag_y, tag_w, 60, 30,
        bk.VERDE_PRIMARIO,
    )
    svg.texto(
        dwg, bk.SP_XL + tag_w // 2, tag_y + 40,
        "NUEVO SERVICIO",
        size=28,
        weight=bk.FW_BOLD,
        color=bk.BLANCO,
        anchor="middle",
        letter_spacing=2,
    )

    # Titulo principal (nombre del servicio)
    y = tag_y + 180
    svg.texto_multilinea(
        dwg,
        bk.SP_XL, y,
        [params.get("servicio", "")],
        size=bk.FS_HERO,
        weight=bk.FW_BOLD,
        color=bk.NEGRO,
        line_height_px=110,
        max_chars=18,
    )

    # Categoria (si hay)
    cat = params.get("categoria")
    if cat:
        y += 200
        svg.texto(
            dwg, bk.SP_XL, y,
            cat.upper(),
            size=bk.FS_CUERPO,
            weight=bk.FW_SEMIBOLD,
            color=bk.VERDE_OSCURO,
            letter_spacing=3,
        )
        y += bk.SP_XL
    else:
        y += 100

    # Precio (destacado)
    precio = params.get("precio_desde")
    if precio:
        # Caja de precio
        caja_y = y + bk.SP_MD
        svg.rect_redondeado(
            dwg, bk.SP_XL, caja_y, 400, 120, 20,
            bk.BLANCO,
        )
        svg.texto(
            dwg, bk.SP_XL + bk.SP_MD, caja_y + 40,
            "DESDE",
            size=bk.FS_PIE,
            weight=bk.FW_SEMIBOLD,
            color=bk.GRIS_500,
            letter_spacing=2,
        )
        svg.texto(
            dwg, bk.SP_XL + bk.SP_MD, caja_y + 95,
            f"${precio:,}".replace(",", "."),
            size=56,
            weight=bk.FW_BOLD,
            color=bk.VERDE_OSCURO,
        )
        y = caja_y + 160

    # Prestador
    y += bk.SP_LG
    svg.texto(
        dwg, bk.SP_XL, y,
        "por",
        size=bk.FS_PIE,
        color=bk.GRIS_500,
    )
    svg.texto(
        dwg, bk.SP_XL, y + 60,
        params.get("prestador", ""),
        size=bk.FS_TITULO,
        weight=bk.FW_BOLD,
        color=bk.NEGRO,
    )

    # Descripcion
    desc = params.get("descripcion")
    if desc:
        y += 180
        svg.texto_multilinea(
            dwg,
            bk.SP_XL, y,
            [desc],
            size=bk.FS_CUERPO,
            color=bk.GRIS_700,
            max_chars=40,
            line_height_px=48,
        )

    # Footer
    _footer_marca(dwg, tamano)
    return dwg


# =========================================================
# Plantilla 2: oferta
# =========================================================

def render_oferta(params: dict, tamano: str = "ig_feed") -> Drawing:
    """Afiche: oferta con descuento y fecha limite.

    params:
        prestador (str): nombre del prestador.
        titulo (str): titulo de la oferta.
        descuento (str): ej "30%" o "2x1".
        fecha_limite (str, opcional): ej "Hasta el 31 de octubre".
        descripcion (str, opcional): texto adicional.
        codigo (str, opcional): codigo de descuento.
    """
    w, h = bk.TAMANOS[tamano]
    dwg = svg.canvas(tamano, bg_color=bk.NARANJA_CTA)

    # Blobs
    svg.circulo_decorativo(dwg, w + 100, h + 100, 500, bk.ROJO_URGENTE, 0.4)
    svg.circulo_decorativo(dwg, -100, -100, 400, "#ffffff", 0.15)

    # Tag "OFERTA"
    tag_w = 280
    tag_y = bk.SP_XL
    svg.rect_redondeado(
        dwg, bk.SP_XL, tag_y, tag_w, 60, 30,
        bk.BLANCO,
    )
    svg.texto(
        dwg, bk.SP_XL + tag_w // 2, tag_y + 40,
        "OFERTA",
        size=32,
        weight=bk.FW_BOLD,
        color=bk.NARANJA_CTA,
        anchor="middle",
        letter_spacing=4,
    )

    # Titulo grande (oferta)
    y = tag_y + 180
    y_final = svg.texto_multilinea(
        dwg, bk.SP_XL, y,
        [params.get("titulo", "")],
        size=bk.FS_HERO,
        weight=bk.FW_BOLD,
        color=bk.BLANCO,
        line_height_px=110,
        max_chars=16,
    )

    # Descuento (numero grande)
    desc = params.get("descuento")
    if desc:
        y_final += bk.SP_LG
        svg.texto(
            dwg, bk.SP_XL, y_final + 120,
            desc,
            size=240,
            weight=bk.FW_BOLD,
            color=bk.BLANCO,
            letter_spacing=-8,
        )
        y_final += 180

    # Descripcion
    txt = params.get("descripcion")
    if txt:
        y_final += bk.SP_MD
        svg.texto_multilinea(
            dwg, bk.SP_XL, y_final,
            [txt],
            size=bk.FS_CUERPO,
            color=bk.BLANCO,
            max_chars=38,
            line_height_px=48,
        )
        y_final += 80

    # Codigo (si hay)
    codigo = params.get("codigo")
    if codigo:
        y_final += bk.SP_MD
        svg.texto(
            dwg, bk.SP_XL, y_final,
            "CODIGO:",
            size=bk.FS_PIE,
            weight=bk.FW_SEMIBOLD,
            color=bk.BLANCO,
            letter_spacing=2,
        )
        svg.texto(
            dwg, bk.SP_XL + 160, y_final,
            codigo,
            size=bk.FS_PIE,
            weight=bk.FW_BOLD,
            color=bk.BLANCO,
            letter_spacing=4,
        )
        y_final += 60

    # Fecha limite (bloque destacado abajo)
    fecha = params.get("fecha_limite")
    if fecha:
        caja_y = h - bk.SP_XXL - 100
        svg.rect_redondeado(
            dwg, bk.SP_XL, caja_y, w - 2 * bk.SP_XL, 100, 20,
            bk.BLANCO,
        )
        svg.texto(
            dwg, bk.SP_XL + bk.SP_MD, caja_y + 42,
            "VENCE",
            size=bk.FS_PIE,
            weight=bk.FW_SEMIBOLD,
            color=bk.NARANJA_CTA,
            letter_spacing=2,
        )
        svg.texto(
            dwg, bk.SP_XL + bk.SP_MD, caja_y + 82,
            fecha,
            size=36,
            weight=bk.FW_BOLD,
            color=bk.NEGRO,
        )

    # Prestador (footer blanco)
    svg.texto(
        dwg, w - bk.SP_XL, h - bk.SP_XL,
        params.get("prestador", ""),
        size=bk.FS_CUERPO,
        weight=bk.FW_BOLD,
        color=bk.BLANCO,
        anchor="end",
    )
    return dwg


# =========================================================
# Plantilla 3: destacado
# =========================================================

def render_destacado(params: dict, tamano: str = "ig_feed") -> Drawing:
    """Afiche: prestador destacado (perfil + branding).

    params:
        prestador (str): nombre del prestador.
        categoria (str): rubro/oficio.
        especialidades (list[str], opcional): lista de hasta 4 especialidades.
        anios_experiencia (int, opcional): anios de trayectoria.
        comuna (str, opcional): ubicacion.
        frase (str, opcional): cita corta del prestador.
    """
    w, h = bk.TAMANOS[tamano]
    dwg = svg.canvas(tamano, bg_color=bk.VERDE_PRIMARIO)

    # Blobs morados para contraste
    svg.circulo_decorativo(dwg, -100, -100, 350, bk.MORADO_PRIMARIO, 0.35)
    svg.circulo_decorativo(dwg, w + 100, h - 200, 400, bk.VERDE_ACENTO, 0.3)

    # Badge "DESTACADO"
    tag_w = 320
    tag_y = bk.SP_XL
    svg.rect_redondeado(
        dwg, bk.SP_XL, tag_y, tag_w, 60, 30,
        bk.AMARILLO_DESTACADO,
    )
    svg.texto(
        dwg, bk.SP_XL + tag_w // 2, tag_y + 40,
        "DESTACADO",
        size=28,
        weight=bk.FW_BOLD,
        color=bk.NEGRO,
        anchor="middle",
        letter_spacing=3,
    )

    # Nombre grande
    y = tag_y + 200
    y_final = svg.texto_multilinea(
        dwg, bk.SP_XL, y,
        [params.get("prestador", "")],
        size=bk.FS_HERO,
        weight=bk.FW_BOLD,
        color=bk.BLANCO,
        line_height_px=110,
        max_chars=14,
    )

    # Categoria con linea
    cat = params.get("categoria")
    if cat:
        y_final += bk.SP_MD
        svg.texto(
            dwg, bk.SP_XL, y_final,
            cat.upper(),
            size=bk.FS_CUERPO,
            weight=bk.FW_SEMIBOLD,
            color=bk.AMARILLO_DESTACADO,
            letter_spacing=4,
        )
        y_final += bk.SP_XL

    # Anios de experiencia (destacado numerico)
    anios = params.get("anios_experiencia")
    if anios:
        y_final += bk.SP_LG
        svg.texto(
            dwg, bk.SP_XL, y_final + 60,
            str(anios),
            size=180,
            weight=bk.FW_BOLD,
            color=bk.BLANCO,
            letter_spacing=-4,
        )
        svg.texto(
            dwg, bk.SP_XL + 220, y_final + 30,
            "ANIOS DE",
            size=32,
            weight=bk.FW_SEMIBOLD,
            color=bk.BLANCO,
            letter_spacing=3,
        )
        svg.texto(
            dwg, bk.SP_XL + 220, y_final + 80,
            "EXPERIENCIA",
            size=32,
            weight=bk.FW_SEMIBOLD,
            color=bk.BLANCO,
            letter_spacing=3,
        )
        y_final += 180

    # Especialidades (chips)
    esp = params.get("especialidades") or []
    if esp:
        y_final += bk.SP_MD
        x = bk.SP_XL
        for i, item in enumerate(esp[:4]):
            chip_w = 40 + len(item) * 18
            if x + chip_w > w - bk.SP_XL:
                x = bk.SP_XL
                y_final += 80
            svg.rect_redondeado(
                dwg, x, y_final, chip_w, 56, 28,
                bk.BLANCO, 0.2,
            )
            svg.texto(
                dwg, x + chip_w // 2, y_final + 36,
                item,
                size=bk.FS_PIE,
                weight=bk.FW_SEMIBOLD,
                color=bk.BLANCO,
                anchor="middle",
            )
            x += chip_w + bk.SP_XS

    # Frase (si hay)
    frase = params.get("frase")
    if frase:
        caja_y = h - bk.SP_XXL - 160
        svg.rect_redondeado(
            dwg, bk.SP_XL, caja_y, w - 2 * bk.SP_XL, 140, 20,
            bk.BLANCO, 0.15,
        )
        svg.texto_multilinea(
            dwg, bk.SP_XL + bk.SP_MD, caja_y + 50,
            [f'"{frase}"'],
            size=32,
            weight=bk.FW_REGULAR,
            color=bk.BLANCO,
            max_chars=44,
            line_height_px=42,
        )

    # Footer
    svg.texto(
        dwg, w - bk.SP_XL, h - bk.SP_XL,
        bk.MARCA_HANDLE,
        size=bk.FS_PIE,
        weight=bk.FW_SEMIBOLD,
        color=bk.BLANCO,
        anchor="end",
    )
    return dwg


# =========================================================
# Plantilla 4: evento
# =========================================================

def render_evento(params: dict, tamano: str = "ig_feed") -> Drawing:
    """Afiche: evento con fecha, hora y ubicacion.

    params:
        titulo (str): nombre del evento.
        fecha (str): ej "Sabado 2 de noviembre".
        hora (str, opcional): ej "19:00 hrs".
        ubicacion (str, opcional): direccion o lugar.
        organizador (str, opcional): quien organiza.
        descripcion (str, opcional): detalle.
    """
    w, h = bk.TAMANOS[tamano]
    dwg = svg.canvas(tamano, bg_color=bk.MORADO_PRIMARIO)

    svg.circulo_decorativo(dwg, w - 100, -100, 500, bk.MORADO_OSCURO, 0.5)
    svg.circulo_decorativo(dwg, -100, h - 200, 400, bk.VERDE_ACENTO, 0.2)

    # Tag EVENTO
    tag_w = 240
    tag_y = bk.SP_XL
    svg.rect_redondeado(dwg, bk.SP_XL, tag_y, tag_w, 56, 28, bk.BLANCO)
    svg.texto(
        dwg, bk.SP_XL + tag_w // 2, tag_y + 38,
        "EVENTO",
        size=26, weight=bk.FW_BOLD, color=bk.MORADO_PRIMARIO,
        anchor="middle", letter_spacing=4,
    )

    # Titulo
    y = tag_y + 180
    y_final = svg.texto_multilinea(
        dwg, bk.SP_XL, y,
        [params.get("titulo", "")],
        size=bk.FS_HERO, weight=bk.FW_BOLD, color=bk.BLANCO,
        line_height_px=110, max_chars=14,
    )

    # Bloque fecha + hora
    fecha = params.get("fecha")
    if fecha:
        y_final += bk.SP_XL
        # Caja blanca con fecha
        svg.rect_redondeado(
            dwg, bk.SP_XL, y_final, w - 2 * bk.SP_XL, 200, 24, bk.BLANCO,
        )
        # Circulo con dia
        svg.circulo_decorativo(
            dwg, bk.SP_XL + 100, y_final + 100, 70, bk.MORADO_CLARO, 1.0,
        )
        svg.texto(
            dwg, bk.SP_XL + 100, y_final + 115,
            "FECHA", size=24, weight=bk.FW_BOLD,
            color=bk.MORADO_PRIMARIO, anchor="middle", letter_spacing=2,
        )
        svg.texto_multilinea(
            dwg, bk.SP_XL + 200, y_final + 70,
            [fecha], size=44, weight=bk.FW_BOLD, color=bk.NEGRO,
            max_chars=20, line_height_px=52,
        )
        hora = params.get("hora")
        if hora:
            svg.texto(
                dwg, bk.SP_XL + 200, y_final + 175,
                hora, size=32, color=bk.GRIS_500,
            )
        y_final += 240

    # Ubicacion
    ubic = params.get("ubicacion")
    if ubic:
        y_final += bk.SP_MD
        svg.texto(
            dwg, bk.SP_XL, y_final,
            "DONDE", size=24, weight=bk.FW_BOLD,
            color=bk.MORADO_CLARO, letter_spacing=2,
        )
        svg.texto_multilinea(
            dwg, bk.SP_XL, y_final + 60,
            [ubic], size=bk.FS_CUERPO, weight=bk.FW_SEMIBOLD,
            color=bk.BLANCO, max_chars=34, line_height_px=48,
        )

    # Organizador (pie)
    org = params.get("organizador")
    if org:
        svg.texto(
            dwg, bk.SP_XL, h - bk.SP_XL,
            f"Organiza: {org}",
            size=bk.FS_PIE, color=bk.BLANCO, weight=bk.FW_SEMIBOLD,
        )

    svg.texto(
        dwg, w - bk.SP_XL, h - bk.SP_XL,
        bk.MARCA_HANDLE,
        size=bk.FS_PIE, weight=bk.FW_SEMIBOLD,
        color=bk.BLANCO, anchor="end",
    )
    return dwg


# =========================================================
# Plantilla 5: profesional (cita + contacto)
# =========================================================

def render_profesional(params: dict, tamano: str = "ig_feed") -> Drawing:
    """Afiche: cita/frase profesional + datos de contacto.

    params:
        prestador (str): nombre del prestador.
        oficio (str): mecanico, electricista, etc.
        frase (str): cita corta o slogan.
        telefono (str, opcional).
        comuna (str, opcional).
    """
    w, h = bk.TAMANOS[tamano]
    dwg = svg.canvas(tamano, bg_color=bk.BLANCO)

    # Blobs
    svg.circulo_decorativo(dwg, w + 100, -100, 400, bk.VERDE_ACENTO, 0.18)
    svg.circulo_decorativo(dwg, -150, h + 150, 500, bk.VERDE_PRIMARIO, 0.08)

    # Comillas decorativas grandes (SVG path)
    dwg.add(dwg.text(
        '"',
        insert=(bk.SP_XL - 20, 300),
        font_family=bk.FONT_FAMILY,
        font_size=360,
        font_weight="900",
        fill=bk.VERDE_CLARO,
    ))

    # Frase (cita grande)
    y = bk.SP_XXL + 100
    y_final = svg.texto_multilinea(
        dwg, bk.SP_XL, y,
        [params.get("frase", "")],
        size=bk.FS_TITULO, weight=bk.FW_BOLD, color=bk.NEGRO,
        line_height_px=95, max_chars=22,
    )

    # Linea decorativa
    svg.rect_redondeado(
        dwg, bk.SP_XL, y_final + bk.SP_LG,
        120, 8, 4, bk.VERDE_PRIMARIO,
    )

    # Nombre + oficio
    y_final += bk.SP_XL + bk.SP_LG
    svg.texto(
        dwg, bk.SP_XL, y_final,
        params.get("prestador", ""),
        size=bk.FS_SUBTITULO, weight=bk.FW_BOLD, color=bk.VERDE_OSCURO,
    )
    y_final += bk.SP_LG
    svg.texto(
        dwg, bk.SP_XL, y_final,
        params.get("oficio", "").upper(),
        size=bk.FS_CUERPO, weight=bk.FW_SEMIBOLD,
        color=bk.GRIS_500, letter_spacing=4,
    )

    # Contacto (bloque inferior)
    caja_y = h - bk.SP_XXL - 120
    svg.rect_redondeado(
        dwg, bk.SP_XL, caja_y, w - 2 * bk.SP_XL, 120, 20,
        bk.VERDE_CLARO,
    )
    tel = params.get("telefono")
    com = params.get("comuna")
    info_parts = []
    if tel:
        info_parts.append(tel)
    if com:
        info_parts.append(com)
    info = "  ?  ".join(info_parts)
    if info:
        svg.texto(
            dwg, w // 2, caja_y + 72,
            info,
            size=bk.FS_CUERPO, weight=bk.FW_BOLD,
            color=bk.VERDE_OSCURO, anchor="middle",
        )

    # Handle pie
    svg.texto(
        dwg, w - bk.SP_XL, h - bk.SP_XL,
        bk.MARCA_HANDLE,
        size=bk.FS_PIE, weight=bk.FW_SEMIBOLD,
        color=bk.VERDE_PRIMARIO, anchor="end",
    )
    return dwg


# =========================================================
# Registro de plantillas
# =========================================================

TEMPLATES: dict[str, Callable[[dict, str], Drawing]] = {
    "nuevo_servicio": render_nuevo_servicio,
    "oferta": render_oferta,
    "destacado": render_destacado,
    "evento": render_evento,
    "profesional": render_profesional,
}


def render(plantilla: str, params: dict, tamano: str = "ig_feed") -> Drawing:
    """Despacha al render de la plantilla pedida."""
    if plantilla not in TEMPLATES:
        raise ValueError(f"Plantilla desconocida: {plantilla}")
    return TEMPLATES[plantilla](params, tamano)


def listar_plantillas() -> list[dict]:
    """Devuelve metadata para la UI (galeria)."""
    return [
        {
            "id": "nuevo_servicio",
            "nombre": "Nuevo servicio",
            "descripcion": "Anuncia un servicio nuevo de un prestador",
            "params_requeridos": ["prestador", "servicio"],
            "params_opcionales": ["categoria", "precio_desde", "descripcion"],
        },
        {
            "id": "oferta",
            "nombre": "Oferta",
            "descripcion": "Promo con descuento y fecha limite",
            "params_requeridos": ["prestador", "titulo"],
            "params_opcionales": ["descuento", "fecha_limite", "descripcion", "codigo"],
        },
        {
            "id": "destacado",
            "nombre": "Prestador destacado",
            "descripcion": "Perfil con branding y especialidades",
            "params_requeridos": ["prestador", "categoria"],
            "params_opcionales": ["especialidades", "anios_experiencia", "comuna", "frase"],
        },
        {
            "id": "evento",
            "nombre": "Evento",
            "descripcion": "Evento con fecha, hora y ubicacion",
            "params_requeridos": ["titulo", "fecha"],
            "params_opcionales": ["hora", "ubicacion", "organizador", "descripcion"],
        },
        {
            "id": "profesional",
            "nombre": "Cita profesional",
            "descripcion": "Frase + datos de contacto",
            "params_requeridos": ["prestador", "oficio", "frase"],
            "params_opcionales": ["telefono", "comuna"],
        },
    ]
