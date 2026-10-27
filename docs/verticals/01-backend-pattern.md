# 01 - Patrón Backend para Nuevas Verticales

> Guía paso a paso para crear el módulo backend de una nueva vertical en Baqueano Natales.

## Estructura de un módulo

Cada vertical vive en `backend/app/modules/<vertical>/` con esta estructura:

~~~text
backend/app/modules/<vertical>/
├── __init__.py          # Re-exporta modelos y schemas
├── models.py            # Tablas SQLAlchemy
├── schemas.py           # Pydantic (validación)
├── services.py          # Lógica de negocio (CRUD, reglas)
├── routes.py            # Endpoints admin (con auth)
├── public_routes.py     # Endpoints públicos (sin auth, ETag)
└── worker.py            # (opcional) tareas programadas
~~~

## Paso 1: Modelos SQLAlchemy

Ver archivo de ejemplo completo: `backend/app/modules/rentacar/models.py`

**Reglas críticas:**

1. **Siempre usar UUID** (`PG_UUID(as_uuid=True)`), no `Integer`. El proyecto migró a UUIDs.
2. **Prefijo en `__tablename__`**: `rentacar_vehiculos` (no `vehiculos`, ya existe en `oficios`).
3. **Heredar de `Base` + `TimestampMixin`**: agrega `created_at` y `updated_at` automáticos.
4. **FK a `prestadores.id` y `usuarios.id`**: estas son las tablas compartidas.
5. **`JSONB` para configuración flexible**: permite agregar campos sin migración.

Ejemplo mínimo:

~~~python
from uuid import UUID, uuid4
from sqlalchemy import ForeignKey, Numeric, String
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.dialects.postgresql import UUID as PG_UUID
from sqlalchemy.orm import Mapped, mapped_column
from app.core.db import Base
from app.core.mixins import TimestampMixin

class RentacarVehiculo(TimestampMixin, Base):
    __tablename__ = "rentacar_vehiculos"
    id: Mapped[UUID] = mapped_column(PG_UUID(as_uuid=True), primary_key=True, default=uuid4)
    prestador_id: Mapped[UUID] = mapped_column(PG_UUID(as_uuid=True), ForeignKey("prestadores.id"), index=True)
    precio_dia: Mapped[float] = mapped_column(Numeric(10, 2))
~~~

## Paso 2: Schemas Pydantic

Ver archivo: `backend/app/modules/rentacar/schemas.py`

**Reglas:**

1. **Tres schemas por entidad**: `Base`, `Create`, `Out` (o `Response`).
2. **`Out` con `Config.from_attributes = True`** para serializar desde SQLAlchemy.
3. **`UUID` para IDs**, no `int`.

Ejemplo:

~~~python
from uuid import UUID
from pydantic import BaseModel

class RentacarVehiculoBase(BaseModel):
    patente: str
    marca: str
    precio_dia: float

class RentacarVehiculoCreate(RentacarVehiculoBase):
    prestador_id: UUID

class RentacarVehiculoOut(RentacarVehiculoBase):
    id: UUID
    class Config:
        from_attributes = True
~~~

## Paso 3: Services (lógica de negocio)

Ver archivo: `backend/app/modules/rentacar/services.py`

**Reglas:**

1. **Funciones async** con `AsyncSession` como primer argumento.
2. **Nombres claros**: `get_<entidad>`, `listar_<entidad>`, `crear_<entidad>`, `actualizar_<entidad>`, `eliminar_<entidad>`.
3. **Sin HTTPException aquí**: los services lanzan `ValueError` o retornan `None`, las rutas traducen a HTTP.
4. **No mezclar con Pydantic**: services reciben schemas `Create` o diccionarios.

## Paso 4: Routes admin (con autenticación)

Ver archivo: `backend/app/modules/rentacar/routes.py`

**Reglas:**

1. **Prefijo claro**: `APIRouter(prefix="/admin/<vertical>", tags=["<vertical>-admin"])`.
2. **Auth obligatoria**: todos los endpoints reciben `_admin: AdminUser`.
3. **Traducir `None` a 404**: `if x is None: raise HTTPException(404, "No encontrado")`.
4. **`status_code=201`** en POST que crean recursos.

Ejemplo mínimo:

~~~python
from fastapi import APIRouter, HTTPException, status
from app.core.db import DbSession
from app.modules.social.deps import AdminUser
from . import services
from .schemas import RentacarVehiculoCreate, RentacarVehiculoOut

router_admin = APIRouter(prefix="/admin/rentacar", tags=["rentacar-admin"])

@router_admin.get("/vehiculos", response_model=list[RentacarVehiculoOut])
async def listar_vehiculos(db: DbSession, _admin: AdminUser):
    return await services.listar_vehiculos(db)

@router_admin.post("/vehiculos", response_model=RentacarVehiculoOut, status_code=201)
async def crear_vehiculo(data: RentacarVehiculoCreate, db: DbSession, _admin: AdminUser):
    return await services.crear_vehiculo(db, data)
~~~

## Paso 5: Public routes (sin auth, con ETag)

Ver archivo: `backend/app/modules/rentacar/public_routes.py`

