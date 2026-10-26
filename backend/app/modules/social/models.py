"""
Modelos de base de datos del módulo social.

Cuatro tablas, todas con UUID como PK, timestamps automáticos y (donde
aplica) soft delete vía `SoftDeleteMixin`:

- CuentaSocial: cuenta conectada a una red (Facebook Page, cuenta de
  Instagram Business, ubicación de Google Business). Multi-tenant vía
  (propietario_tipo, propietario_id). La cuenta central de Baqueano
  Natales tiene propietario_id=NULL.

- TokenSocial: tokens OAuth de una cuenta, cifrados. Separado de la
  cuenta para permitir rotación sin perder la identidad de la cuenta.

- PublicacionSocial: cola de publicaciones. Cada fila es una intención
  de publicar algo en una red. El worker (etapa posterior) las procesa
  con reintentos y backoff.

- ConfigSocial: configuración de qué se publica automáticamente y dónde.
  Una fila global (propietario_id=NULL) + opcionalmente una por
  propietario que quiera override.

Convenciones alineadas con `app.modules.prestadores.models`:
- UUID como PK.
- Enums con `values_callable` para usar los `.value` en la DB.
- Timestamps vía `TimestampMixin`.
- `lazy="selectin"` en relaciones para compatibilidad con async.
- Soft delete vía `SoftDeleteMixin` donde corresponde.

Nota sobre ENUMs de Postgres: los enums `red_social`,
`propietario_tipo_social`, `destino_publicacion` y `estado_publicacion`
se crean UNA vez (la primera tabla que los usa). Las tablas siguientes
que reutilizan el mismo enum deben declarar `create_type=False` para
evitar "type already exists" en la migración.
"""
from datetime import datetime
from enum import Enum
from uuid import UUID, uuid4

from sqlalchemy import (
    Boolean,
    DateTime,
    Enum as SQLEnum,
    ForeignKey,
    Index,
    Integer,
    String,
    Text,
    UniqueConstraint,
    func,
    text,
)
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.dialects.postgresql import UUID as PG_UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.db import Base
from app.core.mixins import SoftDeleteMixin, TimestampMixin


# =========================================================
# Enums
# =========================================================
class Red(str, Enum):
    """
    Redes sociales soportadas.

    Agregar una nueva red implica:
    1. Agregar el valor acá.
    2. Agregar el service de publicación correspondiente.
    3. Agregar el flujo OAuth si aplica.
    Sin cambios en los modelos.
    """

    FACEBOOK = "facebook"
    INSTAGRAM = "instagram"
    GOOGLE_BUSINESS = "google_business"


class PropietarioTipo(str, Enum):
    """
    Tipo de entidad dueña de una cuenta o config.

    - BAQUEANO: cuenta central de Baqueano Natales (propietario_id=NULL).
    - PRESTADOR: un prestador de oficios específico.
    - COMERCIO: un comercio específico.

    Se usa `str` en vez de FK dura para que el módulo social NO dependa
    de los módulos verticales. El vertical importa a social, no al revés.
    """

    BAQUEANO = "baqueano"
    PRESTADOR = "prestador"
    COMERCIO = "comercio"


class DestinoPublicacion(str, Enum):
    """
    A dónde va una publicación.

    - CENTRAL: solo a la cuenta central de Baqueano Natales.
    - PROPIO:  solo a la cuenta propia del recurso (ej: la página del
               taller).
    - AMBOS:   a las dos (si el recurso tiene cuenta propia).
    """

    CENTRAL = "central"
    PROPIO = "propio"
    AMBOS = "ambos"


class EstadoPublicacion(str, Enum):
    """
    Ciclo de vida de una publicación en la cola.

    Flujo típico:
        PENDIENTE -> PUBLICANDO -> PUBLICADO
                        |
                     FALLADO -> (reintento) -> PENDIENTE
                        |
                     AGOTADO (se superaron los reintentos)
    """

    PENDIENTE = "pendiente"
    PUBLICANDO = "publicando"
    PUBLICADO = "publicado"
    FALLADO = "fallado"
    AGOTADO = "agotado"


