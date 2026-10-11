/// Repositorio del modulo oficios (mecanica).
///
/// Encapsula las llamadas HTTP al backend. No maneja estado.
library;

import 'package:dio/dio.dart';

import 'package:baqueano_natales/core/network/api_exceptions.dart';
import 'package:baqueano_natales/core/network/dio_client.dart';
import 'package:baqueano_natales/features/oficios/domain/mecanica_categoria.dart';
import 'package:baqueano_natales/features/oficios/domain/orden_item.dart';
import 'package:baqueano_natales/features/oficios/domain/orden_trabajo.dart';
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

  // =========================================================
  // M2: Ordenes de trabajo (prestador)
  // =========================================================

  /// Lista ordenes del prestador (opcional filtrar por estado).
  Future<List<OrdenTrabajo>> listarOrdenesPrestador(
    String prestadorId, {
    String? estado,
    int limit = 100,
  }) async {
    try {
      final query = <String, dynamic>{'limit': limit};
      if (estado != null && estado.isNotEmpty) query['estado'] = estado;
      final res = await _dio.get(
        '/api/v1/mis-prestadores/$prestadorId/ordenes',
        queryParameters: query,
      );
      final list = res.data as List<dynamic>;
      return list
          .map((o) => OrdenTrabajo.fromJson(o as Map<String, dynamic>))
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

  /// Crea una orden en el taller.
  Future<OrdenTrabajo> crearOrden(
    String prestadorId,
    OrdenTrabajo orden,
  ) async {
    try {
      final res = await _dio.post(
        '/api/v1/mis-prestadores/$prestadorId/ordenes',
        data: orden.toCreateJson(),
      );
      return OrdenTrabajo.fromJson(res.data as Map<String, dynamic>);
    } on ApiException {
      rethrow;
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      throw const UnknownException();
    } catch (e) {
      throw UnknownException('Error inesperado: $e');
    }
  }

  /// Detalle de una orden del taller (con items + historial).
  Future<OrdenTrabajo> detalleOrdenPrestador(
    String prestadorId,
    String ordenId,
  ) async {
    try {
      final res = await _dio.get(
        '/api/v1/mis-prestadores/$prestadorId/ordenes/$ordenId',
      );
      return OrdenTrabajo.fromJson(res.data as Map<String, dynamic>);
    } on ApiException {
      rethrow;
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      throw const UnknownException();
    } catch (e) {
      throw UnknownException('Error inesperado: $e');
    }
  }

  /// Agrega un item al presupuesto.
  Future<OrdenItem> agregarItem(
    String prestadorId,
    String ordenId,
    OrdenItem item,
  ) async {
    try {
      final res = await _dio.post(
        '/api/v1/mis-prestadores/$prestadorId/ordenes/$ordenId/items',
        data: item.toCreateJson(),
      );
      return OrdenItem.fromJson(res.data as Map<String, dynamic>);
    } on ApiException {
      rethrow;
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      throw const UnknownException();
    } catch (e) {
      throw UnknownException('Error inesperado: $e');
    }
  }

  /// Elimina un item del presupuesto.
  Future<void> eliminarItem(
    String prestadorId,
    String ordenId,
    String itemId,
  ) async {
    try {
      await _dio.delete(
        '/api/v1/mis-prestadores/$prestadorId/ordenes/$ordenId/items/$itemId',
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

  /// Cambia el estado de la orden.
  Future<OrdenTrabajo> cambiarEstado(
    String prestadorId,
    String ordenId,
    String nuevoEstado, {
    String? motivo,
  }) async {
    try {
      final res = await _dio.post(
        '/api/v1/mis-prestadores/$prestadorId/ordenes/$ordenId/estado',
        data: {
          'nuevo_estado': nuevoEstado,
          'motivo': ?motivo,
        },
      );
      return OrdenTrabajo.fromJson(res.data as Map<String, dynamic>);
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
  // M2: Ordenes de trabajo (cliente)
  // =========================================================

  /// Lista las ordenes del cliente logueado.
  Future<List<OrdenTrabajo>> listarMisOrdenes({
    String? estado,
    int limit = 100,
  }) async {
    try {
      final query = <String, dynamic>{'limit': limit};
      if (estado != null && estado.isNotEmpty) query['estado'] = estado;
      final res = await _dio.get(
        '/api/v1/mis-ordenes',
        queryParameters: query,
      );
      final list = res.data as List<dynamic>;
      return list
          .map((o) => OrdenTrabajo.fromJson(o as Map<String, dynamic>))
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

  /// Detalle de una orden del cliente.
  Future<OrdenTrabajo> detalleMiOrden(String ordenId) async {
    try {
      final res = await _dio.get('/api/v1/mis-ordenes/$ordenId');
      return OrdenTrabajo.fromJson(res.data as Map<String, dynamic>);
    } on ApiException {
      rethrow;
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      throw const UnknownException();
    } catch (e) {
      throw UnknownException('Error inesperado: $e');
    }
  }

  /// Aprueba/rechaza el presupuesto completo.
  Future<OrdenTrabajo> aprobarPresupuesto(
    String ordenId, {
    bool aprobarTodos = false,
    List<Map<String, dynamic>>? items,
    String? motivoRechazo,
  }) async {
    try {
      final data = <String, dynamic>{
        'aprobar_todos': aprobarTodos,
        'items': ?items,
        'motivo_rechazo': ?motivoRechazo,
      };
      final res = await _dio.post(
        '/api/v1/mis-ordenes/$ordenId/aprobar',
        data: data,
      );
      return OrdenTrabajo.fromJson(res.data as Map<String, dynamic>);
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