class MediaAsset {
  const MediaAsset({
    required this.id,
    required this.turnoId,
    required this.prestadorId,
    required this.tipo,
    required this.fase,
    required this.objectKey,
    required this.estado,
    this.createdAt,
  });

  final String id;
  final String turnoId;
  final String prestadorId;
  final String tipo;
  final String fase;
  final String objectKey;
  final String estado;
  final DateTime? createdAt;

  factory MediaAsset.fromJson(Map<String, dynamic> json) {
    return MediaAsset(
      id: json['id'] as String,
      turnoId: json['turno_id'] as String,
      prestadorId: json['prestador_id'] as String,
      tipo: json['tipo'] as String,
      fase: json['fase'] as String,
      objectKey: json['object_key'] as String,
      estado: json['estado'] as String,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }

  /// URL pública (asumiendo que R2_PUBLIC_URL está configurado)
  String get publicUrl => 'https://pub-xxxx.r2.dev/$objectKey';
}
