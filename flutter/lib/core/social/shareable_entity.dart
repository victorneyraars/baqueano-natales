/// Tipo de entidad que se puede compartir.
enum ShareEntityType {
  turno('turno', 'Turno'),
  prestador('prestador', 'Prestador'),
  comercio('comercio', 'Comercio'),
  producto('producto', 'Producto'),
  servicio('servicio', 'Servicio'),
  review('review', 'Reseña');

  const ShareEntityType(this.value, this.label);
  final String value;
  final String label;
}

/// Entidad compartible genérica. Sirve para CUALQUIER recurso de la app.
///
/// Uso:
/// ```dart
/// final entity = ShareableEntity(
///   type: ShareEntityType.turno,
///   id: turno.id,
///   title: 'Mi turno en Baqueano Natales',
///   description: 'Mirá cómo quedó mi auto después del servicio',
///   publicUrl: 'https://baqueanonatales.com/turnos/${turno.id}',
/// );
/// ```
class ShareableEntity {
  const ShareableEntity({
    required this.type,
    required this.id,
    required this.title,
    this.subtitle,
    this.description,
    this.imageUrl,
    this.deepLink,
    this.publicUrl,
    this.hashtags = const [],
    this.cta = 'Descubrí más en Baqueano Natales',
  });

  final ShareEntityType type;
  final String id;
  final String title;
  final String? subtitle;
  final String? description;
  final String? imageUrl;
  final String? deepLink;
  final String? publicUrl;
  final List<String> hashtags;
  final String cta;

  /// Texto completo para compartir (con hashtags y CTA).
  String buildFullText() {
    final buffer = StringBuffer();
    buffer.writeln(title);
    if (subtitle != null && subtitle!.isNotEmpty) {
      buffer.writeln(subtitle);
    }
    if (description != null && description!.isNotEmpty) {
      buffer.writeln();
      buffer.writeln(description);
    }
    if (hashtags.isNotEmpty) {
      buffer.writeln();
      buffer.writeln(
        hashtags.map((h) => h.startsWith('#') ? h : '#$h').join(' '),
      );
    }
    buffer.writeln();
    buffer.writeln(cta);
    if (publicUrl != null && publicUrl!.isNotEmpty) {
      buffer.writeln(publicUrl);
    }
    return buffer.toString().trim();
  }

  /// Texto corto para WhatsApp (más conciso, sin hashtags).
  String buildShortText() {
    final buffer = StringBuffer();
    buffer.writeln(title);
    if (description != null && description!.isNotEmpty) {
      buffer.writeln(description);
    }
    if (publicUrl != null && publicUrl!.isNotEmpty) {
      buffer.writeln();
      buffer.writeln(publicUrl);
    }
    return buffer.toString().trim();
  }
}
