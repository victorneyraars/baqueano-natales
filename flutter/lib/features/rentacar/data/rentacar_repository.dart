/// Repositorio de Rent a Car (propietario/prestador).
///
/// Endpoints que consume:
///   GET    /api/v1/mis-vehiculos-rentacar
///   POST   /api/v1/mis-vehiculos-rentacar
///   GET    /api/v1/mis-vehiculos-rentacar/{id}
///   PUT    /api/v1/mis-vehiculos-rentacar/{id}
///   DELETE /api/v1/mis-vehiculos-rentacar/{id}
///   POST   /api/v1/mis-vehiculos-rentacar/{id}/imagen/presigned
///   POST   /api/v1/mis-vehiculos-rentacar/{id}/imagen/confirmar
library;

import 'package:dio/dio.dart';
import 'package:baqueano_natales/core/network/api_exceptions.dart';
import 'package:baqueano_natales/core/network/dio_client.dart';
import 'package:baqueano_natales/features/rentacar/domain/vehiculo.dart';

class RentacarRepository {
  RentacarRepository({Dio? dio}) : _dio = dio ?? DioClient.instance;

  final Dio _dio;

  Future<List<Vehiculo>> listarMisVehiculos() async {
    try {
      final res = await _dio.get('/api/v1/mis-vehiculos-rentacar');
      final list = res.data as List<dynamic>;
      return list
          .map((v) => Vehiculo.fromJson(v as Map<String, dynamic>))
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

  Future<Vehiculo> crearVehiculo(Map<String, dynamic> payload) async {
    try {
      final res = await _dio.post(
        '/api/v1/mis-vehiculos-rentacar',
        data: payload,
      );
      return Vehiculo.fromJson(res.data as Map<String, dynamic>);
    } on ApiException {
      rethrow;
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      throw const UnknownException();
    } catch (e) {
      throw UnknownException('Error inesperado: $e');
    }
  }

  Future<Vehiculo> actualizarVehiculo(
    String id,
    Map<String, dynamic> payload,
  ) async {
    try {
      final res = await _dio.put(
        '/api/v1/mis-vehiculos-rentacar/$id',
        data: payload,
      );
      return Vehiculo.fromJson(res.data as Map<String, dynamic>);
    } on ApiException {
      rethrow;
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      throw const UnknownException();
    } catch (e) {
      throw UnknownException('Error inesperado: $e');
    }
  }

  Future<void> eliminarVehiculo(String id) async {
    try {
      await _dio.delete('/api/v1/mis-vehiculos-rentacar/$id');
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
