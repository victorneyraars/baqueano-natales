/// Repositorio de notificaciones admin.
///
/// Encapsula las llamadas HTTP al backend. No maneja estado, solo hace
/// las llamadas y devuelve datos o lanza ApiException.
///
/// Endpoints que consume:
///   POST /api/v1/admin/notificaciones/enviar
///   GET  /api/v1/admin/notificaciones
///   GET  /api/v1/admin/notificaciones/stats
library;

import 'package:dio/dio.dart';

import 'package:baqueano_natales/core/network/api_exceptions.dart';
import 'package:baqueano_natales/core/network/dio_client.dart';
import 'package:baqueano_natales/features/notificaciones/domain/notificacion.dart';
import 'package:baqueano_natales/features/notificaciones/domain/segmento.dart';
import 'package:baqueano_natales/features/notificaciones/domain/preferencia_notificacion.dart';
import 'package:baqueano_natales/features/notificaciones/domain/stats.dart';

class EnvioMasivoResult {
  const EnvioMasivoResult({
    required this.total,
    required this.enviados,
    required this.fallidos,
    required this.skipped,
  });

  final int total;
  final int enviados;
  final int fallidos;
  final int skipped;

  factory EnvioMasivoResult.fromJson(Map<String, dynamic> json) {
    return EnvioMasivoResult(
      total: (json['total'] as num).toInt(),
      enviados: (json['enviados'] as num).toInt(),
      fallidos: (json['fallidos'] as num).toInt(),
      skipped: (json['skipped'] as num).toInt(),
    );
  }
}

class NotificacionesRepository {
  NotificacionesRepository({Dio? dio}) : _dio = dio ?? DioClient.instance;

  final Dio _dio;

  /// Envia una notificacion a un segmento. Devuelve contadores.
  Future<EnvioMasivoResult> enviar({
    required String titulo,
    required String body,
    required String tipo,
    required Segmento segmento,
    String? analyticsLabel,
  }) async {
    try {
      final res = await _dio.post(
        '/api/v1/admin/notificaciones/enviar',
        data: {
          'titulo': titulo,
          'body': body,
          'tipo': tipo,
          'segmento': segmento.toJson(),
          'analytics_label': ?analyticsLabel,
        },
      );
      return EnvioMasivoResult.fromJson(res.data as Map<String, dynamic>);
    } on ApiException {
      rethrow;
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      throw const UnknownException();
    } catch (e) {
      throw UnknownException('Error inesperado: $e');
    }
  }

  /// Lista el historial de notificaciones con filtros opcionales.
  Future<List<NotificacionAdmin>> listar({
    String? tipo,
    String? estado,
    DateTime? desde,
    DateTime? hasta,
    int limit = 100,
    int offset = 0,
  }) async {
    try {
      final res = await _dio.get(
        '/api/v1/admin/notificaciones',
        queryParameters: {
          'tipo': ?tipo,
          'estado': ?estado,
          'desde': ?desde?.toIso8601String(),
          'hasta': ?hasta?.toIso8601String(),
          'limit': limit,
          'offset': offset,
        },
      );
      final list = res.data as List<dynamic>;
      return list
          .map((e) => NotificacionAdmin.fromJson(e as Map<String, dynamic>))
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

  /// Devuelve el dashboard de estadisticas.
  Future<StatsNotificacion> stats({DateTime? desde, DateTime? hasta}) async {
    try {
      final res = await _dio.get(
        '/api/v1/admin/notificaciones/stats',
        queryParameters: {
          'desde': ?desde?.toIso8601String(),
          'hasta': ?hasta?.toIso8601String(),
        },
      );
      return StatsNotificacion.fromJson(res.data as Map<String, dynamic>);
    } on ApiException {
      rethrow;
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      throw const UnknownException();
    } catch (e) {
      throw UnknownException('Error inesperado: $e');
    }
  }

  // ==================== Endpoints del usuario (no admin) ====================

  /// Lista las notificaciones del usuario autenticado.
  Future<List<NotificacionAdmin>> misNotificaciones({
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final res = await _dio.get(
        '/api/v1/notificaciones',
        queryParameters: {'limit': limit, 'offset': offset},
      );
      final list = res.data as List<dynamic>;
      return list
          .map((e) => NotificacionAdmin.fromJson(e as Map<String, dynamic>))
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

  /// Marca una notificacion como abierta/leida.
  Future<void> marcarAbierta(String notifId) async {
    try {
      await _dio.post('/api/v1/notificaciones/$notifId/abierta');
    } on ApiException {
      rethrow;
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      throw const UnknownException();
    } catch (e) {
      throw UnknownException('Error inesperado: $e');
    }
  }

  /// Devuelve las preferencias de notificacion del usuario.
  Future<PreferenciaNotificacion> misPreferencias() async {
    try {
      final res = await _dio.get(
        '/api/v1/usuarios/me/preferencias-notificacion',
      );
      return PreferenciaNotificacion.fromJson(res.data as Map<String, dynamic>);
    } on ApiException {
      rethrow;
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      throw const UnknownException();
    } catch (e) {
      throw UnknownException('Error inesperado: $e');
    }
  }

  /// Actualiza las preferencias (parcial). Devuelve las actualizadas.
  Future<PreferenciaNotificacion> actualizarPreferencias({
    bool? recordatorios,
    bool? promociones,
    bool? confirmaciones,
    bool? sistema,
    bool? quietHoursEnabled,
    String? quietHoursInicio,
    String? quietHoursFin,
    String? timezone,
  }) async {
    try {
      final res = await _dio.put(
        '/api/v1/usuarios/me/preferencias-notificacion',
        data: {
          'recordatorios': ?recordatorios,
          'promociones': ?promociones,
          'confirmaciones': ?confirmaciones,
          'sistema': ?sistema,
          'quiet_hours_enabled': ?quietHoursEnabled,
          'quiet_hours_inicio': ?quietHoursInicio,
          'quiet_hours_fin': ?quietHoursFin,
          'timezone': ?timezone,
        },
      );
      return PreferenciaNotificacion.fromJson(res.data as Map<String, dynamic>);
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
