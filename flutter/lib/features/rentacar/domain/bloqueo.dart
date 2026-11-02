/// Bloqueo de disponibilidad de un vehiculo (Fase 1.1).
///
/// Tipos:
/// - reserva: vinculado a una reserva (reservaId NOT NULL)
/// - mantenimiento: bloqueo de taller
/// - manual: bloqueo del dueno
class Bloqueo {
  const Bloqueo({
    required this.id,
    required this.vehiculoId,
    this.reservaId,
    required this.fechaInicio,
    required this.fechaFin,
    required this.tipo,
    this.motivo,
    required this.createdAt,
  });

  final String id;
  final String vehiculoId;
  final String? reservaId;
  final DateTime fechaInicio;
  final DateTime fechaFin;
  final String tipo; // reserva | mantenimiento | manual
  final String? motivo;
  final DateTime createdAt;

  factory Bloqueo.fromJson(Map<String, dynamic> json) => Bloqueo(
    id: json['id'] as String,
    vehiculoId: json['vehiculo_id'] as String,
    reservaId: json['reserva_id'] as String?,
    fechaInicio: DateTime.parse('${json['fecha_inicio']}T00:00:00'),
    fechaFin: DateTime.parse('${json['fecha_fin']}T00:00:00'),
    tipo: json['tipo'] as String,
    motivo: json['motivo'] as String?,
    createdAt: DateTime.parse(json['created_at'] as String),
  );

  String get tipoLabel {
    switch (tipo) {
      case 'reserva':
        return 'Reservado';
      case 'mantenimiento':
        return 'Mantenimiento';
      case 'manual':
        return 'Bloqueado';
      default:
        return tipo;
    }
  }

  /// True si este bloqueo cubre la fecha dada (en rango [inicio, fin)).
  bool cubreDia(DateTime dia) {
    final d = DateTime(dia.year, dia.month, dia.day);
    return !d.isBefore(fechaInicio) && d.isBefore(fechaFin);
  }
}
