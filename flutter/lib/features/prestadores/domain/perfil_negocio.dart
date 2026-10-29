/// Modelo del bloque `perfil_negocio` (JSONB del backend).
///
/// Concentra toda la información estructurada del prestador que se
/// consume desde servicios externos: Google Business Profile,
/// Schema.org / JSON-LD, WhatsApp Business, Open Graph y PWA.
///
/// Todos los campos son opcionales para permitir edición progresiva.
library;

/// Dirección postal estructurada (requerida por JSON-LD y GBP).
class DireccionEstructurada {
  const DireccionEstructurada({
    this.calle,
    this.numero,
    this.unidad,
    this.comuna,
    this.region,
    this.pais = 'CL',
    this.codigoPostal,
    this.referencia,
  });

  final String? calle;
  final String? numero;
  final String? unidad;
  final String? comuna;
  final String? region;
  final String pais;
  final String? codigoPostal;
  final String? referencia;

  factory DireccionEstructurada.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const DireccionEstructurada();
    return DireccionEstructurada(
      calle: json['calle'] as String?,
      numero: json['numero'] as String?,
      unidad: json['unidad'] as String?,
      comuna: json['comuna'] as String?,
      region: json['region'] as String?,
      pais: (json['pais'] as String?) ?? 'CL',
      codigoPostal: json['codigo_postal'] as String?,
      referencia: json['referencia'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    if (calle != null) 'calle': calle,
    if (numero != null) 'numero': numero,
    if (unidad != null) 'unidad': unidad,
    if (comuna != null) 'comuna': comuna,
    if (region != null) 'region': region,
    'pais': pais,
    if (codigoPostal != null) 'codigo_postal': codigoPostal,
    if (referencia != null) 'referencia': referencia,
  };
}

/// Coordenadas geográficas.
class Coordenadas {
  const Coordenadas({required this.lat, required this.lng});

  final double lat;
  final double lng;

  factory Coordenadas.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const Coordenadas(lat: 0, lng: 0);
    return Coordenadas(
      lat: (json['lat'] as num?)?.toDouble() ?? 0,
      lng: (json['lng'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {'lat': lat, 'lng': lng};

  bool get isValid => lat != 0 || lng != 0;
}

/// Rango horario de un día.
class HorarioRango {
  const HorarioRango({required this.abre, required this.cierra});

  final String abre;
  final String cierra;

  factory HorarioRango.fromJson(Map<String, dynamic> json) => HorarioRango(
    abre: json['abre'] as String? ?? '00:00',
    cierra: json['cierra'] as String? ?? '00:00',
  );

  Map<String, dynamic> toJson() => {'abre': abre, 'cierra': cierra};
}

/// Horario semanal estructurado por día.
class HorarioSemanal {
  const HorarioSemanal({
    this.lunes = const [],
    this.martes = const [],
    this.miercoles = const [],
    this.jueves = const [],
    this.viernes = const [],
    this.sabado = const [],
    this.domingo = const [],
  });

  final List<HorarioRango> lunes;
  final List<HorarioRango> martes;
  final List<HorarioRango> miercoles;
  final List<HorarioRango> jueves;
  final List<HorarioRango> viernes;
  final List<HorarioRango> sabado;
  final List<HorarioRango> domingo;

  factory HorarioSemanal.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const HorarioSemanal();
    List<HorarioRango> parseDia(String key) {
      final raw = json[key];
      if (raw is! List) return const [];
      return raw
          .whereType<Map<String, dynamic>>()
          .map(HorarioRango.fromJson)
          .toList();
    }

    return HorarioSemanal(
      lunes: parseDia('lunes'),
      martes: parseDia('martes'),
      miercoles: parseDia('miercoles'),
      jueves: parseDia('jueves'),
      viernes: parseDia('viernes'),
      sabado: parseDia('sabado'),
      domingo: parseDia('domingo'),
    );
  }

  Map<String, dynamic> toJson() => {
    'lunes': lunes.map((r) => r.toJson()).toList(),
    'martes': martes.map((r) => r.toJson()).toList(),
    'miercoles': miercoles.map((r) => r.toJson()).toList(),
    'jueves': jueves.map((r) => r.toJson()).toList(),
    'viernes': viernes.map((r) => r.toJson()).toList(),
    'sabado': sabado.map((r) => r.toJson()).toList(),
    'domingo': domingo.map((r) => r.toJson()).toList(),
  };

  bool get isEmpty =>
      lunes.isEmpty &&
      martes.isEmpty &&
      miercoles.isEmpty &&
      jueves.isEmpty &&
      viernes.isEmpty &&
      sabado.isEmpty &&
      domingo.isEmpty;
}

/// Categorías GBP (principal + secundarias).
class CategoriasGbp {
  const CategoriasGbp({this.principal, this.secundarias = const []});

  final String? principal;
  final List<String> secundarias;

  factory CategoriasGbp.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const CategoriasGbp();
    final sec = json['secundarias'];
    return CategoriasGbp(
      principal: json['principal'] as String?,
      secundarias: (sec is List) ? sec.whereType<String>().toList() : const [],
    );
  }

  Map<String, dynamic> toJson() => {
    if (principal != null) 'principal': principal,
    'secundarias': secundarias,
  };
}

/// Métodos de pago y monedas aceptadas.
class PagosConfig {
  const PagosConfig({this.metodos = const [], this.monedas = const ['CLP']});

