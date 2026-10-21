/// Segmento de destinatarios para una notificacion admin.
library;

/// Tipo de segmento: todos los usuarios, por rol, o lista explicita.
enum TipoSegmento {
  todos('todos'),
  rol('rol'),
  usuarios('usuarios');

  const TipoSegmento(this.value);
  final String value;

  static TipoSegmento fromValue(String v) {
    return TipoSegmento.values.firstWhere(
      (e) => e.value == v,
      orElse: () => TipoSegmento.todos,
    );
  }
}

/// Segmento de destinatarios.
///
/// - `todos`: valor null.
/// - `rol`: valor = "cliente" | "prestador" | "admin" | "comercio".
/// - `usuarios`: valor = lista de UUIDs como strings.
class Segmento {
  const Segmento({required this.tipo, this.valor});

  final TipoSegmento tipo;
  final dynamic valor; // String (rol) o List<String> (usuarios) o null

  const Segmento.todos() : tipo = TipoSegmento.todos, valor = null;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{'tipo': tipo.value};
    if (valor != null) {
      map['valor'] = valor;
    }
    return map;
  }
}
