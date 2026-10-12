/// Modelo de un turno agendado (cliente <-> prestador).
library;

enum EstadoTurno {
  pendiente('pendiente', 'Pendiente'),
  confirmado('confirmado', 'Confirmado'),
  enCurso('en_curso', 'En curso'),
  completado('completado', 'Completado'),
  cancelado('cancelado', 'Cancelado'),
  rechazado('rechazado', 'Rechazado'),
  noAsistio('no_asistio', 'No asistio');

  const EstadoTurno(this.value, this.label);
  final String value;
  final String label;

  static EstadoTurno fromValue(String? v) {
    return EstadoTurno.values.firstWhere(
      (e) => e.value == v,
      orElse: () => EstadoTurno.pendiente,
    );
  }

  String get colorHex {
    switch (this) {
      case EstadoTurno.pendiente:
        return '#f97316';
      case EstadoTurno.confirmado:
        return '#16a34a';
      case EstadoTurno.enCurso:
        return '#eab308';
      case EstadoTurno.completado:
        return '#0ea5e9';
      case EstadoTurno.cancelado:
        return '#6b7280';
      case EstadoTurno.rechazado:
        return '#dc2626';
      case EstadoTurno.noAsistio:
        return '#64748b';
    }
  }
}

class Turno {
  const Turno({
    required this.id,
    required this.clienteId,
    required this.prestadorId,
    required this.objetoId,
    required this.fechaInicio,
    required this.duracionMin,
    required this.estado,
    required this.createdAt,
    required this.updatedAt,
    this.motivo,
    this.notasCliente,
    this.notasPrestador,
    this.ordenId,
  });

  final String id;
  final String clienteId;
  final String prestadorId;
  final String objetoId;
  final DateTime fechaInicio;
  final int duracionMin;
  final EstadoTurno estado;
  final DateTime createdAt;
  final DateTime updatedAt;

  final String? motivo;
  final String? notasCliente;
  final String? notasPrestador;
  final String? ordenId;

  DateTime get fechaFin => fechaInicio.add(Duration(minutes: duracionMin));

  bool get esPasado => fechaInicio.isBefore(DateTime.now());

  factory Turno.fromJson(Map<String, dynamic> json) {
    return Turno(
      id: json['id'] as String,
      clienteId: json['cliente_id'] as String,
      prestadorId: json['prestador_id'] as String,
      objetoId: json['objeto_servicio_id'] as String,
      fechaInicio: DateTime.parse(json['fecha_inicio'] as String).toLocal(),
      duracionMin: json['duracion_min'] as int? ?? 30,
      estado: EstadoTurno.fromValue(json['estado'] as String?),
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      updatedAt: DateTime.parse(json['updated_at'] as String).toLocal(),
      motivo: json['motivo'] as String?,
      notasCliente: json['notas_cliente'] as String?,
      notasPrestador: json['notas_prestador'] as String?,
      ordenId: json['orden_id'] as String?,
    );
  }
}