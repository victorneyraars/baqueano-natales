/// Página de Facebook disponible para conectar.
class PaginaFacebook {
  const PaginaFacebook({
    required this.id,
    required this.name,
    this.category,
    this.tasks = const [],
    this.yaConectada = false,
  });

  final String id;
  final String name;
  final String? category;
  final List<String> tasks;
  final bool yaConectada;

  factory PaginaFacebook.fromJson(Map<String, dynamic> json) {
    return PaginaFacebook(
      id: json['id'] as String,
      name: json['name'] as String,
      category: json['category'] as String?,
      tasks:
          (json['tasks'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      yaConectada: json['ya_conectada'] as bool? ?? false,
    );
  }
}
