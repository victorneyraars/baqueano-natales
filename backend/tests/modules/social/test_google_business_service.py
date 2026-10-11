"""Tests de google_business_service.py con respx (mock de httpx)."""
import httpx
import pytest
import respx

from app.core.config import settings
from app.modules.social import google_business_service as gbp


@pytest.fixture(autouse=True)
def _gbp_config(monkeypatch):
    """Habilita GBP para los tests y fija la version de API."""
    monkeypatch.setattr(settings, "GOOGLE_BUSINESS_ENABLED", True)
    monkeypatch.setattr(settings, "GOOGLE_BUSINESS_API_VERSION", "v4")


# ------------------------------------------------------------ gating

async def test_deshabilitado_no_llama_http(monkeypatch):
    """Con GOOGLE_BUSINESS_ENABLED=false, devuelve error sin HTTP."""
    monkeypatch.setattr(settings, "GOOGLE_BUSINESS_ENABLED", False)
    name, err = await gbp.publicar_post_en_gbp(
        account_name="accounts/123",
        location_id="456",
        access_token="TOK",
        mensaje="Hola GBP",
    )
    assert name is None
    assert err is not None
    assert "deshabilitado" in err.message.lower()


async def test_faltan_params():
    name, err = await gbp.publicar_post_en_gbp(
        account_name="", location_id="456", access_token="TOK",
        mensaje="test",
    )
    assert name is None
    assert "Faltan" in err.message


async def test_sin_mensaje_falla():
    name, err = await gbp.publicar_post_en_gbp(
        account_name="accounts/123", location_id="456",
        access_token="TOK", mensaje="",
    )
    assert name is None
    assert "mensaje" in err.message.lower()


# ------------------------------------------------------------ publicacion OK

@respx.mock
async def test_publicar_ok_sin_imagen():
    url = "https://mybusiness.googleapis.com/v4/accounts/123/locations/456/localPosts"
    respx.post(url).mock(
        return_value=httpx.Response(200, json={
            "name": "accounts/123/locations/456/localPosts/789"
        })
    )
    name, err = await gbp.publicar_post_en_gbp(
        account_name="accounts/123",
        location_id="456",
        access_token="TOK",
        mensaje="Hola GBP",
    )
    assert err is None
    assert name == "accounts/123/locations/456/localPosts/789"


@respx.mock
async def test_publicar_ok_con_imagen():
    url = "https://mybusiness.googleapis.com/v4/accounts/123/locations/456/localPosts"
    route = respx.post(url).mock(
        return_value=httpx.Response(201, json={
            "name": "accounts/123/locations/456/localPosts/999"
        })
    )
    name, err = await gbp.publicar_post_en_gbp(
        account_name="accounts/123",
        location_id="456",
        access_token="TOK",
        mensaje="Con foto",
        image_url="https://example.com/img.jpg",
    )
    assert err is None
    assert name == "accounts/123/locations/456/localPosts/999"
    # El body debe incluir media[]
    import json
    body = json.loads(route.calls[0].request.content)
    assert "media" in body
    assert body["media"][0]["sourceUrl"] == "https://example.com/img.jpg"


# ------------------------------------------------------------ errores

@respx.mock
async def test_error_google():
    url = "https://mybusiness.googleapis.com/v4/accounts/123/locations/456/localPosts"
    respx.post(url).mock(
        return_value=httpx.Response(403, json={
            "error": {
                "code": 403,
                "message": "API not enabled",
                "status": "PERMISSION_DENIED",
            }
        })
    )
    name, err = await gbp.publicar_post_en_gbp(
        account_name="accounts/123", location_id="456",
        access_token="TOK", mensaje="test",
    )
    assert name is None
    assert err is not None
    assert err.code == 403
    assert err.status == "PERMISSION_DENIED"
    assert "API not enabled" in err.message


@respx.mock
async def test_respuesta_sin_name():
    url = "https://mybusiness.googleapis.com/v4/accounts/123/locations/456/localPosts"
    respx.post(url).mock(
        return_value=httpx.Response(200, json={})
    )
    name, err = await gbp.publicar_post_en_gbp(
        account_name="accounts/123", location_id="456",
        access_token="TOK", mensaje="test",
    )
    assert name is None
    assert "name" in err.message


@respx.mock
async def test_error_de_red():
    url = "https://mybusiness.googleapis.com/v4/accounts/123/locations/456/localPosts"
    respx.post(url).mock(side_effect=httpx.ConnectError("timeout"))
    name, err = await gbp.publicar_post_en_gbp(
        account_name="accounts/123", location_id="456",
        access_token="TOK", mensaje="test",
    )
    assert name is None
    assert "Error de red" in err.message