  final List<String> metodos;
  final List<String> monedas;

  factory PagosConfig.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const PagosConfig();
    final met = json['metodos'];
    final mon = json['monedas'];
    return PagosConfig(
      metodos: (met is List) ? met.whereType<String>().toList() : const [],
      monedas: (mon is List) ? mon.whereType<String>().toList() : const ['CLP'],
    );
  }

  Map<String, dynamic> toJson() => {'metodos': metodos, 'monedas': monedas};
}

/// Atributos GBP agrupados por categoría.
class AtributosGbp {
  const AtributosGbp({
    this.pagos = const [],
    this.servicios = const [],
    this.accesibilidad = const [],
    this.comodidades = const [],
    this.planificacion = const [],
  });

  final List<String> pagos;
  final List<String> servicios;
  final List<String> accesibilidad;
  final List<String> comodidades;
  final List<String> planificacion;

  factory AtributosGbp.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const AtributosGbp();
    List<String> parse(String k) {
      final raw = json[k];
      return (raw is List) ? raw.whereType<String>().toList() : const [];
    }

    return AtributosGbp(
      pagos: parse('pagos'),
      servicios: parse('servicios'),
      accesibilidad: parse('accesibilidad'),
      comodidades: parse('comodidades'),
      planificacion: parse('planificacion'),
    );
  }

  Map<String, dynamic> toJson() => {
    'pagos': pagos,
    'servicios': servicios,
    'accesibilidad': accesibilidad,
    'comodidades': comodidades,
    'planificacion': planificacion,
  };
}

/// Área geográfica de cobertura.
class AreaServicio {
  const AreaServicio({
    this.radioKm,
    this.regiones = const [],
    this.ciudades = const [],
  });

  final double? radioKm;
  final List<String> regiones;
  final List<String> ciudades;

  factory AreaServicio.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const AreaServicio();
    List<String> parse(String k) {
      final raw = json[k];
      return (raw is List) ? raw.whereType<String>().toList() : const [];
    }

    return AreaServicio(
      radioKm: (json['radio_km'] as num?)?.toDouble(),
      regiones: parse('regiones'),
      ciudades: parse('ciudades'),
    );
  }

  Map<String, dynamic> toJson() => {
    if (radioKm != null) 'radio_km': radioKm,
    'regiones': regiones,
    'ciudades': ciudades,
  };
}

/// Redes sociales y directorios externos.
class RedesSocialesPerfil {
  const RedesSocialesPerfil({
    this.instagram,
    this.facebook,
    this.tiktok,
    this.youtube,
    this.googleBusiness,
    this.tripadvisor,
  });

