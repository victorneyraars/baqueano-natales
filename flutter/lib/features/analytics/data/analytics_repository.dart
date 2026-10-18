/// Repositorio del módulo Analytics (Cloudflare Web Analytics).
///
/// Endpoints que consume:
///   GET /api/v1/analytics/stats?days=N&hostname=X (admin)
///   GET /api/v1/analytics/mi-prestador/stats?days=N (prestador)
library;

import 'package:dio/dio.dart';

import 'package:baqueano_natales/core/network/api_exceptions.dart';
import 'package:baqueano_natales/core/network/dio_client.dart';
import 'package:baqueano_natales/features/analytics/domain/stats_response.dart';

class AnalyticsRepository {
  AnalyticsRepository({Dio? dio}) : _dio = dio ?? DioClient.instance;

  final Dio _dio;

  static const String _base = '/api/v1/analytics';

  /// Stats de todos los sitios (admin) o filtrados por hostname.
  Future<StatsResponse> fetchStats({
    int days = 7,
    String? hostname,
  }) async {
    try {
      final res = await _dio.get(
        '$_base/stats',
        queryParameters: {
          'days': days,
          if (hostname case final h?) 'hostname': h,
        },
      );
      return StatsResponse.fromJson(res.data as Map<String, dynamic>);
    } on ApiException {
      rethrow;
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      throw const UnknownException();
    } catch (e) {
      throw UnknownException('Error inesperado: $e');
    }
  }

  /// Stats del prestador autenticado (auto-filtro por su hostname).
  Future<StatsResponse> fetchMyStats({int days = 7}) async {
    try {
      final res = await _dio.get(
        '$_base/mi-prestador/stats',
        queryParameters: {'days': days},
      );
      return StatsResponse.fromJson(res.data as Map<String, dynamic>);
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
