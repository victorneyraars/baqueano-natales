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


def generar_png_servicio_sealquilamarido(
    *,
    titulo: str,
    texto_precio: str | None,
    duracion_min: int | None,
    garantia_dias: int | None,
) -> bytes:
    """Genera una gráfica cuadrada 1080x1080 de alto contraste para feed social."""
    w, h = 1080, 1080
    img = Image.new("RGB", (w, h), "#0F172A")
    draw = ImageDraw.Draw(img)

    draw.rectangle([0, 0, w, 140], fill="#1E293B")
    draw.rectangle([0, 140, w, 150], fill="#F97316")

    f_badge = _cargar_fuente(28, negrita=True)
    f_marca = _cargar_fuente(34, negrita=True)
    f_sub = _cargar_fuente(24, negrita=False)
    f_titulo = _cargar_fuente(54, negrita=True)
    f_precio = _cargar_fuente(72, negrita=True)
    f_chip = _cargar_fuente(28, negrita=True)
    f_pie = _cargar_fuente(26, negrita=False)

    draw.text((56, 34), "SE ALQUILA MARIDO", fill="#FFFFFF", font=f_marca)
    draw.text((56, 82), "Puerto Natales · Mecánica a domicilio", fill="#CBD5E1", font=f_sub)

    draw.rounded_rectangle([56, 190, 390, 250], radius=28, fill="#F97316")
    draw.text((84, 204), "A DOMICILIO", fill="#0F172A", font=f_badge)

    titulo_limpio = re.sub(
        r"\s+de\s+motor(?=\s+a\s+domicilio|$)",
        "",
        (titulo or "Servicio mecánico").strip().rstrip("."),
        flags=re.IGNORECASE,
    )
    lineas_titulo = textwrap.wrap(titulo_limpio, width=28)[:3]
    y_actual = 290
    for linea in lineas_titulo:
        draw.text((56, y_actual), linea, fill="#F8FAFC", font=f_titulo)
        y_actual += 68

    y_card = max(y_actual + 28, 520)
    draw.rounded_rectangle(
        [56, y_card, w - 56, y_card + 165],
        radius=24,
        fill="#1E293B",
        outline="#334155",
        width=2,
    )
    draw.text((88, y_card + 22), "TARIFA REFERENCIAL", fill="#94A3B8", font=f_sub)
    draw.text(
        (88, y_card + 62),
        texto_precio or "Consultar precio",
        fill="#4ADE80",
        font=f_precio,
    )

    y_chips = y_card + 195
    x_chip = 56
    chips: list[str] = []
    if duracion_min and duracion_min > 0:
        chips.append(f"Duración: {duracion_min} min")
    if garantia_dias and garantia_dias > 0:
        chips.append(f"Garantía: {garantia_dias} días")

    for chip in chips:
        bbox = draw.textbbox((0, 0), chip, font=f_chip)
        ancho_chip = (bbox[2] - bbox[0]) + 44
        draw.rounded_rectangle(
            [x_chip, y_chips, x_chip + ancho_chip, y_chips + 58],
            radius=20,
            fill="#1E293B",
            outline="#475569",
            width=2,
        )
        draw.text((x_chip + 22, y_chips + 13), chip, fill="#E2E8F0", font=f_chip)
        x_chip += ancho_chip + 18

    draw.line([56, h - 115, w - 56, h - 115], fill="#334155", width=2)
    draw.text(
        (56, h - 85),
        "Agenda y detalles en sealquilamarido.com/mecanica",
        fill="#94A3B8",
        font=f_pie,
    )

    buf = BytesIO()
    img.save(buf, format="PNG", optimize=True)
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
