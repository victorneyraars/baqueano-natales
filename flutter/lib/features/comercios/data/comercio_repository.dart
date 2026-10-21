/// Repositorio de comercios.
///
/// Encapsula las llamadas HTTP al backend (público, dueño, admin).
/// No maneja estado, solo hace las llamadas y devuelve datos o
/// lanza ApiException.
library;

import 'package:dio/dio.dart';

import 'package:baqueano_natales/core/network/api_exceptions.dart';
import 'package:baqueano_natales/core/network/dio_client.dart';
import 'package:baqueano_natales/features/comercios/domain/categoria.dart';
import 'package:baqueano_natales/features/comercios/domain/comercio.dart';
import 'package:baqueano_natales/features/comercios/domain/horario.dart';

/// Metadata de paginación devuelta por el backend.
class PaginacionMeta {
  const PaginacionMeta({
    required this.total,
    required this.page,
    required this.pageSize,
    required this.totalPages,
  });

  final int total;
  final int page;
  final int pageSize;
  final int totalPages;

  factory PaginacionMeta.fromJson(Map<String, dynamic> json) {
    return PaginacionMeta(
      total: (json['total'] as num).toInt(),
      page: (json['page'] as num).toInt(),
      pageSize: (json['page_size'] as num).toInt(),
      totalPages: (json['total_pages'] as num).toInt(),
    );
  }
}

/// Resultado paginado genérico.
class Paginated<T> {
  const Paginated({required this.items, required this.meta});

  final List<T> items;
  final PaginacionMeta meta;
}

/// Filtros para el listado público de comercios.
class ComerciosFiltros {
  const ComerciosFiltros({
    this.categoriaId,
    this.busqueda,
    this.soloDestacados,
    this.soloDelivery,
    this.page = 1,
    this.pageSize = 20,
  });

  final String? categoriaId;
  final String? busqueda;
  final bool? soloDestacados;
  final bool? soloDelivery;
  final int page;
  final int pageSize;

  Map<String, dynamic> toQuery() {
    final q = <String, dynamic>{'page': page, 'page_size': pageSize};
    if (categoriaId != null) q['categoria_id'] = categoriaId;
    if (busqueda != null && busqueda!.isNotEmpty) q['q'] = busqueda;
    if (soloDestacados == true) q['destacados'] = true;
    if (soloDelivery != null) q['delivery'] = soloDelivery;
    return q;
  }
}

class ComercioRepository {
  ComercioRepository({Dio? dio}) : _dio = dio ?? DioClient.instance;

  final Dio _dio;

  // =========================================================
  // Público
  // =========================================================

  /// Lista las categorías activas.
  Future<List<Categoria>> listarCategorias() async {
    try {
      final res = await _dio.get('/api/v1/comercios/categorias');
      final list = res.data as List<dynamic>;
      return list
          .map((c) => Categoria.fromJson(c as Map<String, dynamic>))
          .toList();
    } on ApiException {
      rethrow;
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      throw const UnknownException();
    } catch (e) {
      throw UnknownException('Error inesperado: $e');
    }
  }

  /// Lista comercios verificados con filtros y paginación.
  Future<Paginated<Comercio>> listarComercios({
    ComerciosFiltros filtros = const ComerciosFiltros(),
  }) async {
    try {
      final res = await _dio.get(
        '/api/v1/comercios',
        queryParameters: filtros.toQuery(),
      );
      final data = res.data as Map<String, dynamic>;
      final items = (data['items'] as List<dynamic>)
          .map((c) => Comercio.fromJson(c as Map<String, dynamic>))
          .toList();
      final meta = PaginacionMeta.fromJson(
        data['meta'] as Map<String, dynamic>,
      );
      return Paginated(items: items, meta: meta);
    } on ApiException {
      rethrow;
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      throw const UnknownException();
    } catch (e) {
      throw UnknownException('Error inesperado: $e');
    }
  }

  /// Detalle público por slug.
  Future<Comercio> obtenerPorSlug(String slug) async {
    try {
      final res = await _dio.get('/api/v1/comercios/$slug');
      return Comercio.fromJson(res.data as Map<String, dynamic>);
    } on ApiException {
      rethrow;
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      throw const UnknownException();
    } catch (e) {
      throw UnknownException('Error inesperado: $e');
    }
  }

  // =========================================================
  // Dueño (/mis-comercios)
  // =========================================================

  /// Lista los comercios del usuario autenticado.
  Future<List<Comercio>> listarMisComercios() async {
    try {
      final res = await _dio.get('/api/v1/mis-comercios');
      final data = res.data as Map<String, dynamic>;
      return (data['items'] as List<dynamic>)
          .map((c) => Comercio.fromJson(c as Map<String, dynamic>))
          .toList();
    } on ApiException {
      rethrow;
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      throw const UnknownException();
    } catch (e) {
      throw UnknownException('Error inesperado: $e');
    }
  }

