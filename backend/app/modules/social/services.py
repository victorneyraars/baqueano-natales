"""
Funciones del módulo social.

Todas las funciones son async y reciben `db: AsyncSession` como primer
argumento. No hay clases: es el patrón del proyecto (ver `prestadores`).

Responsabilidades:
- CRUD de cuentas sociales (con soft delete).
- Guardado/rotación de tokens (con cifrado transparente vía `core.crypto`).
- Lectura/escritura de la config (con herencia global -> propietario).
- Encolado y consulta de publicaciones.

Lo que NO hace este módulo (todavía):
- Hablar con las APIs de Meta/Google (etapa siguiente).
- Procesar la cola de publicaciones (worker futuro).
"""
import logging
from datetime import datetime, timedelta, timezone
from uuid import UUID

from fastapi import HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core import crypto
from app.modules.auth.models import Usuario
from app.modules.social import facebook_service, oauth_state
from app.modules.social.models import (
    ConfigSocial,
    CuentaSocial,
    EstadoPublicacion,
    PropietarioTipo,
    PublicacionSocial,
    Red,
    TokenSocial,
)
from app.modules.social.schemas import (
    ConfigSocialUpdate,
    CuentaSocialCreate,
    CuentaSocialUpdate,
    PaginaFacebookPublic,
    PublicacionSocialCreate,
    TokenSocialGuardar,
)

logger = logging.getLogger(__name__)


# =========================================================
# Cuentas sociales
# =========================================================
async def listar_cuentas(
    db: AsyncSession,
    *,
    red: str | None = None,
    propietario_tipo: PropietarioTipo | None = None,
    propietario_id: UUID | None = None,
    activas_solo: bool = True,
    limit: int = 50,
    offset: int = 0,
) -> tuple[list[CuentaSocial], int]:
    """
    Lista cuentas sociales con filtros y paginación.

    Devuelve `(items, total)` donde total es el conteo sin paginación.
    """
    base = select(CuentaSocial)
    if activas_solo:
        base = base.where(CuentaSocial.activo.is_(True))
    if red is not None:
        base = base.where(CuentaSocial.red == red)
    if propietario_tipo is not None:
        base = base.where(CuentaSocial.propietario_tipo == propietario_tipo)
    if propietario_id is not None:
        base = base.where(CuentaSocial.propietario_id == propietario_id)

    total_stmt = select(func.count()).select_from(base.subquery())
    total = (await db.execute(total_stmt)).scalar_one()

    items_stmt = (
        base.order_by(CuentaSocial.created_at.desc())
        .limit(limit)
        .offset(offset)
    )
    items = list((await db.execute(items_stmt)).scalars().all())
    return items, total


async def obtener_cuenta(
    db: AsyncSession, cuenta_id: UUID
) -> CuentaSocial | None:
    """Devuelve una cuenta por ID (incluye inactivas). None si no existe."""
    stmt = select(CuentaSocial).where(CuentaSocial.id == cuenta_id)
    return (await db.execute(stmt)).scalar_one_or_none()


async def crear_cuenta(
    db: AsyncSession, datos: CuentaSocialCreate
) -> CuentaSocial:
    """
    Crea una cuenta social.

    Valida la restricción UNIQUE(red, external_id) antes de insertar para
    devolver 409 con mensaje claro (en vez de un error de constraint).
    """
    # Chequeo explícito de duplicado
    dup_stmt = select(CuentaSocial).where(
        CuentaSocial.red == datos.red,
        CuentaSocial.external_id == datos.external_id,
    )
    existente = (await db.execute(dup_stmt)).scalar_one_or_none()
    if existente is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=(
                f"Ya existe una cuenta {datos.red.value} con "
                f"external_id={datos.external_id}"
            ),
        )

    cuenta = CuentaSocial(
        red=datos.red,
        external_id=datos.external_id,
        external_name=datos.external_name,
        propietario_tipo=datos.propietario_tipo,
        propietario_id=datos.propietario_id,
        cuenta_padre_id=datos.cuenta_padre_id,
        auto_publish=datos.auto_publish,
        metadata_extra=datos.metadata_extra,
    )
    db.add(cuenta)
    await db.flush()
    await db.refresh(cuenta)
    return cuenta


