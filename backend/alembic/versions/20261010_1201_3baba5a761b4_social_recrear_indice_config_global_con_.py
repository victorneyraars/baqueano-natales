"""social: recrear indice config global con nulls not distinct

Revision ID: 3baba5a761b4
Revises: d16ad0e2b9dc
Create Date: 2026-10-10 12:01:39.155407

Recrea el índice único parcial `uq_config_social_global` sobre
config_social, esta vez con NULLS NOT DISTINCT.

Motivo: el índice anterior (migración d16ad0e2b9dc) declaraba el WHERE
parcial, pero NO declaraba NULLS NOT DISTINCT. En Postgres, los índices
únicos tratan los NULL como distintos entre sí (NULL != NULL) por
defecto, así que dos filas con (NULL, NULL) NO violaban el UNIQUE.

Este fix (Postgres 15+) hace que los NULL se traten como iguales, y
bloquea la duplicación de la config global a nivel DB.

Nota: Alembic también detectó alter_column sobre `usuarios.*`
(server_defaults), un falso positivo recurrente del proyecto. Fue
removido para que este cambio sea quirúrgico.
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision: str = '3baba5a761b4'
down_revision: Union[str, None] = 'd16ad0e2b9dc'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.drop_index(
        "uq_config_social_global",
        table_name="config_social",
        postgresql_where=sa.text(
            "propietario_tipo IS NULL AND propietario_id IS NULL"
        ),
    )
    op.create_index(
        "uq_config_social_global",
        "config_social",
        ["propietario_tipo", "propietario_id"],
        unique=True,
        postgresql_where=sa.text(
            "propietario_tipo IS NULL AND propietario_id IS NULL"
        ),
        postgresql_nulls_not_distinct=True,
    )


def downgrade() -> None:
    op.drop_index(
        "uq_config_social_global",
        table_name="config_social",
        postgresql_where=sa.text(
            "propietario_tipo IS NULL AND propietario_id IS NULL"
        ),
        postgresql_nulls_not_distinct=True,
    )
    op.create_index(
        "uq_config_social_global",
        "config_social",
        ["propietario_tipo", "propietario_id"],
        unique=True,
        postgresql_where=sa.text(
            "propietario_tipo IS NULL AND propietario_id IS NULL"
        ),
    )