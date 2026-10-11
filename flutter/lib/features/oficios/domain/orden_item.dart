/// Item del presupuesto de una orden.
///
/// El cliente puede aprobar/rechazar cada item individualmente.
/// `aprobado=null` significa pendiente de decision.
library;

enum TipoItemOrden {
  servicio('servicio', 'Servicio'),
  repuesto('repuesto', 'Repuesto'),
  manoObra('mano_obra', 'Mano de obra'),
  otro('otro', 'Otro');

  const TipoItemOrden(this.value, this.label);
  final String value;
  final String label;

  static TipoItemOrden fromValue(String? v) {
    return TipoItemOrden.values.firstWhere(
      (t) => t.value == v,
      orElse: () => TipoItemOrden.otro,
    );
  }
}

class OrdenItem {
  const OrdenItem({
    required this.id,
    required this.tipo,
    required this.descripcion,
    required this.cantidad,
    required this.precioUnitario,
    required this.subtotal,
    required this.ordenDisplay,
    this.aprobado,
  });

  final String id;
  final TipoItemOrden tipo;
  final String descripcion;
  final double cantidad;
  final double precioUnitario;
  final double subtotal;
  final int ordenDisplay;

  /// null = pendiente, true = aprobado, false = rechazado.
  final bool? aprobado;

  bool get pendiente => aprobado == null;
  bool get aprobadoCliente => aprobado == true;

  factory OrdenItem.fromJson(Map<String, dynamic> json) {
    return OrdenItem(
      id: json['id'] as String,
      tipo: TipoItemOrden.fromValue(json['tipo'] as String?),
      descripcion: json['descripcion'] as String,
      cantidad: _toDouble(json['cantidad']),
      precioUnitario: _toDouble(json['precio_unitario']),
      subtotal: _toDouble(json['subtotal']),
      ordenDisplay: json['orden_display'] as int? ?? 0,
      aprobado: json['aprobado'] as bool?,
    );
  }

  Map<String, dynamic> toCreateJson() {
    return {
      'tipo': tipo.value,
      'descripcion': descripcion,
      'cantidad': cantidad,
      'precio_unitario': precioUnitario,
      'orden_display': ordenDisplay,
    };
  }
}

double _toDouble(dynamic v) {
  if (v == null) return 0.0;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0.0;
  return 0.0;
}