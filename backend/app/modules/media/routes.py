from fastapi import APIRouter, Depends, HTTPException
from app.core.db import DbSession
from app.modules.auth.deps import AdminUser, CurrentUser
from pydantic import BaseModel
import boto3
from botocore.config import Config
import os
import uuid

router = APIRouter(prefix="/media", tags=["media"])

class PresignedUrlRequest(BaseModel):
    filename: str
    content_type: str
    turno_id: str
    fase: str  # antes, durante, despues

class MediaAssetEstadoUpdate(BaseModel):
    estado: str  # aprobado | rechazado

class MediaAssetRegister(BaseModel):
    turno_id: str
    tipo: str  # foto | video
    fase: str  # ingreso | diagnostico | en_proceso | entrega | reclamo | otro
    object_key: str
    url_publica: str
    descripcion: str | None = None
    visible_publico: bool = False

class PresignedUrlResponse(BaseModel):
    upload_url: str
    object_key: str
    public_url: str

@router.post("/presigned-url", response_model=PresignedUrlResponse)
async def get_presigned_url(data: PresignedUrlRequest):
    endpoint = os.getenv("R2_ENDPOINT_URL")
    access_key = os.getenv("R2_ACCESS_KEY_ID")
    secret_key = os.getenv("R2_SECRET_ACCESS_KEY")
    bucket = os.getenv("R2_BUCKET_NAME")
    public_url = os.getenv("R2_PUBLIC_URL")

    if not all([endpoint, access_key, secret_key, bucket, public_url]):
        raise HTTPException(status_code=500, detail="R2 no configurado en el servidor")

    raw_ext = data.filename.rsplit(".", 1)[-1].lower().strip() if "." in data.filename else ""
    safe_ext = "".join(c for c in raw_ext if c.isalnum())[:10] or "bin"
    safe_fase = "".join(c for c in (data.fase or "otro").lower() if c.isalnum() or c == "_")[:30] or "otro"
    object_key = f"turnos/{data.turno_id}/{safe_fase}/{uuid.uuid4()}.{safe_ext}"

    s3 = boto3.client(
        "s3",
        endpoint_url=endpoint,
        aws_access_key_id=access_key,
        aws_secret_access_key=secret_key,
        config=Config(
            signature_version="s3v4",
            s3={
                "addressing_style": "path",
                "payload_signing_enabled": False,
            },
            request_checksum_calculation="when_required",
            response_checksum_validation="when_required",
        ),
        region_name="auto"
    )

    try:
        presigned_url = s3.generate_presigned_url(
            "put_object",
            Params={
                "Bucket": bucket,
                "Key": object_key,
            },
            ExpiresIn=900,
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

    return PresignedUrlResponse(
        upload_url=presigned_url,
        object_key=object_key,
        public_url=f"{public_url.rstrip('/')}/{object_key}"
    )


@router.post('/register', status_code=201)
async def register_media_asset(
    data: MediaAssetRegister,
    user: CurrentUser,
    db: DbSession,
):
    from sqlalchemy import text
    asset_id = str(uuid.uuid4())
    # Validar que el turno existe
    tipo_norm = (data.tipo or "").strip().lower()
    if tipo_norm not in ("foto", "video"):
        raise HTTPException(400, "Tipo inválido. Usar 'foto' o 'video'.")
    result = await db.execute(
        text('SELECT id FROM turnos WHERE id = :turno'),
        {'turno': data.turno_id}
    )
    if not result.fetchone():
        raise HTTPException(404, 'Turno no encontrado')
    await db.execute(
        text('INSERT INTO media_assets (id, entidad_tipo, entidad_id, subido_por_id, subido_por_rol, tipo, fase, storage_key, url_publica, descripcion, visible_publico, estado_moderacion, mime_type, tamano_bytes, hash_sha256) VALUES (:id, :ent, :ent_id, :sub_id, :sub_rol, :tipo, :fase, :key, :url, :desc, :vis, :estado, :mime, :tam, :hash)'),
        {
            'id': asset_id,
            'ent': 'turno',
            'ent_id': data.turno_id,
            'sub_id': str(user.id),
            'sub_rol': 'prestador',
            'tipo': tipo_norm,
            'fase': data.fase,
            'key': data.object_key,
            'url': data.url_publica or '',
            'desc': data.descripcion or '',
            'vis': data.visible_publico,
            'estado': 'pendiente',
            'mime': 'application/octet-stream',
            'tam': 0,
            'hash': '',
        }
    )
    await db.commit()
    return {'id': asset_id, 'status': 'ok'}


@router.get('/pendientes')
async def listar_media_pendiente(
    admin: AdminUser,
    db: DbSession,
    limit: int = 50,
    offset: int = 0,
):
    from sqlalchemy import text
    result = await db.execute(
        text('SELECT id, entidad_tipo, entidad_id, tipo, fase, storage_key, url_publica, estado_moderacion, created_at FROM media_assets WHERE estado_moderacion = :estado AND activo = true ORDER BY created_at DESC LIMIT :lim OFFSET :off'),
        {'estado': 'pendiente', 'lim': limit, 'off': offset}
    )
    rows = result.fetchall()
    items = []
    for row in rows:
        items.append({
            'id': str(row[0]),
            'entidad_tipo': row[1],
            'entidad_id': str(row[2]),
            'tipo': row[3],
            'fase': row[4],
            'storage_key': row[5],
            'url_publica': row[6],
            'estado_moderacion': row[7],
            'created_at': row[8].isoformat() if row[8] else None,
        })
    return {'items': items, 'total': len(items)}


@router.patch('/{asset_id}/estado')
async def cambiar_estado_media(
    asset_id: str,
    data: MediaAssetEstadoUpdate,
    admin: AdminUser,
    db: DbSession,
):
    from sqlalchemy import text
    from app.modules.social.eventos_media import encolar_media_aprobada

    nuevo_estado = getattr(data, 'estado', 'aprobado')
    if nuevo_estado not in ('aprobado', 'rechazado'):
        raise HTTPException(400, 'Estado inválido. Usar aprobado o rechazado.')

    # Actualizar estado
    await db.execute(
        text('UPDATE media_assets SET estado_moderacion = :estado, moderado_por_id = :admin_id, moderado_en = now() WHERE id = :id'),
        {'estado': nuevo_estado, 'admin_id': str(admin.id), 'id': asset_id}
    )

    # Obtener el asset para encolar si fue aprobado
    if nuevo_estado == 'aprobado':
        result = await db.execute(
            text('SELECT id, tipo, fase, url_publica, descripcion, entidad_id, entidad_tipo FROM media_assets WHERE id = :id'),
            {'id': asset_id}
        )
        row = result.fetchone()
        if row:
            # Objeto simple para pasar a eventos_media
            class AssetSimple:
                pass
            asset = AssetSimple()
            asset.id = str(row[0])
            asset.tipo = row[1]
            asset.fase = row[2]
            asset.url_publica = row[3]
            asset.descripcion = row[4]
            asset.entidad_id = row[5]
            asset.entidad_tipo = row[6]
            asset.prestador_id = None
            if row[6] == 'turno' and row[5]:
                t_res = await db.execute(
                    text('SELECT prestador_id FROM turnos WHERE id = :tid'),
                    {'tid': str(row[5])}
                )
                t_row = t_res.fetchone()
                if t_row and t_row[0]:
                    asset.prestador_id = t_row[0]
            await encolar_media_aprobada(db, asset)

    await db.commit()
    return {'id': asset_id, 'estado': nuevo_estado}
