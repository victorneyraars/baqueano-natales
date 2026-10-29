import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'package:baqueano_natales/core/network/api_exceptions.dart';
import 'package:baqueano_natales/core/network/dio_client.dart';
import 'package:baqueano_natales/features/brand_kit/domain/brand_asset.dart';

/// Repositorio del brand kit del prestador.
class BrandKitRepository {
  BrandKitRepository({Dio? dio}) : _dio = dio ?? DioClient.instance;

  final Dio _dio;

  Future<BrandKit> listAssets(String slug) async {
    try {
      final res = await _dio.get('/api/v1/mis-brand/$slug/assets/list');
      return BrandKit.fromJson(res.data as Map<String, dynamic>);
    } on ApiException {
      rethrow;
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      throw const UnknownException();
    } catch (e) {
      throw UnknownException('Error inesperado: $e');
    }
  }

  Future<Uint8List> downloadAssetBytes(String slug, String path) async {
    try {
      final res = await _dio.get<List<int>>(
        '/api/v1/mis-brand/$slug/assets/file/$path',
        options: Options(responseType: ResponseType.bytes),
      );
      return Uint8List.fromList(res.data ?? const []);
    } on ApiException {
      rethrow;
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      throw const UnknownException();
    } catch (e) {
      throw UnknownException('Error inesperado: $e');
    }
  }

  Future<void> downloadZipToPath(
    String slug,
    String savePath,
    void Function(int received, int total)? onProgress,
  ) async {
    await _dio.download(
      '/api/v1/mis-brand/$slug/assets',
      savePath,
      onReceiveProgress: onProgress,
    );
  }
}
