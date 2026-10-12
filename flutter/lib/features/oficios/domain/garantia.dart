/// Modelo de una garantia asociada a una orden entregada.
library;

enum TipoGarantia {
  manoObra('mano_obra', 'Mano de obra'),
  repuesto('repuesto', 'Repuesto'),
  completo('completo', 'Completo');

  const TipoGarantia(this.value, this.label);
  final String value;
  final String label;

  static TipoGarantia fromValue(String? v) {
    return TipoGarantia.values.firstWhere(
      (t) => t.value == v,
      orElse: () => TipoGarantia.completo,
    );
  }
}

class Garantia {
  const Garantia({
    required this.id,
    required this.ordenId,
    required this.tipo,
    required this.duracionDias,
    required this.fechaInicio,
    required this.fechaFin,
    required this.activo,
    required this.createdAt,
    this.cobertura,
    this.condiciones,
  });

  final String id;
  final String ordenId;
  final TipoGarantia tipo;
  final int duracionDias;
  final DateTime fechaInicio;
  final DateTime fechaFin;
  final bool activo;
  final DateTime createdAt;
  final String? cobertura;
  final String? condiciones;

  /// True si la fecha_fin esta en el futuro.
  bool get vigente => activo && fechaFin.isAfter(DateTime.now());

  /// Dias restantes (0 si ya vencio).
  int get diasRestantes {
    final d = fechaFin.difference(DateTime.now()).inDays;
    return d < 0 ? 0 : d;
  }

  factory Garantia.fromJson(Map<String, dynamic> json) {
    return Garantia(
      id: json['id'] as String,
      ordenId: json['orden_id'] as String,
      tipo: TipoGarantia.fromValue(json['tipo'] as String?),
      duracionDias: json['duracion_dias'] as int,
      fechaInicio: DateTime.parse(json['fecha_inicio'] as String),
      fechaFin: DateTime.parse(json['fecha_fin'] as String),
      activo: json['activo'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      cobertura: json['cobertura'] as String?,
      condiciones: json['condiciones'] as String?,
    );
  }
}