# =========================================================
# Cuenta social
# =========================================================
class CuentaSocial(TimestampMixin, SoftDeleteMixin, Base):
    """
    Cuenta conectada a una red social.

    Multi-tenant vía (propietario_tipo, propietario_id):
    - propietario_tipo=BAQUEANO, propietario_id=NULL  -> cuenta central
    - propietario_tipo=PRESTADOR, propietario_id=<uuid> -> del prestador
    - propietario_tipo=COMERCIO, propietario_id=<uuid>  -> del comercio

    La restricción UNIQUE(red, external_id) evita conectar dos veces la
    misma página de Facebook.
    """

    __tablename__ = "cuentas_sociales"
    __table_args__ = (
        UniqueConstraint(
            "red", "external_id",
            name="uq_cuenta_social_red_ext",
        ),
        Index(
            "ix_cuenta_social_propietario",
            "propietario_tipo", "propietario_id",
        ),
    )

    id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        primary_key=True,
        default=uuid4,
    )

    # -----------------------------------------------------
    # Propietario (multi-tenant)
    # -----------------------------------------------------
    propietario_tipo: Mapped[PropietarioTipo] = mapped_column(
        SQLEnum(
            PropietarioTipo,
            name="propietario_tipo_social",
            values_callable=lambda x: [e.value for e in x],
        ),
        nullable=False,
    )
    propietario_id: Mapped[UUID | None] = mapped_column(
        PG_UUID(as_uuid=True),
        nullable=True,
        comment="NULL = cuenta central de Baqueano Natales",
    )

    # -----------------------------------------------------
    # Red y cuenta externa
    # -----------------------------------------------------
    red: Mapped[Red] = mapped_column(
        SQLEnum(
            Red,
            name="red_social",
            values_callable=lambda x: [e.value for e in x],
        ),
        nullable=False,
        index=True,
    )
    external_id: Mapped[str] = mapped_column(
        String(150),
        nullable=False,
        comment="ID en la red (page_id de FB, ig_user_id, location_id de Google)",
    )
    external_name: Mapped[str | None] = mapped_column(
        String(255),
        nullable=True,
        comment="Nombre visible en la red (para mostrar en admin)",
    )

    # Para Instagram: apunta a la cuenta de Facebook que lo contiene.
    cuenta_padre_id: Mapped[UUID | None] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("cuentas_sociales.id", ondelete="SET NULL"),
        nullable=True,
        comment="IG -> cuenta de FB que lo contiene (mismo token)",
    )

    # -----------------------------------------------------
    # Estado
    # -----------------------------------------------------
    auto_publish: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=False,
        server_default="false",
        comment="Si true, se publican automáticamente los eventos configurados",
    )

    # -----------------------------------------------------
    # Metadata flexible (lo que devuelve la red, cacheado)
    # -----------------------------------------------------
    metadata_extra: Mapped[dict | None] = mapped_column(
        JSONB,
        nullable=True,
        comment="Datos extra de la red (categoría, seguidores, etc.)",
    )

    # -----------------------------------------------------
    # Relaciones
    # -----------------------------------------------------
    tokens: Mapped[list["TokenSocial"]] = relationship(
        back_populates="cuenta",
        cascade="all, delete-orphan",
        lazy="selectin",
    )

    def __repr__(self) -> str:
        return (
            f"<CuentaSocial(id={self.id}, red={self.red.value}, "
            f"external_id={self.external_id}, activo={self.activo})>"
        )


