from app.modules.notificaciones.reservas import notificar_contrato_cliente

from fastapi import BackgroundTasks, APIRouter, Depends, HTTPException, Request, Response
from pydantic import BaseModel
from app.core.db import DbSession
from . import services

router = APIRouter(prefix="/documents", tags=["Documentos Digitales"])

class CrearDocumentoRequest(BaseModel):
    tenant_id: str
    tipo: str
    payload: dict

class FirmarRequest(BaseModel):
    firma_base64: str

@router.post("/crear")
async def crear_documento_firma(data: CrearDocumentoRequest, db: DbSession, background_tasks: BackgroundTasks):
    token = await services.crear_token_firma(db, data.tenant_id, data.tipo, data.payload)
    url_firma = f"https://rentacarvasquez.com/firmar/{token}"
    
    # Enviar correo si tenemos los datos del cliente
    email = data.payload.get("email_cliente")
    nombre = data.payload.get("cliente", "Cliente")
    vehiculo = data.payload.get("vehiculo", "Vehículo")
    
    if email:
        background_tasks.add_task(
            notificar_contrato_cliente,
            email_cliente=email,
            nombre_cliente=nombre,
            link_firma=url_firma,
            vehiculo=vehiculo
        )
        print(f"📧 Correo de contrato programado para {email}")

    return {"token": token, "url_firma": url_firma, "email_enviado": bool(email)}

@router.get("/{token}/pdf")
async def descargar_pdf(token: str, db: DbSession):
    doc = await services.obtener_documento_por_token(db, token)
    if not doc:
        raise HTTPException(status_code=404, detail="Documento no encontrado")
    
    # Generamos el PDF incluyendo la firma si ya fue firmado
    pdf_bytes = services.generar_pdf_basico(f"Documento: {doc.tipo}", doc.payload, firma_base64=doc.firma_base64)
    return Response(content=pdf_bytes, media_type="application/pdf")

@router.post("/{token}/firmar")
async def firmar_documento(token: str, data: FirmarRequest, request: Request, db: DbSession):
    ip = request.client.host if request.client else "desconocida"
    success = await services.firmar_documento(db, token, data.firma_base64, ip)
    if not success:
        raise HTTPException(status_code=400, detail="Documento inválido o ya firmado")
    return {"ok": True, "mensaje": "Documento firmado exitosamente"}


@router.get("/{token}/status")
async def estado_documento(token: str, db: DbSession):
    doc = await services.obtener_documento_por_token(db, token)
    if not doc:
        raise HTTPException(status_code=404, detail="Documento no encontrado")
    return {"estado": doc.estado, "firmado_at": doc.firmado_at}
