/// Visitas de un día específico.
library;

class VisitaDia {
  const VisitaDia({
    required this.date,
    required this.visits,
    required this.pageviews,
  });

  final DateTime date;
  final int visits;
  final int pageviews;

  factory VisitaDia.fromJson(Map<String, dynamic> json) {
    return VisitaDia(
      date: DateTime.parse(json['date'] as String),
      visits: json['visits'] as int? ?? 0,
      pageviews: json['pageviews'] as int? ?? 0,
    );
  }
}
