/// Modelo de notificacion (vista admin).
library;

class NotificacionAdmin {
  const NotificacionAdmin({
    required this.id,
    this.usuarioId,
    required this.tipo,
    required this.canal,
    required this.titulo,
    required this.body,
    this.data,
    this.analyticsLabel,
    required this.estado,
    this.error,
    required this.creadoEn,
    this.enviadoEn,
    this.abiertoEn,
  });

  final String id;
  final String? usuarioId;
  final String tipo;
  final String canal;
  final String titulo;
  final String body;
  final Map<String, dynamic>? data;
  final String? analyticsLabel;
  final String estado;
  final String? error;
  final DateTime creadoEn;
  final DateTime? enviadoEn;
  final DateTime? abiertoEn;

  factory NotificacionAdmin.fromJson(Map<String, dynamic> json) {
    return NotificacionAdmin(
      id: json['id'] as String,
      usuarioId: json['usuario_id'] as String?,
      tipo: json['tipo'] as String,
      canal: json['canal'] as String,
      titulo: json['titulo'] as String,
      body: json['body'] as String,
      data: json['data'] as Map<String, dynamic>?,
      analyticsLabel: json['analytics_label'] as String?,
      estado: json['estado'] as String,
      error: json['error'] as String?,
      creadoEn: DateTime.parse(json['creado_en'] as String),
      enviadoEn: json['enviado_en'] != null
          ? DateTime.parse(json['enviado_en'] as String)
          : null,
      abiertoEn: json['abierto_en'] != null
          ? DateTime.parse(json['abierto_en'] as String)
          : null,
    );
  }
}
