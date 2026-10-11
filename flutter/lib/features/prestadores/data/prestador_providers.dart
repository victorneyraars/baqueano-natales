/// Providers de Riverpod para el módulo prestadores.
///
/// Expone:
/// - Repositorio (inyectable para tests).
/// - Categorías (públicas y admin).
/// - Filtros de búsqueda (Notifier).
/// - Listado público con auto-refresh al cambiar filtros.
/// - Detalle por slug.
/// - Mis prestadores (dueño).
/// - Listados admin y detalle admin.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:baqueano_natales/features/comercios/data/comercio_repository.dart'
    show Paginated;
import 'package:baqueano_natales/features/prestadores/data/prestador_repository.dart';
import 'package:baqueano_natales/features/prestadores/domain/categoria_oficio.dart';
import 'package:baqueano_natales/features/prestadores/domain/prestador.dart';

// =========================================================
// Repositorio (inyectable para tests)
// =========================================================
final prestadorRepositoryProvider = Provider<PrestadorRepository>((ref) {
  return PrestadorRepository();
});

// =========================================================
// Categorías (público)
// =========================================================
final categoriasOficioProvider =
    FutureProvider<List<CategoriaOficio>>((ref) async {
  final repo = ref.watch(prestadorRepositoryProvider);
  return repo.listarCategorias();
});

// =========================================================
// Filtros de búsqueda (Notifier)
// =========================================================
class PrestadoresFiltrosState {
  const PrestadoresFiltrosState({
    this.categoriaId,
    this.busqueda,
    this.soloDestacados = false,
    this.soloDomicilio = false,
    this.soloEmergencias = false,
  });

  final String? categoriaId;
  final String? busqueda;
  final bool soloDestacados;
  final bool soloDomicilio;
  final bool soloEmergencias;

  PrestadoresFiltrosState copyWith({
    String? categoriaId,
    String? busqueda,
    bool? soloDestacados,
    bool? soloDomicilio,
    bool? soloEmergencias,
    bool clearCategoria = false,
    bool clearBusqueda = false,
  }) {
    return PrestadoresFiltrosState(
      categoriaId: clearCategoria ? null : (categoriaId ?? this.categoriaId),
      busqueda: clearBusqueda ? null : (busqueda ?? this.busqueda),
      soloDestacados: soloDestacados ?? this.soloDestacados,
      soloDomicilio: soloDomicilio ?? this.soloDomicilio,
      soloEmergencias: soloEmergencias ?? this.soloEmergencias,
    );
  }

  bool get hayFiltrosActivos =>
      categoriaId != null ||
      soloDestacados ||
      soloDomicilio ||
      soloEmergencias;

  PrestadoresFiltros toFiltros({int page = 1, int pageSize = 20}) {
    return PrestadoresFiltros(
      categoriaId: categoriaId,
      busqueda: busqueda,
      soloDestacados: soloDestacados ? true : null,
      soloDomicilio: soloDomicilio ? true : null,
      soloEmergencias: soloEmergencias ? true : null,
      page: page,
      pageSize: pageSize,
    );
  }
}

class PrestadoresFiltrosNotifier extends Notifier<PrestadoresFiltrosState> {
  @override
  PrestadoresFiltrosState build() => const PrestadoresFiltrosState();

  void setCategoria(String? categoriaId) {
    if (categoriaId == null) {
      state = state.copyWith(clearCategoria: true);
    } else {
      state = state.copyWith(categoriaId: categoriaId);
    }
  }

  void setBusqueda(String? busqueda) {
    final q = busqueda?.trim();
    if (q == null || q.isEmpty) {
      state = state.copyWith(clearBusqueda: true);
    } else {
      state = state.copyWith(busqueda: q);
    }
  }

  void toggleDestacados() {
    state = state.copyWith(soloDestacados: !state.soloDestacados);
  }

  void toggleDomicilio() {
    state = state.copyWith(soloDomicilio: !state.soloDomicilio);
  }

  void toggleEmergencias() {
    state = state.copyWith(soloEmergencias: !state.soloEmergencias);
  }

  void limpiar() {
    state = const PrestadoresFiltrosState();
  }
}

final prestadoresFiltrosProvider = NotifierProvider<
    PrestadoresFiltrosNotifier, PrestadoresFiltrosState>(
  PrestadoresFiltrosNotifier.new,
);

// =========================================================
// Listado público (auto-refresh al cambiar filtros)
// =========================================================
final prestadoresProvider =
    FutureProvider<Paginated<Prestador>>((ref) async {
  final repo = ref.watch(prestadorRepositoryProvider);
  final filtros = ref.watch(prestadoresFiltrosProvider);
  return repo.listarPrestadores(filtros: filtros.toFiltros());
});

// =========================================================
// Detalle por slug (family)
// =========================================================
final prestadorDetalleProvider =
    FutureProvider.family<Prestador, String>((ref, slug) async {
  final repo = ref.watch(prestadorRepositoryProvider);
  return repo.obtenerPorSlug(slug);
});

// =========================================================
// Dueño: mis prestadores
// =========================================================
final misPrestadoresProvider =
    FutureProvider<List<Prestador>>((ref) async {
  final repo = ref.watch(prestadorRepositoryProvider);
  return repo.listarMisPrestadores();
});

/// Detalle de un prestador propio por ID.
final miPrestadorDetalleProvider =
    FutureProvider.family<Prestador, String>((ref, id) async {
  final repo = ref.watch(prestadorRepositoryProvider);
  return repo.obtenerMiPrestador(id);
});

// =========================================================
// Admin: categorías (incluye inactivas)
// =========================================================
final adminCategoriasOficioProvider =
    FutureProvider<List<CategoriaOficio>>((ref) async {
  final repo = ref.watch(prestadorRepositoryProvider);
  return repo.adminListarCategorias(incluirInactivas: true);
});

// =========================================================
// Admin: listado de prestadores (por estado)
// =========================================================
class AdminPrestadoresParams {
  const AdminPrestadoresParams({
    this.estado,
    this.categoriaId,
    this.busqueda,
    this.incluirInactivos = false,
  });

  final EstadoPrestador? estado;
  final String? categoriaId;
  final String? busqueda;
  final bool incluirInactivos;

  @override
  bool operator ==(Object other) {
    return other is AdminPrestadoresParams &&
        other.estado == estado &&
        other.categoriaId == categoriaId &&
        other.busqueda == busqueda &&
        other.incluirInactivos == incluirInactivos;
  }

  @override
  int get hashCode =>
      Object.hash(estado, categoriaId, busqueda, incluirInactivos);
}

final adminPrestadoresProvider =
    FutureProvider.family<Paginated<Prestador>, AdminPrestadoresParams>(
        (ref, params) async {
  final repo = ref.watch(prestadorRepositoryProvider);
  return repo.adminListarPrestadores(
    estado: params.estado,
    categoriaId: params.categoriaId,
    busqueda: params.busqueda,
    incluirInactivos: params.incluirInactivos,
  );
});

// =========================================================
// Admin: detalle de prestador (por ID)
// =========================================================

/// Detalle de un prestador para admin (por ID).
///
/// Se usa en el panel admin para verificar/rechazar/suspender/destacar.
final adminPrestadorDetalleProvider =
    FutureProvider.family<Prestador, String>((ref, id) async {
  final repo = ref.watch(prestadorRepositoryProvider);
  return repo.adminObtenerPrestador(id);
});