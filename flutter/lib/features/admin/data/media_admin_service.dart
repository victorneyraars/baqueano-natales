import 'package:dio/dio.dart';
import 'package:baqueano_natales/core/network/dio_client.dart';
import 'package:baqueano_natales/features/admin/domain/media_asset.dart';

class MediaAdminService {
  final Dio _dio = DioClient.instance;

  Future<List<MediaAsset>> listarPendientes() async {
    final res = await _dio.get('/api/v1/media/pendientes');
    final data = res.data as Map<String, dynamic>;
    final items = data['items'] as List<dynamic>;
    return items
        .map((e) => MediaAsset.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> cambiarEstado({
    required String assetId,
    required String estado,
  }) async {
    await _dio.patch('/api/v1/media/$assetId/estado', data: {'estado': estado});
  }
}
