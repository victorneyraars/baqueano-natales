
import uuid
import secrets
import base64
from io import BytesIO
from reportlab.lib.pagesizes import letter
from reportlab.pdfgen import canvas
from reportlab.lib.utils import ImageReader
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from .models import DocumentoFirma

def generar_pdf_basico(titulo: str, payload: dict, firma_base64: str = None) -> bytes:
    buffer = BytesIO()
    c = canvas.Canvas(buffer, pagesize=letter)
    width, height = letter
    
    c.setFont("Helvetica-Bold", 16)
    c.drawString(50, height - 50, titulo)
    
    c.setFont("Helvetica", 12)
    y = height - 100
    for key, value in payload.items():
        c.drawString(50, y, f"{key}: {value}")
        y -= 20
        
    c.setFont("Helvetica-Bold", 14)
    c.drawString(50, y - 40, "Firma del Cliente")
    
    # Si hay firma, incrustarla
    if firma_base64:
        try:
            # Decodificar Base64 a imagen
            img_data = base64.b64decode(firma_base64.split(",")[1] if "," in firma_base64 else firma_base64)
            img_reader = ImageReader(BytesIO(img_data))
            c.drawImage(img_reader, 50, y - 120, width=200, height=60, preserveAspectRatio=True, mask='auto')
        except Exception as e:
            c.drawString(50, y - 100, "[Error al cargar la firma]")
    else:
        c.line(50, y - 90, 250, y - 90)
    
    c.save()
    buffer.seek(0)
    return buffer.getvalue()

async def crear_token_firma(db: AsyncSession, tenant_id: uuid.UUID, tipo: str, payload: dict) -> str:
    token = secrets.token_urlsafe(32)
    doc = DocumentoFirma(
        token=token,
        tenant_id=tenant_id,
        tipo=tipo,
        payload=payload,
        estado="pendiente"
    )
    db.add(doc)
    await db.commit()
    return token

async def obtener_documento_por_token(db: AsyncSession, token: str) -> DocumentoFirma | None:
    stmt = select(DocumentoFirma).where(DocumentoFirma.token == token)
    return (await db.execute(stmt)).scalar_one_or_none()

async def firmar_documento(db: AsyncSession, token: str, firma_base64: str, ip: str) -> bool:
    doc = await obtener_documento_por_token(db, token)
    if not doc or doc.estado != "pendiente":
        return False
    
    doc.estado = "firmado"
    doc.firma_base64 = firma_base64
    doc.ip_firma = ip
    from datetime import datetime, timezone
    doc.firmado_at = datetime.now(timezone.utc)
    
    await db.commit()
    return True
