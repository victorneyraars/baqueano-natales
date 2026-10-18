/// Item genérico para "top" (país, referrer, página).
library;

class TopItem {
  const TopItem({required this.name, required this.count});

  final String name;
  final int count;

  factory TopItem.fromJson(Map<String, dynamic> json) {
    return TopItem(
      name: json['name'] as String? ?? 'Desconocido',
      count: json['count'] as int? ?? 0,
    );
  }
}
