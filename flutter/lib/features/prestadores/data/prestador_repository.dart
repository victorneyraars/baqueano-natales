/// Repositorio de prestadores de oficios.
///
/// Encapsula las llamadas HTTP al backend (público, dueño, admin).
/// No maneja estado, solo hace las llamadas y devuelve datos o
/// lanza ApiException.
library;

import 'package:dio/dio.dart';

import 'package:baqueano_natales/core/network/api_exceptions.dart';
import 'package:baqueano_natales/core/network/dio_client.dart';
import 'package:baqueano_natales/features/comercios/data/comercio_repository.dart'
    show PaginacionMeta, Paginated;
import 'package:baqueano_natales/features/prestadores/domain/categoria_oficio.dart';
import 'package:baqueano_natales/features/prestadores/domain/foto_trabajo.dart';
import 'package:baqueano_natales/features/prestadores/domain/prestador.dart';
import 'package:baqueano_natales/features/prestadores/domain/prestador_servicio.dart';
import 'package:baqueano_natales/features/prestadores/domain/review.dart';

/// Filtros para el listado público de prestadores.
class PrestadoresFiltros {
  const PrestadoresFiltros({
    this.categoriaId,
    this.busqueda,
    this.soloDestacados,
    this.soloDomicilio,
    this.soloEmergencias,
    this.page = 1,
    this.pageSize = 20,
  });

  final String? categoriaId;
  final String? busqueda;
  final bool? soloDestacados;
  final bool? soloDomicilio;
  final bool? soloEmergencias;
  final int page;
  final int pageSize;

  Map<String, dynamic> toQuery() {
    final q = <String, dynamic>{
      'page': page,
      'page_size': pageSize,
    };
    if (categoriaId != null) q['categoria_id'] = categoriaId;
    if (busqueda != null && busqueda!.isNotEmpty) q['q'] = busqueda;
    if (soloDestacados == true) q['destacados'] = true;
    if (soloDomicilio != null) q['domicilio'] = soloDomicilio;
    if (soloEmergencias != null) q['emergencias'] = soloEmergencias;
    return q;
  }
}

class PrestadorRepository {
  PrestadorRepository({Dio? dio}) : _dio = dio ?? DioClient.instance;

  final Dio _dio;

  // =========================================================
  // Público
  // =========================================================

