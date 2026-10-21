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

/// Resumen del cliente que hizo la reserva (para mostrar en agenda/detalle).
class ClienteResumen {
  const ClienteResumen({
    required this.id,
    required this.nombre,
    this.apellido,
    required this.email,
    this.phone,
  });

  final String id;
  final String nombre;
  final String? apellido;
  final String email;
  final String? phone;

  String get nombreCompleto {
    if (apellido == null || apellido!.isEmpty) return nombre;
    return '$nombre $apellido';
  }

  factory ClienteResumen.fromJson(Map<String, dynamic> json) {
    return ClienteResumen(
      id: json['id'] as String,
      nombre: json['nombre'] as String,
      apellido: json['apellido'] as String?,
      email: json['email'] as String,
      phone: json['phone'] as String?,
    );
  }
}

/// Resumen del vehiculo asociado al turno.
class VehiculoResumen {
  const VehiculoResumen({
    required this.id,
    required this.patente,
    required this.marca,
    required this.modelo,
    required this.anio,
    this.color,
  });

  final String id;
  final String patente;
  final String marca;
  final String modelo;
  final int anio;
  final String? color;

  String get descripcion => '$marca $modelo ($anio) - $patente';

  factory VehiculoResumen.fromJson(Map<String, dynamic> json) {
    return VehiculoResumen(
      id: json['id'] as String,
      patente: json['patente'] as String,
      marca: json['marca'] as String,
      modelo: json['modelo'] as String,
      anio: json['anio'] as int,
      color: json['color'] as String?,
    );
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
    this.createdAt,
    this.updatedAt,
    this.motivo,
    this.notasCliente,
    this.notasPrestador,
    this.ordenId,
    this.cliente,
    this.vehiculo,
  });

  final String id;
  final String clienteId;
  final String prestadorId;
  final String objetoId;
  final DateTime fechaInicio;
  final int duracionMin;
  final EstadoTurno estado;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  final String? motivo;
  final String? notasCliente;
  final String? notasPrestador;
  final String? ordenId;

  /// Relaciones expandidas (opcionales, vienen del backend).
  final ClienteResumen? cliente;
  final VehiculoResumen? vehiculo;

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
      createdAt: _parseFechaOpcional(json['created_at']),
      updatedAt: _parseFechaOpcional(json['updated_at']),
      motivo: json['motivo'] as String?,
      notasCliente: json['notas_cliente'] as String?,
      notasPrestador: json['notas_prestador'] as String?,
      ordenId: json['orden_id'] as String?,
      cliente: json['cliente'] != null
          ? ClienteResumen.fromJson(json['cliente'] as Map<String, dynamic>)
          : null,
      vehiculo: json['vehiculo'] != null
          ? VehiculoResumen.fromJson(json['vehiculo'] as Map<String, dynamic>)
          : null,
    );
  }

  static DateTime? _parseFechaOpcional(dynamic v) {
    if (v is String) return DateTime.tryParse(v)?.toLocal();
    return null;
  }
}
