/// Repositorio de social (admin).
///
/// Encapsula las llamadas HTTP al backend. No maneja estado, solo hace
/// las llamadas y devuelve datos o lanza ApiException.
///
/// Endpoints que consume:
///   GET    /api/v1/admin/social/cuentas
///   GET    /api/v1/admin/social/config
///   POST   /api/v1/admin/social/publicaciones/procesar-ahora
library;

import 'package:baqueano_natales/features/social/domain/oauth_url.dart';
import 'package:baqueano_natales/features/social/domain/admin_token_status.dart';
import 'package:baqueano_natales/features/social/domain/pagina_facebook.dart';

import 'package:dio/dio.dart';

import 'package:baqueano_natales/core/network/api_exceptions.dart';
import 'package:baqueano_natales/core/network/dio_client.dart';
import 'package:baqueano_natales/features/social/domain/cuenta_social.dart';
import 'package:baqueano_natales/features/social/domain/publicacion_social.dart';

/// Metadata de paginacion del backend.
///
/// El backend devuelve `{total, limit, offset}`. Derivamos `page` y
/// `totalPages` para conveniencia del cliente.
class SocialPaginacion {
  const SocialPaginacion({
    required this.total,
    required this.limit,
    required this.offset,
  });

  final int total;
  final int limit;
  final int offset;

  /// Pagina actual (1-based). Calculada a partir del offset.
  int get page => limit > 0 ? (offset ~/ limit) + 1 : 1;

  /// Cantidad total de paginas.
  int get totalPages => limit > 0 ? ((total + limit - 1) ~/ limit) : 1;

