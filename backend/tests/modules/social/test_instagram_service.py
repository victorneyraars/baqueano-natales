"""Tests de instagram_service.py con respx (mock de httpx)."""
import httpx
import pytest
import respx

from app.modules.social import instagram_service


# ------------------------------------------------------------ helpers

@pytest.fixture(autouse=True)
def _graph_version(monkeypatch):
    from app.core.config import settings
    monkeypatch.setattr(settings, "FACEBOOK_GRAPH_API_VERSION", "v26.0")


# ------------------------------------------------------------ validaciones

async def test_sin_ig_user_id_falla():
    id_, err = await instagram_service.publicar_post_en_instagram(
        ig_user_id="", page_token="TOK", image_url="https://x.com/i.jpg",
        caption="test",
    )
    assert id_ is None
    assert err is not None
    assert "Faltan" in err.message


async def test_sin_imagen_falla():
    id_, err = await instagram_service.publicar_post_en_instagram(
        ig_user_id="IG1", page_token="TOK", image_url="", caption="test",
    )
    assert id_ is None
    assert err is not None
    assert "image_url" in err.message


# ------------------------------------------------------------ publicacion OK

@respx.mock
async def test_publicar_ok():
    """Container + publish exitoso."""
    respx.post("https://graph.facebook.com/v26.0/IG1/media").mock(
        return_value=httpx.Response(200, json={"id": "CONTAINER_1"})
    )
    respx.post("https://graph.facebook.com/v26.0/IG1/media_publish").mock(
        return_value=httpx.Response(200, json={"id": "POST_1"})
    )

    media_id, err = await instagram_service.publicar_post_en_instagram(
        ig_user_id="IG1", page_token="TOK",
        image_url="https://x.com/i.jpg", caption="Hola IG",
    )
    assert err is None
    assert media_id == "POST_1"


# ------------------------------------------------------------ container creado pero error en publish

@respx.mock
async def test_container_error_no_listo_reintenta_y_falla():
    """Si el container nunca esta listo, devuelve error tras reintentos."""
    respx.post("https://graph.facebook.com/v26.0/IG1/media").mock(
        return_value=httpx.Response(200, json={"id": "CONTAINER_1"})
    )
    respx.post("https://graph.facebook.com/v26.0/IG1/media_publish").mock(
        return_value=httpx.Response(400, json={
            "error": {"message": "Media ID is not available", "code": 9007}
        })
    )

    media_id, err = await instagram_service.publicar_post_en_instagram(
        ig_user_id="IG1", page_token="TOK",
        image_url="https://x.com/i.jpg", caption="Hola IG",
        max_reintentos=2,
    )
    assert media_id is None
    assert err is not None
    assert "no estuvo listo" in err.message.lower()


# ------------------------------------------------------------ errores de Meta

@respx.mock
async def test_error_creando_container():
    respx.post("https://graph.facebook.com/v26.0/IG1/media").mock(
        return_value=httpx.Response(400, json={
            "error": {"message": "Invalid image", "code": 100}
        })
    )

    media_id, err = await instagram_service.publicar_post_en_instagram(
        ig_user_id="IG1", page_token="TOK",
        image_url="https://x.com/mala.png", caption="test",
    )
    assert media_id is None
    assert err is not None
    assert "Invalid image" in err.message


@respx.mock
async def test_error_sin_creation_id():
    respx.post("https://graph.facebook.com/v26.0/IG1/media").mock(
        return_value=httpx.Response(200, json={})
    )
    media_id, err = await instagram_service.publicar_post_en_instagram(
        ig_user_id="IG1", page_token="TOK",
        image_url="https://x.com/i.jpg", caption="test",
    )
    assert media_id is None
    assert err is not None
    assert "creation_id" in err.message


@respx.mock
async def test_error_de_red_en_container():
    respx.post("https://graph.facebook.com/v26.0/IG1/media").mock(
        side_effect=httpx.ConnectError("timeout")
    )
    media_id, err = await instagram_service.publicar_post_en_instagram(
        ig_user_id="IG1", page_token="TOK",
        image_url="https://x.com/i.jpg", caption="test",
    )
    assert media_id is None
    assert err is not None
    assert "Error de red" in err.message
