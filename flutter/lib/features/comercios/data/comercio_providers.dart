/// Providers de Riverpod para el módulo comercios.
///
/// Expone:
/// - Repositorio (inyectable para tests).
/// - Categorías (públicas y admin).
/// - Filtros de búsqueda (StateNotifier).
/// - Listado público con auto-refresh al cambiar filtros.
/// - Detalle por slug.
/// - Mis comercios (dueño).
/// - Listados admin.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:baqueano_natales/features/comercios/data/comercio_repository.dart';
import 'package:baqueano_natales/features/comercios/domain/categoria.dart';
import 'package:baqueano_natales/features/comercios/domain/comercio.dart';

// =========================================================
// Repositorio (inyectable para tests)
// =========================================================
final comercioRepositoryProvider = Provider<ComercioRepository>((ref) {
  return ComercioRepository();
});

// =========================================================
// Categorías (público)
// =========================================================
final categoriasProvider = FutureProvider<List<Categoria>>((ref) async {
  final repo = ref.watch(comercioRepositoryProvider);
  return repo.listarCategorias();
});

// =========================================================
// Filtros de búsqueda (StateNotifier)
// =========================================================
class ComerciosFiltrosState {
  const ComerciosFiltrosState({
    this.categoriaId,
    this.busqueda,
    this.soloDestacados = false,
    this.soloDelivery = false,
  });

  final String? categoriaId;
  final String? busqueda;
  final bool soloDestacados;
  final bool soloDelivery;

  ComerciosFiltrosState copyWith({
    String? categoriaId,
    String? busqueda,
    bool? soloDestacados,
    bool? soloDelivery,
    bool clearCategoria = false,
    bool clearBusqueda = false,
  }) {
    return ComerciosFiltrosState(
      categoriaId: clearCategoria ? null : (categoriaId ?? this.categoriaId),
      busqueda: clearBusqueda ? null : (busqueda ?? this.busqueda),
      soloDestacados: soloDestacados ?? this.soloDestacados,
      soloDelivery: soloDelivery ?? this.soloDelivery,
    );
  }

  /// ¿Hay algún filtro activo (sin contar búsqueda)?
  bool get hayFiltrosActivos =>
      categoriaId != null || soloDestacados || soloDelivery;

  /// Convierte al objeto de filtros del repo (para la API).
  ComerciosFiltros toFiltros({int page = 1, int pageSize = 20}) {
    return ComerciosFiltros(
      categoriaId: categoriaId,
      busqueda: busqueda,
      soloDestacados: soloDestacados ? true : null,
      soloDelivery: soloDelivery ? true : null,
      page: page,
      pageSize: pageSize,
    );
  }
}

class ComerciosFiltrosNotifier extends StateNotifier<ComerciosFiltrosState> {
  ComerciosFiltrosNotifier() : super(const ComerciosFiltrosState());

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

  void toggleDelivery() {
    state = state.copyWith(soloDelivery: !state.soloDelivery);
  }

  void limpiar() {
    state = const ComerciosFiltrosState();
  }
}

final comerciosFiltrosProvider =
    StateNotifierProvider<ComerciosFiltrosNotifier, ComerciosFiltrosState>(
  (ref) => ComerciosFiltrosNotifier(),
);

// =========================================================
// Listado público (auto-refresh al cambiar filtros)
// =========================================================
final comerciosProvider = FutureProvider<Paginated<Comercio>>((ref) async {
  final repo = ref.watch(comercioRepositoryProvider);
  final filtros = ref.watch(comerciosFiltrosProvider);
  return repo.listarComercios(filtros: filtros.toFiltros());
});

// =========================================================
// Detalle por slug (family)
// =========================================================
final comercioDetalleProvider =
    FutureProvider.family<Comercio, String>((ref, slug) async {
  final repo = ref.watch(comercioRepositoryProvider);
  return repo.obtenerPorSlug(slug);
});

// =========================================================
// Dueño: mis comercios
// =========================================================
final misComerciosProvider = FutureProvider<List<Comercio>>((ref) async {
  final repo = ref.watch(comercioRepositoryProvider);
  return repo.listarMisComercios();
});

/// Detalle de un comercio propio por ID.
final miComercioDetalleProvider =
    FutureProvider.family<Comercio, String>((ref, id) async {
  final repo = ref.watch(comercioRepositoryProvider);
  return repo.obtenerMiComercio(id);
});

// =========================================================
// Admin: categorías (incluye inactivas)
// =========================================================
final adminCategoriasProvider = FutureProvider<List<Categoria>>((ref) async {
  final repo = ref.watch(comercioRepositoryProvider);
  return repo.adminListarCategorias(incluirInactivas: true);
});

// =========================================================
// Admin: listado de comercios (por estado)
// =========================================================
/// Parámetros del listado admin.
class AdminComerciosParams {
  const AdminComerciosParams({
    this.estado,
    this.categoriaId,
    this.busqueda,
    this.incluirInactivos = false,
  });

  final EstadoComercio? estado;
  final String? categoriaId;
  final String? busqueda;
  final bool incluirInactivos;

  @override
  bool operator ==(Object other) {
    return other is AdminComerciosParams &&
        other.estado == estado &&
        other.categoriaId == categoriaId &&
        other.busqueda == busqueda &&
        other.incluirInactivos == incluirInactivos;
  }

  @override
  int get hashCode =>
      Object.hash(estado, categoriaId, busqueda, incluirInactivos);
}

final adminComerciosProvider = FutureProvider.family<Paginated<Comercio>,
    AdminComerciosParams>((ref, params) async {
  final repo = ref.watch(comercioRepositoryProvider);
  return repo.adminListarComercios(
    estado: params.estado,
    categoriaId: params.categoriaId,
    busqueda: params.busqueda,
    incluirInactivos: params.incluirInactivos,
  );
});

// =========================================================
// Admin: detalle de comercio (por ID)
// =========================================================

/// Detalle de un comercio para admin (por ID).
///
/// Se usa en el panel admin para verificar/rechazar/suspender/destacar.
final adminComercioDetalleProvider =
    FutureProvider.family<Comercio, String>((ref, id) async {
  final repo = ref.watch(comercioRepositoryProvider);
  return repo.adminObtenerComercio(id);
});