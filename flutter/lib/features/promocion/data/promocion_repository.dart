/// Repositorio del modulo promocion (afiches SVG).
///
/// Endpoints que consume:
///   GET  /api/v1/admin/promocion/plantillas
///   POST /api/v1/admin/promocion/generar
library;

import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'package:baqueano_natales/core/network/api_exceptions.dart';
import 'package:baqueano_natales/core/network/dio_client.dart';
import 'package:baqueano_natales/features/promocion/domain/afiche.dart';

class PromocionRepository {
  PromocionRepository({Dio? dio}) : _dio = dio ?? DioClient.instance;

  final Dio _dio;

  static const String _base = '/api/v1/admin/promocion';

  /// Lista las plantillas disponibles.
  Future<List<PlantillaInfo>> listarPlantillas() async {
    try {
      final resp = await _dio.get('$_base/plantillas');
      final data = resp.data as Map<String, dynamic>;
      return (data['plantillas'] as List)
          .map((j) => PlantillaInfo.fromJson(j as Map<String, dynamic>))
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

  /// Genera un afiche SVG.
  Future<AficheGenerado> generarAfiche({
    required String plantilla,
    required TamanoAfiche tamano,
    required Map<String, dynamic> params,
  }) async {
    try {
      final resp = await _dio.post(
        '$_base/generar',
        data: {
          'plantilla': plantilla,
          'tamano': tamano.id,
          'params': params,
        },
      );
      return AficheGenerado.fromJson(resp.data as Map<String, dynamic>);
    } on ApiException {
      rethrow;
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      throw const UnknownException();
    } catch (e) {
      throw UnknownException('Error inesperado: $e');
    }
  }

  /// Genera el afiche como PNG (bytes).
  ///
  /// Util para descargar y compartir.
  Future<Uint8List> generarAfichePng({
    required String plantilla,
    required TamanoAfiche tamano,
    required Map<String, dynamic> params,
  }) async {
    try {
      final resp = await _dio.post(
        '$_base/generar-png',
        data: {
          'plantilla': plantilla,
          'tamano': tamano.id,
          'params': params,
        },
        options: Options(responseType: ResponseType.bytes),
      );
      return Uint8List.fromList(resp.data as List<int>);
    } on ApiException {
      rethrow;
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      throw const UnknownException();
    } catch (e) {
      throw UnknownException('Error inesperado: $e');
    }
  }

  /// Genera + publica el afiche en las redes indicadas.
  Future<PublicarAficheResult> publicarAfiche({
    required String plantilla,
    required TamanoAfiche tamano,
    required Map<String, dynamic> params,
    List<String>? redes,
    String? caption,
  }) async {
    try {
      final resp = await _dio.post(
        '$_base/publicar',
        data: {
          'plantilla': plantilla,
          'tamano': tamano.id,
          'params': params,
          'redes': ?redes,
          if (caption != null && caption.isNotEmpty) 'caption': caption,
        },
      );
      return PublicarAficheResult.fromJson(
        resp.data as Map<String, dynamic>,
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
}

/// Resultado de publicar un afiche.
class PublicarAficheResult {
  const PublicarAficheResult({
    required this.aficheUrl,
    required this.aficheFilename,
    required this.publicaciones,
    required this.redes,
  });

  final String aficheUrl;
  final String aficheFilename;
  final List<String> publicaciones;
  final List<String> redes;

  factory PublicarAficheResult.fromJson(Map<String, dynamic> json) {
    return PublicarAficheResult(
      aficheUrl: json['afiche_url'] as String,
      aficheFilename: json['afiche_filename'] as String,
      publicaciones: (json['publicaciones'] as List)
          .map((e) => e as String)
          .toList(),
      redes: (json['redes'] as List).map((e) => e as String).toList(),
    );
  }
}