  factory SocialPaginacion.fromJson(Map<String, dynamic> json) {
    return SocialPaginacion(
      total: (json['total'] as num?)?.toInt() ?? 0,
      limit: (json['limit'] as num?)?.toInt() ?? 0,
      offset: (json['offset'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Listado paginado de cuentas.
class CuentasPaginadas {
  const CuentasPaginadas({required this.items, required this.meta});

  final List<CuentaSocial> items;
  final SocialPaginacion meta;
}

/// Config global de social.
class ConfigSocial {
  const ConfigSocial({
    required this.id,
    required this.propietarioTipo,
    required this.propietarioId,
    required this.autoPublish,
    required this.destino,
    required this.publicarEnFacebook,
    required this.publicarEnInstagram,
    required this.publicarEnGoogle,
  });

  final String id;
  final String? propietarioTipo;
  final String? propietarioId;
  final bool autoPublish;
  final String destino;
  final bool publicarEnFacebook;
  final bool publicarEnInstagram;
  final bool publicarEnGoogle;

  factory ConfigSocial.fromJson(Map<String, dynamic> json) {
    return ConfigSocial(
      id: json['id'] as String,
      propietarioTipo: json['propietario_tipo'] as String?,
      propietarioId: json['propietario_id'] as String?,
      autoPublish: json['auto_publish'] as bool? ?? false,
      destino: json['destino'] as String? ?? 'central',
      publicarEnFacebook: json['publicar_en_facebook'] as bool? ?? false,
      publicarEnInstagram: json['publicar_en_instagram'] as bool? ?? false,
      publicarEnGoogle: json['publicar_en_google'] as bool? ?? false,
    );
  }
}

/// Listado paginado de publicaciones.
class PublicacionesPaginadas {
  const PublicacionesPaginadas({required this.items, required this.meta});

  final List<PublicacionSocial> items;
  final SocialPaginacion meta;
}

/// Repositorio del modulo social (admin).
class SocialRepository {
  SocialRepository({Dio? dio}) : _dio = dio ?? DioClient.instance;

  final Dio _dio;

  static const String _base = '/api/v1/admin/social';

  /// Lista las cuentas conectadas, opcionalmente filtradas por red.
  Future<CuentasPaginadas> listarCuentas({
    RedSocial? red,
    int page = 1,
    int pageSize = 50,
  }) async {
    try {
      final query = <String, dynamic>{
        'page': page,
        'page_size': pageSize,
        if (red != null) 'red': red.value,
      };
      final resp = await _dio.get('$_base/cuentas', queryParameters: query);
      final data = resp.data as Map<String, dynamic>;
      final items = (data['items'] as List)
          .map((j) => CuentaSocial.fromJson(j as Map<String, dynamic>))
          .toList();
      final meta = SocialPaginacion.fromJson(
        data['meta'] as Map<String, dynamic>,
      );
      return CuentasPaginadas(items: items, meta: meta);
    } on ApiException {
      rethrow;
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      throw const UnknownException();
    } catch (e) {
      throw UnknownException('Error inesperado: $e');
    }
  }

  /// Obtiene la config global.
  Future<ConfigSocial> obtenerConfig({
    String? propietarioTipo,
    String? propietarioId,
  }) async {
    try {
      final qp = (propietarioTipo != null && propietarioId != null)
          ? {
              'propietario_tipo': propietarioTipo,
              'propietario_id': propietarioId,
            }
          : null;
      final resp = await _dio.get('$_base/config', queryParameters: qp);
      return ConfigSocial.fromJson(resp.data as Map<String, dynamic>);
    } on ApiException {
      rethrow;
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      throw const UnknownException();
    } catch (e) {
      throw UnknownException('Error inesperado: $e');
    }
  }

  /// Lista las publicaciones de la cola, opcionalmente filtradas.
  Future<PublicacionesPaginadas> listarPublicaciones({
    EstadoPublicacion? estado,
    RedSocial? red,
    int page = 1,
    int pageSize = 50,
  }) async {
    try {
      final query = <String, dynamic>{
        'page': page,
        'page_size': pageSize,
        if (estado != null) 'estado': estado.value,
        if (red != null) 'red': red.value,
      };
      final resp = await _dio.get(
        '$_base/publicaciones',
        queryParameters: query,
      );
      final data = resp.data as Map<String, dynamic>;
      final items = (data['items'] as List)
          .map((j) => PublicacionSocial.fromJson(j as Map<String, dynamic>))
          .toList();
      final meta = SocialPaginacion.fromJson(
        data['meta'] as Map<String, dynamic>,
      );
      return PublicacionesPaginadas(items: items, meta: meta);
    } on ApiException {
      rethrow;
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      throw const UnknownException();
    } catch (e) {
      throw UnknownException('Error inesperado: $e');
    }
  }

  /// Lista las publicaciones relacionadas con un prestador.
  ///
  /// Incluye su alta como prestador + los servicios agregados.
  /// Endpoint: GET /api/v1/mis-prestadores/{id}/publicaciones
  Future<List<PublicacionSocial>> listarPublicacionesDePrestador(
    String prestadorId,
  ) async {
    try {
      final resp = await _dio.get(
        '/api/v1/mis-prestadores/$prestadorId/publicaciones',
      );
      final data = resp.data as Map<String, dynamic>;
      final items = (data['items'] as List)
          .map((j) => PublicacionSocial.fromJson(j as Map<String, dynamic>))
          .toList();
      return items;
    } on ApiException {
      rethrow;
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      throw const UnknownException();
    } catch (e) {
      throw UnknownException('Error inesperado: $e');
    }
  }

  /// Reencola una publicacion fallada/agotada.
  ///
  /// Resetea estado a PENDIENTE, limpia intentos y error. El worker
  /// la procesara en el proximo ciclo o cuando se llame a procesar-ahora.
  Future<PublicacionSocial> reencolarPublicacion(String publicacionId) async {
    try {
      final resp = await _dio.patch(
        '$_base/publicaciones/$publicacionId/reencolar',
      );
      return PublicacionSocial.fromJson(resp.data as Map<String, dynamic>);
    } on ApiException {
      rethrow;
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      throw const UnknownException();
    } catch (e) {
      throw UnknownException('Error inesperado: $e');
    }
  }

  /// Actualiza la config global (parcial). Solo envia los campos no-null.
  Future<ConfigSocial> actualizarConfig({
    bool? autoPublish,
    String? destino,
    bool? publicarEnFacebook,
    bool? publicarEnInstagram,
    bool? publicarEnGoogle,
    String? propietarioTipo,
    String? propietarioId,
  }) async {
    try {
      final body = <String, dynamic>{
        'auto_publish': ?autoPublish,
        'destino': ?destino,
        'publicar_en_facebook': ?publicarEnFacebook,
        'publicar_en_instagram': ?publicarEnInstagram,
        'publicar_en_google': ?publicarEnGoogle,
      };
      final qp = (propietarioTipo != null && propietarioId != null)
          ? {
              'propietario_tipo': propietarioTipo,
              'propietario_id': propietarioId,
            }
          : null;
      final resp = await _dio.patch(
        '$_base/config',
        queryParameters: qp,
        data: body,
      );
      return ConfigSocial.fromJson(resp.data as Map<String, dynamic>);
    } on ApiException {
      rethrow;
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      throw const UnknownException();
    } catch (e) {
      throw UnknownException('Error inesperado: $e');
    }
  }

  /// Activa/desactiva publicacion automatica en una cuenta.
  Future<CuentaSocial> toggleAutoPublishCuenta({
    required String cuentaId,
    required bool activo,
  }) async {
    try {
      final resp = await _dio.patch(
        '$_base/cuentas/$cuentaId/toggle-auto-publish',
        queryParameters: {'activo': activo},
      );
      return CuentaSocial.fromJson(resp.data as Map<String, dynamic>);
    } on ApiException {
      rethrow;
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      throw const UnknownException();
    } catch (e) {
      throw UnknownException('Error inesperado: $e');
    }
  }

  /// Fuerza un ciclo del worker y devuelve stats.
  Future<Map<String, dynamic>> procesarColaAhora() async {
    try {
      final resp = await _dio.post('$_base/publicaciones/procesar-ahora');
      return resp.data as Map<String, dynamic>;
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
  // Facebook admin token (setup escalable)
  // =========================================================

  /// Devuelve el estado del admin token (has_token + updated_at).
  Future<AdminTokenStatus> getAdminTokenStatus() async {
    try {
      final res = await _dio.get(
        '/api/v1/admin/social/facebook/admin-token/status',
      );
      return AdminTokenStatus.fromJson(res.data as Map<String, dynamic>);
    } on ApiException {
      rethrow;
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      throw const UnknownException();
    } catch (e) {
      throw UnknownException('Error inesperado: $e');
    }
  }

  /// Genera la URL de OAuth de Facebook (para el setup inicial).
  Future<OAuthUrl> getFacebookOAuthUrl({bool appRedirect = false}) async {
    try {
      final res = await _dio.get(
        '/api/v1/admin/social/facebook/oauth/url',
        queryParameters: {'app_redirect': appRedirect},
      );
      return OAuthUrl.fromJson(res.data as Map<String, dynamic>);
    } on ApiException {
      rethrow;
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      throw const UnknownException();
    } catch (e) {
      throw UnknownException('Error inesperado: $e');
    }
  }

  /// Guarda el admin token (setup inicial).
  Future<AdminTokenStatus> setupAdminTokenDirecto(String accessToken) async {
    try {
      final res = await _dio.post(
        '/api/v1/admin/social/facebook/admin-token/setup-token',
        data: {'access_token': accessToken.trim()},
      );
      return AdminTokenStatus.fromJson(res.data as Map<String, dynamic>);
    } on ApiException {
      rethrow;
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      throw const UnknownException();
    } catch (e) {
      throw UnknownException('Error inesperado: $e');
    }
  }

  Future<AdminTokenStatus> setupAdminToken(String tokenRef) async {
    try {
      final res = await _dio.post(
        '/api/v1/admin/social/facebook/admin-token/setup',
        data: {'token_ref': tokenRef},
      );
      return AdminTokenStatus.fromJson(res.data as Map<String, dynamic>);
    } on ApiException {
      rethrow;
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      throw const UnknownException();
    } catch (e) {
      throw UnknownException('Error inesperado: $e');
    }
  }

  /// Lista las paginas de Facebook usando el admin token guardado.
  Future<List<PaginaFacebook>> listarPaginasAdmin() async {
    try {
      final res = await _dio.get('/api/v1/admin/social/facebook/paginas');
      final data = res.data as Map<String, dynamic>;
      final paginas = data['paginas'] as List<dynamic>;
      return paginas
          .map((e) => PaginaFacebook.fromJson(e as Map<String, dynamic>))
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

  /// Conecta una pagina de Facebook usando el admin token guardado.
  Future<CuentaSocial> conectarPaginaAdmin({
    required String pageId,
    required String propietarioTipo,
    String? propietarioId,
    String? alias,
  }) async {
    try {
      final data = <String, dynamic>{
        'page_id': pageId,
        'propietario_tipo': propietarioTipo,
      };
      if (propietarioId != null && propietarioId.isNotEmpty) {
        data['propietario_id'] = propietarioId;
      }
      if (alias != null && alias.isNotEmpty) {
        data['alias'] = alias;
      }
      final res = await _dio.post(
        '/api/v1/admin/social/facebook/conectar-directo',
        data: data,
      );
      final resp = res.data as Map<String, dynamic>;
      return CuentaSocial.fromJson(resp['cuenta'] as Map<String, dynamic>);
    } on ApiException {
      rethrow;
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      throw const UnknownException();
    } catch (e) {
      throw UnknownException('Error inesperado: $e');
    }
  }

  Future<List<dynamic>> listarPostsFacebook(
    String cuentaId, {
    int limit = 20,
  }) async {
    final res = await _dio.get(
      '/api/v1/admin/social/cuentas/$cuentaId/facebook/posts',
      queryParameters: {'limit': limit},
    );
    return ((res.data as Map)['items'] as List?) ?? const [];
  }

  Future<bool> editarPostFacebook({
    required String cuentaId,
    required String postId,
    required String mensaje,
  }) async {
    final res = await _dio.post(
      '/api/v1/admin/social/facebook/posts/$postId/editar',
      queryParameters: {'cuenta_id': cuentaId},
      data: {'mensaje': mensaje},
    );
    return ((res.data as Map)['ok'] as bool?) ?? true;
  }

  Future<bool> eliminarPostFacebook({
    required String cuentaId,
    required String postId,
  }) async {
    final res = await _dio.delete(
      '/api/v1/admin/social/facebook/posts/$postId',
      queryParameters: {'cuenta_id': cuentaId},
    );
    return ((res.data as Map)['ok'] as bool?) ?? true;
  }

  Future<List<dynamic>> listarComentariosFacebook({
    required String cuentaId,
    required String objectId,
    int limit = 50,
  }) async {
    final res = await _dio.get(
      '/api/v1/admin/social/facebook/objetos/$objectId/comentarios',
      queryParameters: {'cuenta_id': cuentaId, 'limit': limit},
    );
    return ((res.data as Map)['items'] as List?) ?? const [];
  }

  Future<String?> responderComentarioFacebook({
    required String cuentaId,
    required String objectId,
    required String mensaje,
  }) async {
    final res = await _dio.post(
      '/api/v1/admin/social/facebook/objetos/$objectId/comentarios',
      queryParameters: {'cuenta_id': cuentaId},
      data: {'mensaje': mensaje},
    );
    return (res.data as Map)['id'] as String?;
  }

  Future<bool> ocultarComentarioFacebook({
    required String cuentaId,
    required String commentId,
    bool ocultar = true,
  }) async {
    final res = await _dio.post(
      '/api/v1/admin/social/facebook/comentarios/$commentId/ocultar',
      queryParameters: {'cuenta_id': cuentaId},
      data: {'ocultar': ocultar},
    );
    return ((res.data as Map)['ok'] as bool?) ?? true;
  }

  Future<bool> eliminarComentarioFacebook({
    required String cuentaId,
    required String commentId,
  }) async {
    final res = await _dio.delete(
      '/api/v1/admin/social/facebook/comentarios/$commentId',
      queryParameters: {'cuenta_id': cuentaId},
    );
    return ((res.data as Map)['ok'] as bool?) ?? true;
  }

  Future<List<dynamic>> listarConversacionesFacebook(
    String cuentaId, {
    String platform = 'messenger',
    int limit = 25,
  }) async {
    final res = await _dio.get(
      '/api/v1/admin/social/cuentas/$cuentaId/facebook/conversaciones',
      queryParameters: {'platform': platform, 'limit': limit},
    );
    return ((res.data as Map)['items'] as List?) ?? const [];
  }

  Future<List<dynamic>> listarMensajesConversacionFacebook({
    required String cuentaId,
    required String conversationId,
    int limit = 50,
  }) async {
    final res = await _dio.get(
      '/api/v1/admin/social/facebook/conversaciones/$conversationId/mensajes',
      queryParameters: {'cuenta_id': cuentaId, 'limit': limit},
    );
    return ((res.data as Map)['items'] as List?) ?? const [];
  }

  Future<String?> enviarMensajeFacebook({
    required String cuentaId,
    required String recipientId,
    required String texto,
  }) async {
    final res = await _dio.post(
      '/api/v1/admin/social/cuentas/$cuentaId/facebook/mensajes',
      data: {'recipient_id': recipientId, 'texto': texto},
    );
    return (res.data as Map)['message_id'] as String?;
  }

  Future<List<dynamic>> obtenerInsightsFacebook(
    String cuentaId, {
    String period = 'day',
  }) async {
    final res = await _dio.get(
      '/api/v1/admin/social/cuentas/$cuentaId/facebook/insights',
      queryParameters: {'period': period},
    );
    return ((res.data as Map)['items'] as List?) ?? const [];
  }

  Future<Map<String, dynamic>> suscribirWebhookFacebook(String cuentaId) async {
    final res = await _dio.post(
      '/api/v1/admin/social/cuentas/$cuentaId/facebook/suscribir-webhook',
    );
    final raw = res.data;
    if (raw is Map<String, dynamic>) {
      return raw;
    }
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    return const {'ok': true};
  }

  Future<Map<String, dynamic>> obtenerConfiguracionFacebook(
    String cuentaId,
  ) async {
    final res = await _dio.get(
      '/api/v1/admin/social/cuentas/$cuentaId/facebook/configuracion',
    );
    final raw = res.data;
    if (raw is Map<String, dynamic>) {
      return raw;
    }
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    return const {};
  }

  Future<Map<String, dynamic>> actualizarConfiguracionFacebook({
    required String cuentaId,
    String? about,
    String? phone,
    String? website,
    bool? autoPublish,
  }) async {
    final payload = <String, dynamic>{};
    if (about != null) payload['about'] = about;
    if (phone != null) payload['phone'] = phone;
    if (website != null) payload['website'] = website;
    if (autoPublish != null) payload['auto_publish'] = autoPublish;
    final res = await _dio.patch(
      '/api/v1/admin/social/cuentas/$cuentaId/facebook/configuracion',
      data: payload,
    );
    final raw = res.data;
    if (raw is Map<String, dynamic>) {
      return raw;
    }
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    return const {'ok': true};
  }
}
