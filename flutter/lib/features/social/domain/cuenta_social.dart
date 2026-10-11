/// Modelo de cuenta social conectada (Facebook, Instagram, etc.).
///
/// Refleja el schema `CuentaSocialResponse` del backend.
/// NO incluye tokens (esos viven cifrados y nunca llegan al cliente).
library;

/// Redes soportadas.
enum RedSocial {
  facebook('facebook'),
  instagram('instagram'),
  googleBusiness('google_business');

  const RedSocial(this.value);
  final String value;

  static RedSocial fromString(String s) {
    return RedSocial.values.firstWhere(
      (r) => r.value == s,
      orElse: () => RedSocial.facebook,
    );
  }

  String get label {
    switch (this) {
      case RedSocial.facebook:
        return 'Facebook';
      case RedSocial.instagram:
        return 'Instagram';
      case RedSocial.googleBusiness:
        return 'Google Business';
    }
  }
}

/// Tipo de propietario de una cuenta social.
enum PropietarioTipoSocial {
  baqueano('baqueano'),
  prestador('prestador'),
  comercio('comercio');

  const PropietarioTipoSocial(this.value);
  final String value;

  static PropietarioTipoSocial fromString(String s) {
    return PropietarioTipoSocial.values.firstWhere(
      (p) => p.value == s,
      orElse: () => PropietarioTipoSocial.baqueano,
    );
  }

  String get label {
    switch (this) {
      case PropietarioTipoSocial.baqueano:
        return 'Baqueano (central)';
      case PropietarioTipoSocial.prestador:
        return 'Prestador';
      case PropietarioTipoSocial.comercio:
        return 'Comercio';
    }
  }
}

/// Cuenta conectada a una red social.
class CuentaSocial {
  const CuentaSocial({
    required this.id,
    required this.red,
    required this.externalId,
    required this.externalName,
    required this.propietarioTipo,
    required this.propietarioId,
    required this.cuentaPadreId,
    required this.autoPublish,
    required this.activo,
    required this.metadataExtra,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final RedSocial red;
  final String externalId;
  final String? externalName;
  final PropietarioTipoSocial propietarioTipo;
  final String? propietarioId;
  final String? cuentaPadreId;
  final bool autoPublish;
  final bool activo;
  final Map<String, dynamic>? metadataExtra;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Nombre legible: `external_name` si esta, si no el `external_id`.
  String get nombreVisible => externalName?.isNotEmpty == true
      ? externalName!
      : externalId;

  /// Instagram username si esta en `metadata_extra`.
  String? get instagramUsername =>
      metadataExtra?['instagram_username'] as String?;

  factory CuentaSocial.fromJson(Map<String, dynamic> json) {
    return CuentaSocial(
      id: json['id'] as String,
      red: RedSocial.fromString(json['red'] as String),
      externalId: json['external_id'] as String,
      externalName: json['external_name'] as String?,
      propietarioTipo: PropietarioTipoSocial.fromString(
        json['propietario_tipo'] as String,
      ),
      propietarioId: json['propietario_id'] as String?,
      cuentaPadreId: json['cuenta_padre_id'] as String?,
      autoPublish: json['auto_publish'] as bool? ?? false,
      activo: json['activo'] as bool? ?? true,
      metadataExtra: json['metadata_extra'] as Map<String, dynamic>?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}
