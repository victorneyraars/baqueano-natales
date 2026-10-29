"""Servicios de generación y empaquetado de brand kits."""
import io
import zipfile
from datetime import date
from pathlib import Path

STATIC_DIR = Path(__file__).parent / "static"

def _list_slugs() -> list[str]:
    if not STATIC_DIR.exists():
        return []
    return sorted(p.name for p in STATIC_DIR.iterdir() if p.is_dir())

def build_zip(slug: str) -> tuple[bytes, str]:
    base = STATIC_DIR / slug
    if not base.exists() or not base.is_dir():
        raise FileNotFoundError(f"brand kit no existe: {slug}")

    buf = io.BytesIO()
    with zipfile.ZipFile(buf, "w", zipfile.ZIP_DEFLATED) as zf:
        for path in sorted(base.rglob("*")):
            if path.is_file():
                arcname = path.relative_to(base).as_posix()
                zf.write(path, arcname)

    filename = f"{slug}-brand-kit-{date.today().isoformat()}.zip"
    return buf.getvalue(), filename

def list_available() -> list[str]:
    return _list_slugs()