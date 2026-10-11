/// Modelo de publicacion en la cola de redes sociales.
///
/// Refleja el schema `PublicacionSocialResponse` del backend.
library;

import 'package:baqueano_natales/features/social/domain/cuenta_social.dart';

/// Estados posibles de una publicacion en la cola.
enum EstadoPublicacion {
  pendiente('pendiente'),
  publicando('publicando'),
  publicado('publicado'),
  fallado('fallado'),
  agotado('agotado');

  const EstadoPublicacion(this.value);
  final String value;

  static EstadoPublicacion fromString(String s) {
    return EstadoPublicacion.values.firstWhere(
      (e) => e.value == s,
      orElse: () => EstadoPublicacion.pendiente,
    );
  }

  String get label {
    switch (this) {
      case EstadoPublicacion.pendiente:
        return 'Pendiente';
      case EstadoPublicacion.publicando:
        return 'Publicando';
      case EstadoPublicacion.publicado:
        return 'Publicado';
      case EstadoPublicacion.fallado:
        return 'Fallado';
      case EstadoPublicacion.agotado:
        return 'Agotado';
    }
  }

  /// Color de UI (ARGB). Coincide con el theme.
  int get colorValue {
    switch (this) {
      case EstadoPublicacion.pendiente:
        return 0xFFF59E0B; // amber
      case EstadoPublicacion.publicando:
        return 0xFF3B82F6; // blue
      case EstadoPublicacion.publicado:
        return 0xFF10B981; // green
      case EstadoPublicacion.fallado:
        return 0xFFEF4444; // red
      case EstadoPublicacion.agotado:
        return 0xFF6B7280; // gray
    }
  }
}

/// Publicacion en la cola de redes.
class PublicacionSocial {
  const PublicacionSocial({
    required this.id,
    required this.cuentaId,
    required this.recursoTipo,
    required this.recursoId,
    required this.red,
    required this.contenido,
    required this.estado,
    required this.intentos,
    required this.proximoIntentoEn,
    required this.externalPostId,
    required this.errorUltimo,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String cuentaId;
  final String recursoTipo;
  final String recursoId;
  final RedSocial red;
  final Map<String, dynamic> contenido;
  final EstadoPublicacion estado;
  final int intentos;
  final DateTime? proximoIntentoEn;
  final String? externalPostId;
  final String? errorUltimo;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Mensaje corto del contenido (o placeholder).
  String get mensajePreview {
    final m = contenido['message'] as String?;
    if (m == null || m.isEmpty) return '(sin mensaje)';
    return m.length > 100 ? '${m.substring(0, 100)}...' : m;
  }

  /// ¿Tiene imagen?
  bool get tieneImagen {
    final urls = contenido['image_urls'];
    return urls is List && urls.isNotEmpty;
  }

  factory PublicacionSocial.fromJson(Map<String, dynamic> json) {
    return PublicacionSocial(
      id: json['id'] as String,
      cuentaId: json['cuenta_id'] as String,
      recursoTipo: json['recurso_tipo'] as String,
      recursoId: json['recurso_id'] as String,
      red: RedSocial.fromString(json['red'] as String),
      contenido: (json['contenido'] as Map).cast<String, dynamic>(),
      estado: EstadoPublicacion.fromString(json['estado'] as String),
      intentos: (json['intentos'] as num?)?.toInt() ?? 0,
      proximoIntentoEn: json['proximo_intento_en'] != null
          ? DateTime.parse(json['proximo_intento_en'] as String)
          : null,
      externalPostId: json['external_post_id'] as String?,
      errorUltimo: json['error_ultimo'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}
