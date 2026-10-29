"""Servicios de generación y empaquetado de brand kits."""
import io
import mimetypes
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

def list_assets(slug: str) -> dict:
    """Lista todos los assets del brand kit agrupados por categoria."""
    base = STATIC_DIR / slug
    if not base.exists() or not base.is_dir():
        raise FileNotFoundError(f"brand kit no existe: {slug}")

    out: dict[str, list[dict]] = {
        "web": [],
        "android": [],
        "ios": [],
        "print": [],
    }

    for path in sorted(base.rglob("*")):
        if not path.is_file():
            continue
        rel = path.relative_to(base)
        if not rel.parts:
            continue
        category = rel.parts[0]
        if category not in out:
            continue

        content_type, _ = mimetypes.guess_type(str(path))
        info: dict = {
            "path": rel.as_posix(),
            "name": path.name,
            "category": category,
            "size_bytes": path.stat().st_size,
            "content_type": content_type or "application/octet-stream",
        }

        if content_type == "image/png":
            try:
                from PIL import Image
                with Image.open(path) as img:
                    info["dimensions"] = f"{img.width}x{img.height}"
            except Exception:
                pass

        out[category].append(info)

    total = sum(len(v) for v in out.values())
    return {"slug": slug, "total": total, "categories": out}


def get_asset_path(slug: str, relative_path: str) -> Path:
    """Resuelve y valida el path absoluto de un asset."""
    base = STATIC_DIR / slug
    if not base.exists() or not base.is_dir():
        raise FileNotFoundError(f"brand kit no existe: {slug}")

    target = (base / relative_path).resolve()
    base_resolved = base.resolve()

    try:
        target.relative_to(base_resolved)
    except ValueError:
        raise ValueError("path fuera del brand kit")

    if not target.exists() or not target.is_file():
        raise FileNotFoundError(f"asset no existe: {relative_path}")

    return target
