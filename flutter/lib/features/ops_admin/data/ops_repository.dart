/// Repositorio del Ops Dashboard (Fase 1 read-only).
///
/// Encapsula las llamadas HTTP al backend. No maneja estado, solo hace
/// las llamadas y devuelve datos o lanza ApiException.
///
/// Endpoints que consume:
///   GET /api/v1/admin/ops/health
///   GET /api/v1/admin/ops/runs
///   GET /api/v1/admin/ops/runs/{run_id}
///   GET /api/v1/admin/ops/tracks
///   GET /api/v1/admin/ops/links
library;

import 'package:dio/dio.dart';

import 'package:baqueano_natales/core/network/api_exceptions.dart';
import 'package:baqueano_natales/core/network/dio_client.dart';
import 'package:baqueano_natales/features/ops_admin/domain/ops_models.dart';

class OpsRepository {
  OpsRepository({Dio? dio}) : _dio = dio ?? DioClient.instance;

  final Dio _dio;

  static const String _base = '/api/v1/admin/ops';

  /// Estado consolidado del sistema (health + ultimo release + stats 24h).
  Future<SystemHealth> health() async {
    try {
      final res = await _dio.get('$_base/health');
      return SystemHealth.fromJson(res.data as Map<String, dynamic>);
    } on ApiException {
      rethrow;
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      throw const UnknownException();
    } catch (e) {
      throw UnknownException('Error inesperado: $e');
    }
  }

  /// Lista los ultimos workflow runs. `branch` opcional.
  Future<RunsResponse> runs({
    int limit = 10,
    String? branch,
  }) async {
    try {
      final res = await _dio.get(
        '$_base/runs',
        queryParameters: {
          'limit': limit,
          'branch': ?branch,
        },
      );
      return RunsResponse.fromJson(res.data as Map<String, dynamic>);
    } on ApiException {
      rethrow;
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      throw const UnknownException();
    } catch (e) {
      throw UnknownException('Error inesperado: $e');
    }
  }

  /// Detalle de un run especifico (incluye jobs + steps).
  Future<RunDetail> runDetail(int runId) async {
    try {
      final res = await _dio.get('$_base/runs/$runId');
      return RunDetail.fromJson(res.data as Map<String, dynamic>);
    } on ApiException {
      rethrow;
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      throw const UnknownException();
    } catch (e) {
      throw UnknownException('Error inesperado: $e');
    }
  }

  /// Versiones actuales por track de las 2 apps (Play Console).
  Future<TracksResponse> tracks() async {
    try {
      final res = await _dio.get('$_base/tracks');
      return TracksResponse.fromJson(res.data as Map<String, dynamic>);
    } on ApiException {
      rethrow;
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      throw const UnknownException();
    } catch (e) {
      throw UnknownException('Error inesperado: $e');
    }
  }

  /// Links de descarga (opt-in + Play Store) de las 2 apps.
  Future<LinksResponse> links() async {
    try {
      final res = await _dio.get('$_base/links');
      return LinksResponse.fromJson(res.data as Map<String, dynamic>);
    } on ApiException {
      rethrow;
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      throw const UnknownException();
    } catch (e) {
      throw UnknownException('Error inesperado: $e');
    }
  }
  /// Quick links a dashboards externos (Play Console, GitHub, Cloudflare, etc.).
  Future<QuickLinksResponse> quickLinks() async {
    try {
      final res = await _dio.get('$_base/quick-links');
      return QuickLinksResponse.fromJson(res.data as Map<String, dynamic>);
    } on ApiException {
      rethrow;
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      throw const UnknownException();
    } catch (e) {
      throw UnknownException('Error inesperado: $e');
    }
  }
  // ==================== Fase 2 - Release ====================

  /// Preview de un release (dry-run). Valida + calcula versiones.
  Future<ReleasePreview> releasePreview({
    required String versionName,
    String branch = 'main',
  }) async {
    try {
      final res = await _dio.post(
        '$_base/release/preview',
        data: {
          'version_name': versionName,
          'branch': branch,
        },
      );
      return ReleasePreview.fromJson(res.data as Map<String, dynamic>);
    } on ApiException {
      rethrow;
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      throw const UnknownException();
    } catch (e) {
      throw UnknownException('Error inesperado: $e');
    }
  }

  /// Ejecuta el release: crea el tag en GitHub.
  Future<ReleaseTrigger> releaseTrigger({
    required String previewToken,
  }) async {
    try {
      final res = await _dio.post(
        '$_base/release/trigger',
        data: {
          'preview_token': previewToken,
          'confirm': 'CONFIRMAR',
        },
      );
      return ReleaseTrigger.fromJson(res.data as Map<String, dynamic>);
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