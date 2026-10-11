/// Repositorio del modulo promocion (afiches SVG).
///
/// Endpoints que consume:
///   GET  /api/v1/admin/promocion/plantillas
///   POST /api/v1/admin/promocion/generar
library;

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
}
