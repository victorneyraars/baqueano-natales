/// Modelo del bloque `perfil_negocio.transparencia` (JSONB del backend).
///
/// Datos que el cliente necesita conocer ANTES de reservar:
/// depósito, kilometraje, combustible, cancelación, edad mínima y licencia.
///
/// El backend (`transparencia.py`) tiene defaults regionales; aquí solo
/// se persiste lo que el prestador configuró explícitamente.
library;

class Transparencia {
  final bool visible;
  final int? depositoClp;
  final String? kilometraje;
  final int? kilometrajeKmDia;
  final String? combustible;
  final String? cancelacion;
  final String? cancelacionDetalle;
  final int? edadMinima;
  final String? licenciaRequerida;
  final String? notasExtra;

  const Transparencia({
    this.visible = true,
    this.depositoClp,
    this.kilometraje,
    this.kilometrajeKmDia,
    this.combustible,
    this.cancelacion,
    this.cancelacionDetalle,
    this.edadMinima,
    this.licenciaRequerida,
    this.notasExtra,
  });

  /// Defaults regionales (mismos que backend transparencia.py).
  factory Transparencia.regionalDefaults() => const Transparencia(
    visible: true,
    depositoClp: 100000,
    kilometraje: 'ilimitado',
    combustible: 'lleno_lleno',
    cancelacion: 'gratis_48h',
    edadMinima: 21,
    licenciaRequerida: 'chilena_o_internacional',
  );

  factory Transparencia.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const Transparencia(visible: false);
    return Transparencia(
      visible: (json['visible'] as bool?) ?? true,
      depositoClp: (json['deposito_clp'] as num?)?.toInt(),
      kilometraje: json['kilometraje'] as String?,
      kilometrajeKmDia: (json['kilometraje_km_dia'] as num?)?.toInt(),
      combustible: json['combustible'] as String?,
      cancelacion: json['cancelacion'] as String?,
      cancelacionDetalle: json['cancelacion_detalle'] as String?,
      edadMinima: (json['edad_minima'] as num?)?.toInt(),
      licenciaRequerida: json['licencia_requerida'] as String?,
      notasExtra: json['notas_extra'] as String?,
    );
  }

  /// Si no es visible, solo persiste `visible: false` (bloque oculto en web).
  /// Si es visible, persiste solo los campos no-null (backend usa defaults
  /// regionales para los omitidos).
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{'visible': visible};
    if (!visible) return json;
    if (depositoClp != null) json['deposito_clp'] = depositoClp;
    if (kilometraje != null) json['kilometraje'] = kilometraje;
    if (kilometrajeKmDia != null) json['kilometraje_km_dia'] = kilometrajeKmDia;
    if (combustible != null) json['combustible'] = combustible;
    if (cancelacion != null) json['cancelacion'] = cancelacion;
    if (cancelacionDetalle != null) {
      json['cancelacion_detalle'] = cancelacionDetalle;
    }
    if (edadMinima != null) json['edad_minima'] = edadMinima;
    if (licenciaRequerida != null) {
      json['licencia_requerida'] = licenciaRequerida;
    }
    if (notasExtra != null) json['notas_extra'] = notasExtra;
    return json;
  }

  Transparencia copyWith({
    bool? visible,
    int? depositoClp,
    String? kilometraje,
    int? kilometrajeKmDia,
    String? combustible,
    String? cancelacion,
    String? cancelacionDetalle,
    int? edadMinima,
    String? licenciaRequerida,
    String? notasExtra,
    bool clearKilometrajeKmDia = false,
    bool clearCancelacionDetalle = false,
    bool clearNotasExtra = false,
  }) => Transparencia(
    visible: visible ?? this.visible,
    depositoClp: depositoClp ?? this.depositoClp,
    kilometraje: kilometraje ?? this.kilometraje,
    kilometrajeKmDia: clearKilometrajeKmDia
        ? null
        : (kilometrajeKmDia ?? this.kilometrajeKmDia),
    combustible: combustible ?? this.combustible,
    cancelacion: cancelacion ?? this.cancelacion,
    cancelacionDetalle: clearCancelacionDetalle
        ? null
        : (cancelacionDetalle ?? this.cancelacionDetalle),
    edadMinima: edadMinima ?? this.edadMinima,
    licenciaRequerida: licenciaRequerida ?? this.licenciaRequerida,
    notasExtra: clearNotasExtra ? null : (notasExtra ?? this.notasExtra),
  );
}
