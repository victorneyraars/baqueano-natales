/// ImageProvider custom que descarga imagenes autenticadas con JWT.
///
/// A diferencia de `Image.network`, este provider usa el `DioClient`
/// singleton (que ya inyecta `Authorization: Bearer <jwt>` en cada
/// request), permitiendo servir imagenes privadas (fotos de orden,
/// documentos, etc.) sin exponer un endpoint publico.
///
/// Reusable en cualquier feature. No sabe nada de ordenes ni de fotos:
/// solo "bajar bytes autenticados de una URL del backend".
///
/// Uso:
///   Image(image: AuthedImage(url: '/api/v1/ordenes/fotos/.../archivo/thumb'))
///
/// Nota: la URL puede ser relativa (recomendado); se resuelve con el
/// baseUrl del DioClient.
library;

import 'dart:async';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'package:baqueano_natales/core/network/dio_client.dart';

@immutable
class AuthedImage extends ImageProvider<AuthedImage> {
  const AuthedImage({required this.url, this.scale = 1.0});

  /// URL relativa (ej. `/api/v1/ordenes/.../thumb`) o absoluta.
  final String url;
  final double scale;

  @override
  Future<AuthedImage> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<AuthedImage>(this);
  }

  @override
  ImageStreamCompleter loadImage(AuthedImage key, ImageDecoderCallback decode) {
    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key, decode),
      scale: key.scale,
      debugLabel: key.url,
      informationCollector: () => <DiagnosticsNode>[
        DiagnosticsProperty<ImageProvider>('Image provider', this),
        DiagnosticsProperty<String>('URL', key.url),
      ],
    );
  }

  Future<ui.Codec> _loadAsync(
    AuthedImage key,
    ImageDecoderCallback decode,
  ) async {
    assert(key == this);

    try {
      final res = await DioClient.instance.get<List<int>>(
        key.url,
        options: Options(responseType: ResponseType.bytes),
      );
      final bytes = Uint8List.fromList(res.data ?? const <int>[]);
      if (bytes.isEmpty) {
        throw Exception('Respuesta vacia');
      }
      final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      return await decode(buffer);
    } on DioException catch (e) {
      throw NetworkImageLoadException(
        statusCode: e.response?.statusCode ?? 0,
        uri: Uri.parse(key.url),
      );
    }
  }

  @override
  bool operator ==(Object other) {
    if (other is! AuthedImage) return false;
    return other.url == url && other.scale == scale;
  }

  @override
  int get hashCode => Object.hash(url, scale);

  @override
  String toString() =>
      '${objectRuntimeType(this, 'AuthedImage')}("$url", scale: $scale)';
}
