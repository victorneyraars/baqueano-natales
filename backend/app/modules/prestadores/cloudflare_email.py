"""Gestion de Cloudflare Email Routing via API (destinations + rules).

Uso exclusivo server-side. Reutiliza CF_API_KEY y CF_API_EMAIL del env.
Docs: https://developers.cloudflare.com/api/operations/email-routing
"""
import os
import json
import logging
import urllib.request
import urllib.error

logger = logging.getLogger(__name__)

CF_API = "https://api.cloudflare.com/client/v4"
# Zone rentacarvasquez.com
RENTACAR_ZONE_ID = "3dd2b73b92db1bdfec1ba7a7fc6dfd6f"
# Account (compartida para todos los dominios)
CF_ACCOUNT_ID = "37959226fabd04f973ea41c91f200fad"
HEADERS_BASE = {"User-Agent": "Baqueano-Setup/1.0", "Content-Type": "application/json"}


def _auth_headers() -> dict:
    return {
        **HEADERS_BASE,
        "X-Auth-Email": os.environ.get("CF_API_EMAIL", ""),
        "X-Auth-Key": os.environ.get("CF_API_KEY", ""),
    }


def _request(method: str, path: str, body: dict | None = None) -> dict:
    """Ejecuta una request a CF API. Devuelve dict con success/result/errors."""
    data = json.dumps(body).encode() if body else None
    req = urllib.request.Request(
        f"{CF_API}{path}",
        data=data,
        method=method,
        headers=_auth_headers(),
    )
    try:
        with urllib.request.urlopen(req) as r:
            return json.load(r)
    except urllib.error.HTTPError as e:
        err_body = e.read().decode()
        logger.error(f"CF API {method} {path} -> {e.code}: {err_body[:300]}")
        try:
            return json.loads(err_body)
        except Exception:
            return {"success": False, "errors": [{"message": err_body[:200]}]}


def listar_destinations() -> list[dict]:
    """Devuelve los emails destino configurados en la cuenta CF."""
    r = _request(
        "GET", f"/accounts/{CF_ACCOUNT_ID}/email/routing/addresses"
    )
    if not r.get("success"):
        return []
    return [
        {
            "email": a.get("email"),
            "verified": a.get("verified") is not None,
            "verified_at": a.get("verified"),
        }
        for a in r.get("result", [])
    ]


def agregar_destination(email: str) -> dict:
    """Agrega un email como destination. CF envia email de verificacion.

    Devuelve {ok: bool, verified: bool, error: str | None}.
    Si ya existia y estaba verificado, devuelve ok=True, verified=True.
    """
    existentes = listar_destinations()
    for d in existentes:
        if d["email"].lower() == email.lower():
            return {"ok": True, "verified": d["verified"], "error": None}

    r = _request(
        "POST",
        f"/accounts/{CF_ACCOUNT_ID}/email/routing/addresses",
        body={"email": email},
    )
    if r.get("success"):
        return {"ok": True, "verified": False, "error": None}
    err = r.get("errors") or [{"message": "unknown"}]
    return {"ok": False, "verified": False, "error": err[0].get("message", "unknown")}


def verificar_destination(email: str) -> bool:
    """Consulta si un email esta verificado en CF."""
    for d in listar_destinations():
        if d["email"].lower() == email.lower():
            return d["verified"]
    return False


def actualizar_catch_all(email_destino: str) -> dict:
    """Configura el catch-all para forwardear a email_destino.

    Requiere que email_destino este verificado.
    """
    if not verificar_destination(email_destino):
        return {
            "ok": False,
            "error": f"El email {email_destino} no esta verificado en Cloudflare",
        }

    r = _request(
        "PUT",
        f"/zones/{RENTACAR_ZONE_ID}/email/routing/rules/catch_all",
        body={
            "enabled": True,
            "name": f"Catch-all -> {email_destino}",
            "matchers": [{"type": "all"}],
            "actions": [
                {"type": "forward", "value": [email_destino]}
            ],
        },
    )
    if r.get("success"):
        return {"ok": True, "error": None}
    err = r.get("errors") or [{"message": "unknown"}]
    return {"ok": False, "error": err[0].get("message", "unknown")}


def crear_regla_override(canal_tipo: str, email_destino: str) -> dict:
    """Crea regla especifica para un canal (ej: facturacion@ -> contador@x.com).

    Se ejecuta ANTES que el catch-all (priority menor = mas prioridad).
    """
    if not verificar_destination(email_destino):
        return {
            "ok": False,
            "error": f"{email_destino} no esta verificado en CF",
        }
    r = _request(
        "POST",
        f"/zones/{RENTACAR_ZONE_ID}/email/routing/rules",
        body={
            "enabled": True,
            "name": f"Override {canal_tipo} -> {email_destino}",
            "matchers": [
                {
                    "type": "literal",
                    "field": "to",
                    "value": f"{canal_tipo}@rentacarvasquez.com",
                }
            ],
            "actions": [{"type": "forward", "value": [email_destino]}],
        },
    )
    if r.get("success"):
        return {"ok": True, "rule_id": r.get("result", {}).get("id")}
    err = r.get("errors") or [{"message": "unknown"}]
    return {"ok": False, "error": err[0].get("message", "unknown")}


def eliminar_regla_override(rule_id: str) -> bool:
    """Elimina una regla de override por ID."""
    r = _request(
        "DELETE",
        f"/zones/{RENTACAR_ZONE_ID}/email/routing/rules/{rule_id}",
    )
    return bool(r.get("success"))