  /// Obtiene un comercio propio por ID.
  Future<Comercio> obtenerMiComercio(String id) async {
    try {
      final res = await _dio.get('/api/v1/mis-comercios/$id');
      return Comercio.fromJson(res.data as Map<String, dynamic>);
    } on ApiException {
      rethrow;
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      throw const UnknownException();
    } catch (e) {
      throw UnknownException('Error inesperado: $e');
    }
  }

  /// Crea un comercio (queda en borrador).
  Future<Comercio> crearComercio({
    required String nombre,
    required String direccion,
    String? descripcionCorta,
    String? descripcionLarga,
    String? categoriaId,
    String? telefono,
    String? whatsapp,
    String? email,
    String? sitioWeb,
    String? referencia,
    bool aceptaDelivery = false,
    bool aceptaRetiro = true,
    int costoEnvioClp = 0,
    int pedidoMinimoClp = 0,
  }) async {
    try {
      final res = await _dio.post(
        '/api/v1/mis-comercios',
        data: {
          'nombre': nombre,
          'direccion': direccion,
          'descripcion_corta': descripcionCorta,
          'descripcion_larga': descripcionLarga,
          'categoria_id': categoriaId,
          'telefono': telefono,
          'whatsapp': whatsapp,
          'email': email,
          'sitio_web': sitioWeb,
          'referencia': referencia,
          'acepta_delivery': aceptaDelivery,
          'acepta_retiro': aceptaRetiro,
          'costo_envio_clp': costoEnvioClp,
          'pedido_minimo_clp': pedidoMinimoClp,
        },
      );
      return Comercio.fromJson(res.data as Map<String, dynamic>);
    } on ApiException {
      rethrow;
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      throw const UnknownException();
    } catch (e) {
      throw UnknownException('Error inesperado: $e');
    }
  }

  /// Edita un comercio propio (parcial).
  Future<Comercio> editarComercio({
    required String id,
    Map<String, dynamic> cambios = const {},
  }) async {
    try {
      final res = await _dio.patch('/api/v1/mis-comercios/$id', data: cambios);
      return Comercio.fromJson(res.data as Map<String, dynamic>);
    } on ApiException {
      rethrow;
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      throw const UnknownException();
    } catch (e) {
      throw UnknownException('Error inesperado: $e');
    }
  }

  /// Soft-delete de un comercio propio.
  Future<void> eliminarComercio(String id) async {
    try {
      await _dio.delete('/api/v1/mis-comercios/$id');
    } on ApiException {
      rethrow;
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      throw const UnknownException();
    } catch (e) {
      throw UnknownException('Error inesperado: $e');
    }
  }

  /// Envía un comercio a revisión (borrador/rechazado → pendiente).
  Future<Comercio> enviarARevision(String id) async {
    try {
      final res = await _dio.post('/api/v1/mis-comercios/$id/enviar-revision');
      return Comercio.fromJson(res.data as Map<String, dynamic>);
    } on ApiException {
      rethrow;
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      throw const UnknownException();
    } catch (e) {
      throw UnknownException('Error inesperado: $e');
    }
  }

  /// Reemplaza TODOS los horarios del comercio.
  Future<List<Horario>> setearHorarios({
    required String comercioId,
    required List<Map<String, dynamic>> horarios,
  }) async {
    try {
      final res = await _dio.put(
        '/api/v1/mis-comercios/$comercioId/horarios',
        data: {'horarios': horarios},
      );
      final list = res.data as List<dynamic>;
      return list
          .map((h) => Horario.fromJson(h as Map<String, dynamic>))
          .toList();
    } on ApiException {
      rethrow;
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      throw const UnknownException();
    } catch (e) {
      throw UnknownException('Error inesperado: $e');
    }
  }

  // =========================================================
  // Admin — Categorías
  // =========================================================

  /// Lista TODAS las categorías (incluidas inactivas).
  Future<List<Categoria>> adminListarCategorias({
    bool incluirInactivas = false,
  }) async {
    try {
      final res = await _dio.get(
        '/api/v1/admin/categorias-comercio',
        queryParameters: {'incluir_inactivas': incluirInactivas},
      );
      final list = res.data as List<dynamic>;
      return list
          .map((c) => Categoria.fromJson(c as Map<String, dynamic>))
          .toList();
    } on ApiException {
      rethrow;
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      throw const UnknownException();
    } catch (e) {
      throw UnknownException('Error inesperado: $e');
    }
  }

  /// Crea una categoría (admin).
  Future<Categoria> adminCrearCategoria({
    required String nombre,
    String? slug,
    String? descripcion,
    String? icono,
    String? colorHex,
    int orden = 0,
  }) async {
    try {
      final res = await _dio.post(
        '/api/v1/admin/categorias-comercio',
        data: {
          'nombre': nombre,
          'slug': slug ?? _slugify(nombre),
          'descripcion': descripcion,
          'icono': icono,
          'color_hex': colorHex,
          'orden': orden,
        },
      );
      return Categoria.fromJson(res.data as Map<String, dynamic>);
    } on ApiException {
      rethrow;
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      throw const UnknownException();
    } catch (e) {
      throw UnknownException('Error inesperado: $e');
    }
  }

