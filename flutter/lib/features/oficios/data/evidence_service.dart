import 'dart:io';

import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;
import 'package:baqueano_natales/core/network/dio_client.dart';

class EvidenceService {
  final Dio _dio = DioClient.instance;

  Future<String?> uploadEvidence({
    required File file,
    required String turnoId,
    required String fase,
    required String contentType,
    String? descripcion,
    bool visiblePublico = false,
    void Function(double)? onProgress,
  }) async {
    try {
      final response = await _dio.post(
        '/api/v1/media/presigned-url',
        data: {
          'filename': file.path.split('/').last,
          'content_type': contentType,
          'turno_id': turnoId,
          'fase': fase,
        },
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        return null;
      }

      final uploadUrl = response.data['upload_url'] as String;
      final publicUrl = response.data['public_url'] as String;
      final objectKey = response.data['object_key'] as String;

      onProgress?.call(0.1);
      final fileBytes = await file.readAsBytes();
      final uploadResponse = await http.put(
        Uri.parse(uploadUrl),
        headers: {'Content-Type': contentType},
        body: fileBytes,
      );

      if (uploadResponse.statusCode != 200 &&
          uploadResponse.statusCode != 204) {
        return null;
      }
      onProgress?.call(0.9);

      await _dio.post(
        '/api/v1/media/register',
        data: {
          'turno_id': turnoId,
          'tipo': contentType.startsWith('video') ? 'video' : 'foto',
          'fase': fase,
          'object_key': objectKey,
          'url_publica': publicUrl,
        },
      );

      onProgress?.call(1.0);
      return publicUrl;
    } catch (e) {
      return null;
    }
  }
}