**Reglas:**

1. **Prefijo público**: `APIRouter(prefix="/public/<vertical>", tags=["<vertical>-public"])`.
2. **Sin `_admin`**: son accesibles sin token.
3. **ETag + Cache-Control**: para que la web haga polling eficiente (304 Not Modified).

Patrón ETag mínimo:

~~~python
import hashlib, json
from fastapi import APIRouter, Header, Response

router_publico = APIRouter(prefix="/public/rentacar", tags=["rentacar-public"])

def _etag(payload: object) -> str:
    raw = json.dumps(payload, sort_keys=True, default=str).encode()
    return '"' + hashlib.sha256(raw).hexdigest()[:32] + '"'

@router_publico.get("/vehiculos")
async def listar_publico(db: DbSession, response: Response, if_none_match: str | None = Header(default=None, alias="If-None-Match")):
    vehiculos = await services.listar_vehiculos(db)
    payload = [RentacarVehiculoOut.model_validate(v).model_dump() for v in vehiculos]
    current_etag = _etag(payload)
    if if_none_match == current_etag:
        return Response(status_code=304, headers={"ETag": current_etag})
    response.headers["ETag"] = current_etag
    response.headers["Cache-Control"] = "public, max-age=30"
    return vehiculos
~~~

## Paso 6: Registro en `main.py`

En `backend/app/main.py`, agregar los imports y `include_router`:

~~~python
from app.modules.rentacar.routes import router_admin as rentacar_admin_router
from app.modules.rentacar.public_routes import router_publico as rentacar_publico_router

# ... después del resto de include_router
app.include_router(rentacar_admin_router, prefix="/api/v1")
app.include_router(rentacar_publico_router, prefix="/api/v1")
~~~

## Paso 7: Migración Alembic

**CRÍTICO**: `alembic revision --autogenerate` a veces detecta **schema drift** en tablas existentes y genera `DROP TABLE` peligrosos. **Nunca confíes ciegamente en el autogenerate.**

**Flujo seguro:**

1. Agregar el import en `backend/alembic/env.py`:
   ~~~python
   from app.modules.rentacar import models as rentacar_models
   ~~~

2. Generar migración:
   ~~~bash
   docker exec baqueano_backend_dev alembic revision --autogenerate -m "add_<vertical>_tables"
   ~~~

3. **Revisar el archivo generado** en `backend/alembic/versions/`. Si contiene `DROP TABLE` o `DROP INDEX` de tablas existentes → **borrar la migración y crearla manualmente**.

4. Aplicar:
   ~~~bash
   docker exec baqueano_backend_dev alembic upgrade head
   ~~~

5. Verificar:
   ~~~bash
   docker exec baqueano_db psql -U baqueano_user -d baqueano_natales_dev -c "\dt" | grep <vertical>
   ~~~

Ver ejemplo real: `backend/alembic/versions/20261027_manual_rentacar.py`

## Paso 8: Datos de prueba

Script SQL para crear el prestador + config + items de ejemplo:

~~~sql
-- 1. Crear categoría (si aplica)
INSERT INTO categorias_oficio (id, nombre, slug, activo, created_at, updated_at)
VALUES (gen_random_uuid(), 'Arriendo de Vehículos', 'arriendo-vehiculos', true, now(), now());

-- 2. Crear prestador vinculado a un usuario QA
INSERT INTO prestadores (id, usuario_id, categoria_id, nombre, slug, comuna, region, activo, verificado, created_at, updated_at)
VALUES (gen_random_uuid(), '<usuario-uuid>'::uuid, (SELECT id FROM categorias_oficio WHERE slug='arriendo-vehiculos'), 'Rent a Car Vásquez', 'rentacar-vasquez', 'Puerto Natales', 'Magallanes', true, true, now(), now());

-- 3. Config JSONB por defecto
INSERT INTO rentacar_config (id, prestador_id, metodos_pago, deposito, conductor_adicional, categorias, created_at, updated_at)
SELECT gen_random_uuid(), p.id, '{"efectivo": true, "transferencia": true}'::jsonb, '{"tipo": "porcentaje", "valor": 20}'::jsonb, '{"habilitado": true, "tarifa_por_dia": 5000}'::jsonb, '[{"codigo": "SUV", "nombre": "SUV"}]'::jsonb, now(), now()
FROM prestadores p WHERE p.slug = 'rentacar-vasquez';
~~~

## Referencias del caso real

- **Modelos completos**: `backend/app/modules/rentacar/models.py`
- **Schemas completos**: `backend/app/modules/rentacar/schemas.py`
- **Services completos**: `backend/app/modules/rentacar/services.py`
- **Routes completos**: `backend/app/modules/rentacar/routes.py`
- **Public routes completos**: `backend/app/modules/rentacar/public_routes.py`
- **Migración manual**: `backend/alembic/versions/20261027_manual_rentacar.py`

## Commit

