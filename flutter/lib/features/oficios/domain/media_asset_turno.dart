/// Evidencia (foto/video) asociada a un turno.
///
/// Refleja el schema de `GET /api/v1/mis-turnos/{id}/media`.
class MediaAssetTurno {
  const MediaAssetTurno({
    required this.id,
    required this.tipo,
    required this.fase,
    required this.urlPublica,
    this.descripcion,
    this.createdAt,
  });

  final String id;
  final String tipo; // 'foto' | 'video'
  final String fase;
  final String urlPublica;
  final String? descripcion;
  final DateTime? createdAt;

  bool get esVideo => tipo == 'video';

  String get faseLabel {
    const labels = {
      'ingreso': 'Ingreso',
      'diagnostico': 'Diagnostico',
      'en_proceso': 'En proceso',
      'entrega': 'Entrega',
      'reclamo': 'Reclamo',
      'otro': 'Otro',
    };
    return labels[fase] ?? fase;
  }

  factory MediaAssetTurno.fromJson(Map<String, dynamic> json) {
    return MediaAssetTurno(
      id: json['id'] as String,
      tipo: json['tipo'] as String,
      fase: json['fase'] as String,
      urlPublica: json['url_publica'] as String? ?? '',
      descripcion: json['descripcion'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }
}