  /// Lista las categorías activas.
  Future<List<CategoriaOficio>> listarCategorias() async {
    try {
      final res = await _dio.get('/api/v1/prestadores/categorias');
      final list = res.data as List<dynamic>;
      return list
          .map((c) => CategoriaOficio.fromJson(c as Map<String, dynamic>))
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

  /// Lista prestadores verificados con filtros y paginación.
  Future<Paginated<Prestador>> listarPrestadores({
    PrestadoresFiltros filtros = const PrestadoresFiltros(),
  }) async {
    try {
      final res = await _dio.get(
        '/api/v1/prestadores',
        queryParameters: filtros.toQuery(),
      );
      final data = res.data as Map<String, dynamic>;
      final items = (data['items'] as List<dynamic>)
          .map((p) => Prestador.fromJson(p as Map<String, dynamic>))
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
  Future<Prestador> obtenerPorSlug(String slug) async {
    try {
      final res = await _dio.get('/api/v1/prestadores/$slug');
      return Prestador.fromJson(res.data as Map<String, dynamic>);
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
  // Dueño (/mis-prestadores)
  // =========================================================

  /// Lista los prestadores del usuario autenticado.
  Future<List<Prestador>> listarMisPrestadores() async {
    try {
      final res = await _dio.get('/api/v1/mis-prestadores');
      final data = res.data as Map<String, dynamic>;
      return (data['items'] as List<dynamic>)
          .map((p) => Prestador.fromJson(p as Map<String, dynamic>))
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

  /// Obtiene un prestador propio por ID.
  Future<Prestador> obtenerMiPrestador(String id) async {
    try {
      final res = await _dio.get('/api/v1/mis-prestadores/$id');
      return Prestador.fromJson(res.data as Map<String, dynamic>);
    } on ApiException {
      rethrow;
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      throw const UnknownException();
    } catch (e) {
      throw UnknownException('Error inesperado: $e');
    }
  }

  /// Crea un prestador (queda en borrador).
  Future<Prestador> crearPrestador({
    required String nombre,
    required String categoriaId,
    String? descripcion,
    int? aniosExperiencia,
    String? telefono,
    String? whatsapp,
    String? whatsappMensaje,
    String? email,
    String? sitioWeb,
    String? direccion,
    bool atiendeDomicilio = false,
    bool atiendeLocal = true,
    bool atiendeEmergencias = false,
    String? horarioDescripcion,
    List<String>? especialidades,
    Map<String, dynamic>? datosExtra,
    Map<String, dynamic>? redesSociales,
  }) async {
    try {
      final res = await _dio.post(
        '/api/v1/mis-prestadores',
        data: {
          'nombre': nombre,
          'categoria_id': categoriaId,
          'descripcion': descripcion,
          'anios_experiencia': aniosExperiencia,
          'telefono': telefono,
          'whatsapp': whatsapp,
          'whatsapp_mensaje': whatsappMensaje,
          'email': email,
          'sitio_web': sitioWeb,
          'direccion': direccion,
          'atiende_domicilio': atiendeDomicilio,
          'atiende_local': atiendeLocal,
          'atiende_emergencias': atiendeEmergencias,
          'horario_descripcion': horarioDescripcion,
          'especialidades': especialidades,
          'datos_extra': datosExtra,
          'redes_sociales': redesSociales,
        },
      );
      return Prestador.fromJson(res.data as Map<String, dynamic>);
    } on ApiException {
      rethrow;
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      throw const UnknownException();
    } catch (e) {
      throw UnknownException('Error inesperado: $e');
    }
  }

  /// Edita un prestador propio (parcial).
  Future<Prestador> editarPrestador({
    required String id,
    Map<String, dynamic> cambios = const {},
  }) async {
    try {
      final res = await _dio.patch(
        '/api/v1/mis-prestadores/$id',
        data: cambios,
      );
      return Prestador.fromJson(res.data as Map<String, dynamic>);
    } on ApiException {
      rethrow;
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      throw const UnknownException();
    } catch (e) {
      throw UnknownException('Error inesperado: $e');
    }
  }

  /// Soft-delete de un prestador propio.
  Future<void> eliminarPrestador(String id) async {
    try {
      await _dio.delete('/api/v1/mis-prestadores/$id');
    } on ApiException {
      rethrow;
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      throw const UnknownException();
    } catch (e) {
      throw UnknownException('Error inesperado: $e');
    }
  }

  /// Envía un prestador a revisión (borrador/rechazado → pendiente).
  Future<Prestador> enviarARevision(String id) async {
    try {
      final res =
          await _dio.post('/api/v1/mis-prestadores/$id/enviar-revision');
      return Prestador.fromJson(res.data as Map<String, dynamic>);
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
  // Servicios del catálogo (dueño)
  // =========================================================

  /// Reemplaza TODOS los servicios del prestador.
  Future<List<PrestadorServicio>> setearServicios({
    required String prestadorId,
    required List<Map<String, dynamic>> servicios,
  }) async {
    try {
      final res = await _dio.put(
        '/api/v1/mis-prestadores/$prestadorId/servicios',
        data: {'servicios': servicios},
      );
      final list = res.data as List<dynamic>;
      return list
          .map((s) => PrestadorServicio.fromJson(s as Map<String, dynamic>))
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

  /// Agrega un servicio al catálogo.
  Future<PrestadorServicio> agregarServicio({
    required String prestadorId,
    required String nombre,
    String? descripcion,
    String? categoriaServicio,
    int? precioDesdeClp,
    int? precioHastaClp,
    int? duracionEstimadaMin,
    int? garantiaDias,
    bool destacado = false,
    int orden = 0,
  }) async {
    try {
      final res = await _dio.post(
        '/api/v1/mis-prestadores/$prestadorId/servicios',
        data: {
          'nombre': nombre,
          'descripcion': descripcion,
          'categoria_servicio': categoriaServicio,
          'precio_desde_clp': precioDesdeClp,
          'precio_hasta_clp': precioHastaClp,
          'duracion_estimada_min': duracionEstimadaMin,
          'garantia_dias': garantiaDias,
          'destacado': destacado,
          'orden': orden,
        },
      );
      return PrestadorServicio.fromJson(res.data as Map<String, dynamic>);
    } on ApiException {
      rethrow;
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      throw const UnknownException();
    } catch (e) {
      throw UnknownException('Error inesperado: $e');
    }
  }

  /// Edita un servicio del catálogo (parcial).
  Future<PrestadorServicio> editarServicio({
    required String prestadorId,
    required String servicioId,
    Map<String, dynamic> cambios = const {},
  }) async {
    try {
      final res = await _dio.patch(
        '/api/v1/mis-prestadores/$prestadorId/servicios/$servicioId',
        data: cambios,
      );
      return PrestadorServicio.fromJson(res.data as Map<String, dynamic>);
    } on ApiException {
      rethrow;
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      throw const UnknownException();
    } catch (e) {
      throw UnknownException('Error inesperado: $e');
    }
  }

  /// Elimina un servicio del catálogo.
  Future<void> eliminarServicio({
    required String prestadorId,
    required String servicioId,
  }) async {
    try {
      await _dio.delete(
        '/api/v1/mis-prestadores/$prestadorId/servicios/$servicioId',
      );
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
  // Fotos (dueño)
  // =========================================================

  /// Reemplaza TODA la galería de fotos.
  Future<List<FotoTrabajo>> setearFotos({
    required String prestadorId,
    required List<Map<String, dynamic>> fotos,
  }) async {
    try {
      final res = await _dio.put(
        '/api/v1/mis-prestadores/$prestadorId/fotos',
        data: {'fotos': fotos},
      );
      final list = res.data as List<dynamic>;
      return list
          .map((f) => FotoTrabajo.fromJson(f as Map<String, dynamic>))
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

  Future<List<CategoriaOficio>> adminListarCategorias({
    bool incluirInactivas = false,
  }) async {
    try {
      final res = await _dio.get(
        '/api/v1/admin/categorias-oficio',
        queryParameters: {'incluir_inactivas': incluirInactivas},
      );
      final list = res.data as List<dynamic>;
      return list
          .map((c) => CategoriaOficio.fromJson(c as Map<String, dynamic>))
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

  Future<CategoriaOficio> adminCrearCategoria({
    required String nombre,
    String? slug,
    String? descripcion,
    String? icono,
    String? colorHex,
    int orden = 0,
  }) async {
    try {
      final res = await _dio.post(
        '/api/v1/admin/categorias-oficio',
        data: {
          'nombre': nombre,
          'slug': slug ?? _slugify(nombre),
          'descripcion': descripcion,
          'icono': icono,
          'color_hex': colorHex,
          'orden': orden,
        },
      );
      return CategoriaOficio.fromJson(res.data as Map<String, dynamic>);
    } on ApiException {
      rethrow;
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      throw const UnknownException();
    } catch (e) {
      throw UnknownException('Error inesperado: $e');
    }
  }

  Future<CategoriaOficio> adminEditarCategoria({
    required String id,
    Map<String, dynamic> cambios = const {},
  }) async {
    try {
      final res = await _dio.patch(
        '/api/v1/admin/categorias-oficio/$id',
        data: cambios,
      );
      return CategoriaOficio.fromJson(res.data as Map<String, dynamic>);
    } on ApiException {
      rethrow;
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      throw const UnknownException();
    } catch (e) {
      throw UnknownException('Error inesperado: $e');
    }
  }

  Future<void> adminDesactivarCategoria(String id) async {
    try {
      await _dio.delete('/api/v1/admin/categorias-oficio/$id');
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
  // Admin — Prestadores
  // =========================================================

  Future<Paginated<Prestador>> adminListarPrestadores({
    EstadoPrestador? estado,
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

      final res = await _dio.get(
        '/api/v1/admin/prestadores',
        queryParameters: q,
      );
      final data = res.data as Map<String, dynamic>;
      final items = (data['items'] as List<dynamic>)
          .map((p) => Prestador.fromJson(p as Map<String, dynamic>))
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

  Future<Prestador> adminObtenerPrestador(String id) async {
    try {
      final res = await _dio.get('/api/v1/admin/prestadores/$id');
      return Prestador.fromJson(res.data as Map<String, dynamic>);
    } on ApiException {
      rethrow;
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      throw const UnknownException();
    } catch (e) {
      throw UnknownException('Error inesperado: $e');
    }
  }

  Future<Prestador> adminVerificar({
    required String id,
    String? categoriaId,
  }) async {
    try {
      final res = await _dio.post(
        '/api/v1/admin/prestadores/$id/verificar',
        data: {'categoria_id': categoriaId},
      );
      return Prestador.fromJson(res.data as Map<String, dynamic>);
    } on ApiException {
      rethrow;
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      throw const UnknownException();
    } catch (e) {
      throw UnknownException('Error inesperado: $e');
    }
  }

  Future<Prestador> adminRechazar({
    required String id,
    required String motivo,
  }) async {
    try {
      final res = await _dio.post(
        '/api/v1/admin/prestadores/$id/rechazar',
        data: {'motivo': motivo},
      );
      return Prestador.fromJson(res.data as Map<String, dynamic>);
    } on ApiException {
      rethrow;
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      throw const UnknownException();
    } catch (e) {
      throw UnknownException('Error inesperado: $e');
    }
  }

  Future<Prestador> adminSuspender({
    required String id,
    required String motivo,
  }) async {
    try {
      final res = await _dio.post(
        '/api/v1/admin/prestadores/$id/suspender',
        data: {'motivo': motivo},
      );
      return Prestador.fromJson(res.data as Map<String, dynamic>);
    } on ApiException {
      rethrow;
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      throw const UnknownException();
    } catch (e) {
      throw UnknownException('Error inesperado: $e');
    }
  }

  Future<Prestador> adminDestacar({
    required String id,
    required bool destacado,
  }) async {
    try {
      final res = await _dio.post(
        '/api/v1/admin/prestadores/$id/destacar',
        data: {'destacado': destacado},
      );
      return Prestador.fromJson(res.data as Map<String, dynamic>);
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

  static String _slugify(String texto) {
    return texto
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
  }

  // =========================================================
  // M6: Reviews
  // =========================================================

  /// Lista las reviews publicas de un prestador (paginado).
  Future<ReviewListResponse> listarReviewsPublicas(
    String slug, {
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final res = await _dio.get(
        '/api/v1/prestadores/$slug/reviews',
        queryParameters: {'page': page, 'page_size': pageSize},
      );
      return ReviewListResponse.fromJson(res.data as Map<String, dynamic>);
    } on ApiException {
      rethrow;
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      throw const UnknownException();
    } catch (e) {
      throw UnknownException('Error inesperado: $e');
    }
  }

  /// Prestador responde una review (una sola vez).
  Future<Review> responderReview(
    String prestadorId,
    String reviewId,
    String respuesta,
  ) async {
    try {
      final res = await _dio.post(
        '/api/v1/mis-prestadores/$prestadorId/reviews/$reviewId/respuesta',
        data: {'respuesta': respuesta},
      );
      return Review.fromJson(res.data as Map<String, dynamic>);
    } on ApiException {
      rethrow;
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      throw const UnknownException();
    } catch (e) {
      throw UnknownException('Error inesperado: $e');
    }
  }
}