  /// Edita una categoría (admin).
  Future<Categoria> adminEditarCategoria({
    required String id,
    Map<String, dynamic> cambios = const {},
  }) async {
    try {
      final res = await _dio.patch(
        '/api/v1/admin/categorias-comercio/$id',
        data: cambios,
      );
      return Categoria.fromJson(res.data as Map<String, dynamic>);
    } on ApiException {
      rethrow;
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      throw const UnknownException();
    } catch (e) {
      throw UnknownException('Error inesperado: $e');
    }
  }

  /// Desactiva una categoría (admin).
  Future<void> adminDesactivarCategoria(String id) async {
    try {
      await _dio.delete('/api/v1/admin/categorias-comercio/$id');
    } on ApiException {
      rethrow;
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      throw const UnknownException();
    } catch (e) {
      throw UnknownException('Error inesperado: $e');
    }
  }

  // =========================================================
  // Admin — Comercios
  // =========================================================

  /// Lista TODOS los comercios (admin).
  Future<Paginated<Comercio>> adminListarComercios({
    EstadoComercio? estado,
    String? categoriaId,
    String? busqueda,
    bool incluirInactivos = false,
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final q = <String, dynamic>{
        'page': page,
        'page_size': pageSize,
        'incluir_inactivos': incluirInactivos,
      };
      if (estado != null) q['estado'] = estado.name;
      if (categoriaId != null) q['categoria_id'] = categoriaId;
      if (busqueda != null && busqueda.isNotEmpty) q['q'] = busqueda;

      final res = await _dio.get('/api/v1/admin/comercios', queryParameters: q);
      final data = res.data as Map<String, dynamic>;
      final items = (data['items'] as List<dynamic>)
          .map((c) => Comercio.fromJson(c as Map<String, dynamic>))
          .toList();
      final meta = PaginacionMeta.fromJson(
        data['meta'] as Map<String, dynamic>,
      );
      return Paginated(items: items, meta: meta);
    } on ApiException {
      rethrow;
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      throw const UnknownException();
    } catch (e) {
      throw UnknownException('Error inesperado: $e');
    }
  }

  /// Obtiene un comercio por ID (admin).
  Future<Comercio> adminObtenerComercio(String id) async {
    try {
      final res = await _dio.get('/api/v1/admin/comercios/$id');
      return Comercio.fromJson(res.data as Map<String, dynamic>);
    } on ApiException {
      rethrow;
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      throw const UnknownException();
    } catch (e) {
      throw UnknownException('Error inesperado: $e');
    }
  }

  /// Verifica un comercio (admin).
  Future<Comercio> adminVerificar({
    required String id,
    String? categoriaId,
  }) async {
    try {
      final res = await _dio.post(
        '/api/v1/admin/comercios/$id/verificar',
        data: {'categoria_id': categoriaId},
      );
      return Comercio.fromJson(res.data as Map<String, dynamic>);
    } on ApiException {
      rethrow;
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      throw const UnknownException();
    } catch (e) {
      throw UnknownException('Error inesperado: $e');
    }
  }

  /// Rechaza un comercio (admin).
  Future<Comercio> adminRechazar({
    required String id,
    required String motivo,
  }) async {
    try {
      final res = await _dio.post(
        '/api/v1/admin/comercios/$id/rechazar',
        data: {'motivo': motivo},
      );
      return Comercio.fromJson(res.data as Map<String, dynamic>);
    } on ApiException {
      rethrow;
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      throw const UnknownException();
    } catch (e) {
      throw UnknownException('Error inesperado: $e');
    }
  }

  /// Suspende un comercio (admin).
  Future<Comercio> adminSuspender({
    required String id,
    required String motivo,
  }) async {
    try {
      final res = await _dio.post(
        '/api/v1/admin/comercios/$id/suspender',
        data: {'motivo': motivo},
      );
      return Comercio.fromJson(res.data as Map<String, dynamic>);
    } on ApiException {
      rethrow;
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      throw const UnknownException();
    } catch (e) {
      throw UnknownException('Error inesperado: $e');
    }
  }

  /// Marca/desmarca destacado (admin).
  Future<Comercio> adminDestacar({
    required String id,
    required bool destacado,
  }) async {
    try {
      final res = await _dio.post(
        '/api/v1/admin/comercios/$id/destacar',
        data: {'destacado': destacado},
      );
      return Comercio.fromJson(res.data as Map<String, dynamic>);
    } on ApiException {
      rethrow;
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      throw const UnknownException();
    } catch (e) {
      throw UnknownException('Error inesperado: $e');
    }
  }

  // =========================================================
  // Helpers
  // =========================================================

  /// Slugify simple (el backend puede re-generarlo).
  static String _slugify(String texto) {
    return texto
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
  }
}
