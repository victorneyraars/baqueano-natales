/// Resultado de busqueda de cliente (para crear ordenes desde el taller).
library;

class ClienteBusqueda {
  const ClienteBusqueda({
    required this.id,
    this.nombre,
    this.apellido,
    this.email,
  });

  final String id;
  final String? nombre;
  final String? apellido;
  final String? email;

  /// Nombre completo para mostrar. Cae a email o ID si no hay nombre.
  String get nombreDisplay {
    final n = [
      nombre,
      apellido,
    ].where((s) => s != null && s.isNotEmpty).join(' ');
    if (n.isNotEmpty) return n;
    if (email != null && email!.isNotEmpty) return email!;
    return id;
  }

  factory ClienteBusqueda.fromJson(Map<String, dynamic> json) {
    return ClienteBusqueda(
      id: json['id'] as String,
      nombre: json['nombre'] as String?,
      apellido: json['apellido'] as String?,
      email: json['email'] as String?,
    );
  }
}
