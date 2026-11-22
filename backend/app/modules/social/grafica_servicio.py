from io import BytesIO
import logging
import os
import re
import textwrap
import boto3
from botocore.config import Config
from PIL import Image, ImageDraw, ImageFont

logger = logging.getLogger(__name__)

STATIC_SOCIAL_DIR = "/tmp/baqueano_static/social/servicios"


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
        (cx + int(r * 0.75), cy + int(r * 0.55)),
        (cx, cy + r),
        (cx - int(r * 0.75), cy + int(r * 0.55)),
        (cx - r, cy - int(r * 0.45)),
    ]
    draw.polygon(pts, outline=color)
    draw.line([cx, cy - r, cx + r, cy - int(r * 0.45)], fill=color, width=3)
    draw.line([cx + r, cy - int(r * 0.45), cx + int(r * 0.75), cy + int(r * 0.55)], fill=color, width=3)
    draw.line([cx + int(r * 0.75), cy + int(r * 0.55), cx, cy + r], fill=color, width=3)
    draw.line([cx, cy + r, cx - int(r * 0.75), cy + int(r * 0.55)], fill=color, width=3)
    draw.line([cx - int(r * 0.75), cy + int(r * 0.55), cx - r, cy - int(r * 0.45)], fill=color, width=3)
    draw.line([cx - r, cy - int(r * 0.45), cx, cy - r], fill=color, width=3)


