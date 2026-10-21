/// Modelo de horario de comercio.
///
/// Coincide con la respuesta del backend (HorarioResponse).
///
/// Soporta múltiples franjas por día (ej: 12:00-15:00 y 19:00-23:00).
/// Las horas se guardan como `String` en formato `HH:MM:SS` (ISO time),
/// para evitar acoplar el modelo a Flutter.
library;

class Horario {
  const Horario({
    required this.id,
    required this.comercioId,
    required this.diaSemana,
    required this.cerrado,
    this.abre,
    this.cierra,
  });

  final String id; // UUID
  final String comercioId; // UUID
  final int diaSemana; // 0=lunes ... 6=domingo
  final bool cerrado;
  final String? abre; // "HH:MM:SS"
  final String? cierra; // "HH:MM:SS"

  /// Nombre del día en español.
  String get nombreDia {
    const nombres = [
      'Lunes',
      'Martes',
      'Miércoles',
      'Jueves',
      'Viernes',
      'Sábado',
      'Domingo',
    ];
    return (diaSemana >= 0 && diaSemana <= 6) ? nombres[diaSemana] : '?';
  }

  /// Horas en formato corto (HH:MM) para mostrar en UI.
  /// `null` si está cerrado o faltan datos.
  String? get abreCorto => _corto(abre);
  String? get cierraCorto => _corto(cierra);

  static String? _corto(String? hhmmss) {
    if (hhmmss == null || hhmmss.isEmpty) return null;
    final partes = hhmmss.split(':');
    if (partes.length < 2) return hhmmss;
    return '${partes[0]}:${partes[1]}';
  }

  /// Rango legible para UI (ej: "12:00 - 15:00" o "Cerrado").
  String get rangoLegible {
    if (cerrado) return 'Cerrado';
    if (abreCorto == null || cierraCorto == null) return 'Sin horario';
    return '$abreCorto - $cierraCorto';
  }

  factory Horario.fromJson(Map<String, dynamic> json) {
    return Horario(
      id: json['id'] as String,
      comercioId: json['comercio_id'] as String,
      diaSemana: (json['dia_semana'] as num).toInt(),
      cerrado: json['cerrado'] as bool? ?? false,
      abre: json['abre'] as String?,
      cierra: json['cierra'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'comercio_id': comercioId,
      'dia_semana': diaSemana,
      'cerrado': cerrado,
      'abre': abre,
      'cierra': cierra,
    };
  }

  @override
  String toString() => 'Horario(dia=$diaSemana, $rangoLegible)';
}
