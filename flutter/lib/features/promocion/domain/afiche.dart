/// Modelos del modulo promocion (afiches SVG).
library;

/// Metadata de una plantilla (para la galeria).
class PlantillaInfo {
  const PlantillaInfo({
    required this.id,
    required this.nombre,
    required this.descripcion,
    required this.paramsRequeridos,
    required this.paramsOpcionales,
  });

  final String id;
  final String nombre;
  final String descripcion;
  final List<String> paramsRequeridos;
  final List<String> paramsOpcionales;

  factory PlantillaInfo.fromJson(Map<String, dynamic> json) {
    return PlantillaInfo(
      id: json['id'] as String,
      nombre: json['nombre'] as String,
      descripcion: json['descripcion'] as String,
      paramsRequeridos: (json['params_requeridos'] as List)
          .map((e) => e as String)
          .toList(),
      paramsOpcionales: (json['params_opcionales'] as List)
          .map((e) => e as String)
          .toList(),
    );
  }

  /// Todos los parametros (requeridos + opcionales).
  List<String> get todosLosParams =>
      [...paramsRequeridos, ...paramsOpcionales];
}

/// Tamanos de afiche soportados.
enum TamanoAfiche {
  igFeed('ig_feed', 'IG Feed', '1080?1350', '4:5'),
  igStory('ig_story', 'IG Story', '1080?1920', '9:16'),
  igCuadrado('ig_cuadrado', 'Cuadrado', '1080?1080', '1:1'),
  fbFeed('fb_feed', 'FB Feed', '1200?630', '1.91:1'),
  gbpPost('gbp_post', 'Google', '720?720', '1:1');

  const TamanoAfiche(this.id, this.label, this.dimensiones, this.aspecto);
  final String id;
  final String label;
  final String dimensiones;
  final String aspecto;

  static TamanoAfiche fromId(String s) {
    return TamanoAfiche.values.firstWhere(
      (t) => t.id == s,
      orElse: () => TamanoAfiche.igFeed,
    );
  }
}

/// Resultado de generar un afiche.
class AficheGenerado {
  const AficheGenerado({
    required this.svg,
    required this.plantilla,
    required this.tamano,
    required this.width,
    required this.height,
  });

  final String svg;
  final String plantilla;
  final String tamano;
  final int width;
  final int height;

  /// Aspect ratio (para el preview).
  double get aspecto => width / height;

  factory AficheGenerado.fromJson(Map<String, dynamic> json) {
    return AficheGenerado(
      svg: json['svg'] as String,
      plantilla: json['plantilla'] as String,
      tamano: json['tamano'] as String,
      width: (json['width'] as num).toInt(),
      height: (json['height'] as num).toInt(),
    );
  }
}

/// Labels human-friendly para los parametros.
const Map<String, String> kParamLabels = {
  'prestador': 'Nombre del prestador',
  'servicio': 'Nombre del servicio',
  'titulo': 'Titulo',
  'categoria': 'Categoria',
  'descripcion': 'Descripcion',
  'precio_desde': 'Precio desde (CLP)',
  'descuento': 'Descuento (%)',
  'fecha_limite': 'Fecha limite',
  'codigo': 'Codigo de descuento',
  'especialidades': 'Especialidades',
  'anios_experiencia': 'A?os de experiencia',
  'comuna': 'Comuna',
  'frase': 'Frase',
  'fecha': 'Fecha',
  'hora': 'Hora',
  'ubicacion': 'Ubicacion',
  'organizador': 'Organizador',
  'oficio': 'Oficio',
  'telefono': 'Telefono',
};

/// Placeholder (ejemplo) para cada parametro, util en el editor.
const Map<String, String> kParamPlaceholders = {
  'prestador': 'Taller Mecanico del Sur',
  'servicio': 'Cambio de aceite',
  'titulo': 'Cambio de aceite',
  'categoria': 'Mecanica automotriz',
  'descripcion': 'Servicio rapido y con garantia',
  'precio_desde': '25000',
  'descuento': '30',
  'fecha_limite': 'Hasta el 31 de octubre',
  'codigo': 'BAQUEANO30',
  'especialidades': 'Frenos, Motor, Suspension',
  'anios_experiencia': '15',
  'comuna': 'Puerto Natales',
  'frase': 'Confia en quien sabe',
  'fecha': 'Sabado 2 de noviembre',
  'hora': '19:00 hrs',
  'ubicacion': 'Plaza principal',
  'organizador': 'Baqueano Natales',
  'oficio': 'Mecanico',
  'telefono': '+56 9 1234 5678',
};