# =========================================================
# Token social
# =========================================================
class TokenSocial(TimestampMixin, Base):
    """
    Tokens OAuth de una cuenta, cifrados.

    Se separa de `CuentaSocial` para poder rotar tokens (agregar uno
    nuevo, marcar el viejo como expirado) sin tocar la cuenta.

    `access_token` y `refresh_token` se guardan cifrados con
    `app.core.crypto.cifrar()`. Nunca en claro.
    """

    __tablename__ = "tokens_sociales"

    id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        primary_key=True,
        default=uuid4,
    )
    cuenta_id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("cuentas_sociales.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    # -----------------------------------------------------
    # Tokens (cifrados)
    # -----------------------------------------------------
    access_token: Mapped[str] = mapped_column(
        Text,
        nullable=False,
        comment="Cifrado con prefijo 'enc:'",
    )
    refresh_token: Mapped[str | None] = mapped_column(
        Text,
        nullable=True,
        comment="Cifrado con prefijo 'enc:'",
    )
    token_type: Mapped[str] = mapped_column(
        String(50),
        nullable=False,
        default="Bearer",
        server_default="Bearer",
    )

    # -----------------------------------------------------
    # Vigencia
    # -----------------------------------------------------
    expires_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
        comment="NULL = no expira (tokens de página de FB pueden ser así)",
    )
    scope: Mapped[str | None] = mapped_column(Text, nullable=True)

    # -----------------------------------------------------
    # Relaciones
    # -----------------------------------------------------
    cuenta: Mapped[CuentaSocial] = relationship(back_populates="tokens")

    def __repr__(self) -> str:
        return (
            f"<TokenSocial(id={self.id}, cuenta_id={self.cuenta_id}, "
            f"expires_at={self.expires_at})>"
        )


# =========================================================
# Publicación social (cola)
# =========================================================
class PublicacionSocial(TimestampMixin, Base):
    """
    Cola de publicaciones. Cada fila es una intención de publicar algo
    en una red específica.

    `recurso_tipo` + `recurso_id` identifican QUÉ se está publicando
    (ej: 'prestador_servicio', 'comercio_producto') sin acoplar el
    módulo social a los verticales.

    El worker (a implementar en etapa posterior) procesa:
        estado=PENDIENTE y proximo_intento_en <= now()
    Publica, actualiza estado, y en caso de fallo incrementa `intentos`
    y reprograma `proximo_intento_en` con backoff exponencial.
    """

    __tablename__ = "publicaciones_sociales"
    __table_args__ = (
        Index(
            "ix_publicacion_social_cola",
            "estado",
            "proximo_intento_en",
        ),
    )

    id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        primary_key=True,
        default=uuid4,
    )
    cuenta_id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("cuentas_sociales.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    # -----------------------------------------------------
    # Recurso publicado (polimórfico)
    # -----------------------------------------------------
    recurso_tipo: Mapped[str] = mapped_column(
        String(50),
        nullable=False,
        comment="Ej: 'prestador_servicio', 'comercio_producto'",
    )
    recurso_id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        nullable=False,
        comment="UUID del recurso (prestador, servicio, producto, ...)",
    )

    # -----------------------------------------------------
    # Contenido
    # -----------------------------------------------------
    red: Mapped[Red] = mapped_column(
        SQLEnum(
            Red,
            name="red_social",
            values_callable=lambda x: [e.value for e in x],
            create_type=False,  # ya creado por CuentaSocial.red
        ),
        nullable=False,
    )
    contenido: Mapped[dict] = mapped_column(
        JSONB,
        nullable=False,
        comment="{'message': str, 'image_urls': [str], 'link': str}",
    )

    # -----------------------------------------------------
    # Estado de la cola
    # -----------------------------------------------------
    estado: Mapped[EstadoPublicacion] = mapped_column(
        SQLEnum(
            EstadoPublicacion,
            name="estado_publicacion",
            values_callable=lambda x: [e.value for e in x],
        ),
        nullable=False,
        default=EstadoPublicacion.PENDIENTE,
        server_default=EstadoPublicacion.PENDIENTE.value,
        index=True,
    )
    intentos: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
        default=0,
        server_default="0",
    )
    proximo_intento_en: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
        comment="NULL si aún no se programó. Worker la usa para reintentos.",
    )

    # -----------------------------------------------------
    # Prioridad (0=Baqueano, 10=Prestador, 20=Comercio)
    # -----------------------------------------------------
    prioridad: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
        default=0,
        server_default='0',
        comment='0=Baqueano, 10=Prestador, 20=Comercio',
    )
    # -----------------------------------------------------
    # Resultado
    # -----------------------------------------------------
    external_post_id: Mapped[str | None] = mapped_column(
        String(255),
        nullable=True,
        comment="ID del post en la red (para correlacionar)",
    )
    error_ultimo: Mapped[str | None] = mapped_column(
        Text,
        nullable=True,
        comment="Último error. Se sobreescribe en cada reintento.",
    )

    # -----------------------------------------------------
    # Relaciones
    # -----------------------------------------------------
    cuenta: Mapped[CuentaSocial] = relationship(lazy="selectin")

    def __repr__(self) -> str:
        return (
            f"<PublicacionSocial(id={self.id}, red={self.red.value}, "
            f"estado={self.estado.value})>"
        )


