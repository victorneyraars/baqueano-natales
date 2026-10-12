"""Services de reportes del taller (M5.3).

Metricas de industria basadas en Jobber / ServiceTitan / TallerPro.
SQL agregado directo (GROUP BY + func.sum/count/avg). Optimizar a vistas
materializadas cuando haya volumen real (>10k ordenes por taller).
"""
import logging
from datetime import date, datetime, timedelta, timezone
from decimal import Decimal
from uuid import UUID

from sqlalchemy import case, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.modules.auth.models import Usuario
from app.modules.oficios.models import EstadoOrden, OrdenItem, OrdenTrabajo

logger = logging.getLogger(__name__)


def _ventana_default(desde: date | None, hasta: date | None) -> tuple[date, date]:
    """Si no se pasa rango, usa los ultimos 12 meses."""
    hoy = date.today()
    h = hasta or hoy
    d = desde or (h - timedelta(days=365))
    return d, h


def _a_float(valor) -> float:
    if valor is None:
        return 0.0
    if isinstance(valor, Decimal):
        return float(valor)
    return float(valor)


async def _kpis(
    db: AsyncSession, prestador_id: UUID, desde: date, hasta: date,
) -> dict:
    """KPIs del periodo."""
    desde_dt = datetime.combine(desde, datetime.min.time()).replace(tzinfo=timezone.utc)
    hasta_dt = datetime.combine(hasta, datetime.max.time()).replace(tzinfo=timezone.utc)

    base_where = [
        OrdenTrabajo.prestador_id == prestador_id,
        OrdenTrabajo.fecha_ingreso >= desde_dt,
        OrdenTrabajo.fecha_ingreso <= hasta_dt,
    ]

    total = (
        await db.execute(
            select(func.count(OrdenTrabajo.id)).where(*base_where)
        )
    ).scalar_one() or 0

    stmt_estado = (
        select(OrdenTrabajo.estado, func.count(OrdenTrabajo.id))
        .where(*base_where)
        .group_by(OrdenTrabajo.estado)
    )
    por_estado_rows = (await db.execute(stmt_estado)).all()
    por_estado = {estado.value: count for estado, count in por_estado_rows}

    stmt_ing = select(func.coalesce(func.sum(OrdenTrabajo.total_aprobado), 0)).where(
        *base_where, OrdenTrabajo.estado == EstadoOrden.ENTREGADO,
    )
    ingresos = _a_float((await db.execute(stmt_ing)).scalar_one())

    entregadas = por_estado.get(EstadoOrden.ENTREGADO.value, 0)
    ticket_promedio = ingresos / entregadas if entregadas > 0 else 0.0

    stmt_items = (
        select(
            func.count(OrdenItem.id),
            func.sum(case((OrdenItem.aprobado.is_(True), 1), else_=0)),
        )
        .select_from(OrdenItem)
        .join(OrdenTrabajo, OrdenTrabajo.id == OrdenItem.orden_id)
        .where(*base_where)
    )
    row_items = (await db.execute(stmt_items)).one()
    total_items = row_items[0] or 0
    aprobados = row_items[1] or 0
    tasa = (aprobados / total_items) if total_items > 0 else 0.0

    stmt_dur = select(
        func.avg(
            func.extract(
                "epoch",
                OrdenTrabajo.fecha_entrega_real - OrdenTrabajo.fecha_ingreso,
            )
        )
    ).where(
        *base_where,
        OrdenTrabajo.estado == EstadoOrden.ENTREGADO,
        OrdenTrabajo.fecha_entrega_real.isnot(None),
    )
    seg = (await db.execute(stmt_dur)).scalar_one()
    duracion_dias = (float(seg) / 86400.0) if seg is not None else None

    return {
        "total_ordenes": int(total),
        "ordenes_por_estado": por_estado,
        "ingresos_totales": round(ingresos, 2),
        "ticket_promedio": round(ticket_promedio, 2),
        "tasa_aprobacion_items": round(tasa, 4),
        "duracion_promedio_dias": round(duracion_dias, 2) if duracion_dias else None,
    }


async def _serie_mensual(
    db: AsyncSession, prestador_id: UUID, desde: date, hasta: date,
) -> list[dict]:
    desde_dt = datetime.combine(desde, datetime.min.time()).replace(tzinfo=timezone.utc)
    hasta_dt = datetime.combine(hasta, datetime.max.time()).replace(tzinfo=timezone.utc)
    mes_col = func.to_char(OrdenTrabajo.fecha_ingreso, "YYYY-MM").label("mes")

    stmt = (
        select(
            mes_col,
            func.count(OrdenTrabajo.id).label("ordenes"),
            func.coalesce(func.sum(OrdenTrabajo.total_aprobado), 0).label("ingresos"),
        )
        .where(
            OrdenTrabajo.prestador_id == prestador_id,
            OrdenTrabajo.fecha_ingreso >= desde_dt,
            OrdenTrabajo.fecha_ingreso <= hasta_dt,
        )
        .group_by(mes_col)
        .order_by(mes_col)
    )
    rows = (await db.execute(stmt)).all()
    return [
        {
            "mes": r.mes,
            "ordenes": int(r.ordenes),
            "ingresos": round(_a_float(r.ingresos), 2),
        }
        for r in rows
    ]


