"""social: indice unico parcial para config global

Revision ID: d16ad0e2b9dc
Revises: 3a833c2fff44
Create Date: 2026-10-10 11:47:05.201977

Agrega un índice único PARCIAL sobre (propietario_tipo, propietario_id)
en config_social, que solo aplica cuando ambos son NULL.

Por qué: en Postgres, UNIQUE(a, b) NO bloquea duplicados cuando uno de
los valores es NULL (NULL != NULL en SQL). Sin este índice, se pueden
insertar múltiples filas con (NULL, NULL) — la config global. Este
índice garantiza que solo exista UNA config global a nivel DB.

Nota: Alembic también detectó alter_column sobre `usuarios.*`
(server_defaults), que es un falso positivo recurrente del proyecto.
Fue removido de la migración para que el cambio sea quirúrgico.
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision: str = 'd16ad0e2b9dc'
down_revision: Union[str, None] = '3a833c2fff44'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Índice único parcial: solo aplica a la config global (ambos NULL).
    op.create_index(
        "uq_config_social_global",
        "config_social",
        ["propietario_tipo", "propietario_id"],
        unique=True,
        postgresql_where=sa.text(
            "propietario_tipo IS NULL AND propietario_id IS NULL"
        ),
    )


def downgrade() -> None:
    op.drop_index(
        "uq_config_social_global",
        table_name="config_social",
        postgresql_where=sa.text(
            "propietario_tipo IS NULL AND propietario_id IS NULL"
        ),
    )