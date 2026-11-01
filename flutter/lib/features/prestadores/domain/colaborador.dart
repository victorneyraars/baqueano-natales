/// Modelo del colaborador de un prestador (JSONB colaboradores).
///
/// El owner del prestador puede invitar a otras personas. Cada colaborador
/// tiene permisos limitados: puede gestionar reservas y vehículos, pero NO
/// puede gestionar colaboradores ni ver el audit log.
library;

class Colaborador {
  final String email;
  final String nombre;
  final String? whatsapp;
  final String invitadoPor;
  final DateTime invitadoAt;
  final DateTime? activadoAt;
  final String rol;

  const Colaborador({
    required this.email,
    required this.nombre,
    this.whatsapp,
    required this.invitadoPor,
    required this.invitadoAt,
    this.activadoAt,
    this.rol = 'colaborador',
  });

  /// true si el colaborador ya aceptó la invitación.
  bool get activo => activadoAt != null;

  factory Colaborador.fromJson(Map<String, dynamic> json) {
    return Colaborador(
      email: json['email'] as String? ?? '',
      nombre: json['nombre'] as String? ?? '',
      whatsapp: json['whatsapp'] as String?,
      invitadoPor: json['invitado_por'] as String? ?? '',
      invitadoAt: DateTime.parse(json['invitado_at'] as String),
      activadoAt: json['activado_at'] != null
          ? DateTime.parse(json['activado_at'] as String)
          : null,
      rol: json['rol'] as String? ?? 'colaborador',
    );
  }
}
