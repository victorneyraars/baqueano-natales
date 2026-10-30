# Pipeline de generación de assets de marca.
# Uso: python3 generate.py [--only web|android|ios|print]
import json
import sys
from io import BytesIO
from pathlib import Path

import cairosvg
from PIL import Image

ROOT = Path(__file__).parent
LOGOS = ROOT / "logos"
OUTPUTS = ROOT / "outputs"

def load_brand():
    with open(ROOT / "brand.json") as f:
        return json.load(f)

def svg_to_png(svg_path, size, output_path, bg=None, keep_aspect=False):
    """Renderiza SVG a PNG.

    Args:
        size: ancho del PNG en px.
        keep_aspect: si True, lee el viewBox del SVG y calcula
            la altura proporcional (útil para logos horizontales).
    """
    height = size
    if keep_aspect:
        import re
        with open(svg_path) as f:
            content = f.read()
        m = re.search(r'viewBox=["\']([^"\']+)["\']', content)
        if m:
            parts = m.group(1).split()
            if len(parts) >= 4:
                vb_w, vb_h = float(parts[2]), float(parts[3])
                if vb_w > 0:
                    height = int(size * vb_h / vb_w)
    png_bytes = cairosvg.svg2png(
        url=str(svg_path),
        output_width=size,
        output_height=height,
    )
    img = Image.open(BytesIO(png_bytes)).convert("RGBA")
    if bg:
        background = Image.new("RGBA", img.size, bg)
        background.paste(img, (0, 0), img)
        img = background
    output_path = Path(output_path)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    img.save(output_path, "PNG", optimize=True)
    return output_path

def _build_ico(ico_path, sizes, png_dir):
    """Construye ICO multi-resolución con PNG embebido (Windows Vista+).

    Pillow 10.x tiene bug: save(format=ICO) con append_images solo empaqueta
    el primer tamaño. Este helper escribe el binario ICO a mano.
    """
    import struct

    pngs = [
        (png_dir / f"favicon-{w}x{h}.png").read_bytes() for w, h in sizes
    ]
    header = struct.pack("<HHH", 0, 1, len(pngs))
    entries = b""
    offset = 6 + 16 * len(pngs)
    for (w, h), png in zip(sizes, pngs):
        bw = w if w < 256 else 0
        bh = h if h < 256 else 0
        entries += struct.pack(
            "<BBBBHHII", bw, bh, 0, 0, 1, 32, len(png), offset
        )
        offset += len(png)
    Path(ico_path).write_bytes(header + entries + b"".join(pngs))


