/// Modelo de un recordatorio (por km, fecha o evento).
library;

enum TipoRecordatorio {
  km('km', 'Por km'),
  fecha('fecha', 'Por fecha'),
  evento('evento', 'Por evento');

  const TipoRecordatorio(this.value, this.label);
  final String value;
  final String label;

  static TipoRecordatorio fromValue(String? v) {
    return TipoRecordatorio.values.firstWhere(
      (t) => t.value == v,
      orElse: () => TipoRecordatorio.evento,
    );
  }
}

class Recordatorio {
  const Recordatorio({
    required this.id,
    required this.objetoId,
    required this.tipo,
    required this.condicion,
    required this.mensaje,
    required this.enviado,
    required this.activo,
    required this.createdAt,
    this.fechaEnvio,
  });

  final String id;
  final String objetoId;
  final TipoRecordatorio tipo;
  final Map<String, dynamic> condicion;
  final String mensaje;
  final bool enviado;
  final bool activo;
  final DateTime createdAt;
  final DateTime? fechaEnvio;

  /// Texto legible de la condicion.
  String get condicionDisplay {
    switch (tipo) {
      case TipoRecordatorio.km:
        final km = condicion['km_umbral'] ?? 0;
        return 'A los $km km';
      case TipoRecordatorio.fecha:
        final fecha = condicion['fecha'] ?? '';
        return 'El $fecha';
      case TipoRecordatorio.evento:
        return condicion['descripcion'] ?? 'Evento';
    }
  }

  Map<String, dynamic> toCreateJson() {
    return {
      'objeto_servicio_id': objetoId,
      'tipo': tipo.value,
      'condicion': condicion,
      'mensaje': mensaje,
    };
  }

  factory Recordatorio.fromJson(Map<String, dynamic> json) {
    return Recordatorio(
      id: json['id'] as String,
      objetoId: json['objeto_servicio_id'] as String,
      tipo: TipoRecordatorio.fromValue(json['tipo'] as String?),
      condicion: Map<String, dynamic>.from(json['condicion'] as Map),
      mensaje: json['mensaje'] as String,
      enviado: json['enviado'] as bool? ?? false,
      activo: json['activo'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      fechaEnvio: json['fecha_envio'] != null
          ? DateTime.tryParse(json['fecha_envio'] as String)
          : null,
    );
  }
}