/// Modelos de reviews (calificaciones cliente -> prestador).
library;

class Review {
  const Review({
    required this.id,
    required this.prestadorId,
    required this.clienteId,
    required this.ordenId,
    required this.rating,
    required this.activo,
    required this.createdAt,
    this.comentario,
    this.respuestaPrestador,
    this.respuestaEn,
  });

  final String id;
  final String prestadorId;
  final String clienteId;
  final String ordenId;
  final int rating;
  final String? comentario;
  final String? respuestaPrestador;
  final DateTime? respuestaEn;
  final bool activo;
  final DateTime createdAt;

  bool get tieneRespuesta =>
      respuestaPrestador != null && respuestaPrestador!.isNotEmpty;

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      id: json['id'] as String,
      prestadorId: json['prestador_id'] as String,
      clienteId: json['cliente_id'] as String,
      ordenId: json['orden_id'] as String,
      rating: (json['rating'] as num).toInt(),
      comentario: json['comentario'] as String?,
      respuestaPrestador: json['respuesta_prestador'] as String?,
      respuestaEn: json['respuesta_en'] != null
          ? DateTime.parse(json['respuesta_en'] as String).toLocal()
          : null,
      activo: json['activo'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    );
  }
}

class ReviewItem {
  const ReviewItem({
    required this.id,
    required this.rating,
    required this.createdAt,
    this.clienteNombre,
    this.comentario,
    this.respuestaPrestador,
    this.respuestaEn,
  });

  final String id;
  final String? clienteNombre;
  final int rating;
  final String? comentario;
  final String? respuestaPrestador;
  final DateTime? respuestaEn;
  final DateTime createdAt;

  bool get tieneRespuesta =>
      respuestaPrestador != null && respuestaPrestador!.isNotEmpty;

  factory ReviewItem.fromJson(Map<String, dynamic> json) {
    return ReviewItem(
      id: json['id'] as String,
      clienteNombre: json['cliente_nombre'] as String?,
      rating: (json['rating'] as num).toInt(),
      comentario: json['comentario'] as String?,
      respuestaPrestador: json['respuesta_prestador'] as String?,
      respuestaEn: json['respuesta_en'] != null
          ? DateTime.parse(json['respuesta_en'] as String).toLocal()
          : null,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    );
  }
}

class ReviewListResponse {
  const ReviewListResponse({
    required this.items,
    required this.total,
    required this.promedio,
    required this.page,
    required this.pageSize,
  });

  final List<ReviewItem> items;
  final int total;
  final double promedio;
  final int page;
  final int pageSize;

  factory ReviewListResponse.fromJson(Map<String, dynamic> json) {
    return ReviewListResponse(
      items: (json['items'] as List<dynamic>? ?? [])
          .map((x) => ReviewItem.fromJson(x as Map<String, dynamic>))
          .toList(),
      total: (json['total'] as num?)?.toInt() ?? 0,
      promedio: (json['promedio'] as num?)?.toDouble() ?? 0.0,
      page: (json['page'] as num?)?.toInt() ?? 1,
      pageSize: (json['page_size'] as num?)?.toInt() ?? 20,
    );
  }
}
