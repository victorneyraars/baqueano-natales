/// Modelo de una reserva (panel del prestador).
class Reserva {
  const Reserva({
    required this.id,
    required this.vehiculoId,
    required this.fechaInicio,
    required this.fechaFin,
    required this.metodoPago,
    required this.precioTotal,
    required this.estado,
    this.nombreCliente,
    this.emailCliente,
    this.telefonoCliente,
    this.vehiculoPatente,
    this.vehiculoMarca,
    this.vehiculoModelo,
    this.vehiculoImagenUrl,
  });

  final String id;
  final String vehiculoId;
  final DateTime fechaInicio;
  final DateTime fechaFin;
  final String metodoPago;
  final double precioTotal;
  final String estado;
  final String? nombreCliente;
  final String? emailCliente;
  final String? telefonoCliente;
  final String? vehiculoPatente;
  final String? vehiculoMarca;
  final String? vehiculoModelo;
  final String? vehiculoImagenUrl;

  factory Reserva.fromJson(Map<String, dynamic> json) => Reserva(
    id: json['id'] as String,
    vehiculoId: json['vehiculo_id'] as String,
    fechaInicio: DateTime.parse(json['fecha_inicio'] as String),
    fechaFin: DateTime.parse(json['fecha_fin'] as String),
    metodoPago: json['metodo_pago'] as String,
    precioTotal: (json['precio_total'] as num).toDouble(),
    estado: json['estado'] as String,
    nombreCliente: json['nombre_cliente'] as String?,
    emailCliente: json['email_cliente'] as String?,
    telefonoCliente: json['telefono_cliente'] as String?,
    vehiculoPatente: json['vehiculo_patente'] as String?,
    vehiculoMarca: json['vehiculo_marca'] as String?,
    vehiculoModelo: json['vehiculo_modelo'] as String?,
    vehiculoImagenUrl: json['vehiculo_imagen_url'] as String?,
  );

  int get diasTotales => fechaFin.difference(fechaInicio).inDays;

  String get vehiculoDescripcion {
    if (vehiculoMarca != null && vehiculoModelo != null) {
      return '$vehiculoMarca $vehiculoModelo';
    }
    return vehiculoPatente ?? 'Vehiculo';
  }

  String get estadoLabel {
    switch (estado) {
      case 'pendiente':
        return 'Pendiente';
      case 'confirmada':
        return 'Confirmada';
      case 'en_curso':
        return 'En curso';
      case 'completada':
        return 'Completada';
      case 'cancelada':
        return 'Cancelada';
      default:
        return estado;
    }
  }

  /// Estados a los que puede transicionar (mismo mapa que backend).
  List<String> get transicionesValidas {
    switch (estado) {
      case 'pendiente':
        return ['confirmada', 'cancelada'];
      case 'confirmada':
        return ['en_curso', 'cancelada'];
      case 'en_curso':
        return ['completada'];
      default:
        return [];
    }
  }
}
