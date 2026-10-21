/// Modelo del usuario autenticado.
///
/// Coincide con la respuesta del backend (UsuarioMeResponse).
library;

class User {
  const User({
    required this.id,
    required this.role,
    this.email,
    this.phone,
    this.nombre,
    this.apellido,
    this.avatarUrl,
    required this.verificado,
    required this.activo,
    required this.tieneGoogle,
    required this.tieneWhatsapp,
    required this.tieneSms,
    required this.createdAt,
    this.ultimoLogin,
  });

  final String id; // UUID
  final String role; // cliente | comercio | prestador | admin
  final String? email;
  final String? phone;
  final String? nombre;
  final String? apellido;
  final String? avatarUrl;
  final bool verificado;
  final bool activo;
  final bool tieneGoogle;
  final bool tieneWhatsapp;
  final bool tieneSms;
  final DateTime createdAt;
  final DateTime? ultimoLogin;

  /// Nombre completo (nombre + apellido) o fallback.
  String get nombreCompleto {
    final parts = [nombre, apellido].where((s) => s != null && s.isNotEmpty);
    return parts.isEmpty ? 'Usuario' : parts.join(' ');
  }

  /// Iniciales para avatar por defecto (ej: "Juan Pérez" → "JP").
  String get iniciales {
    final n = nombre;
    final a = apellido;
    if (n != null && n.isNotEmpty) {
      if (a != null && a.isNotEmpty) {
        return '${n[0]}${a[0]}'.toUpperCase();
      }
      return n[0].toUpperCase();
    }
    return '?';
  }

  /// ¿Es admin?
  bool get isAdmin => role == 'admin';

  /// Crea un User desde JSON del backend.
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      role: json['rol'] as String,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      nombre: json['nombre'] as String?,
      apellido: json['apellido'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      verificado: json['verificado'] as bool? ?? false,
      activo: json['activo'] as bool? ?? true,
      tieneGoogle: json['tiene_google'] as bool? ?? false,
      tieneWhatsapp: json['tiene_whatsapp'] as bool? ?? false,
      tieneSms: json['tiene_sms'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      ultimoLogin: json['ultimo_login'] != null
          ? DateTime.parse(json['ultimo_login'] as String)
          : null,
    );
  }

  /// Convierte el User a JSON.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'rol': role,
      'email': email,
      'phone': phone,
      'nombre': nombre,
      'apellido': apellido,
      'avatar_url': avatarUrl,
      'verificado': verificado,
      'activo': activo,
      'tiene_google': tieneGoogle,
      'tiene_whatsapp': tieneWhatsapp,
      'tiene_sms': tieneSms,
      'created_at': createdAt.toIso8601String(),
      'ultimo_login': ultimoLogin?.toIso8601String(),
    };
  }

  User copyWith({String? nombre, String? apellido, String? avatarUrl}) {
    return User(
      id: id,
      role: role,
      email: email,
      phone: phone,
      nombre: nombre ?? this.nombre,
      apellido: apellido ?? this.apellido,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      verificado: verificado,
      activo: activo,
      tieneGoogle: tieneGoogle,
      tieneWhatsapp: tieneWhatsapp,
      tieneSms: tieneSms,
      createdAt: createdAt,
      ultimoLogin: ultimoLogin,
    );
  }
}
