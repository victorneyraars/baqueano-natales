class MediaAsset {
  const MediaAsset({
    required this.id,
    required this.entidadTipo,
    required this.entidadId,
    required this.tipo,
    required this.fase,
    required this.storageKey,
    required this.urlPublica,
    required this.estadoModeracion,
    this.descripcion,
    this.visiblePublico = false,
    this.createdAt,
  });

  final String id;
  final String entidadTipo;
  final String entidadId;
  final String tipo;
  final String fase;
  final String storageKey;
  final String urlPublica;
  final String estadoModeracion;
  final String? descripcion;
  final bool visiblePublico;
  final DateTime? createdAt;

  factory MediaAsset.fromJson(Map<String, dynamic> json) {
    return MediaAsset(
      id: json['id'] as String,
      entidadTipo: json['entidad_tipo'] as String? ?? 'turno',
      entidadId: json['entidad_id'] as String,
      tipo: json['tipo'] as String,
      fase: json['fase'] as String,
      storageKey: json['storage_key'] as String,
      urlPublica: json['url_publica'] as String? ?? '',
      estadoModeracion: json['estado_moderacion'] as String? ?? 'pendiente',
      descripcion: json['descripcion'] as String?,
      visiblePublico: json['visible_publico'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }

  String get faseLabel {
    const labels = {
      'ingreso': 'Ingreso',
      'diagnostico': 'Diagnóstico',
      'en_proceso': 'En proceso',
      'entrega': 'Entrega',
      'reclamo': 'Reclamo',
      'otro': 'Otro',
    };
    return labels[fase] ?? fase;
  }
}