async def actualizar_cuenta(
    db: AsyncSession, cuenta: CuentaSocial, datos: CuentaSocialUpdate
) -> CuentaSocial:
    """
    Actualiza campos parciales de una cuenta.

    Solo aplica los campos que vienen seteados (diferentes de None).
    """
    cambios = datos.model_dump(exclude_unset=True)
    for campo, valor in cambios.items():
        setattr(cuenta, campo, valor)
    await db.flush()
    await db.refresh(cuenta)
    return cuenta


async def desactivar_cuenta(
    db: AsyncSession, cuenta: CuentaSocial
) -> CuentaSocial:
    """Soft delete: marca activo=False."""
    cuenta.activo = False
    cuenta.auto_publish = False  # ya no se publica nada automático
    await db.flush()
    await db.refresh(cuenta)
    return cuenta


# =========================================================
# Tokens (cifrado transparente)
# =========================================================
async def guardar_token(
    db: AsyncSession,
    cuenta: CuentaSocial,
    datos: TokenSocialGuardar,
) -> TokenSocial:
    """
    Guarda un token para una cuenta, cifrando los campos sensibles.

    Si la cuenta ya tiene tokens, los deja. El token más reciente es el
    que se usa (ver `obtener_token_vigente`).
    """
    token = TokenSocial(
        cuenta_id=cuenta.id,
        access_token=crypto.cifrar(datos.access_token),
        refresh_token=crypto.cifrar(datos.refresh_token)
        if datos.refresh_token
        else None,
        token_type=datos.token_type,
        expires_at=datos.expires_at,
        scope=datos.scope,
    )
    db.add(token)
    await db.flush()
    await db.refresh(token)
    return token


async def obtener_token_vigente(
    db: AsyncSession, cuenta_id: UUID
) -> TokenSocial | None:
    """
    Devuelve el token más reciente de una cuenta que no esté expirado.

    Criterio:
    - Ordenado por created_at descendente.
    - Si `expires_at` es NULL, el token no expira (típico de page tokens).
    - Si `expires_at` <= now, se considera expirado y no se devuelve.
    """
    ahora = datetime.now(timezone.utc)
    stmt = (
        select(TokenSocial)
        .where(TokenSocial.cuenta_id == cuenta_id)
        .order_by(TokenSocial.created_at.desc())
        .limit(5)
    )
    candidatos = list((await db.execute(stmt)).scalars().all())

    for t in candidatos:
        if t.expires_at is None:
            return t
        exp = t.expires_at
        if exp.tzinfo is None:
            exp = exp.replace(tzinfo=timezone.utc)
        if exp > ahora:
            return t
    return None


def descifrar_token(token: TokenSocial) -> tuple[str, str | None]:
    """
    Devuelve `(access_token, refresh_token)` en claro.

    NUNCA loguear el resultado. NUNCA incluirlo en responses.
    """
    access = crypto.descifrar(token.access_token) or ""
    refresh = crypto.descifrar(token.refresh_token) if token.refresh_token else None
    return access, refresh


# =========================================================
# Config (con herencia global -> propietario)
# =========================================================
def _defaults_config() -> dict:
    """Valores por defecto cuando no hay fila global."""
    return {
        "auto_publish": False,
        "destino": "ambos",
        "publicar_en_facebook": True,
        "publicar_en_instagram": False,
        "publicar_en_google": False,
    }


