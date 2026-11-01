/// Modelo de entrada del audit log (append-only).
///
/// Cada acción del owner o sus colaboradores queda registrada con:
/// quién, qué, cuándo, entidad afectada y metadata (antes/después).
library;

class AuditLogEntry {
  final String id;
  final String userEmail;
  final String accion;
  final String entidad;
  final String? entidadId;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;

  const AuditLogEntry({
    required this.id,
    required this.userEmail,
    required this.accion,
    required this.entidad,
    this.entidadId,
    this.metadata = const {},
    required this.createdAt,
  });

  factory AuditLogEntry.fromJson(Map<String, dynamic> json) {
    return AuditLogEntry(
      id: json['id'] as String? ?? '',
      userEmail: json['user_email'] as String? ?? '',
      accion: json['accion'] as String? ?? '',
      entidad: json['entidad'] as String? ?? '',
      entidadId: json['entidad_id'] as String?,
      metadata: (json['metadata'] as Map<String, dynamic>?) ?? const {},
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// Texto legible de la acción para mostrar en la UI.
  String get accionLegible {
    switch (accion) {
      case 'colaborador_invitado':
        return 'Invito a un colaborador';
      case 'colaborador_activado':
        return 'Colaborador acepto la invitacion';
      case 'colaborador_eliminado':
        return 'Elimino un colaborador';
      case 'reserva_confirmada':
        return 'Confirmo una reserva';
      case 'reserva_cancelada':
        return 'Cancelo una reserva';
      default:
        return accion.replaceAll('_', ' ');
    }
  }
}

/// Página paginada del audit log.
class AuditLogPage {
  final List<AuditLogEntry> data;
  final int total;
  final int page;
  final int pageSize;

  const AuditLogPage({
    required this.data,
    required this.total,
    required this.page,
    required this.pageSize,
  });

  factory AuditLogPage.fromJson(Map<String, dynamic> json) {
    return AuditLogPage(
      data: (json['data'] as List<dynamic>? ?? [])
          .map((e) => AuditLogEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: json['total'] as int? ?? 0,
      page: json['page'] as int? ?? 1,
      pageSize: json['page_size'] as int? ?? 50,
    );
  }
}
