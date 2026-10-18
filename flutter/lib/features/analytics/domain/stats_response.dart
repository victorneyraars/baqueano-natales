/// Modelo principal de la respuesta del endpoint /analytics/stats.
///
/// Endpoint backend:
///   GET /api/v1/analytics/stats?days=N&hostname=X
///   GET /api/v1/analytics/mi-prestador/stats?days=N
library;

import 'visita_dia.dart';
import 'top_item.dart';

class StatsResponse {
  const StatsResponse({
    required this.periodDays,
    required this.hostname,
    required this.totalVisits,
    required this.totalPageviews,
    required this.byDay,
    required this.topCountries,
    required this.topReferrers,
    required this.topPages,
  });

  final int periodDays;
  final String? hostname;
  final int totalVisits;
  final int totalPageviews;
  final List<VisitaDia> byDay;
  final List<TopItem> topCountries;
  final List<TopItem> topReferrers;
  final List<TopItem> topPages;

  factory StatsResponse.fromJson(Map<String, dynamic> json) {
    return StatsResponse(
      periodDays: json['period_days'] as int? ?? 7,
      hostname: json['hostname'] as String?,
      totalVisits: json['total_visits'] as int? ?? 0,
      totalPageviews: json['total_pageviews'] as int? ?? 0,
      byDay: (json['by_day'] as List<dynamic>? ?? [])
          .map((e) => VisitaDia.fromJson(e as Map<String, dynamic>))
          .toList(),
      topCountries: (json['top_countries'] as List<dynamic>? ?? [])
          .map((e) => TopItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      topReferrers: (json['top_referrers'] as List<dynamic>? ?? [])
          .map((e) => TopItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      topPages: (json['top_pages'] as List<dynamic>? ?? [])
          .map((e) => TopItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
