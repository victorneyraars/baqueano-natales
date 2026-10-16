/// Providers del Ops Dashboard (Riverpod).
///
/// Patron del proyecto: repository provider inyectable + FutureProvider
/// (o FutureProvider.family) por cada endpoint. Los params de family son
/// inmutables (== / hashCode) para que Riverpod cachee correctamente.
///
/// El auto-refresh cada 30s de la pantalla se maneja en la capa de
/// presentacion (Bloque 4c), no aca. Los providers son puros.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:baqueano_natales/features/ops_admin/data/ops_repository.dart';
import 'package:baqueano_natales/features/ops_admin/domain/ops_models.dart';

/// Provider del repositorio (inyectable para tests).
final opsRepositoryProvider = Provider<OpsRepository>((ref) {
  return OpsRepository();
});

// ==================== Health ====================

/// Estado consolidado del sistema.
final opsHealthProvider = FutureProvider<SystemHealth>((ref) async {
  final repo = ref.read(opsRepositoryProvider);
  return repo.health();
});

// ==================== Runs ====================

/// Parametros del listado de runs (inmutables, para cache correcto).
class RunsParams {
  const RunsParams({
    this.limit = 10,
    this.branch,
  });

  final int limit;
  final String? branch;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RunsParams &&
          runtimeType == other.runtimeType &&
          limit == other.limit &&
          branch == other.branch;

  @override
  int get hashCode => Object.hash(limit, branch);
}

/// Lista de runs con filtros (family).
final opsRunsProvider =
    FutureProvider.family<RunsResponse, RunsParams>((ref, params) async {
  final repo = ref.read(opsRepositoryProvider);
  return repo.runs(limit: params.limit, branch: params.branch);
});

/// Detalle de un run (family por run id).
final opsRunDetailProvider =
    FutureProvider.family<RunDetail, int>((ref, runId) async {
  final repo = ref.read(opsRepositoryProvider);
  return repo.runDetail(runId);
});

// ==================== Tracks (Play Console) ====================

/// Versiones por track de las 2 apps (client + admin).
final opsTracksProvider = FutureProvider<TracksResponse>((ref) async {
  final repo = ref.read(opsRepositoryProvider);
  return repo.tracks();
});

// ==================== Links ====================

/// Links de descarga (opt-in + Play Store) de las 2 apps.
final opsLinksProvider = FutureProvider<LinksResponse>((ref) async {
  final repo = ref.read(opsRepositoryProvider);
  return repo.links();
});
// ==================== Quick Links ====================

/// Quick links a dashboards externos (Play Console, GitHub, etc.).
final opsQuickLinksProvider = FutureProvider<QuickLinksResponse>((ref) async {
  final repo = ref.read(opsRepositoryProvider);
  return repo.quickLinks();
});