def generar_png_servicio_sealquilamarido(
    *,
    titulo: str,
    texto_precio: str | None,
    duracion_min: int | None,
    garantia_dias: int | None,
) -> bytes:
    """Genera una gráfica cuadrada 1080x1080 refinada y equilibrada para feed social."""
    w, h = 1080, 1080

    # 1. Fondo con degradado vertical sutil y resplandor cálido superior derecho
    base_img = Image.new("RGBA", (w, h), (11, 17, 32, 255))
    top_rgb = (15, 23, 42)
    bot_rgb = (17, 24, 39)
    grad_draw = ImageDraw.Draw(base_img)
    for y in range(h):
        t = y / max(h - 1, 1)
        r = int(top_rgb[0] * (1 - t) + bot_rgb[0] * t)
        g = int(top_rgb[1] * (1 - t) + bot_rgb[1] * t)
        b = int(top_rgb[2] * (1 - t) + bot_rgb[2] * t)
        grad_draw.line([(0, y), (w, y)], fill=(r, g, b, 255))

    glow = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow)
    for radio, alpha in [(420, 10), (300, 14), (190, 18), (100, 22)]:
        glow_draw.ellipse(
            [w - 140 - radio, 120 - radio, w - 140 + radio, 120 + radio],
            fill=(249, 115, 22, alpha),
        )
    base_img = Image.alpha_composite(base_img, glow)
    draw = ImageDraw.Draw(base_img)

    # Tipografías
    f_marca = _cargar_fuente(36, negrita=True)
    f_sub = _cargar_fuente(24, negrita=False)
    f_tag_top = _cargar_fuente(20, negrita=True)
    f_badge = _cargar_fuente(26, negrita=True)
    f_titulo = _cargar_fuente(58, negrita=True)
    f_label = _cargar_fuente(22, negrita=True)
    f_precio = _cargar_fuente(76, negrita=True)
    f_chip = _cargar_fuente(28, negrita=True)
    f_nota = _cargar_fuente(25, negrita=False)
    f_cta = _cargar_fuente(27, negrita=True)

    # 2. Cabecera superior con barra naranja izquierda y sello de ubicación
    header_h = 148
    draw.rectangle([0, 0, w, header_h], fill=(22, 32, 50, 255))
    draw.rectangle([0, 0, 12, header_h], fill=(249, 115, 22, 255))
    draw.rectangle([0, header_h, w, header_h + 4], fill=(249, 115, 22, 255))

    draw.text((56, 30), "SE ALQUILA MARIDO", fill="#FFFFFF", font=f_marca)
    draw.text((56, 84), "Puerto Natales · Mecánica a domicilio", fill="#CBD5E1", font=f_sub)

    sello_txt = "PUERTO NATALES"
    sw, sh = _medir_texto(draw, sello_txt, f_tag_top)
    sello_w = sw + 34
    sello_h = sh + 18
    sello_x1 = w - 56 - sello_w
    sello_y1 = (header_h - sello_h) // 2
    draw.rounded_rectangle(
        [sello_x1, sello_y1, sello_x1 + sello_w, sello_y1 + sello_h],
        radius=12,
        fill=(249, 115, 22, 36),
        outline=(249, 115, 22, 160),
        width=2,
    )
    draw.text(
        (sello_x1 + (sello_w - sw) // 2, sello_y1 + (sello_h - sh) // 2 - 1),
        sello_txt,
        fill="#FDBA74",
        font=f_tag_top,
    )

    # 3. Badge de modalidad + Título del servicio
    badge_txt = "A DOMICILIO"
    bw, bh = _medir_texto(draw, badge_txt, f_badge)
    badge_w = bw + 48
    badge_h = bh + 22
    badge_x1 = 56
    badge_y1 = 192
    draw.rounded_rectangle(
        [badge_x1, badge_y1, badge_x1 + badge_w, badge_y1 + badge_h],
        radius=badge_h // 2,
        fill=(249, 115, 22, 255),
    )
    draw.text(
        (badge_x1 + (badge_w - bw) // 2, badge_y1 + (badge_h - bh) // 2 - 2),
        badge_txt,
        fill="#090D16",
        font=f_badge,
    )

    titulo_limpio = re.sub(
        r"\s+de\s+motor(?=\s+a\s+domicilio|$)",
        "",
        (titulo or "Servicio mecánico").strip().rstrip("."),
        flags=re.IGNORECASE,
    )
    lineas_titulo = textwrap.wrap(titulo_limpio, width=25)[:3]
    y_actual = badge_y1 + badge_h + 28
    _, alto_linea_t = _medir_texto(draw, "Ag", f_titulo)
    interlinea_t = alto_linea_t + 14
    for linea in lineas_titulo:
        draw.text((56, y_actual), linea, fill="#F8FAFC", font=f_titulo)
        y_actual += interlinea_t

    # 4. Tarjeta principal de tarifa con acento lateral y sombra sutil
    card_x1 = 56
    card_x2 = w - 56
    card_y1 = max(y_actual + 26, 480)
    card_h = 176
    card_y2 = card_y1 + card_h

    draw.rounded_rectangle(
        [card_x1 + 4, card_y1 + 6, card_x2 + 4, card_y2 + 6],
        radius=24,
        fill=(4, 7, 15, 130),
    )
    draw.rounded_rectangle(
        [card_x1, card_y1, card_x2, card_y2],
        radius=24,
        fill=(24, 35, 56, 245),
        outline=(51, 65, 85, 255),
        width=2,
    )
    draw.rounded_rectangle(
        [card_x1, card_y1, card_x1 + 12, card_y2],
        radius=6,
        fill=(249, 115, 22, 255),
    )

    lbl_txt = "TARIFA REFERENCIAL"
    _, lbl_h = _medir_texto(draw, lbl_txt, f_label)
    draw.text((card_x1 + 36, card_y1 + 24), lbl_txt, fill="#94A3B8", font=f_label)

    precio_str = (texto_precio or "Consultar precio").strip()
    _, pr_h = _medir_texto(draw, precio_str, f_precio)
    draw.text(
        (card_x1 + 36, card_y1 + 24 + lbl_h + 14),
        precio_str,
        fill="#34D399",
        font=f_precio,
    )

    # 5. Chips de duración y garantía con íconos geométricos
    y_chips = card_y2 + 28
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
            fill=(22, 32, 50, 240),
            outline=(71, 85, 105, 255),
            width=2,
        )
        ico_cx = x_chip + 22 + 12
        ico_cy = y_chips + chip_h // 2
        if tipo_ico == "reloj":
            _dibujar_icono_reloj(draw, ico_cx, ico_cy, 12, "#F97316")
        else:
            _dibujar_icono_escudo(draw, ico_cx, ico_cy, 12, "#38BDF8")

        draw.text(
            (x_chip + 60, y_chips + (chip_h - ch_txt) // 2 - 2),
            texto_chip,
            fill="#F1F5F9",
            font=f_chip,
        )
        x_chip += ancho_chip + 18

    # 6. Bloque de respaldo en el espacio intermedio para evitar hueco vacío
    y_respaldo = (y_chips + chip_h + 36) if chips_data else (card_y2 + 36)
    respaldo_h = 84
    if y_respaldo + respaldo_h < h - 135:
        draw.rounded_rectangle(
            [56, y_respaldo, w - 56, y_respaldo + respaldo_h],
            radius=18,
            fill=(20, 29, 46, 190),
            outline=(39, 52, 73, 255),
            width=1,
        )
        nota_txt = "Atención directa en tu domicilio · Reserva en línea"
        _, nh = _medir_texto(draw, nota_txt, f_nota)
        draw.text(
            (84, y_respaldo + (respaldo_h - nh) // 2 - 2),
            nota_txt,
            fill="#CBD5E1",
            font=f_nota,
        )

    # 7. Banda inferior de cierre con URL y marca
    footer_y1 = h - 104
    draw.rectangle([0, footer_y1, w, h], fill=(22, 32, 50, 255))
    draw.rectangle([0, footer_y1, w, footer_y1 + 3], fill=(51, 65, 85, 255))

    cta_txt = "Agenda en sealquilamarido.com/mecanica"
    _, ctah = _medir_texto(draw, cta_txt, f_cta)
    draw.text(
        (56, footer_y1 + (104 - ctah) // 2 - 2),
        cta_txt,
        fill="#E2E8F0",
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