# =========================================================
# Config social
# =========================================================
class ConfigSocial(TimestampMixin, Base):
    """
    Configuración de publicación social.

    Una fila global (propietario_tipo=NULL, propietario_id=NULL) para
    defaults. Opcionalmente una fila por propietario que quiera override.

    El service de lectura hace: busca la config del propietario; si no
    existe, usa la global.
    """

    __tablename__ = "config_social"
    __table_args__ = (
        UniqueConstraint(
            "propietario_tipo",
            "propietario_id",
            name="uq_config_social_propietario",
        ),
        # Índice único parcial, con NULLS NOT DISTINCT.
        #
        # Por qué parcial: solo aplica cuando ambos son NULL — o sea, a
        # la fila global. Las filas por propietario usan el UniqueConstraint
        # de arriba.
        #
        # Por qué NULLS NOT DISTINCT: en Postgres, por defecto el índice
        # único trata los NULL como distintos entre sí (NULL != NULL),
        # así que DOS filas con (NULL, NULL) NO violaban el UNIQUE. Esta
        # opción (Postgres 15+) los trata como iguales y bloquea la
        # duplicación de la config global a nivel DB.
        Index(
            "uq_config_social_global",
            "propietario_tipo",
            "propietario_id",
            unique=True,
            postgresql_where=text(
                "propietario_tipo IS NULL AND propietario_id IS NULL"
            ),
            postgresql_nulls_not_distinct=True,
        ),
    )

    id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        primary_key=True,
        default=uuid4,
    )

    # -----------------------------------------------------
    # Propietario (NULL = config global)
    # -----------------------------------------------------
    propietario_tipo: Mapped[PropietarioTipo | None] = mapped_column(
        SQLEnum(
            PropietarioTipo,
            name="propietario_tipo_social",
            values_callable=lambda x: [e.value for e in x],
            create_type=False,  # ya creado por CuentaSocial
        ),
        nullable=True,
    )
    propietario_id: Mapped[UUID | None] = mapped_column(
        PG_UUID(as_uuid=True),
        nullable=True,
    )

    # -----------------------------------------------------
    # Qué se publica
    # -----------------------------------------------------
    auto_publish: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=False,
        server_default="false",
        comment="Interruptor maestro. Si false, no se publica nada automático.",
    )
    destino: Mapped[DestinoPublicacion] = mapped_column(
        SQLEnum(
            DestinoPublicacion,
            name="destino_publicacion",
            values_callable=lambda x: [e.value for e in x],
        ),
        nullable=False,
        default=DestinoPublicacion.AMBOS,
        server_default=DestinoPublicacion.AMBOS.value,
    )

    # -----------------------------------------------------
    # En qué redes
    # -----------------------------------------------------
    publicar_en_facebook: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=True,
        server_default="true",
    )
    publicar_en_instagram: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=False,
        server_default="false",
    )
    publicar_en_google: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=False,
        server_default="false",
    )

    def __repr__(self) -> str:
        return (
            f"<ConfigSocial(propietario_tipo={self.propietario_tipo}, "
            f"propietario_id={self.propietario_id}, "
            f"auto_publish={self.auto_publish})>"
        )