/// Modelo de una categoria de servicio de mecanica.
///
/// Catalogo admin-managed. Se usa para agrupar visualmente servicios
/// (Frenos, Motor, etc.) y filtrar.
library;

class MecanicaCategoria {
  const MecanicaCategoria({
    required this.id,
    required this.nombre,
    required this.slug,
    required this.orden,
    required this.activo,
    this.descripcion,
    this.icono,
    this.colorHex,
  });

  final String id;
  final String nombre;
  final String slug;
  final int orden;
  final bool activo;
  final String? descripcion;
  final String? icono;
  final String? colorHex;

  factory MecanicaCategoria.fromJson(Map<String, dynamic> json) {
    return MecanicaCategoria(
      id: json['id'] as String,
      nombre: json['nombre'] as String,
      slug: json['slug'] as String,
      orden: json['orden'] as int? ?? 0,
      activo: json['activo'] as bool? ?? true,
      descripcion: json['descripcion'] as String?,
      icono: json['icono'] as String?,
      colorHex: json['color_hex'] as String?,
    );
  }
}