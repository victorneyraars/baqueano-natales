/// Evento del timeline de una orden (append-only).
library;

enum TipoEventoHistorial {
  estadoCambio('estado_cambio', 'Cambio de estado'),
  comentario('comentario', 'Comentario'),
  foto('foto', 'Foto'),
  presupuesto('presupuesto', 'Presupuesto'),
  aprobacion('aprobacion', 'Aprobacion'),
  rechazo('rechazo', 'Rechazo'),
  garantia('garantia', 'Garantia');

  const TipoEventoHistorial(this.value, this.label);
  final String value;
  final String label;

  static TipoEventoHistorial fromValue(String? v) {
    return TipoEventoHistorial.values.firstWhere(
      (t) => t.value == v,
      orElse: () => TipoEventoHistorial.comentario,
    );
  }
}

class OrdenHistorialEvento {
  const OrdenHistorialEvento({
    required this.id,
    required this.tipo,
    required this.createdAt,
    this.estadoAnterior,
    this.estadoNuevo,
    this.usuarioId,
    this.contenido,
  });

  final String id;
  final TipoEventoHistorial tipo;
  final DateTime createdAt;
  final String? estadoAnterior;
  final String? estadoNuevo;
  final String? usuarioId;
  final Map<String, dynamic>? contenido;

  /// Mensaje legible para mostrar en el timeline.
  String get descripcion {
    final msg = contenido?['mensaje'] as String?;
    if (msg != null) return msg;

    switch (tipo) {
      case TipoEventoHistorial.estadoCambio:
        return '${_labelEstado(estadoAnterior)} -> ${_labelEstado(estadoNuevo)}';
      case TipoEventoHistorial.aprobacion:
        return 'Presupuesto aprobado';
      case TipoEventoHistorial.rechazo:
        return 'Presupuesto rechazado';
      default:
        return tipo.label;
    }
  }

  static String _labelEstado(String? estado) {
    if (estado == null) return '-';
    return estado.replaceAll('_', ' ').toUpperCase();
  }

  factory OrdenHistorialEvento.fromJson(Map<String, dynamic> json) {
    return OrdenHistorialEvento(
      id: json['id'] as String,
      tipo: TipoEventoHistorial.fromValue(json['tipo'] as String?),
      createdAt: DateTime.parse(json['created_at'] as String),
      estadoAnterior: json['estado_anterior'] as String?,
      estadoNuevo: json['estado_nuevo'] as String?,
      usuarioId: json['usuario_id'] as String?,
      contenido: json['contenido'] as Map<String, dynamic>?,
    );
  }
}
