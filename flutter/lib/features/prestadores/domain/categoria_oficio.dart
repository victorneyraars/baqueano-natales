/// Modelo de categoría de oficio.
///
/// Coincide con la respuesta del backend (CategoriaOficioResponse).
library;

class CategoriaOficio {
  const CategoriaOficio({
    required this.id,
    required this.nombre,
    required this.slug,
    this.descripcion,
    this.icono,
    this.colorHex,
    required this.orden,
    required this.activo,
  });

  final String id; // UUID
  final String nombre;
  final String slug;
  final String? descripcion;
  final String? icono;
  final String? colorHex;
  final int orden;
  final bool activo;

  factory CategoriaOficio.fromJson(Map<String, dynamic> json) {
    return CategoriaOficio(
      id: json['id'] as String,
      nombre: json['nombre'] as String,
      slug: json['slug'] as String,
      descripcion: json['descripcion'] as String?,
      icono: json['icono'] as String?,
      colorHex: json['color_hex'] as String?,
      orden: (json['orden'] as num?)?.toInt() ?? 0,
      activo: json['activo'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
      'slug': slug,
      'descripcion': descripcion,
      'icono': icono,
      'color_hex': colorHex,
      'orden': orden,
      'activo': activo,
    };
  }

  @override
  String toString() => 'CategoriaOficio($slug)';
}