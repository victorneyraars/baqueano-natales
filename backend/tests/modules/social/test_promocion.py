"""Tests del modulo promocion (SVG generation pura, sin HTTP)."""
import pytest
from fastapi import HTTPException

from app.modules.promocion import brand_kit as bk
from app.modules.promocion import services, svg_service as svg, templates


# ------------------------------------------------------------ plantillas

def test_5_plantillas_registradas():
    assert set(templates.TEMPLATES.keys()) == {
        "nuevo_servicio", "oferta", "destacado", "evento", "profesional",
    }


def test_listar_plantillas_metadata():
    items = services.listar_plantillas()
    assert len(items) == 5
    for p in items:
        assert "id" in p
        assert "nombre" in p
        assert "params_requeridos" in p
        assert "params_opcionales" in p


# ------------------------------------------------------------ render OK

@pytest.mark.parametrize("plantilla,params", [
    ("nuevo_servicio", {"prestador": "Taller", "servicio": "Cambio aceite"}),
    ("oferta", {"prestador": "Taller", "titulo": "Descuento"}),
    ("destacado", {"prestador": "Taller", "categoria": "Mecanica"}),
    ("evento", {"titulo": "Feria", "fecha": "Sab 2 nov"}),
    ("profesional", {"prestador": "Taller", "oficio": "Mecanico", "frase": "Confia"}),
])
def test_render_basico_ok(plantilla, params):
    result = services.generar_afiche(plantilla, "ig_feed", params)
    assert "svg" in result
    assert result["plantilla"] == plantilla
    assert result["tamano"] == "ig_feed"
    assert result["width"] == 1080
    assert result["height"] == 1350
    assert len(result["svg"]) > 100


def test_render_todos_los_tamanos():
    """La misma plantilla funciona en todos los tamanos."""
    for tamano in bk.TAMANOS.keys():
        result = services.generar_afiche(
            "nuevo_servicio",
            tamano,
            {"prestador": "X", "servicio": "Y"},
        )
        w, h = bk.TAMANOS[tamano]
        assert result["width"] == w
        assert result["height"] == h


# ------------------------------------------------------------ seguridad

def test_xss_escape():
    """El texto malicioso se escapa (svgwrite lo hace por nosotros)."""
    result = services.generar_afiche(
        "nuevo_servicio",
        "ig_feed",
        {
            "prestador": '<script>alert("xss")</script>',
            "servicio": "Normal",
        },
    )
    # El string malicioso literal NO debe aparecer
    assert '<script>alert("xss")</script>' not in result["svg"]
    # Pero el texto (escapado) s?
    assert "&lt;script&gt;" in result["svg"]


def test_plantilla_desconocida_404():
    with pytest.raises(HTTPException) as exc:
        services.generar_afiche("no_existe", "ig_feed", {})
    assert exc.value.status_code == 404


def test_tamano_desconocido_404():
    with pytest.raises(HTTPException) as exc:
        services.generar_afiche("nuevo_servicio", "no_existe", {"prestador": "X", "servicio": "Y"})
    assert exc.value.status_code == 404


def test_demasiados_params_422():
    params = {f"k{i}": "v" for i in range(31)}
    with pytest.raises(HTTPException) as exc:
        services.generar_afiche("nuevo_servicio", "ig_feed", params)
    assert exc.value.status_code == 422


def test_param_str_demasiado_largo_422():
    with pytest.raises(HTTPException) as exc:
        services.generar_afiche(
            "nuevo_servicio", "ig_feed",
            {"prestador": "x" * 3000, "servicio": "y"},
        )
    assert exc.value.status_code == 422


def test_param_lista_demasiado_larga_422():
    with pytest.raises(HTTPException) as exc:
        services.generar_afiche(
            "destacado", "ig_feed",
            {"prestador": "X", "categoria": "Y", "especialidades": [f"e{i}" for i in range(25)]},
        )
    assert exc.value.status_code == 422


# ------------------------------------------------------------ svg helpers

def test_canvas_tamano_invalido():
    with pytest.raises(ValueError):
        svg.canvas("no_existe")


def test_to_string_devuelve_xml():
    dwg = svg.canvas("ig_feed")
    out = svg.to_string(dwg)
    assert out.startswith("<")
    assert "svg" in out
    assert "xmlns" in out