  final String? instagram;
  final String? facebook;
  final String? tiktok;
  final String? youtube;
  final String? googleBusiness;
  final String? tripadvisor;

  factory RedesSocialesPerfil.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const RedesSocialesPerfil();
    return RedesSocialesPerfil(
      instagram: json['instagram'] as String?,
      facebook: json['facebook'] as String?,
      tiktok: json['tiktok'] as String?,
      youtube: json['youtube'] as String?,
      googleBusiness: json['google_business'] as String?,
      tripadvisor: json['tripadvisor'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    if (instagram != null) 'instagram': instagram,
    if (facebook != null) 'facebook': facebook,
    if (tiktok != null) 'tiktok': tiktok,
    if (youtube != null) 'youtube': youtube,
    if (googleBusiness != null) 'google_business': googleBusiness,
    if (tripadvisor != null) 'tripadvisor': tripadvisor,
  };
}

/// Descripciones en distintos formatos (según destino).
class DescripcionesNegocio {
  const DescripcionesNegocio({this.corta, this.gbp, this.larga});

  /// ≤155 chars (meta description, WhatsApp).
  final String? corta;

  /// ≤750 chars (Google Business Profile).
  final String? gbp;

  /// Texto largo (página web).
  final String? larga;

  factory DescripcionesNegocio.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const DescripcionesNegocio();
    return DescripcionesNegocio(
      corta: json['corta'] as String?,
      gbp: json['gbp'] as String?,
      larga: json['larga'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    if (corta != null) 'corta': corta,
    if (gbp != null) 'gbp': gbp,
    if (larga != null) 'larga': larga,
  };
}

/// Foto de galería con metadatos.
class FotoNegocio {
  const FotoNegocio({required this.url, this.tipo, this.alt});

  final String url;
  final String? tipo;
  final String? alt;

  factory FotoNegocio.fromJson(Map<String, dynamic> json) => FotoNegocio(
    url: json['url'] as String? ?? '',
    tipo: json['tipo'] as String?,
    alt: json['alt'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'url': url,
    if (tipo != null) 'tipo': tipo,
    if (alt != null) 'alt': alt,
  };
}

/// Fotos del negocio (logo, portada, galería).
class FotosNegocio {
  const FotosNegocio({this.logo512, this.portada, this.galeria = const []});

  final String? logo512;
  final String? portada;
  final List<FotoNegocio> galeria;

  factory FotosNegocio.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const FotosNegocio();
    final raw = json['galeria'];
    return FotosNegocio(
      logo512: json['logo_512'] as String?,
      portada: json['portada'] as String?,
      galeria: (raw is List)
          ? raw
                .whereType<Map<String, dynamic>>()
                .map(FotoNegocio.fromJson)
                .toList()
          : const [],
    );
  }

  Map<String, dynamic> toJson() => {
    if (logo512 != null) 'logo_512': logo512,
    if (portada != null) 'portada': portada,
    'galeria': galeria.map((f) => f.toJson()).toList(),
  };
}

/// Configuración de reservas (booking, mensajería).
class ReservaConfig {
  const ReservaConfig({
    this.bookingUrl,
    this.mensajeriaHabilitada = false,
    this.tiempoRespuestaHoras,
  });

  final String? bookingUrl;
  final bool mensajeriaHabilitada;
  final int? tiempoRespuestaHoras;