async def obtener_config(
    db: AsyncSession,
    *,
    propietario_tipo: PropietarioTipo | None = None,
    propietario_id: UUID | None = None,
) -> ConfigSocial | None:
    """
    Devuelve la config aplicable.

    Lógica de herencia:
    1. Si se pasa (propietario_tipo, propietario_id), busca esa config.
    2. Si no existe, busca la global (ambos NULL).
    3. Si tampoco existe, devuelve None (el llamador usa defaults).
    """
    if propietario_tipo is not None and propietario_id is not None:
        stmt = select(ConfigSocial).where(
            ConfigSocial.propietario_tipo == propietario_tipo,
            ConfigSocial.propietario_id == propietario_id,
        )
        cfg = (await db.execute(stmt)).scalar_one_or_none()
        if cfg is not None:
            return cfg

    stmt_global = select(ConfigSocial).where(
        ConfigSocial.propietario_tipo.is_(None),
        ConfigSocial.propietario_id.is_(None),
    )
    return (await db.execute(stmt_global)).scalar_one_or_none()


async def obtener_o_crear_config_global(
    db: AsyncSession,
) -> ConfigSocial:
    """
    Devuelve la config global, creándola con defaults si no existe.

    Se usa en endpoints admin para garantizar que siempre haya una fila
    editable.
    """
    cfg = await obtener_config(db)
    if cfg is not None:
        return cfg
    cfg = ConfigSocial(
        propietario_tipo=None,
        propietario_id=None,
        **_defaults_config(),
    )
    db.add(cfg)
    await db.flush()
    await db.refresh(cfg)
    return cfg


async def actualizar_config(
    db: AsyncSession,
    cfg: ConfigSocial,
    datos: ConfigSocialUpdate,
) -> ConfigSocial:
    """Actualiza campos parciales de la config."""
    cambios = datos.model_dump(exclude_unset=True)
    for campo, valor in cambios.items():
        setattr(cfg, campo, valor)
    await db.flush()
    await db.refresh(cfg)
    return cfg


# =========================================================
# Publicaciones (encolar + consultar)
# =========================================================
async def encolar_publicacion(
    db: AsyncSession, datos: PublicacionSocialCreate
) -> PublicacionSocial:
    """
    Encola una publicación.

    Verifica que la cuenta exista y esté activa. El worker (futuro)
    tomará las filas en estado PENDIENTE con `proximo_intento_en` vencido
    (o NULL, que significa "intentar ya").
    """
    cuenta = await obtener_cuenta(db, datos.cuenta_id)
    if cuenta is None or not cuenta.activo:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Cuenta no encontrada o inactiva",
        )

    pub = PublicacionSocial(
        cuenta_id=datos.cuenta_id,
        recurso_tipo=datos.recurso_tipo,
        recurso_id=datos.recurso_id,
        red=datos.red,
        contenido=datos.contenido,
        estado=EstadoPublicacion.PENDIENTE,
        intentos=0,
        proximo_intento_en=None,
    )
    db.add(pub)
    await db.flush()
    await db.refresh(pub)
    return pub


async def listar_publicaciones(
    db: AsyncSession,
    *,
    cuenta_id: UUID | None = None,
    estado: EstadoPublicacion | None = None,
    red: Red | None = None,
    recurso_tipo: str | None = None,
    recurso_id: UUID | None = None,
    limit: int = 50,
    offset: int = 0,
) -> tuple[list[PublicacionSocial], int]:
    """Lista publicaciones con filtros y paginación."""
    base = select(PublicacionSocial)
    if cuenta_id is not None:
        base = base.where(PublicacionSocial.cuenta_id == cuenta_id)
    if estado is not None:
        base = base.where(PublicacionSocial.estado == estado)
    if red is not None:
        base = base.where(PublicacionSocial.red == red)
    if recurso_tipo is not None:
        base = base.where(PublicacionSocial.recurso_tipo == recurso_tipo)
    if recurso_id is not None:
        base = base.where(PublicacionSocial.recurso_id == recurso_id)

    total_stmt = select(func.count()).select_from(base.subquery())
    total = (await db.execute(total_stmt)).scalar_one()

    items_stmt = (
        base.order_by(PublicacionSocial.created_at.desc())
        .limit(limit)
        .offset(offset)
    )
    items = list((await db.execute(items_stmt)).scalars().all())
    return items, total