~~~bash
git add backend/app/modules/<vertical>/ backend/alembic/versions/*.py backend/app/main.py
git commit -m "feat(<vertical>): módulo backend completo con admin + public ETag"
git push origin main
~~~

## Paso 9: Storage de imágenes con Cloudflare R2

Todas las imágenes (fotos de vehículos, habitaciones, productos, etc.) se guardan en **Cloudflare R2** mediante **presigned URLs**. El cliente sube directo a R2 sin pasar por el backend.

### Arquitectura

~~~text
Cliente (Flutter/Next.js)
  ↓ 1. POST /admin/<vertical>/<entidad>/{id}/imagen/presigned
  ↓ ← { upload_url, object_key, imagen_url }
  ↓ 2. PUT upload_url (directo a R2) con el archivo binario
  ↓ 3. POST /admin/<vertical>/<entidad>/{id}/imagen/confirmar?object_key=...
  ↓ ← { vehiculo/con entidad actualizada con imagen_url }
~~~

**Ventajas**:
- El backend no procesa binarios (0 CPU, 0 ancho de banda).
- Upload directo a R2 (más rápido, aprovecha el edge de Cloudflare).
- Presigned URL expira a los 15 min (seguridad).

### Helper reutilizable: `backend/app/core/storage.py`

Contiene 4 funciones que se usan en TODAS las verticales:

~~~python
from app.core.storage import (
    generate_object_key,       # "rentacar/vehiculos/abc/foto.jpg"
    generate_presigned_upload_url,  # URL prefirmada (15 min)
    get_public_url,            # URL pública R2
    delete_object,             # Eliminar de R2
)
~~~

### Endpoint presigned (patrón)

~~~python
from app.core.storage import (
    generate_object_key,
    generate_presigned_upload_url,
    get_public_url,
)

ALLOWED_IMAGE_TYPES = {"image/jpeg", "image/png", "image/webp"}

@router_admin.post(
    "/<entidad>/{id}/imagen/presigned",
    response_model=<Vertical>ImagenPresignedResponse,
)
async def presigned_upload(
    id: UUID,
    data: <Vertical>ImagenPresignedRequest,
    db: DbSession,
    _admin: AdminUser,
):
    if data.content_type not in ALLOWED_IMAGE_TYPES:
        raise HTTPException(400, f"Tipo no permitido: {data.content_type}")

    object_key = generate_object_key(f"<vertical>/<entidad>/{id}", data.filename)
    upload_url = generate_presigned_upload_url(object_key, data.content_type)
    imagen_url = get_public_url(object_key)

    return <Vertical>ImagenPresignedResponse(
        upload_url=upload_url,
        object_key=object_key,
        imagen_url=imagen_url,
    )
~~~

### Endpoint confirmar (patrón)

~~~python
@router_admin.post("/<entidad>/{id}/imagen/confirmar")
async def confirmar_imagen(
    id: UUID,
    object_key: str,
    db: DbSession,
    _admin: AdminUser,
):
    entidad = await services.get_<entidad>(db, id)
    if entidad is None:
        raise HTTPException(404, "No encontrado")

    entidad.imagen_url = get_public_url(object_key)
    await db.commit()
    await db.refresh(entidad)
    return entidad
~~~

### Modelo: agregar `imagen_url`

~~~python
imagen_url: Mapped[str | None] = mapped_column(String(500), nullable=True)
~~~

### Migración

~~~python
op.add_column('<vertical>_<entidad>', sa.Column('imagen_url', sa.String(500), nullable=True))
~~~

### Configuración R2 (env vars)

~~~text
R2_ENDPOINT_URL=https://<account-id>.r2.cloudflarestorage.com
R2_ACCESS_KEY_ID=<access-key>
R2_SECRET_ACCESS_KEY=<secret-key>
R2_BUCKET_NAME=baqueano-public
R2_PUBLIC_URL=https://pub-<hash>.r2.dev
~~~

**Bucket**: usar `baqueano-public` (público, CDN) para imágenes de producto/vehículos/habitaciones.
**Bucket privado**: `baqueano-evidence` para evidencias de trabajos (con acceso firmado).

### Crear el bucket vía API (una vez por proyecto)

~~~bash
ACCOUNT_ID="<account-id>"

# Crear bucket
curl -X POST "https://api.cloudflare.com/client/v4/accounts/$ACCOUNT_ID/r2/buckets" \
  -H "X-Auth-Email: $CF_API_EMAIL" -H "X-Auth-Key: $CF_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"name": "baqueano-public"}'

# Habilitar acceso público (R2.dev subdomain)
curl -X PUT "https://api.cloudflare.com/client/v4/accounts/$ACCOUNT_ID/r2/buckets/baqueano-public/domains/managed" \
  -H "X-Auth-Email: $CF_API_EMAIL" -H "X-Auth-Key: $CF_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"enabled": true}'
~~~

### Convención de object keys

~~~text
<vertical>/<entidad>/<id>/<uuid>.<ext>
# Ejemplo:
rentacar/vehiculos/bbcc12/e9d4beeecf264dd7aac9743176655f91.jpg
hostales/habitaciones/<id>/<uuid>.jpg
delivery/productos/<id>/<uuid>.webp
~~~

El `<uuid>` único evita colisiones y permite cachear por 1 año (`Cache-Control: immutable`).
