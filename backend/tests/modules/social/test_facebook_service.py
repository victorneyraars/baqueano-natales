"""Tests de facebook_service.py con respx (mock de httpx)."""
import httpx
import pytest
import respx

from app.core.config import settings
from app.modules.social import facebook_service


@pytest.fixture(autouse=True)
def _facebook_config(monkeypatch):
    monkeypatch.setattr(settings, "FACEBOOK_APP_ID", "app-id-test")
    monkeypatch.setattr(settings, "FACEBOOK_APP_SECRET", "app-secret-test")
    monkeypatch.setattr(
        settings,
        "FACEBOOK_OAUTH_REDIRECT_URI",
        "https://dev-api.baqueanonatales.com/api/v1/admin/social/facebook/oauth/callback",
    )
    monkeypatch.setattr(settings, "FACEBOOK_GRAPH_API_VERSION", "v26.0")
    monkeypatch.setattr(
        settings,
        "FACEBOOK_OAUTH_SCOPES",
        "pages_show_list,pages_read_engagement,pages_manage_posts",
    )


# ------------------------------------------------------------ URL autorizacion

def test_url_autorizacion_contiene_params():
    url = facebook_service.construir_url_autorizacion("state-abc")
    assert "client_id=app-id-test" in url
    assert "state=state-abc" in url
    assert "scope=pages_show_list" in url
    assert "response_type=code" in url
    assert "redirect_uri=https%3A%2F%2Fdev-api.baqueanonatales.com" in url
    assert "dialog/oauth" in url


def test_url_autorizacion_sin_app_id(monkeypatch):
    monkeypatch.setattr(settings, "FACEBOOK_APP_ID", "")
    with pytest.raises(RuntimeError, match="FACEBOOK_APP_ID"):
        facebook_service.construir_url_autorizacion("s")


# ------------------------------------------------------------ exchange code

@respx.mock
async def test_intercambiar_codigo_ok():
    respx.get("https://graph.facebook.com/v26.0/oauth/access_token").mock(
        return_value=httpx.Response(200, json={"access_token": "short-tok"})
    )
    token, err = await facebook_service.intercambiar_codigo_por_token("code123")
    assert err is None
    assert token == "short-tok"


@respx.mock
async def test_intercambiar_codigo_error_meta():
    respx.get("https://graph.facebook.com/v26.0/oauth/access_token").mock(
        return_value=httpx.Response(
            400,
            json={
                "error": {
                    "message": "Invalid code",
                    "code": 100,
                    "type": "OAuthException",
                    "fbtrace_id": "xyz",
                }
            },
        )
    )
    token, err = await facebook_service.intercambiar_codigo_por_token("malo")
    assert token is None
    assert err is not None
    assert err.message == "Invalid code"
    assert err.code == 100
    assert err.trace_id == "xyz"


@respx.mock
async def test_intercambiar_codigo_sin_token_en_respuesta():
    respx.get("https://graph.facebook.com/v26.0/oauth/access_token").mock(
        return_value=httpx.Response(200, json={})
    )
    token, err = await facebook_service.intercambiar_codigo_por_token("c")
    assert token is None
    assert err is not None
    assert "sin access_token" in err.message


@respx.mock
async def test_intercambiar_codigo_error_de_red():
    respx.get("https://graph.facebook.com/v26.0/oauth/access_token").mock(
        side_effect=httpx.ConnectError("timeout")
    )
    token, err = await facebook_service.intercambiar_codigo_por_token("c")
    assert token is None
    assert err is not None
    assert "Error de red" in err.message


# ------------------------------------------------------------ extender token

@respx.mock
async def test_extender_token_ok():
    respx.get("https://graph.facebook.com/v26.0/oauth/access_token").mock(
        return_value=httpx.Response(200, json={"access_token": "long-tok"})
    )
    token, err = await facebook_service.extender_token("short")
    assert err is None
    assert token == "long-tok"


# ------------------------------------------------------------ listar paginas

@respx.mock
async def test_listar_paginas_ok():
    respx.get("https://graph.facebook.com/v26.0/me/accounts").mock(
        return_value=httpx.Response(
            200,
            json={
                "data": [
                    {
                        "id": "111",
                        "name": "Pagina Uno",
                        "category": "Local Business",
                        "tasks": ["MANAGE", "CREATE_CONTENT"],
                        "access_token": "page-tok-1",
                    },
                    {
                        "id": "222",
                        "name": "Pagina Dos",
                        "access_token": "page-tok-2",
                    },
                ]
            },
        )
    )
    paginas, err = await facebook_service.listar_paginas("user-tok")
    assert err is None
    assert len(paginas) == 2
    assert paginas[0].id == "111"
    assert paginas[0].access_token == "page-tok-1"
    assert paginas[1].name == "Pagina Dos"


@respx.mock
async def test_listar_paginas_sin_datos():
    respx.get("https://graph.facebook.com/v26.0/me/accounts").mock(
        return_value=httpx.Response(200, json={"data": []})
    )
    paginas, err = await facebook_service.listar_paginas("user-tok")
    assert err is None
    assert paginas == []


# ------------------------------------------------------------ verificar token

@respx.mock
async def test_verificar_token_pagina_ok():
    respx.get("https://graph.facebook.com/v26.0/111").mock(
        return_value=httpx.Response(200, json={"name": "Baqueano Natales"})
    )
    nombre, err = await facebook_service.verificar_token_pagina("111", "tok")
    assert err is None
    assert nombre == "Baqueano Natales"


@respx.mock
async def test_verificar_token_pagina_expirado():
    respx.get("https://graph.facebook.com/v26.0/111").mock(
        return_value=httpx.Response(
            401,
            json={"error": {"message": "Token expired", "code": 190}},
        )
    )
    nombre, err = await facebook_service.verificar_token_pagina("111", "viejo")
    assert nombre is None
    assert err is not None
    assert err.code == 190


# ------------------------------------------------------------ helpers

def test_buscar_pagina_encuentra():
    p1 = facebook_service.PaginaFacebook(id="1", name="A")
    p2 = facebook_service.PaginaFacebook(id="2", name="B")
    assert facebook_service.buscar_pagina([p1, p2], "2") is p2


def test_buscar_pagina_no_encuentra():
    p1 = facebook_service.PaginaFacebook(id="1", name="A")
    assert facebook_service.buscar_pagina([p1], "999") is None


def test_pagina_to_public_dict_no_expone_token():
    p = facebook_service.PaginaFacebook(
        id="1", name="Test", access_token="EAAB_secreto"
    )
    d = p.to_public_dict()
    assert "access_token" not in d
    assert "EAAB_secreto" not in str(d)