async def obtener_publicacion(
    db: AsyncSession, publicacion_id: UUID
) -> PublicacionSocial | None:
    """Devuelve una publicación por ID."""
    stmt = select(PublicacionSocial).where(
        PublicacionSocial.id == publicacion_id
    )
    return (await db.execute(stmt)).scalar_one_or_none()

# =========================================================
# OAuth Facebook (Etapa 2)
# =========================================================

async def generar_url_oauth(user: Usuario) -> tuple[str, str]:
    """Devuelve `(url_facebook, state)` para que el admin abra el di?logo."""
    state = oauth_state.generar_state(str(user.id))
    url = facebook_service.construir_url_autorizacion(state)
    return url, state


async def procesar_callback_oauth(code: str, state: str) -> tuple[str, str]:
    """Valida state, intercambia code -> short -> long token.

    Devuelve `(user_id, token_ref)`. Lanza ValueError si algo falla.
    """
    try:
        user_id = oauth_state.verificar_state(state)
    except oauth_state.OAuthTokenError as e:
        raise ValueError(f"state inv?lido: {e}")

    short_token, err = await facebook_service.intercambiar_codigo_por_token(code)
    if err or not short_token:
        msg = err.message if err else "sin token"
        raise ValueError(f"No se pudo intercambiar el code: {msg}")

    long_token, err = await facebook_service.extender_token(short_token)
    if err or not long_token:
        msg = err.message if err else "sin token"
        raise ValueError(f"No se pudo extender el token: {msg}")

    token_ref = oauth_state.generar_token_ref(user_id, long_token)
    return user_id, token_ref


async def listar_paginas_disponibles(
    db: AsyncSession, token_ref: str
) -> list[PaginaFacebookPublic]:
    """Lee el token_ref, consulta Meta, y marca las p?ginas ya conectadas."""
    try:
        _, user_token = oauth_state.leer_token_ref(token_ref)
    except oauth_state.OAuthTokenError as e:
        raise ValueError(f"token_ref inv?lido: {e}")

    paginas, err = await facebook_service.listar_paginas(user_token)
    if err:
        raise ValueError(f"Error al listar p?ginas: {err.message}")

    external_ids = [p.id for p in paginas]
    ya_conectadas: set[str] = set()
    if external_ids:
        result = await db.execute(
            select(CuentaSocial.external_id).where(
                CuentaSocial.red == Red.FACEBOOK,
                CuentaSocial.external_id.in_(external_ids),
                CuentaSocial.activo.is_(True),
            )
        )
        ya_conectadas = {row[0] for row in result.all()}

    return [
        PaginaFacebookPublic(
            **p.to_public_dict(),
            ya_conectada=p.id in ya_conectadas,
        )
        for p in paginas
    ]


