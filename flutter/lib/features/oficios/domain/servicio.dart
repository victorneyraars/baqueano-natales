/// Modelo de un servicio del catálogo de un prestador.
///
/// Viene de `GET /api/v1/prestadores/{id}/servicios`.
/// Cada servicio tiene nombre, precio orientativo y duración estimada.
library;

class Servicio {
  const Servicio({
    required this.id,
    required this.nombre,
    this.descripcion,
    this.categoriaServicio,
    this.precioDesdeClp,
    this.precioHastaClp,
    this.duracionEstimadaMin,
    this.garantiaDias,
    this.destacado = false,
  });

  final String id;
  final String nombre;
  final String? descripcion;
  final String? categoriaServicio;
  final int? precioDesdeClp;
  final int? precioHastaClp;
  final int? duracionEstimadaMin;
  final int? garantiaDias;
  final bool destacado;

  factory Servicio.fromJson(Map<String, dynamic> json) {
    return Servicio(
      id: json['id']?.toString() ?? '',
      nombre: json['nombre']?.toString() ?? '',
      descripcion: json['descripcion']?.toString(),
      categoriaServicio: json['categoria_servicio']?.toString(),
      precioDesdeClp: json['precio_desde_clp'] as int?,
      precioHastaClp: json['precio_hasta_clp'] as int?,
      duracionEstimadaMin: json['duracion_estimada_min'] as int?,
      garantiaDias: json['garantia_dias'] as int?,
      destacado: json['destacado'] as bool? ?? false,
    );
  }

  /// Precio formateado para mostrar en la UI.
  String get precioLabel {
    if (precioDesdeClp == null && precioHastaClp == null) {
      return 'Consultar precio';
    }
    if (precioDesdeClp != null && precioHastaClp != null) {
      return '\$${_fmt(precioDesdeClp!)} - \$${_fmt(precioHastaClp!)}';
    }
    return '\$${_fmt(precioDesdeClp ?? precioHastaClp!)}';
  }

  /// Duración formateada (ej: "30 min", "1 h 30 min").
  String get duracionLabel {
    final m = duracionEstimadaMin;
    if (m == null || m == 0) return '';
    if (m < 60) return '$m min';
    final h = m ~/ 60;
    final rem = m % 60;
    return rem == 0 ? '$h h' : '$h h $rem min';
  }

  static String _fmt(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}
