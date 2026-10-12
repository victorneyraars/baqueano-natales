/// Modelo de una foto de orden de trabajo (M5.1).
///
/// Content-addressable: el `hash_sha256` es el SHA-256 del contenido
/// original. El backend devuelve las URLs de las 3 variantes
/// (`original` / `medium` / `thumb`), que se sirven via endpoint
/// autenticado (`AuthedImage` en el cliente).
library;

enum MomentoFoto {
  ingreso('ingreso', 'Ingreso'),
  diagnostico('diagnostico', 'Diagnostico'),
  enProceso('en_proceso', 'En proceso'),
  entrega('entrega', 'Entrega'),
  reclamo('reclamo', 'Reclamo'),
  otro('otro', 'Otro');

  const MomentoFoto(this.value, this.label);
  final String value;
  final String label;

  static MomentoFoto fromValue(String? v) {
    return MomentoFoto.values.firstWhere(
      (m) => m.value == v,
      orElse: () => MomentoFoto.otro,
    );
  }
}

class FotoVariante {
  const FotoVariante({
    required this.ancho,
    required this.alto,
    required this.tamanoBytes,
    required this.url,
  });

  final int ancho;
  final int alto;
  final int tamanoBytes;
  final String url;

  factory FotoVariante.fromJson(Map<String, dynamic> json) {
    return FotoVariante(
      ancho: json['ancho'] as int? ?? 0,
      alto: json['alto'] as int? ?? 0,
      tamanoBytes: json['tamano_bytes'] as int? ?? 0,
      url: json['url'] as String,
    );
  }
}

class OrdenFoto {
  const OrdenFoto({
    required this.id,
    required this.ordenId,
    required this.momento,
    required this.subidoPorId,
    required this.subidoPorRol,
    required this.hashSha256,
    required this.variantes,
    required this.mimeType,
    required this.tamanoBytes,
    required this.ancho,
    required this.alto,
    required this.activo,
    required this.createdAt,
    this.itemId,
    this.blurhash,
    this.descripcion,
    this.fechaCaptura,
  });

  final String id;
  final String ordenId;
  final String? itemId;
  final MomentoFoto momento;
  final String subidoPorId;
  final String subidoPorRol;
  final String hashSha256;
  final Map<String, FotoVariante> variantes;
  final String mimeType;
  final int tamanoBytes;
  final int ancho;
  final int alto;
  final String? blurhash;
  final String? descripcion;
  final DateTime? fechaCaptura;
  final bool activo;
  final DateTime createdAt;

  /// Devuelve la URL de la variante pedida, o `null` si no existe.
  String? urlVariante(String variante) => variantes[variante]?.url;

  /// URL del thumbnail (con fallback a medium u original).
  String? get urlThumb =>
      urlVariante('thumb') ?? urlVariante('medium') ?? urlVariante('original');

  /// URL de la version medium (con fallback a original).
  String? get urlMedium => urlVariante('medium') ?? urlVariante('original');

  /// URL de la version original.
  String? get urlOriginal => urlVariante('original');

  factory OrdenFoto.fromJson(Map<String, dynamic> json) {
    final rawVariantes = json['variantes'] as Map<String, dynamic>? ?? {};
    final variantes = rawVariantes.map(
      (k, v) => MapEntry(k, FotoVariante.fromJson(v as Map<String, dynamic>)),
    );
    return OrdenFoto(
      id: json['id'] as String,
      ordenId: json['orden_id'] as String,
      itemId: json['item_id'] as String?,
      momento: MomentoFoto.fromValue(json['momento'] as String?),
      subidoPorId: json['subido_por_id'] as String,
      subidoPorRol: json['subido_por_rol'] as String? ?? 'cliente',
      hashSha256: json['hash_sha256'] as String,
      variantes: variantes,
      mimeType: json['mime_type'] as String? ?? 'image/jpeg',
      tamanoBytes: json['tamano_bytes'] as int? ?? 0,
      ancho: json['ancho'] as int? ?? 0,
      alto: json['alto'] as int? ?? 0,
      blurhash: json['blurhash'] as String?,
      descripcion: json['descripcion'] as String?,
      fechaCaptura: json['fecha_captura'] != null
          ? DateTime.parse(json['fecha_captura'] as String).toLocal()
          : null,
      activo: json['activo'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    );
  }
}