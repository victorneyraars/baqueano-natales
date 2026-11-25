from io import BytesIO
import logging
import os
import re
import textwrap
import boto3
from botocore.config import Config
from PIL import Image, ImageDraw, ImageFont

logger = logging.getLogger(__name__)

STATIC_SOCIAL_DIR = "/var/lib/baqueano-natales/static/social/servicios"


def _cargar_fuente(tamano: int, negrita: bool = False):
    candidatos = (
        [
            "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
            "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf",
        ]
        if negrita
        else [
            "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
            "/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf",
        ]
    )
    for ruta in candidatos:
        if os.path.exists(ruta):
            try:
                return ImageFont.truetype(ruta, tamano)
            except Exception:
                pass
    return ImageFont.load_default()


def _medir_texto(draw: ImageDraw.ImageDraw, texto: str, fuente) -> tuple[int, int]:
    bbox = draw.textbbox((0, 0), texto, font=fuente)
    return (bbox[2] - bbox[0]), (bbox[3] - bbox[1])


def _dibujar_icono_reloj(draw: ImageDraw.ImageDraw, cx: int, cy: int, r: int, color: str) -> None:
    draw.ellipse([cx - r, cy - r, cx + r, cy + r], outline=color, width=3)
    draw.line([cx, cy, cx, cy - int(r * 0.55)], fill=color, width=3)
    draw.line([cx, cy, cx + int(r * 0.45), cy + int(r * 0.2)], fill=color, width=3)


def _dibujar_icono_escudo(draw: ImageDraw.ImageDraw, cx: int, cy: int, r: int, color: str) -> None:
    pts = [
        (cx, cy - r),
        (cx + r, cy - int(r * 0.45)),
        (cx + int(r * 0.72), cy + int(r * 0.55)),
        (cx, cy + r),
        (cx - int(r * 0.72), cy + int(r * 0.55)),
        (cx - r, cy - int(r * 0.45)),
    ]
    draw.polygon(pts, outline=color, width=3)


def _hex_a_rgb(valor_hex: str, fallback: tuple[int, int, int]) -> tuple[int, int, int]:
    limpio = (valor_hex or "").strip().lstrip("#")
    if len(limpio) == 6:
        try:
            return tuple(int(limpio[i : i + 2], 16) for i in (0, 2, 4))  # type: ignore[return-value]
        except ValueError:
            pass
    return fallback


def _envolver_titulo_inteligente(
    draw: ImageDraw.ImageDraw,
    titulo_limpio: str,
    ancho_max: int,
    tamano_inicial: int = 58,
) -> tuple[list[str], ImageFont.ImageFont, int]:
    """Ajusta tamaño de fuente y salto de línea para que títulos largos entren sin cortarse."""
    for tamano, ancho_wrap in [(tamano_inicial, 25), (50, 29), (44, 33), (38, 38)]:
        fuente = _cargar_fuente(tamano, negrita=True)
        lineas = textwrap.wrap(titulo_limpio, width=ancho_wrap)
        if len(lineas) <= 3 and all(_medir_texto(draw, ln, fuente)[0] <= ancho_max for ln in lineas):
            return lineas, fuente, tamano

    fuente_min = _cargar_fuente(38, negrita=True)
    lineas_finales = textwrap.wrap(titulo_limpio, width=38)[:3]
    for i, ln in enumerate(lineas_finales):
        while _medir_texto(draw, ln, fuente_min)[0] > ancho_max and len(ln) > 4:
            ln = ln[:-1]
        lineas_finales[i] = ln
    return lineas_finales, fuente_min, 38