def generate_web(brand):
    print("Web assets...")
    web = OUTPUTS / "web"
    web.mkdir(parents=True, exist_ok=True)
    for size in (16, 32, 48):
        svg_to_png(LOGOS / "vasquez-symbol-favicon.svg", size, web / f"favicon-{size}x{size}.png")
    svg_to_png(LOGOS / "vasquez-symbol.svg", 180, web / "apple-touch-icon.png")
    for size in (192, 512):
        svg_to_png(LOGOS / "vasquez-symbol.svg", size, web / f"icon-{size}x{size}.png")
    svg_to_png(LOGOS / "vasquez-symbol.svg", 410, web / "maskable-512x512.png")
    maskable = Image.open(web / "maskable-512x512.png").convert("RGBA")
    canvas = Image.new("RGBA", (512, 512), brand["palette"]["primary"])
    canvas.paste(maskable, ((512-410)//2, (512-410)//2), maskable)
    canvas.save(web / "maskable-512x512.png")
    favicons = [Image.open(web / f"favicon-{s}x{s}.png") for s in (16, 32, 48)]
    _build_ico(web / "favicon.ico", [(16,16), (32,32), (48,48)], web)
    og = Image.new("RGBA", (1200, 630), brand["palette"]["surface"])
    logo_path = svg_to_png(LOGOS / "vasquez-logo.svg", 800, web / "_tmp_logo.png")
    logo = Image.open(logo_path).convert("RGBA")
    og.paste(logo, ((1200-logo.width)//2, (630-logo.height)//2), logo)
    og.convert("RGB").save(web / "og-image.png", "PNG", optimize=True)
    (web / "_tmp_logo.png").unlink()
    manifest = {
        "name": brand["name"],
        "short_name": brand["short_name"],
        "description": brand["metadata"]["tagline"],
        "start_url": "/",
        "display": "standalone",
        "background_color": brand["palette"]["surface"],
        "theme_color": brand["palette"]["primary"],
        "icons": [
            {"src": "/icon-192x192.png", "sizes": "192x192", "type": "image/png"},
            {"src": "/icon-512x512.png", "sizes": "512x512", "type": "image/png"},
            {"src": "/maskable-512x512.png", "sizes": "512x512", "type": "image/png", "purpose": "maskable"},
        ],
    }
    (web / "manifest.json").write_text(json.dumps(manifest, indent=2, ensure_ascii=False))
    print(f"  OK {len(list(web.iterdir()))} archivos web")

def generate_android(brand):
    print("Android assets...")
    and_dir = OUTPUTS / "android"
    and_dir.mkdir(parents=True, exist_ok=True)
    mipmaps = [
        ("mdpi", 48),
        ("hdpi", 72),
        ("xhdpi", 96),
        ("xxhdpi", 144),
        ("xxxhdpi", 192),
    ]
    for density, size in mipmaps:
        svg_to_png(
            LOGOS / "vasquez-symbol.svg",
            size,
            and_dir / f"mipmap-{density}" / "ic_launcher.png",
        )
    svg_to_png(
        LOGOS / "vasquez-symbol.svg",
        432,
        and_dir / "drawable" / "ic_launcher_foreground.png",
    )
    svg_to_png(
        LOGOS / "vasquez-mono.svg",
        432,
        and_dir / "drawable" / "ic_launcher_monochrome.png",
    )
    adaptive_xml = """<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@drawable/ic_launcher_foreground"/>
    <monochrome android:drawable="@drawable/ic_launcher_monochrome"/>
</adaptive-icon>
"""
    xml_path = and_dir / "mipmap-anydpi-v26" / "ic_launcher.xml"
    xml_path.parent.mkdir(parents=True, exist_ok=True)
    xml_path.write_text(adaptive_xml)
    color_xml = f"""<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">{brand["palette"]["primary"]}</color>
</resources>
"""
    color_path = and_dir / "values" / "ic_launcher_background.xml"
    color_path.parent.mkdir(parents=True, exist_ok=True)
    color_path.write_text(color_xml)
    print(f"  OK {len(list(and_dir.rglob("*.png")))} PNGs Android")

def generate_ios(brand):
    print("iOS assets...")
    ios_dir = OUTPUTS / "ios"
    ios_dir.mkdir(parents=True, exist_ok=True)
    sizes = [
        ("Icon-App-20x20@2x.png", 40),
        ("Icon-App-20x20@3x.png", 60),
        ("Icon-App-29x29@2x.png", 58),
        ("Icon-App-29x29@3x.png", 87),
        ("Icon-App-40x40@2x.png", 80),
        ("Icon-App-40x40@3x.png", 120),
        ("Icon-App-60x60@2x.png", 120),
        ("Icon-App-60x60@3x.png", 180),
        ("Icon-App-76x76@2x.png", 152),
        ("Icon-App-83.5x83.5@2x.png", 167),
        ("Icon-App-1024x1024@1x.png", 1024),
    ]
    for filename, size in sizes:
        svg_to_png(
            LOGOS / "vasquez-symbol.svg",
            size,
            ios_dir / filename,
            bg=brand["palette"]["primary"],
        )
    print(f"  OK {len(list(ios_dir.iterdir()))} archivos iOS")


def generate_print(brand):
    print("Print assets...")
    pdir = OUTPUTS / "print"
    pdir.mkdir(parents=True, exist_ok=True)
    # Logo horizontal (respeta aspect ratio 3:1)
    svg_to_png(LOGOS / "vasquez-logo.svg", 2048, pdir / "logo-2048.png", keep_aspect=True)
    svg_to_png(LOGOS / "vasquez-logo.svg", 1024, pdir / "logo-1024.png", keep_aspect=True)
    svg_to_png(LOGOS / "vasquez-logo.svg", 512, pdir / "logo-512.png", keep_aspect=True)
    # Symbol cuadrado
    svg_to_png(LOGOS / "vasquez-symbol.svg", 1024, pdir / "symbol-1024.png")
    import shutil
    shutil.copy(LOGOS / "vasquez-logo.svg", pdir / "logo.svg")
    shutil.copy(LOGOS / "vasquez-symbol.svg", pdir / "symbol.svg")
    shutil.copy(LOGOS / "vasquez-mono.svg", pdir / "mono.svg")
    print(f"  OK {len(list(pdir.iterdir()))} archivos print")


def main():
    only = None
    if len(sys.argv) > 1 and sys.argv[1] == "--only":
        only = sys.argv[2] if len(sys.argv) > 2 else None
    brand = load_brand()
    generators = {
        "web": generate_web,
        "android": generate_android,
        "ios": generate_ios,
        "print": generate_print,
    }
    targets = [only] if only and only in generators else list(generators.keys())
    for name in targets:
        generators[name](brand)
    print("\n✓ Generación completa")


if __name__ == "__main__":
    main()


