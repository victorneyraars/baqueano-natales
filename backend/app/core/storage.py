"""Helpers de Cloudflare R2 reutilizables para todas las verticales.

Uso:
    from app.core.storage import (
        generate_object_key,
        generate_presigned_upload_url,
        get_public_url,
        delete_object,
    )

    key = generate_object_key("rentacar/vehiculos/abc", "foto.jpg")
    upload_url = generate_presigned_upload_url(key, "image/jpeg")
    public_url = get_public_url(key)
"""
import os
import uuid

import boto3
from botocore.config import Config


def get_r2_client():
    """Crea un cliente S3 apuntando a Cloudflare R2."""
    return boto3.client(
        "s3",
        endpoint_url=os.getenv("R2_ENDPOINT_URL"),
        aws_access_key_id=os.getenv("R2_ACCESS_KEY_ID"),
        aws_secret_access_key=os.getenv("R2_SECRET_ACCESS_KEY"),
        config=Config(
            signature_version="s3v4",
            s3={"addressing_style": "path", "payload_signing_enabled": False},
            request_checksum_calculation="when_required",
            response_checksum_validation="when_required",
        ),
        region_name="auto",
    )


def get_public_url(key: str) -> str:
    """URL pública de un objeto en R2."""
    base = os.getenv("R2_PUBLIC_URL", "").rstrip("/")
    return f"{base}/{key.lstrip('/')}"


def generate_object_key(prefix: str, filename: str) -> str:
    """Genera un object key único: {prefix}/{uuid}.{ext}."""
    ext = filename.split(".")[-1].lower() if "." in filename else "bin"
    return f"{prefix}/{uuid.uuid4().hex}.{ext}"


def generate_presigned_upload_url(
    key: str, content_type: str = "image/jpeg", expires_in: int = 900
) -> str:
    """URL prefirmada para que el cliente suba directo a R2 (15 min TTL)."""
    s3 = get_r2_client()
    return s3.generate_presigned_url(
        "put_object",
        Params={
            "Bucket": os.getenv("R2_BUCKET_NAME"),
            "Key": key,
            "ContentType": content_type,
        },
        ExpiresIn=expires_in,
    )


def delete_object(key: str) -> bool:
    """Elimina un objeto de R2. Retorna True si fue exitoso."""
    try:
        s3 = get_r2_client()
        s3.delete_object(Bucket=os.getenv("R2_BUCKET_NAME"), Key=key)
        return True
    except Exception:
        return False
