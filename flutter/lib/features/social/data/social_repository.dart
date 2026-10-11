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

import 'package:dio/dio.dart';

import 'package:baqueano_natales/core/network/api_exceptions.dart';
import 'package:baqueano_natales/core/network/dio_client.dart';
import 'package:baqueano_natales/features/social/domain/cuenta_social.dart';

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
  Future<ConfigSocial> obtenerConfig() async {
    try {
      final resp = await _dio.get('$_base/config');
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

  /// Actualiza la config global (parcial). Solo envia los campos no-null.
  Future<ConfigSocial> actualizarConfig({
    bool? autoPublish,
    String? destino,
    bool? publicarEnFacebook,
    bool? publicarEnInstagram,
    bool? publicarEnGoogle,
  }) async {
    try {
      final body = <String, dynamic>{
        if (autoPublish != null) 'auto_publish': autoPublish,
        if (destino != null) 'destino': destino,
        if (publicarEnFacebook != null)
          'publicar_en_facebook': publicarEnFacebook,
        if (publicarEnInstagram != null)
          'publicar_en_instagram': publicarEnInstagram,
        if (publicarEnGoogle != null) 'publicar_en_google': publicarEnGoogle,
      };
      final resp = await _dio.patch('$_base/config', data: body);
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
}
