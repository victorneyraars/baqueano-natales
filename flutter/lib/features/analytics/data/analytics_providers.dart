/// Providers de Riverpod para el módulo Analytics.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:baqueano_natales/features/analytics/data/analytics_repository.dart';
import 'package:baqueano_natales/features/analytics/domain/stats_response.dart';

// =========================================================
// Repositorio
// =========================================================
final analyticsRepositoryProvider = Provider<AnalyticsRepository>((ref) {
  return AnalyticsRepository();
});

// =========================================================
// Filtro de hostname (compartido entre stats admin)
// =========================================================
/// `null` = todos los sitios.
/// `"sealquilamarido.com"` = Se Alquila Marido.
/// `"www.baqueanonatales.com"` = Baqueano.
final hostnameFilterProvider = StateProvider<String?>((ref) => null);

// =========================================================
// Stats del admin (con filtro de hostname)
// =========================================================
final adminStatsProvider = FutureProvider.family<StatsResponse, ({int days, String? hostname})>(
  (ref, params) async {
    final repo = ref.watch(analyticsRepositoryProvider);
    return repo.fetchStats(days: params.days, hostname: params.hostname);
  },
);

// =========================================================
// Stats del prestador (auto-filtro)
// =========================================================
final myStatsProvider = FutureProvider.family<StatsResponse, int>((ref, days) async {
  final repo = ref.watch(analyticsRepositoryProvider);
  return repo.fetchMyStats(days: days);
});
