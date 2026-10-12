/// Providers de notificaciones admin (Riverpod).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:baqueano_natales/features/notificaciones/data/notificaciones_repository.dart';
import 'package:baqueano_natales/features/notificaciones/domain/notificacion.dart';
import 'package:baqueano_natales/features/notificaciones/domain/stats.dart';

/// Provider del repositorio (inyectable para tests).
final notificacionesRepositoryProvider = Provider<NotificacionesRepository>((ref) {
  return NotificacionesRepository();
});

/// Parametros del historial (inmutables, para cache correcto).
class HistorialParams {
  const HistorialParams({
    this.tipo,
    this.estado,
    this.limit = 100,
    this.offset = 0,
  });

  final String? tipo;
  final String? estado;
  final int limit;
  final int offset;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HistorialParams &&
          runtimeType == other.runtimeType &&
          tipo == other.tipo &&
          estado == other.estado &&
          limit == other.limit &&
          offset == other.offset;

  @override
  int get hashCode => Object.hash(tipo, estado, limit, offset);
}

/// Historial con filtros (family).
final historialNotificacionesProvider =
    FutureProvider.family<List<NotificacionAdmin>, HistorialParams>(
  (ref, params) async {
    final repo = ref.read(notificacionesRepositoryProvider);
    return repo.listar(
      tipo: params.tipo,
      estado: params.estado,
      limit: params.limit,
      offset: params.offset,
    );
  },
);

/// Stats del dashboard.
final statsNotificacionesProvider = FutureProvider<StatsNotificacion>(
  (ref) async {
    final repo = ref.read(notificacionesRepositoryProvider);
    return repo.stats();
  },
);
