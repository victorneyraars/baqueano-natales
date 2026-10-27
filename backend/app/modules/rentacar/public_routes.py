"""Endpoints públicos de Rent a Car Vásquez.

Router: router_publico (SIN auth, CORS abierto).
Prefijo final: /api/v1/public/rentacar/...

Soporta ETag / If-None-Match para polling eficiente desde la web
(rentacarvasquez.com) sin transferir datos innecesarios.
"""
import hashlib
import json
from uuid import UUID

from fastapi import APIRouter, Header, HTTPException, Response

from app.core.db import DbSession

from . import services
from .schemas import (
    RentacarReservaCreate,
    RentacarReservaOut,
    RentacarVehiculoOut,
)

router_publico = APIRouter(
    prefix="/public/rentacar", tags=["rentacar-public"]
)


def _etag(payload: object) -> str:
    """Genera un ETag estable (SHA-256 del JSON serializado)."""
    raw = json.dumps(payload, sort_keys=True, default=str).encode()
    return '"' + hashlib.sha256(raw).hexdigest()[:32] + '"'


@router_publico.get(
    "/vehiculos",
    response_model=list[RentacarVehiculoOut],
    summary="Catálogo público de vehículos en alquiler",
)
async def listar_vehiculos_publico(
    db: DbSession,
    response: Response,
    if_none_match: str | None = Header(default=None, alias="If-None-Match"),
):
    vehiculos = await services.listar_vehiculos(db)
    # Serializar a dict para calcular ETag estable
    payload = [RentacarVehiculoOut.model_validate(v).model_dump() for v in vehiculos]
    current_etag = _etag(payload)

    if if_none_match == current_etag:
        return Response(status_code=304, headers={"ETag": current_etag})

    response.headers["ETag"] = current_etag
    response.headers["Cache-Control"] = "public, max-age=30"
    return vehiculos


@router_publico.get(
    "/vehiculos/{vehiculo_id}",
    response_model=RentacarVehiculoOut,
    summary="Detalle público de un vehículo",
)
async def detalle_vehiculo_publico(vehiculo_id: UUID, db: DbSession):
    vehiculo = await services.get_vehiculo(db, vehiculo_id)
    if vehiculo is None:
        raise HTTPException(status_code=404, detail="Vehículo no encontrado")
    return vehiculo


@router_publico.get(
    "/prestadores/{prestador_id}/vehiculos",
    response_model=list[RentacarVehiculoOut],
    summary="Vehículos de un prestador específico (para la web del prestador)",
)
async def vehiculos_por_prestador(
    prestador_id: UUID, db: DbSession,
):
    return await services.listar_vehiculos(db, prestador_id)


@router_publico.post(
    "/reservas",
    response_model=RentacarReservaOut,
    status_code=201,
    summary="Crear reserva pública (invitado)",
)
async def crear_reserva_publica(data: RentacarReservaCreate, db: DbSession):
    try:
        reserva = await services.crear_reserva(db, data)
        return reserva
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
