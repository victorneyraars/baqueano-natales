"""rentacar_bloqueos con EXCLUDE USING gist

Revision ID: d2e3f4a5b6c7
Revises: c1d2e3f4a5b6
Create Date: 2026-11-01
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import UUID as PG_UUID

revision = "d2e3f4a5b6c7"
down_revision = "c1d2e3f4a5b6"
branch_labels = None
depends_on = None


def upgrade():
    op.execute("CREATE EXTENSION IF NOT EXISTS btree_gist")
    op.create_table(
        "rentacar_bloqueos",
        sa.Column("id", PG_UUID(as_uuid=True), primary_key=True),
        sa.Column("vehiculo_id", PG_UUID(as_uuid=True),
                  sa.ForeignKey("rentacar_vehiculos.id", ondelete="CASCADE"),
                  nullable=False),
        sa.Column("reserva_id", PG_UUID(as_uuid=True),
                  sa.ForeignKey("rentacar_reservas.id", ondelete="CASCADE"),
                  nullable=True),
        sa.Column("fecha_inicio", sa.Date, nullable=False),
        sa.Column("fecha_fin", sa.Date, nullable=False),
        sa.Column("tipo", sa.String(20), nullable=False, server_default="manual"),
        sa.Column("motivo", sa.String(255), nullable=True),
        sa.Column("created_by", PG_UUID(as_uuid=True),
                  sa.ForeignKey("usuarios.id"), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.CheckConstraint("fecha_fin > fecha_inicio", name="ck_bloqueo_fechas"),
    )
    op.create_index("ix_bloqueos_vehiculo", "rentacar_bloqueos", ["vehiculo_id"])
    op.create_index("ix_bloqueos_reserva", "rentacar_bloqueos", ["reserva_id"])
    op.create_index("ix_bloqueos_vehiculo_fechas", "rentacar_bloqueos",
                    ["vehiculo_id", "fecha_inicio", "fecha_fin"])
    op.execute(
        "ALTER TABLE rentacar_bloqueos ADD CONSTRAINT no_solapamiento "
        "EXCLUDE USING gist ("
        "  vehiculo_id WITH =, "
        "  daterange(fecha_inicio, fecha_fin, '[)'::text) WITH &&"
        ")"
    )


def downgrade():
    op.drop_table("rentacar_bloqueos")