def generar_png_servicio_prestador(
    *,
    titulo: str,
    texto_precio: str | None,
    duracion_min: int | None,
    garantia_dias: int | None,
    nombre_prestador: str = "SE ALQUILA MARIDO",
    subtitulo_prestador: str = "Puerto Natales · Mecánica a domicilio",
    sello_ubicacion: str | None = None,
    badge_texto: str = "A DOMICILIO",
    cta_texto: str | None = None,
    whatsapp_texto: str | None = None,
    limpiar_motor: bool = True,
) -> bytes:
    """Genera una gráfica cuadrada 1080x1080 para cualquier prestador y servicio."""
    w, h = 1080, 1080

    acento_rgb = _hex_a_rgb(os.getenv("GRAFICA_SERVICIO_COLOR_ACENTO", "#F97316"), (249, 115, 22))
    acento_hex = f"#{acento_rgb[0]:02X}{acento_rgb[1]:02X}{acento_rgb[2]:02X}"
    precio_hex = (os.getenv("GRAFICA_SERVICIO_COLOR_PRECIO", "#4ADE80") or "#4ADE80").strip()
    sello_txt = ((sello_ubicacion or os.getenv("GRAFICA_SERVICIO_TEXTO_SELLO", "PUERTO NATALES")) or "PUERTO NATALES").strip()
    nota_txt = (
        os.getenv(
            "GRAFICA_SERVICIO_TEXTO_NOTA",
            "Atención directa en tu domicilio · Reserva en línea",
        )
        or "Atención directa en tu domicilio · Reserva en línea"
    ).strip()
    cta_txt = (
        os.getenv(
            "GRAFICA_SERVICIO_TEXTO_CTA",
            "Agenda en sealquilamarido.com/mecanica",
        )
        or "Agenda en sealquilamarido.com/mecanica"
    ).strip()
    if cta_texto:
        cta_txt = cta_texto.strip()

    # 1. Fondo con degradado vertical sutil y resplandor cálido controlado
    base_img = Image.new("RGBA", (w, h), (11, 17, 32, 255))
    top_rgb = (15, 23, 42)
    bot_rgb = (15, 21, 36)
    grad_draw = ImageDraw.Draw(base_img)
    for y in range(h):
        t = y / max(h - 1, 1)
        r = int(top_rgb[0] * (1 - t) + bot_rgb[0] * t)
        g = int(top_rgb[1] * (1 - t) + bot_rgb[1] * t)
        b = int(top_rgb[2] * (1 - t) + bot_rgb[2] * t)
        grad_draw.line([(0, y), (w, y)], fill=(r, g, b, 255))

    glow = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow)
    for radio, alpha in [(380, 8), (260, 12), (160, 16)]:
        glow_draw.ellipse(
            [w - 150 - radio, 110 - radio, w - 150 + radio, 110 + radio],
            fill=(acento_rgb[0], acento_rgb[1], acento_rgb[2], alpha),
        )
    base_img = Image.alpha_composite(base_img, glow)
    draw = ImageDraw.Draw(base_img)

    # Tipografías base
    f_marca = _cargar_fuente(36, negrita=True)
    f_sub = _cargar_fuente(24, negrita=False)
    f_tag_top = _cargar_fuente(20, negrita=True)
    f_badge = _cargar_fuente(26, negrita=True)
    f_label = _cargar_fuente(22, negrita=True)
    f_precio = _cargar_fuente(76, negrita=True)
    f_chip = _cargar_fuente(28, negrita=True)
    f_nota = _cargar_fuente(26, negrita=False)
    f_cta = _cargar_fuente(27, negrita=True)

    # 2. Cabecera superior con barra de acento izquierda y sello de ubicación
    header_h = 148
    draw.rectangle([0, 0, w, header_h], fill=(22, 32, 50, 255))
    draw.rectangle([0, 0, 12, header_h], fill=(acento_rgb[0], acento_rgb[1], acento_rgb[2], 255))
    draw.rectangle([0, header_h, w, header_h + 4], fill=(acento_rgb[0], acento_rgb[1], acento_rgb[2], 255))

    draw.text((56, 30), (nombre_prestador or "BAQUEANO NATALES").strip().upper(), fill="#FFFFFF", font=f_marca)
    draw.text((56, 84), (subtitulo_prestador or "Puerto Natales").strip(), fill="#CBD5E1", font=f_sub)

    sw, sh = _medir_texto(draw, sello_txt, f_tag_top)
    sello_w = sw + 36
    sello_h = sh + 20
    sello_x1 = w - 56 - sello_w
    sello_y1 = (header_h - sello_h) // 2
    draw.rounded_rectangle(
        [sello_x1, sello_y1, sello_x1 + sello_w, sello_y1 + sello_h],
        radius=12,
        fill=(39, 53, 79, 255),
        outline=(acento_rgb[0], acento_rgb[1], acento_rgb[2], 255),
        width=2,
    )
    draw.text(
        (sello_x1 + (sello_w - sw) // 2, sello_y1 + (sello_h - sh) // 2 - 2),
        sello_txt,
        fill="#FFFFFF",
        font=f_tag_top,
    )

    # 3. Badge de modalidad + Título del servicio con ajuste automático
    badge_txt = (badge_texto or "SERVICIO").strip().upper()
    bw, bh = _medir_texto(draw, badge_txt, f_badge)
    badge_w = bw + 48
    badge_h = bh + 22
    badge_x1 = 56
    badge_y1 = 192
    draw.rounded_rectangle(
        [badge_x1, badge_y1, badge_x1 + badge_w, badge_y1 + badge_h],
        radius=badge_h // 2,
        fill=(acento_rgb[0], acento_rgb[1], acento_rgb[2], 255),
    )
    draw.text(
        (badge_x1 + (badge_w - bw) // 2, badge_y1 + (badge_h - bh) // 2 - 2),
        badge_txt,
        fill="#090D16",
        font=f_badge,
    )

    titulo_base = (titulo or "Servicio disponible").strip().rstrip(".")
    titulo_limpio = (
        re.sub(r"\s+de\s+motor(?=\s+a\s+domicilio|$)", "", titulo_base, flags=re.IGNORECASE)
        if limpiar_motor
        else titulo_base
    )
    lineas_titulo, f_titulo, _ = _envolver_titulo_inteligente(
        draw,
        titulo_limpio,
        ancho_max=w - 112,
        tamano_inicial=58,
    )
    y_actual = badge_y1 + badge_h + 28
    _, alto_linea_t = _medir_texto(draw, "Ag", f_titulo)
    interlinea_t = alto_linea_t + 14
    for linea in lineas_titulo:
        draw.text((56, y_actual), linea, fill="#F8FAFC", font=f_titulo)
        y_actual += interlinea_t

    # 4. Tarjeta principal de tarifa
    card_x1 = 56
    card_x2 = w - 56
    card_y1 = max(y_actual + 24, 435)
    card_h = 176
    card_y2 = card_y1 + card_h

    draw.rounded_rectangle(
        [card_x1 + 4, card_y1 + 6, card_x2 + 4, card_y2 + 6],
        radius=24,
        fill=(4, 7, 15, 140),
    )
    draw.rounded_rectangle(
        [card_x1, card_y1, card_x2, card_y2],
        radius=24,
        fill=(24, 35, 56, 250),
        outline=(51, 65, 85, 255),
        width=2,
    )
    draw.rounded_rectangle(
        [card_x1, card_y1, card_x1 + 12, card_y2],
        radius=6,
        fill=(acento_rgb[0], acento_rgb[1], acento_rgb[2], 255),
    )

    lbl_txt = "TARIFA REFERENCIAL"
    _, lbl_h = _medir_texto(draw, lbl_txt, f_label)
    draw.text((card_x1 + 36, card_y1 + 24), lbl_txt, fill="#94A3B8", font=f_label)

    precio_str = (texto_precio or "Consultar precio").strip()
    draw.text(
        (card_x1 + 36, card_y1 + 24 + lbl_h + 14),
        precio_str,
        fill=precio_hex,
        font=f_precio,
    )

    # 5. Chips de duración y garantía con íconos limpios
    y_chips = card_y2 + 24
    x_chip = 56
    chip_h = 62
    chips_data: list[tuple[str, str]] = []
    if duracion_min and duracion_min > 0:
        chips_data.append(("reloj", f"Duración: {duracion_min} min"))
    if garantia_dias and garantia_dias > 0:
        chips_data.append(("escudo", f"Garantía: {garantia_dias} días"))

    for tipo_ico, texto_chip in chips_data:
        cw_txt, ch_txt = _medir_texto(draw, texto_chip, f_chip)
        ancho_chip = 22 + 26 + 14 + cw_txt + 24
        draw.rounded_rectangle(
            [x_chip, y_chips, x_chip + ancho_chip, y_chips + chip_h],
            radius=18,
            fill=(22, 32, 50, 245),
            outline=(71, 85, 105, 255),
            width=2,
        )
        ico_cx = x_chip + 22 + 12
        ico_cy = y_chips + chip_h // 2
        if tipo_ico == "reloj":
            _dibujar_icono_reloj(draw, ico_cx, ico_cy, 12, acento_hex)
        else:
            _dibujar_icono_escudo(draw, ico_cx, ico_cy, 12, "#38BDF8")

        draw.text(
            (x_chip + 60, y_chips + (chip_h - ch_txt) // 2 - 2),
            texto_chip,
            fill="#F8FAFC",
            font=f_chip,
        )
        x_chip += ancho_chip + 18

    # 6. Bloque de respaldo en el espacio inferior
    y_respaldo = (y_chips + chip_h + 24) if chips_data else (card_y2 + 24)
    respaldo_h = 74
    if y_respaldo + respaldo_h < h - 200:
        draw.rounded_rectangle(
            [56, y_respaldo, w - 56, y_respaldo + respaldo_h],
            radius=18,
            fill=(22, 32, 50, 225),
            outline=(51, 65, 85, 255),
            width=2,
        )
        draw.rectangle([56, y_respaldo + 14, 64, y_respaldo + respaldo_h - 14], fill=(56, 189, 248, 255))
        _, nh = _medir_texto(draw, nota_txt, f_nota)
        draw.text(
            (86, y_respaldo + (respaldo_h - nh) // 2 - 2),
            nota_txt,
            fill="#E2E8F0",
            font=f_nota,
        )

    # 6b. Cápsula de WhatsApp en línea individual (centrada y destacada)
    footer_y1 = h - 104
    if whatsapp_texto and whatsapp_texto.strip():
        wa_txt = whatsapp_texto.strip()
        f_wa = _cargar_fuente(32, negrita=True)
        waw, wah = _medir_texto(draw, wa_txt, f_wa)
        pad_x, pad_y = 38, 18
        pill_w = min(waw + pad_x * 2, w - 112)
        pill_h = wah + pad_y * 2
        y_espacio_inicio = y_respaldo + respaldo_h
        pill_y1 = y_espacio_inicio + max(24, (footer_y1 - y_espacio_inicio - pill_h) // 2)
        pill_y2 = pill_y1 + pill_h
        pill_x1 = (w - pill_w) // 2
        pill_x2 = pill_x1 + pill_w
        draw.rounded_rectangle(
            [pill_x1, pill_y1, pill_x2, pill_y2],
            radius=pill_h // 2,
            fill=(22, 163, 74, 255),
        )
        draw.text(
            (pill_x1 + (pill_w - waw) // 2, pill_y1 + (pill_h - wah) // 2 - 2),
            wa_txt,
            fill="#FFFFFF",
            font=f_wa,
        )

    # 7. Banda inferior de cierre con URL centrada
    draw.rectangle([0, footer_y1, w, h], fill=(22, 32, 50, 255))
    draw.rectangle([0, footer_y1, w, footer_y1 + 3], fill=(acento_rgb[0], acento_rgb[1], acento_rgb[2], 255))

    ctaw, ctah = _medir_texto(draw, cta_txt, f_cta)
    draw.text(
        ((w - ctaw) // 2, footer_y1 + (104 - ctah) // 2 - 2),
        cta_txt,
        fill="#F8FAFC",
        font=f_cta,
    )
    out_rgb = base_img.convert("RGB")
    buf = BytesIO()
    out_rgb.save(buf, format="PNG", optimize=True)
    return buf.getvalue()

def publicar_grafica_servicio(servicio_id, png_bytes: bytes) -> str | None:
    """Sube a R2 si está configurado; si no, guarda en /app/static y retorna ruta relativa /static/..."""
    object_key = f"social/servicios/{servicio_id}.png"

    endpoint = os.getenv("R2_ENDPOINT_URL")
    access_key = os.getenv("R2_ACCESS_KEY_ID")
    secret_key = os.getenv("R2_SECRET_ACCESS_KEY")
    bucket = os.getenv("R2_BUCKET_NAME")
    public_url = os.getenv("R2_PUBLIC_URL")

    if all([endpoint, access_key, secret_key, bucket, public_url]):
        s3 = boto3.client(
            "s3",
            endpoint_url=endpoint,
            aws_access_key_id=access_key,
            aws_secret_access_key=secret_key,
            config=Config(
                signature_version="s3v4",
                s3={
                    "addressing_style": "path",
                    "payload_signing_enabled": False,
                },
                request_checksum_calculation="when_required",
                response_checksum_validation="when_required",
            ),
            region_name="auto",
        )
        try:
            s3.put_object(
                Bucket=bucket,
                Key=object_key,
                Body=png_bytes,
                ContentType="image/png",
                CacheControl="public, max-age=3600",
            )
            return f"{public_url.rstrip('/')}/{object_key}"
        except Exception as e:
            logger.warning("Social: R2 no disponible, usando almacenamiento local /static: %s", e)

    try:
        os.makedirs(STATIC_SOCIAL_DIR, exist_ok=True)
        out_path = os.path.join(STATIC_SOCIAL_DIR, f"{servicio_id}.png")
        with open(out_path, "wb") as f:
            f.write(png_bytes)
        return f"/static/social/servicios/{servicio_id}.png"
    except Exception as e:
        logger.warning("Social: no se pudo guardar gráfica en /static: %s", e)
        return None


def generar_png_servicio_sealquilamarido(
    *,
    titulo: str,
    texto_precio: str | None,
    duracion_min: int | None,
    garantia_dias: int | None,
) -> bytes:
    return generar_png_servicio_prestador(
        titulo=titulo,
        texto_precio=texto_precio,
        duracion_min=duracion_min,
        garantia_dias=garantia_dias,
        nombre_prestador="SE ALQUILA MARIDO",
        subtitulo_prestador="Puerto Natales · Mecánica a domicilio",
        sello_ubicacion="PUERTO NATALES",
        badge_texto="A DOMICILIO",
        cta_texto="Agenda en sealquilamarido.com/mecanica",
        limpiar_motor=True,
    )
