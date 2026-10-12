/// Modelo de preferencias de notificacion del usuario.
library;

class PreferenciaNotificacion {
  const PreferenciaNotificacion({
    required this.recordatorios,
    required this.promociones,
    required this.confirmaciones,
    required this.sistema,
    required this.quietHoursEnabled,
    this.quietHoursInicio,
    this.quietHoursFin,
    required this.timezone,
  });

  final bool recordatorios;
  final bool promociones;
  final bool confirmaciones;
  final bool sistema;
  final bool quietHoursEnabled;
  final String? quietHoursInicio;
  final String? quietHoursFin;
  final String timezone;

  factory PreferenciaNotificacion.fromJson(Map<String, dynamic> json) {
    return PreferenciaNotificacion(
      recordatorios: json['recordatorios'] as bool,
      promociones: json['promociones'] as bool,
      confirmaciones: json['confirmaciones'] as bool,
      sistema: json['sistema'] as bool,
      quietHoursEnabled: json['quiet_hours_enabled'] as bool,
      quietHoursInicio: json['quiet_hours_inicio'] as String?,
      quietHoursFin: json['quiet_hours_fin'] as String?,
      timezone: json['timezone'] as String,
    );
  }

  PreferenciaNotificacion copyWith({
    bool? recordatorios,
    bool? promociones,
    bool? confirmaciones,
    bool? sistema,
    bool? quietHoursEnabled,
    String? quietHoursInicio,
    String? quietHoursFin,
    String? timezone,
  }) {
    return PreferenciaNotificacion(
      recordatorios: recordatorios ?? this.recordatorios,
      promociones: promociones ?? this.promociones,
      confirmaciones: confirmaciones ?? this.confirmaciones,
      sistema: sistema ?? this.sistema,
      quietHoursEnabled: quietHoursEnabled ?? this.quietHoursEnabled,
      quietHoursInicio: quietHoursInicio ?? this.quietHoursInicio,
      quietHoursFin: quietHoursFin ?? this.quietHoursFin,
      timezone: timezone ?? this.timezone,
    );
  }
}