async def conectar_cuenta_facebook(
    db: AsyncSession,
    user: Usuario,
    token_ref: str,
    page_id: str,
    propietario_tipo: PropietarioTipo,
    propietario_id: UUID | None,
    alias: str | None = None,
) -> tuple[CuentaSocial, str]:
    """Crea (o actualiza) la cuenta social y guarda el page token cifrado.

    Devuelve `(cuenta, nombre_pagina)`.
    """
    # 1. Validar token_ref
    try:
        _, user_token = oauth_state.leer_token_ref(token_ref)
    except oauth_state.OAuthTokenError as e:
        raise ValueError(f"token_ref inv?lido: {e}")

    # 2. Traer p?ginas del usuario y encontrar la elegida
    paginas, err = await facebook_service.listar_paginas(user_token)
    if err:
        raise ValueError(f"Error al listar p?ginas: {err.message}")

    pagina = facebook_service.buscar_pagina(paginas, page_id)
    if not pagina:
        raise ValueError(f"La p?gina {page_id} no est? entre las del usuario")
    if not pagina.access_token:
        raise ValueError("La p?gina no devolvi? access_token (?permisos?)")

    # 3. Verificar el token de la p?gina (por si acaso)
    nombre, verr = await facebook_service.verificar_token_pagina(
        pagina.id, pagina.access_token
    )
    if verr:
        raise ValueError(f"Token de p?gina inv?lido: {verr.message}")
    nombre_final = nombre or pagina.name

    # 4. ?Ya existe la cuenta?
    existing = await db.execute(
        select(CuentaSocial).where(
            CuentaSocial.red == Red.FACEBOOK,
            CuentaSocial.external_id == pagina.id,
        )
    )
    cuenta = existing.scalar_one_or_none()

    if cuenta:
        # Actualizar: reactivar, refrescar nombre, rotar token
        cuenta.activo = True
        cuenta.external_name = nombre_final
        if alias:
            cuenta.metadata_extra = {**(cuenta.metadata_extra or {}), "alias": alias}
    else:
        cuenta = CuentaSocial(
            red=Red.FACEBOOK,
            propietario_tipo=propietario_tipo,
            propietario_id=propietario_id,
            external_id=pagina.id,
            external_name=nombre_final,
            metadata_extra={"alias": alias} if alias else None,
        )
        db.add(cuenta)
        await db.flush()  # necesitamos cuenta.id

    # 5. Guardar token cifrado (reemplaza el anterior si exist?a)
    ahora = datetime.now(timezone.utc)
    token_row = await db.execute(
        select(TokenSocial).where(TokenSocial.cuenta_id == cuenta.id)
    )
    token_obj = token_row.scalar_one_or_none()
    token_cifrado = crypto.cifrar(pagina.access_token)
    expira = ahora + timedelta(days=60)

    if token_obj:
        token_obj.access_token = token_cifrado
        token_obj.expires_at = expira
    else:
        token_obj = TokenSocial(
            cuenta_id=cuenta.id,
            access_token=token_cifrado,
            token_type="page",
            expires_at=expira,
            scope="pages_manage_posts,pages_read_engagement",
        )
        db.add(token_obj)

    await db.commit()
    await db.refresh(cuenta)
    return cuenta, nombre_final

# =========================================================
# Worker de publicaciones (Etapa 3)
# =========================================================

# Backoff exponencial: cuanto esperar despues de cada intento fallido.
# Indice = intentos actuales (0-based). Si len < intentos, se agoto.
_BACKOFF_SEGUNDOS = [
    60,       # intento 1 falla -> esperar 1 min
    300,      # intento 2 falla -> esperar 5 min
    1800,     # intento 3 falla -> esperar 30 min
    7200,     # intento 4 falla -> esperar 2 h
]

MAX_INTENTOS = len(_BACKOFF_SEGUNDOS) + 1  # 5 intentos totales


async def obtener_publicaciones_pendientes(
    db: AsyncSession, limit: int = 20
) -> list[PublicacionSocial]:
    """Trae las publicaciones listas para procesar.

    Criterio:
    - estado = PENDIENTE
    - proximo_intento_en IS NULL o <= now()

    Ordenadas por created_at ASC (FIFO).
    """
    ahora = datetime.now(timezone.utc)
    stmt = (
        select(PublicacionSocial)
        .where(
            PublicacionSocial.estado == EstadoPublicacion.PENDIENTE,
            (
                (PublicacionSocial.proximo_intento_en.is_(None))
                | (PublicacionSocial.proximo_intento_en <= ahora)
            ),
        )
        .order_by(PublicacionSocial.created_at.asc())
        .limit(limit)
    )
    result = await db.execute(stmt)
    return list(result.scalars().all())


