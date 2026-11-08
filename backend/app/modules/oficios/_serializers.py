"""Serializadores compartidos del módulo oficios.

Motivo: `_serializar_orden` es usada tanto por `prestador_routes.py` como por
`cliente_routes.py`. En lugar de duplicarla (mala práctica) o acoplarla a uno
de los dos módulos, la movemos a este archivo neutral.

El parámetro `incluir_notas_internas` permite que el prestador vea las notas
internas de la orden, pero el cliente NO (privacidad).
"""
from typing import Any


def _serializar_orden(orden, incluir_notas_internas: bool = True, con_historial: bool = False):
    """Convierte ORM -> dict, respetando visibilidad de notas_internas."""
    data = {
        "id": orden.id,
        "numero": orden.numero,
        "cliente_id": orden.cliente_id,
        "prestador_id": orden.prestador_id,
        "objeto_servicio_id": orden.objeto_servicio_id,
        "estado": orden.estado.value,
        "prioridad": orden.prioridad.value,
        "diagnostico_inicial": orden.diagnostico_inicial,
        "notas_cliente": orden.notas_cliente,
        "notas_internas": orden.notas_internas if incluir_notas_internas else None,
        "fecha_ingreso": orden.fecha_ingreso,
        "fecha_estimada_entrega": orden.fecha_estimada_entrega,
        "fecha_entrega_real": orden.fecha_entrega_real,
        "km_ingreso": orden.km_ingreso,
        "km_salida": orden.km_salida,
        "total_presupuesto": orden.total_presupuesto,
        "total_aprobado": orden.total_aprobado,
        "items": [
            {
                "id": it.id,
                "tipo": it.tipo.value,
                "descripcion": it.descripcion,
                "cantidad": it.cantidad,
                "precio_unitario": it.precio_unitario,
                "subtotal": it.subtotal,
                "aprobado": it.aprobado,
                "orden_display": it.orden_display,
            }
            for it in orden.items
        ],
    }
    if con_historial:
        data["historial"] = [
            {
                "id": ev.id,
                "tipo": ev.tipo.value,
                "estado_anterior": ev.estado_anterior,
                "estado_nuevo": ev.estado_nuevo,
                "usuario_id": ev.usuario_id,
                "contenido": ev.contenido,
                "created_at": ev.created_at,
            }
            for ev in orden.historial
        ]
    return data
