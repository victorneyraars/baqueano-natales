/// Modelo de foto de trabajo.
///
/// Coincide con la respuesta del backend (FotoTrabajoResponse).
/// Forma parte de la galería de un prestador.
library;

class FotoTrabajo {
  const FotoTrabajo({
    required this.id,
    required this.prestadorId,
    required this.url,
    this.descripcion,
    required this.orden,
  });

  final String id; // UUID
  final String prestadorId; // UUID
  final String url;
  final String? descripcion;
  final int orden;

  factory FotoTrabajo.fromJson(Map<String, dynamic> json) {
    return FotoTrabajo(
      id: json['id'] as String,
      prestadorId: json['prestador_id'] as String,
      url: json['url'] as String,
      descripcion: json['descripcion'] as String?,
      orden: (json['orden'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'prestador_id': prestadorId,
      'url': url,
      'descripcion': descripcion,
      'orden': orden,
    };
  }

  @override
  String toString() => 'FotoTrabajo($url)';
}