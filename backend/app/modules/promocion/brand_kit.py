"""Brand kit de Baqueano Natales.

Centraliza colores, fuentes y helpers de branding para todas las plantillas
SVG. Cambiar aca se propaga a todos los afiches generados.

Diseno:
- Paleta coherente con el theme del cliente (verde) y del admin (morado).
- Fuentes web-safe (no requiere instalar fonts custom en el server).
- Tamanos y espaciados en una escala 4px (baseline grid).
"""

# =========================================================
# Colores primarios
# =========================================================

# Verde Baqueano (client, marca principal)
VERDE_PRIMARIO = "#16a34a"
VERDE_OSCURO = "#15803d"
VERDE_CLARO = "#dcfce7"
VERDE_ACENTO = "#22c55e"

# Morado admin (uso secundario)
MORADO_PRIMARIO = "#7c3aed"
MORADO_OSCURO = "#6d28d9"
MORADO_CLARO = "#ede9fe"

# Neutros
NEGRO = "#0f172a"
GRIS_900 = "#1e293b"
GRIS_700 = "#334155"
GRIS_500 = "#64748b"
GRIS_300 = "#cbd5e1"
GRIS_100 = "#f1f5f9"
BLANCO = "#ffffff"

# Acentos (para destacados y CTAs)
NARANJA_CTA = "#f97316"
ROJO_URGENTE = "#ef4444"
AMARILLO_DESTACADO = "#fbbf24"

# =========================================================
# Fuentes
# =========================================================
# Web-safe: no requiere instalar fuentes en el server ni en el cliente.
FONT_FAMILY = "'Helvetica Neue', Helvetica, Arial, sans-serif"
FONT_MONO = "'Courier New', monospace"

# Escala tipografica (px)
FS_HERO = 96
FS_TITULO = 72
FS_SUBTITULO = 44
FS_CUERPO = 32
FS_PIE = 22

# Pesos
FW_BOLD = "700"
FW_SEMIBOLD = "600"
FW_REGULAR = "400"

# =========================================================
# Espaciado (baseline grid 4px)
# =========================================================
SP_XS = 8
SP_SM = 16
SP_MD = 24
SP_LG = 40
SP_XL = 64
SP_XXL = 96

# =========================================================
# Tamanos de afiche (px)
# =========================================================
# Best practices industria:
# - IG feed: 1080x1350 (4:5, mejor rendimiento organico)
# - IG story: 1080x1920 (9:16)
# - FB feed: 1200x630 (1.91:1)
# - GBP post: 720x720 (1:1)
# - Cuadrado universal: 1080x1080
TAMANOS = {
    "ig_feed": (1080, 1350),
    "ig_story": (1080, 1920),
    "ig_cuadrado": (1080, 1080),
    "fb_feed": (1200, 630),
    "gbp_post": (720, 720),
}

# =========================================================
# Textos de marca
# =========================================================
MARCA_NOMBRE = "Baqueano Natales"
MARCA_TAGLINE = "Servicios y oficios de Puerto Natales"
MARCA_HANDLE = "@baqueanonatales"
MARCA_SITIO = "baqueanonatales.com"