async def _top_servicios(
    db: AsyncSession, prestador_id: UUID, desde: date, hasta: date, limit: int = 10,
) -> list[dict]:
    desde_dt = datetime.combine(desde, datetime.min.time()).replace(tzinfo=timezone.utc)
    hasta_dt = datetime.combine(hasta, datetime.max.time()).replace(tzinfo=timezone.utc)
    stmt = (
        select(
            OrdenItem.descripcion,
            func.count(OrdenItem.id).label("cantidad"),
            func.coalesce(func.sum(OrdenItem.subtotal), 0).label("ingresos"),
        )
        .select_from(OrdenItem)
        .join(OrdenTrabajo, OrdenTrabajo.id == OrdenItem.orden_id)
        .where(
            OrdenTrabajo.prestador_id == prestador_id,
            OrdenTrabajo.fecha_ingreso >= desde_dt,
            OrdenTrabajo.fecha_ingreso <= hasta_dt,
        )
        .group_by(OrdenItem.descripcion)
        .order_by(func.count(OrdenItem.id).desc(), OrdenItem.descripcion)
        .limit(limit)
    )
    rows = (await db.execute(stmt)).all()
    return [
        {
            "descripcion": r.descripcion,
            "cantidad": int(r.cantidad),
            "ingresos_totales": round(_a_float(r.ingresos), 2),
        }
        for r in rows
    ]


async def _top_clientes(
    db: AsyncSession, prestador_id: UUID, desde: date, hasta: date, limit: int = 10,
) -> list[dict]:
    desde_dt = datetime.combine(desde, datetime.min.time()).replace(tzinfo=timezone.utc)
    hasta_dt = datetime.combine(hasta, datetime.max.time()).replace(tzinfo=timezone.utc)
    stmt = (
        select(
            OrdenTrabajo.cliente_id,
            func.count(OrdenTrabajo.id).label("ordenes"),
            func.coalesce(func.sum(OrdenTrabajo.total_aprobado), 0).label("ingresos"),
        )
        .where(
            OrdenTrabajo.prestador_id == prestador_id,
            OrdenTrabajo.fecha_ingreso >= desde_dt,
            OrdenTrabajo.fecha_ingreso <= hasta_dt,
        )
        .group_by(OrdenTrabajo.cliente_id)
        .order_by(func.sum(OrdenTrabajo.total_aprobado).desc())
        .limit(limit)
    )
    rows = (await db.execute(stmt)).all()

    cliente_ids = [r.cliente_id for r in rows]
    nombres: dict[UUID, str | None] = {}
    if cliente_ids:
        stmt_users = select(Usuario.id, Usuario.nombre, Usuario.apellido).where(
            Usuario.id.in_(cliente_ids)
        )
        for uid, nombre, apellido in (await db.execute(stmt_users)).all():
            full = " ".join(p for p in [nombre, apellido] if p) or None
            nombres[uid] = full

    return [
        {
            "cliente_id": str(r.cliente_id),
            "cliente_nombre": nombres.get(r.cliente_id),
            "ordenes": int(r.ordenes),
            "ingresos_totales": round(_a_float(r.ingresos), 2),
        }
        for r in rows
    ]


async def generar_reporte(
    db: AsyncSession,
    prestador_id: UUID,
    desde: date | None = None,
    hasta: date | None = None,
) -> dict:
    """Genera el reporte completo del taller en el periodo dado."""
    d, h = _ventana_default(desde, hasta)
    kpis = await _kpis(db, prestador_id, d, h)
    serie = await _serie_mensual(db, prestador_id, d, h)
    servicios = await _top_servicios(db, prestador_id, d, h)
    clientes = await _top_clientes(db, prestador_id, d, h)
    return {
        "prestador_id": str(prestador_id),
        "desde": d.isoformat(),
        "hasta": h.isoformat(),
        "generado_en": datetime.now(timezone.utc).isoformat(),
        "kpis": kpis,
        "serie_mensual": serie,
        "top_servicios": servicios,
        "top_clientes": clientes,
    }


def reporte_a_csv(reporte: dict) -> str:
    """Convierte el reporte a CSV (formato plano, todos los bloques)."""
    lineas: list[str] = []
    lineas.append("# KPIs")
    lineas.append("metric,valor")
    lineas.append(f"total_ordenes,{reporte['kpis']['total_ordenes']}")
    lineas.append(f"ingresos_totales,{reporte['kpis']['ingresos_totales']}")
    lineas.append(f"ticket_promedio,{reporte['kpis']['ticket_promedio']}")
    lineas.append(f"tasa_aprobacion_items,{reporte['kpis']['tasa_aprobacion_items']}")
    dur = reporte["kpis"]["duracion_promedio_dias"]
    lineas.append(f"duracion_promedio_dias,{dur or ''}")
    lineas.append("")
    lineas.append("# Ordenes por estado")
    lineas.append("estado,count")
    for estado, count in reporte["kpis"]["ordenes_por_estado"].items():
        lineas.append(f"{estado},{count}")
    lineas.append("")
    lineas.append("# Serie mensual")
    lineas.append("mes,ordenes,ingresos")
    for s in reporte["serie_mensual"]:
        lineas.append(f"{s['mes']},{s['ordenes']},{s['ingresos']}")
    lineas.append("")
    lineas.append("# Top servicios")
    lineas.append("descripcion,cantidad,ingresos_totales")
    for s in reporte["top_servicios"]:
        desc = s["descripcion"].replace(",", " ")
        lineas.append(f"{desc},{s['cantidad']},{s['ingresos_totales']}")
    lineas.append("")
    lineas.append("# Top clientes")
    lineas.append("cliente_id,cliente_nombre,ordenes,ingresos_totales")
    for c in reporte["top_clientes"]:
        nombre = (c["cliente_nombre"] or "").replace(",", " ")
        lineas.append(
            f"{c['cliente_id']},{nombre},{c['ordenes']},{c['ingresos_totales']}"
        )
    return "\n".join(lineas) + "\n"
