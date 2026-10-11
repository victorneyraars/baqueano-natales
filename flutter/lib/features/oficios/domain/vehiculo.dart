/// Modelo de un vehiculo del cliente (modulo oficios - mecanica).
///
/// Un vehiculo es un `objeto_servicio` de tipo VEHICULO con datos
/// especificos (patente, marca, modelo, etc). Se identifica por
/// `objeto_servicio_id` (el ID del objeto_servicio, no del vehiculo).
library;

enum TipoVehiculo {
  sedan('sedan', 'Sedan'),
  suv('suv', 'SUV'),
  camioneta('camioneta', 'Camioneta'),
  moto('moto', 'Moto'),
  camion('camion', 'Camion'),
  otro('otro', 'Otro');

  const TipoVehiculo(this.value, this.label);
  final String value;
  final String label;

  static TipoVehiculo fromValue(String? v) {
    return TipoVehiculo.values.firstWhere(
      (t) => t.value == v,
      orElse: () => TipoVehiculo.otro,
    );
  }
}

class Vehiculo {
  const Vehiculo({
    required this.objetoId,
    required this.patente,
    required this.marca,
    required this.modelo,
    required this.anio,
    required this.tipoVehiculo,
    required this.kilometrajeActual,
    required this.activo,
    this.alias,
    this.notas,
    this.vin,
    this.color,
    this.fechaUltimaRevision,
  });

  /// ID del objeto_servicio (usado en todas las llamadas HTTP).
  final String objetoId;

  final String patente;
  final String marca;
  final String modelo;
  final int anio;
  final TipoVehiculo tipoVehiculo;
  final int kilometrajeActual;
  final bool activo;

  final String? alias;
  final String? notas;
  final String? vin;
  final String? color;
  final DateTime? fechaUltimaRevision;

  /// Nombre amigable para mostrar en UI.
  /// Si hay alias, lo usa. Si no, "Marca Modelo (PATENTE)".
  String get nombreDisplay {
    if (alias != null && alias!.isNotEmpty) return alias!;
    return '$marca $modelo ($patente)';
  }

  factory Vehiculo.fromJson(Map<String, dynamic> json) {
    return Vehiculo(
      objetoId: json['objeto_servicio_id'] as String,
      patente: json['patente'] as String,
      marca: json['marca'] as String,
      modelo: json['modelo'] as String,
      anio: json['anio'] as int,
      tipoVehiculo: TipoVehiculo.fromValue(json['tipo_vehiculo'] as String?),
      kilometrajeActual: json['kilometraje_actual'] as int? ?? 0,
      activo: json['activo'] as bool? ?? true,
      alias: json['alias'] as String?,
      notas: json['notas'] as String?,
      vin: json['vin'] as String?,
      color: json['color'] as String?,
      fechaUltimaRevision: json['fecha_ultima_revision'] != null
          ? DateTime.tryParse(json['fecha_ultima_revision'] as String)
          : null,
    );
  }

  Map<String, dynamic> toCreateJson() {
    return {
      'patente': patente,
      'marca': marca,
      'modelo': modelo,
      'anio': anio,
      'tipo_vehiculo': tipoVehiculo.value,
      'kilometraje_actual': kilometrajeActual,
      if (alias != null) 'alias': alias,
      if (notas != null) 'notas': notas,
      if (vin != null) 'vin': vin,
      if (color != null) 'color': color,
      if (fechaUltimaRevision != null)
        'fecha_ultima_revision':
            fechaUltimaRevision!.toIso8601String().split('T').first,
    };
  }
}