async def obtener_token_vigente_de_cuenta(
    db: AsyncSession, cuenta_id: UUID
) -> tuple[str | None, str | None]:
    """Devuelve `(access_token_descifrado, error)`.

    Busca el token mas reciente no expirado de la cuenta y lo descifra
    con Fernet.
    """
    ahora = datetime.now(timezone.utc)
    stmt = (
        select(TokenSocial)
        .where(
            TokenSocial.cuenta_id == cuenta_id,
            (TokenSocial.expires_at.is_(None)) | (TokenSocial.expires_at > ahora),
        )
        .order_by(TokenSocial.created_at.desc())
        .limit(1)
    )
    token_obj = (await db.execute(stmt)).scalar_one_or_none()
    if token_obj is None:
        return None, "No hay token vigente para esta cuenta"

    token_plano = crypto.descifrar(token_obj.access_token)
    if not token_plano:
        return None, "No se pudo descifrar el token (?clave Fernet rotada?)"

    return token_plano, None


async def marcar_publicacion_publicando(
    db: AsyncSession, pub: PublicacionSocial
) -> None:
    """Marca la publicacion como PUBLICANDO (evita doble procesamiento)."""
    pub.estado = EstadoPublicacion.PUBLICANDO
    await db.commit()
    await db.refresh(pub)


async def marcar_publicacion_publicada(
    db: AsyncSession, pub: PublicacionSocial, external_post_id: str
) -> None:
    """Marca la publicacion como PUBLICADO con el ID externo."""
    pub.estado = EstadoPublicacion.PUBLICADO
    pub.external_post_id = external_post_id
    pub.error_ultimo = None
    pub.proximo_intento_en = None
    await db.commit()
    await db.refresh(pub)


async def marcar_publicacion_fallada(
    db: AsyncSession, pub: PublicacionSocial, error: str
) -> None:
    """Registra el fallo. Aplica backoff exponencial o marca AGOTADO.

    - Si `pub.intentos` alcanzo MAX_INTENTOS: estado=AGOTADO, no reintenta.
    - Si no: estado=PENDIENTE, incrementa intentos, programa proximo_intento_en.
    """
    pub.intentos += 1
    pub.error_ultimo = error[:1000] if error else "(sin detalle)"

    if pub.intentos >= MAX_INTENTOS:
        pub.estado = EstadoPublicacion.AGOTADO
        pub.proximo_intento_en = None
    else:
        pub.estado = EstadoPublicacion.PENDIENTE
        espera = _BACKOFF_SEGUNDOS[pub.intentos - 1]
        pub.proximo_intento_en = datetime.now(timezone.utc) + timedelta(
            seconds=espera
        )

    await db.commit()
    await db.refresh(pub)

async def obtener_instagram_id_de_cuenta(
    db: AsyncSession, cuenta_id: UUID
) -> str | None:
    """Devuelve el IG Business ID de la cuenta Facebook.

    Lo busca primero en metadata_extra (cacheado) y si no esta, lo
    consulta a la Graph API y lo guarda.
    """
    import httpx
    from app.modules.social import facebook_service

    stmt = select(CuentaSocial).where(CuentaSocial.id == cuenta_id)
    cuenta = (await db.execute(stmt)).scalar_one_or_none()
    if cuenta is None:
        return None

    # 1. Cache hit
    meta = cuenta.metadata_extra or {}
    if meta.get("instagram_business_account_id"):
        return meta["instagram_business_account_id"]

    # 2. Cache miss -> consultar Meta
    token, err = await obtener_token_vigente_de_cuenta(db, cuenta_id)
    if err or not token:
        return None

    try:
        async with httpx.AsyncClient(timeout=15.0) as client:
            resp = await client.get(
                facebook_service._graph_url(cuenta.external_id),
                params={
                    "fields": "instagram_business_account{id,username}",
                    "access_token": token,
                },
            )
    except httpx.HTTPError:
        return None

    if resp.status_code != 200:
        return None

    iga = (resp.json() or {}).get("instagram_business_account")
    if not iga:
        return None

    # 3. Guardar cache
    ig_id = iga.get("id")
    ig_user = iga.get("username")
    cuenta.metadata_extra = {
        **meta,
        "instagram_business_account_id": ig_id,
        "instagram_username": ig_user,
    }
    await db.commit()
    return ig_id