  factory ReservaConfig.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const ReservaConfig();
    return ReservaConfig(
      bookingUrl: json['booking_url'] as String?,
      mensajeriaHabilitada: (json['mensajeria_habilitada'] as bool?) ?? false,
      tiempoRespuestaHoras: (json['tiempo_respuesta_horas'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
    if (bookingUrl != null) 'booking_url': bookingUrl,
    'mensajeria_habilitada': mensajeriaHabilitada,
    if (tiempoRespuestaHoras != null)
      'tiempo_respuesta_horas': tiempoRespuestaHoras,
  };
}

/// Bloque completo `perfil_negocio` del prestador.
///
/// Es la fuente de verdad que consumen GBP, JSON-LD, WhatsApp,
/// Open Graph y PWA. Todos los campos son opcionales.
class PerfilNegocio {
  const PerfilNegocio({
    this.direccionEstructurada,
    this.coordenadas,
    this.horario,
    this.categoriasGbp,
    this.atributos,
    this.pagos,
    this.precioRango,
    this.areaServicio,
    this.redes,
    this.descripciones,
    this.fotos,
    this.reserva,
    this.verticalAtributos = const {},
  });

  final DireccionEstructurada? direccionEstructurada;
  final Coordenadas? coordenadas;
  final HorarioSemanal? horario;
  final CategoriasGbp? categoriasGbp;
  final AtributosGbp? atributos;
  final PagosConfig? pagos;
  final String? precioRango;
  final AreaServicio? areaServicio;
  final RedesSocialesPerfil? redes;
  final DescripcionesNegocio? descripciones;
  final FotosNegocio? fotos;
  final ReservaConfig? reserva;
  final Map<String, dynamic> verticalAtributos;

  factory PerfilNegocio.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const PerfilNegocio();
    return PerfilNegocio(
      direccionEstructurada: DireccionEstructurada.fromJson(
        json['direccion_estructurada'] as Map<String, dynamic>?,
      ),
      coordenadas: Coordenadas.fromJson(
        json['coordenadas'] as Map<String, dynamic>?,
      ),
      horario: HorarioSemanal.fromJson(
        json['horario'] as Map<String, dynamic>?,
      ),
      categoriasGbp: CategoriasGbp.fromJson(
        json['categorias_gbp'] as Map<String, dynamic>?,
      ),
      atributos: AtributosGbp.fromJson(
        json['atributos_gbp'] as Map<String, dynamic>?,
      ),
      pagos: PagosConfig.fromJson(json['pagos'] as Map<String, dynamic>?),
      precioRango: json['precio_rango'] as String?,
      areaServicio: AreaServicio.fromJson(
        json['area_servicio'] as Map<String, dynamic>?,
      ),
      redes: RedesSocialesPerfil.fromJson(
        json['redes'] as Map<String, dynamic>?,
      ),
      descripciones: DescripcionesNegocio.fromJson(
        json['descripciones'] as Map<String, dynamic>?,
      ),
      fotos: FotosNegocio.fromJson(json['fotos'] as Map<String, dynamic>?),
      reserva: ReservaConfig.fromJson(json['reserva'] as Map<String, dynamic>?),
      verticalAtributos:
          (json['vertical_atributos'] as Map<String, dynamic>?) ?? const {},
    );
  }

  Map<String, dynamic> toJson() => {
    if (direccionEstructurada != null)
      'direccion_estructurada': direccionEstructurada!.toJson(),
    if (coordenadas != null) 'coordenadas': coordenadas!.toJson(),
    if (horario != null) 'horario': horario!.toJson(),
    if (categoriasGbp != null) 'categorias_gbp': categoriasGbp!.toJson(),
    if (atributos != null) 'atributos_gbp': atributos!.toJson(),
    if (pagos != null) 'pagos': pagos!.toJson(),
    if (precioRango != null) 'precio_rango': precioRango,
    if (areaServicio != null) 'area_servicio': areaServicio!.toJson(),
    if (redes != null) 'redes': redes!.toJson(),
    if (descripciones != null) 'descripciones': descripciones!.toJson(),
    if (fotos != null) 'fotos': fotos!.toJson(),
    if (reserva != null) 'reserva': reserva!.toJson(),
    if (verticalAtributos.isNotEmpty) 'vertical_atributos': verticalAtributos,
  };

  /// true si hay al menos un campo cargado (para saber si hay perfil).
  bool get hasData =>
      direccionEstructurada != null ||
      coordenadas != null ||
      horario != null ||
      categoriasGbp != null ||
      atributos != null ||
      pagos != null ||
      precioRango != null ||
      areaServicio != null ||
      redes != null ||
      descripciones != null ||
      fotos != null ||
      reserva != null;
}
