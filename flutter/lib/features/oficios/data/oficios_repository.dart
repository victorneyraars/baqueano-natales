/// Repositorio del modulo oficios (mecanica).
///
/// Encapsula las llamadas HTTP al backend. No maneja estado.
library;

import 'package:dio/dio.dart';

import 'package:baqueano_natales/core/network/api_exceptions.dart';
import 'package:baqueano_natales/core/network/dio_client.dart';
import 'package:baqueano_natales/features/oficios/domain/mecanica_categoria.dart';
import 'package:baqueano_natales/features/oficios/domain/vehiculo.dart';

class OficiosRepository {
  OficiosRepository({Dio? dio}) : _dio = dio ?? DioClient.instance;

  final Dio _dio;

  // =========================================================
  // Publico
  // =========================================================

  /// Lista las categorias de mecanica activas.
  Future<List<MecanicaCategoria>> listarCategoriasMecanica() async {
    try {
      final res = await _dio.get('/api/v1/oficios/mecanica/categorias');
      final list = res.data as List<dynamic>;
      return list
          .map((c) => MecanicaCategoria.fromJson(c as Map<String, dynamic>))
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

  // =========================================================
  // Cliente: mis vehiculos
  // =========================================================

  /// Lista los vehiculos del usuario autenticado.
  Future<List<Vehiculo>> listarMisVehiculos() async {
    try {
      final res = await _dio.get('/api/v1/mis-vehiculos');
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

  /// Crea un vehiculo (objeto_servicio + vehiculo).
  Future<Vehiculo> crearVehiculo(Vehiculo vehiculo) async {
    try {
      final res = await _dio.post(
        '/api/v1/mis-vehiculos',
        data: vehiculo.toCreateJson(),
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

  /// Obtiene el detalle de un vehiculo por su objeto_servicio_id.
  Future<Vehiculo> obtenerVehiculo(String objetoId) async {
    try {
      final res = await _dio.get('/api/v1/mis-vehiculos/$objetoId');
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

  /// Actualiza un vehiculo (PATCH parcial).
  Future<Vehiculo> actualizarVehiculo(
    String objetoId,
    Map<String, dynamic> cambios,
  ) async {
    try {
      final res = await _dio.patch(
        '/api/v1/mis-vehiculos/$objetoId',
        data: cambios,
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

  /// Desactiva (soft delete) un vehiculo.
  Future<void> eliminarVehiculo(String objetoId) async {
    try {
      await _dio.delete('/api/v1/mis-vehiculos/$objetoId');
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