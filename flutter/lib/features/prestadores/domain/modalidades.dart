/// Configuración de las 7 modalidades de prestación de servicios.
///
/// Cada modalidad tiene su propia configuración (radio, costo, etc.).
/// El backend lo guarda en `prestadores.modalidades` (JSONB).
library;

class ConfigModalidad {
  const ConfigModalidad({this.activo = false, this.notas});

  final bool activo;
  final String? notas;

  factory ConfigModalidad.fromJson(Map<String, dynamic> json) {
    return ConfigModalidad(
      activo: json['activo'] as bool? ?? false,
      notas: json['notas'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {'activo': activo, 'notas': notas};

  ConfigModalidad copyWith({bool? activo, String? notas}) {
    return ConfigModalidad(
      activo: activo ?? this.activo,
      notas: notas ?? this.notas,
    );
  }
}

class ConfigDomicilio extends ConfigModalidad {
  const ConfigDomicilio({
    super.activo = false,
    super.notas,
    this.radioKm = 15,
    this.costoDesplazamientoClp = 0,
  });

  final int radioKm;
  final int costoDesplazamientoClp;

  factory ConfigDomicilio.fromJson(Map<String, dynamic> json) {
    return ConfigDomicilio(
      activo: json['activo'] as bool? ?? false,
      notas: json['notas'] as String?,
      radioKm: json['radio_km'] as int? ?? 15,
      costoDesplazamientoClp: json['costo_desplazamiento_clp'] as int? ?? 0,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'radio_km': radioKm,
    'costo_desplazamiento_clp': costoDesplazamientoClp,
  };

  @override
  ConfigDomicilio copyWith({
    bool? activo,
    String? notas,
    int? radioKm,
    int? costoDesplazamientoClp,
  }) {
    return ConfigDomicilio(
      activo: activo ?? this.activo,
      notas: notas ?? this.notas,
      radioKm: radioKm ?? this.radioKm,
      costoDesplazamientoClp:
          costoDesplazamientoClp ?? this.costoDesplazamientoClp,
    );
  }
}

class ConfigPuntoEstrategico extends ConfigModalidad {
  const ConfigPuntoEstrategico({
    super.activo = false,
    super.notas,
    this.puntoDescripcion,
  });

  final String? puntoDescripcion;

  factory ConfigPuntoEstrategico.fromJson(Map<String, dynamic> json) {
    return ConfigPuntoEstrategico(
      activo: json['activo'] as bool? ?? false,
      notas: json['notas'] as String?,
      puntoDescripcion: json['punto_descripcion'] as String?,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'punto_descripcion': puntoDescripcion,
  };

  @override
  ConfigPuntoEstrategico copyWith({
    bool? activo,
    String? notas,
    String? puntoDescripcion,
  }) {
    return ConfigPuntoEstrategico(
      activo: activo ?? this.activo,
      notas: notas ?? this.notas,
      puntoDescripcion: puntoDescripcion ?? this.puntoDescripcion,
    );
  }
}

class ConfigRecogidaEntrega extends ConfigModalidad {
  const ConfigRecogidaEntrega({
    super.activo = false,
    super.notas,
    this.costoTrasladoClp = 0,
  });

  final int costoTrasladoClp;

  factory ConfigRecogidaEntrega.fromJson(Map<String, dynamic> json) {
    return ConfigRecogidaEntrega(
      activo: json['activo'] as bool? ?? false,
      notas: json['notas'] as String?,
      costoTrasladoClp: json['costo_traslado_clp'] as int? ?? 0,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'costo_traslado_clp': costoTrasladoClp,
  };

  @override
  ConfigRecogidaEntrega copyWith({
    bool? activo,
    String? notas,
    int? costoTrasladoClp,
  }) {
    return ConfigRecogidaEntrega(
      activo: activo ?? this.activo,
      notas: notas ?? this.notas,
      costoTrasladoClp: costoTrasladoClp ?? this.costoTrasladoClp,
    );
  }
}

class ConfigSuscripcion extends ConfigModalidad {
  const ConfigSuscripcion({
    super.activo = false,
    super.notas,
    this.planes = const [],
  });

  final List<Map<String, dynamic>> planes;

  factory ConfigSuscripcion.fromJson(Map<String, dynamic> json) {
    return ConfigSuscripcion(
      activo: json['activo'] as bool? ?? false,
      notas: json['notas'] as String?,
      planes: (json['planes'] as List<dynamic>? ?? [])
          .map((p) => p as Map<String, dynamic>)
          .toList(),
    );
  }

  @override
  Map<String, dynamic> toJson() => {...super.toJson(), 'planes': planes};

  @override
  ConfigSuscripcion copyWith({
    bool? activo,
    String? notas,
    List<Map<String, dynamic>>? planes,
  }) {
    return ConfigSuscripcion(
      activo: activo ?? this.activo,
      notas: notas ?? this.notas,
      planes: planes ?? this.planes,
    );
  }
}

class ModalidadesConfig {
  const ModalidadesConfig({
    this.tallerFisico = const ConfigModalidad(),
    this.domicilio = const ConfigDomicilio(),
    this.puntoEstrategico = const ConfigPuntoEstrategico(),
    this.recogidaEntrega = const ConfigRecogidaEntrega(),
    this.suscripcion = const ConfigSuscripcion(),
    this.flotas = const ConfigModalidad(),
    this.hibrido = const ConfigModalidad(),
  });

  final ConfigModalidad tallerFisico;
  final ConfigDomicilio domicilio;
  final ConfigPuntoEstrategico puntoEstrategico;
  final ConfigRecogidaEntrega recogidaEntrega;
  final ConfigSuscripcion suscripcion;
  final ConfigModalidad flotas;
  final ConfigModalidad hibrido;

  factory ModalidadesConfig.fromJson(Map<String, dynamic> json) {
    return ModalidadesConfig(
      tallerFisico: ConfigModalidad.fromJson(
        json['taller_fisico'] as Map<String, dynamic>? ?? {},
      ),
      domicilio: ConfigDomicilio.fromJson(
        json['domicilio'] as Map<String, dynamic>? ?? {},
      ),
      puntoEstrategico: ConfigPuntoEstrategico.fromJson(
        json['punto_estrategico'] as Map<String, dynamic>? ?? {},
      ),
      recogidaEntrega: ConfigRecogidaEntrega.fromJson(
        json['recogida_entrega'] as Map<String, dynamic>? ?? {},
      ),
      suscripcion: ConfigSuscripcion.fromJson(
        json['suscripcion'] as Map<String, dynamic>? ?? {},
      ),
      flotas: ConfigModalidad.fromJson(
        json['flotas'] as Map<String, dynamic>? ?? {},
      ),
      hibrido: ConfigModalidad.fromJson(
        json['hibrido'] as Map<String, dynamic>? ?? {},
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'taller_fisico': tallerFisico.toJson(),
    'domicilio': domicilio.toJson(),
    'punto_estrategico': puntoEstrategico.toJson(),
    'recogida_entrega': recogidaEntrega.toJson(),
    'suscripcion': suscripcion.toJson(),
    'flotas': flotas.toJson(),
    'hibrido': hibrido.toJson(),
  };

  ModalidadesConfig copyWith({
    ConfigModalidad? tallerFisico,
    ConfigDomicilio? domicilio,
    ConfigPuntoEstrategico? puntoEstrategico,
    ConfigRecogidaEntrega? recogidaEntrega,
    ConfigSuscripcion? suscripcion,
    ConfigModalidad? flotas,
    ConfigModalidad? hibrido,
  }) {
    return ModalidadesConfig(
      tallerFisico: tallerFisico ?? this.tallerFisico,
      domicilio: domicilio ?? this.domicilio,
      puntoEstrategico: puntoEstrategico ?? this.puntoEstrategico,
      recogidaEntrega: recogidaEntrega ?? this.recogidaEntrega,
      suscripcion: suscripcion ?? this.suscripcion,
      flotas: flotas ?? this.flotas,
      hibrido: hibrido ?? this.hibrido,
    );
  }
}
