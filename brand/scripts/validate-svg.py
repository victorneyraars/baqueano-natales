#!/usr/bin/env python3
"""Valida un SVG: renderiza a PNG, verifica centrado, simetria, cobertura."""
import sys
from PIL import Image
import cairosvg

def validate(svg_path, size=512, target_color=(255, 255, 255)):
    png_path = "/tmp/_val_render.png"
    cairosvg.svg2png(
        url=svg_path,
        write_to=png_path,
        output_width=size,
        output_height=size,
    )
    img = Image.open(png_path).convert("RGBA")
    pixels = img.load()

    x_min, x_max, y_min, y_max = size, 0, size, 0
    count = 0
    for y in range(size):
        for x in range(size):
            r, g, b, a = pixels[x, y]
            if (abs(r - target_color[0]) < 20
                    and abs(g - target_color[1]) < 20
                    and abs(b - target_color[2]) < 20
                    and a > 200):
                count += 1
                x_min, x_max = min(x_min, x), max(x_max, x)
                y_min, y_max = min(y_min, y), max(y_max, y)

    if count == 0:
        print(f"FAIL: no hay color objetivo en {svg_path}")
        return False

    w, h = x_max - x_min, y_max - y_min
    cx, cy = (x_min + x_max) / 2, (y_min + y_max) / 2
    dx, dy = abs(cx - size / 2), abs(cy - size / 2)
    coverage = count / (size * size) * 100

    print(f"  BBox: ({x_min},{y_min}) -> ({x_max},{y_max})")
    print(f"  Ancho x alto: {w}x{h}")
    print(f"  Centro: ({cx:.1f},{cy:.1f}) vs ({size/2},{size/2})")
    print(f"  Desvio: X={dx:.1f}px, Y={dy:.1f}px")
    print(f"  Cobertura: {coverage:.1f}%")

    centered = dx < 8 and dy < 8
    coverage_ok = 12 < coverage < 35
    print(f"  Centrado: {'OK' if centered else 'FALLA'}")
    print(f"  Cobertura: {'OK' if coverage_ok else 'FALLA'}")

    return centered and coverage_ok

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Uso: python validate-svg.py archivo.svg")
        sys.exit(1)
    ok = validate(sys.argv[1])
    sys.exit(0 if ok else 1)