/// Modelo de un servicio ofrecido por un prestador.
///
/// Coincide con la respuesta del backend (PrestadorServicioResponse).
///
/// Estructura industrial:
/// - `nombre` + `descripcion` (qué incluye)
/// - `categoriaServicio` (agrupación visual: Mantenimiento, Frenos...)
/// - `precioDesdeClp` / `precioHastaClp` (rango orientativo)
/// - `duracionEstimadaMin` (transparencia)
/// - `garantiaDias` (sello de confianza)
/// - `destacado` (servicio estrella / hook comercial)
library;

class PrestadorServicio {
  const PrestadorServicio({
    required this.id,
    required this.prestadorId,
    required this.nombre,
    this.descripcion,
    this.categoriaServicio,
    this.precioDesdeClp,
    this.precioHastaClp,
    this.duracionEstimadaMin,
    this.garantiaDias,
    this.destacado = false,
    required this.activo,
    required this.orden,
  });

  final String id;
  final String prestadorId;
  final String nombre;
  final String? descripcion;
  final String? categoriaServicio;
  final int? precioDesdeClp;
  final int? precioHastaClp;
  final int? duracionEstimadaMin;
  final int? garantiaDias;
  final bool destacado;
  final bool activo;
  final int orden;

  // =========================================================
  // Helpers
  // =========================================================

  /// Rango de precio formateado (ej: "$25.000 - $55.000", "$25.000+", "Consultar")
  String get precioLegible {
    if (precioDesdeClp == null && precioHastaClp == null) {
      return 'Consultar';
    }
    if (precioDesdeClp != null && precioHastaClp != null) {
      if (precioDesdeClp == precioHastaClp) {
        return _formatClp(precioDesdeClp!);
      }
      return '${_formatClp(precioDesdeClp!)} - ${_formatClp(precioHastaClp!)}';
    }
    if (precioDesdeClp != null) {
      return 'Desde ${_formatClp(precioDesdeClp!)}';
    }
    return 'Hasta ${_formatClp(precioHastaClp!)}';
  }

  /// Duración legible ("30 min", "1h 30min", "3h").
  String? get duracionLegible {
    final m = duracionEstimadaMin;
    if (m == null || m <= 0) return null;
    if (m < 60) return '$m min';
    final horas = m ~/ 60;
    final mins = m % 60;
    if (mins == 0) return '${horas}h';
    return '${horas}h ${mins}min';
  }

  /// Garantía legible ("30 días", "6 meses", "1 año").
  String? get garantiaLegible {
    final d = garantiaDias;
    if (d == null || d <= 0) return null;
    if (d < 30) return '$d días';
    if (d == 30) return '30 días';
    if (d < 365) {
      final meses = d ~/ 30;
      return meses == 1 ? '1 mes' : '$meses meses';
    }
    final anios = d ~/ 365;
    return anios == 1 ? '1 año' : '$anios años';
  }

  /// Formato CLP: "$25.000"
  static String _formatClp(int valor) {
    final s = valor.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buffer.write('.');
      buffer.write(s[i]);
    }
    return '\$$buffer';
  }

  factory PrestadorServicio.fromJson(Map<String, dynamic> json) {
    return PrestadorServicio(
      id: json['id'] as String,
      prestadorId: json['prestador_id'] as String,
      nombre: json['nombre'] as String,
      descripcion: json['descripcion'] as String?,
      categoriaServicio: json['categoria_servicio'] as String?,
      precioDesdeClp: (json['precio_desde_clp'] as num?)?.toInt(),
      precioHastaClp: (json['precio_hasta_clp'] as num?)?.toInt(),
      duracionEstimadaMin: (json['duracion_estimada_min'] as num?)?.toInt(),
      garantiaDias: (json['garantia_dias'] as num?)?.toInt(),
      destacado: json['destacado'] as bool? ?? false,
      activo: json['activo'] as bool? ?? true,
      orden: (json['orden'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'prestador_id': prestadorId,
      'nombre': nombre,
      'descripcion': descripcion,
      'categoria_servicio': categoriaServicio,
      'precio_desde_clp': precioDesdeClp,
      'precio_hasta_clp': precioHastaClp,
      'duracion_estimada_min': duracionEstimadaMin,
      'garantia_dias': garantiaDias,
      'destacado': destacado,
      'activo': activo,
      'orden': orden,
    };
  }

  @override
  String toString() => 'PrestadorServicio($nombre)';
}