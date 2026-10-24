/// Repositorio del modulo oficios (mecanica).
///
/// Encapsula las llamadas HTTP al backend. No maneja estado.
library;

import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'package:baqueano_natales/core/network/api_exceptions.dart';
import 'package:baqueano_natales/core/network/dio_client.dart';
import 'package:baqueano_natales/features/oficios/domain/cliente_busqueda.dart';
import 'package:baqueano_natales/features/oficios/domain/garantia.dart';
import 'package:baqueano_natales/features/oficios/domain/mecanica_categoria.dart';
import 'package:baqueano_natales/features/oficios/domain/recordatorio.dart';
import 'package:baqueano_natales/features/oficios/domain/orden_foto.dart';
import 'package:baqueano_natales/features/oficios/domain/orden_item.dart';
import 'package:baqueano_natales/features/oficios/domain/orden_trabajo.dart';
import 'package:baqueano_natales/features/oficios/domain/reporte_taller.dart';
import 'package:baqueano_natales/features/prestadores/domain/review.dart';
import 'package:baqueano_natales/features/oficios/domain/turno.dart';
import 'package:baqueano_natales/features/oficios/domain/vehiculo.dart';
import 'package:baqueano_natales/features/oficios/domain/servicio.dart';

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
        data: {'nuevo_estado': nuevoEstado, 'motivo': ?motivo},
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
      final res = await _dio.get('/api/v1/mis-ordenes', queryParameters: query);
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

  // =========================================================
  // M2+: Busqueda de clientes y vehiculos (para crear ordenes)
  // =========================================================

  /// Busca clientes por email, nombre o apellido.
  Future<List<ClienteBusqueda>> buscarClientes(
    String prestadorId,
    String query, {
    int limit = 20,
  }) async {
    if (query.trim().length < 2) return [];
    try {
      final res = await _dio.get(
        '/api/v1/mis-prestadores/$prestadorId/clientes',
        queryParameters: {'q': query.trim(), 'limit': limit},
      );
      final list = res.data as List<dynamic>;
      return list
          .map((c) => ClienteBusqueda.fromJson(c as Map<String, dynamic>))
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

  /// Lista los vehiculos de un cliente.
  Future<List<Vehiculo>> listarVehiculosDeCliente(
    String prestadorId,
    String clienteId,
  ) async {
    try {
      final res = await _dio.get(
        '/api/v1/mis-prestadores/$prestadorId/clientes/$clienteId/vehiculos',
      );
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

  // =========================================================
  // M3: Turnos (cliente)
  // =========================================================

  /// Lista los turnos del cliente autenticado.
  Future<List<Turno>> listarMisTurnos({String? estado}) async {
    try {
      final query = <String, dynamic>{};
      if (estado != null && estado.isNotEmpty) query['estado'] = estado;
      final res = await _dio.get(
        '/api/v1/mis-turnos',
        queryParameters: query.isEmpty ? null : query,
      );
      final list = res.data as List<dynamic>;
      return list
          .map((t) => Turno.fromJson(t as Map<String, dynamic>))
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

  /// Crea un turno (cliente reserva con un prestador).
  /// Lista los servicios activos del catalogo de un prestador.
  Future<List<Servicio>> listarServiciosPrestador(String prestadorId) async {
    try {
      final res = await _dio.get('/api/v1/prestadores/\$prestadorId/servicios');
      final list = res.data as List<dynamic>;
      return list
          .map((j) => Servicio.fromJson(j as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      throw const UnknownException();
    } catch (e) {
      throw UnknownException('Error inesperado: $e');
    }
  }

  Future<Turno> crearTurno({
    required String prestadorId,
    required String objetoId,
    required DateTime fechaInicio,
    int duracionMin = 30,
    String? servicioId,
    String? motivo,
    String? notasCliente,
  }) async {
    try {
      final res = await _dio.post(
        '/api/v1/mis-turnos',
        data: {
          'prestador_id': prestadorId,
          'objeto_servicio_id': objetoId,
          'fecha_inicio': fechaInicio.toUtc().toIso8601String(),
          'duracion_min': duracionMin,
          'servicio_id': ?servicioId,
          'motivo': ?motivo,
          'notas_cliente': ?notasCliente,
        },
      );
      return Turno.fromJson(res.data as Map<String, dynamic>);
    } on ApiException {
      rethrow;
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      throw const UnknownException();
    } catch (e) {
      throw UnknownException('Error inesperado: $e');
    }
  }

  /// Detalle de un turno del cliente.
  Future<Turno> detalleMiTurno(String turnoId) async {
    try {
      final res = await _dio.get('/api/v1/mis-turnos/$turnoId');
      return Turno.fromJson(res.data as Map<String, dynamic>);
    } on ApiException {
      rethrow;
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      throw const UnknownException();
    } catch (e) {
      throw UnknownException('Error inesperado: $e');
    }
  }

  /// Cancela un turno (cliente).
  Future<Turno> cancelarTurno(String turnoId, {String? motivo}) async {
    try {
      final res = await _dio.post(
        '/api/v1/mis-turnos/$turnoId/cancelar',
        data: {'motivo': ?motivo},
      );
      return Turno.fromJson(res.data as Map<String, dynamic>);
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
  // M3: Turnos (prestador)
  // =========================================================

  /// Lista los turnos del taller (agenda).
  Future<List<Turno>> listarTurnosPrestador(
    String prestadorId, {
    String? estado,
    DateTime? desde,
    DateTime? hasta,
  }) async {
    try {
      final query = <String, dynamic>{};
      if (estado != null && estado.isNotEmpty) query['estado'] = estado;
      if (desde != null) query['desde'] = desde.toUtc().toIso8601String();
      if (hasta != null) query['hasta'] = hasta.toUtc().toIso8601String();
      final res = await _dio.get(
        '/api/v1/mis-prestadores/$prestadorId/turnos',
        queryParameters: query.isEmpty ? null : query,
      );
      final list = res.data as List<dynamic>;
      return list
          .map((t) => Turno.fromJson(t as Map<String, dynamic>))
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

  /// Detalle de un turno (prestador).
  Future<Turno> detalleTurnoPrestador(
    String prestadorId,
    String turnoId,
  ) async {
    try {
      final res = await _dio.get(
        '/api/v1/mis-prestadores/$prestadorId/turnos/$turnoId',
      );
      return Turno.fromJson(res.data as Map<String, dynamic>);
    } on ApiException {
      rethrow;
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      throw const UnknownException();
    } catch (e) {
      throw UnknownException('Error inesperado: $e');
    }
  }

  /// Completa un turno con detalles (crea orden + items + entrega).
  Future<Map<String, dynamic>> completarTurnoConDetalles(
    String prestadorId,
    String turnoId, {
    required int precioFinal,
    required List<Map<String, dynamic>> serviciosRealizados,
    String? notasPrestador,
  }) async {
    try {
      final data = <String, dynamic>{
        'precio_final': precioFinal,
        'servicios_realizados': serviciosRealizados,
      };
      if (notasPrestador != null && notasPrestador.trim().isNotEmpty) {
        data['notas_prestador'] = notasPrestador.trim();
      }
      final res = await _dio.post(
        '/api/v1/mis-prestadores/$prestadorId/turnos/$turnoId/completar',
        data: data,
      );
      return res.data as Map<String, dynamic>;
    } on ApiException {
      rethrow;
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      throw const UnknownException();
    } catch (e) {
      throw UnknownException('Error inesperado: $e');
    }
  }

  /// Cambia el estado de un turno (prestador).
  Future<Turno> cambiarEstadoTurno(
    String prestadorId,
    String turnoId,
    String nuevoEstado, {
    String? motivo,
  }) async {
    try {
      final res = await _dio.post(
        '/api/v1/mis-prestadores/$prestadorId/turnos/$turnoId/estado',
        data: {'nuevo_estado': nuevoEstado, 'motivo': ?motivo},
      );
      return Turno.fromJson(res.data as Map<String, dynamic>);
    } on ApiException {
      rethrow;
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      throw const UnknownException();
    } catch (e) {
      throw UnknownException('Error inesperado: $e');
    }
  }

  /// Rechaza un turno (prestador).
  Future<Turno> rechazarTurno(
    String prestadorId,
    String turnoId, {
    String? motivo,
  }) async {
    try {
      final res = await _dio.post(
        '/api/v1/mis-prestadores/$prestadorId/turnos/$turnoId/rechazar',
        data: {'motivo': ?motivo},
      );
      return Turno.fromJson(res.data as Map<String, dynamic>);
    } on ApiException {
      rethrow;
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      throw const UnknownException();
    } catch (e) {
      throw UnknownException('Error inesperado: $e');
    }
  }

  /// Vincula una orden existente al turno.
  Future<Turno> vincularOrdenATurno(
    String prestadorId,
    String turnoId,
    String ordenId,
  ) async {
    try {
      final res = await _dio.post(
        '/api/v1/mis-prestadores/$prestadorId/turnos/$turnoId/vincular-orden',
        data: {'orden_id': ordenId},
      );
      return Turno.fromJson(res.data as Map<String, dynamic>);
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
  // M4: Garantias
  // =========================================================

  /// Obtiene la garantia activa de una orden (cliente).
  /// Devuelve null si no hay garantia.
  Future<Garantia?> obtenerGarantiaDeMiOrden(String ordenId) async {
    try {
      final res = await _dio.get('/api/v1/mis-ordenes/$ordenId/garantia');
      if (res.data == null) return null;
      return Garantia.fromJson(res.data as Map<String, dynamic>);
    } on ApiException {
      rethrow;
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      throw const UnknownException();
    } catch (e) {
      throw UnknownException('Error inesperado: $e');
    }
  }

  /// Obtiene la garantia de una orden (prestador).
  Future<Garantia?> obtenerGarantiaDeOrdenPrestador(
    String prestadorId,
    String ordenId,
  ) async {
    try {
      final res = await _dio.get(
        '/api/v1/mis-prestadores/$prestadorId/ordenes/$ordenId/garantia',
      );
      if (res.data == null) return null;
      return Garantia.fromJson(res.data as Map<String, dynamic>);
    } on ApiException {
      rethrow;
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      throw const UnknownException();
    } catch (e) {
      throw UnknownException('Error inesperado: $e');
    }
  }

  /// Crea o actualiza la garantia de una orden (prestador).
  Future<Garantia> crearGarantiaDeOrden(
    String prestadorId,
    String ordenId, {
    required String tipo,
    required int duracionDias,
    String? cobertura,
    String? condiciones,
  }) async {
    try {
      final res = await _dio.post(
        '/api/v1/mis-prestadores/$prestadorId/ordenes/$ordenId/garantia',
        data: {
          'tipo': tipo,
          'duracion_dias': duracionDias,
          'cobertura': ?cobertura,
          'condiciones': ?condiciones,
        },
      );
      return Garantia.fromJson(res.data as Map<String, dynamic>);
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
  // M4: Recordatorios (por objeto_servicio)
  // =========================================================

  /// Lista los recordatorios de un objeto_servicio.
  Future<List<Recordatorio>> listarRecordatorios(
    String objetoId, {
    bool incluirEnviados = false,
  }) async {
    try {
      final res = await _dio.get(
        '/api/v1/mis-vehiculos/$objetoId/recordatorios',
        queryParameters: {'incluir_enviados': incluirEnviados},
      );
      final list = res.data as List<dynamic>;
      return list
          .map((r) => Recordatorio.fromJson(r as Map<String, dynamic>))
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

  /// Crea un recordatorio.
  Future<Recordatorio> crearRecordatorio(Recordatorio r) async {
    try {
      final res = await _dio.post(
        '/api/v1/mis-vehiculos/${r.objetoId}/recordatorios',
        data: r.toCreateJson(),
      );
      return Recordatorio.fromJson(res.data as Map<String, dynamic>);
    } on ApiException {
      rethrow;
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      throw const UnknownException();
    } catch (e) {
      throw UnknownException('Error inesperado: $e');
    }
  }

  /// Elimina un recordatorio (soft delete).
  Future<void> eliminarRecordatorio(String objetoId, String recId) async {
    try {
      await _dio.delete('/api/v1/mis-vehiculos/$objetoId/recordatorios/$recId');
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
  // M5.1: Fotos de orden
  // =========================================================

  /// Sube una foto a una orden (cliente dueno o admin).
  Future<OrdenFoto> subirFoto({
    required String ordenId,
    required Uint8List bytes,
    required String nombreArchivo,
    required MomentoFoto momento,
    String? itemId,
    String? descripcion,
  }) async {
    try {
      final form = FormData.fromMap({
        'archivo': MultipartFile.fromBytes(bytes, filename: nombreArchivo),
        'momento': momento.value,
        'item_id': ?itemId,
        if (descripcion != null && descripcion.isNotEmpty)
          'descripcion': descripcion,
      });
      final res = await _dio.post(
        '/api/v1/mis-ordenes/$ordenId/fotos',
        data: form,
      );
      return OrdenFoto.fromJson(res.data as Map<String, dynamic>);
    } on ApiException {
      rethrow;
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      throw const UnknownException();
    } catch (e) {
      throw UnknownException('Error inesperado: $e');
    }
  }

  /// Sube una foto a una orden (prestador dueno o admin).
  Future<OrdenFoto> subirFotoPrestador({
    required String prestadorId,
    required String ordenId,
    required Uint8List bytes,
    required String nombreArchivo,
    required MomentoFoto momento,
    String? itemId,
    String? descripcion,
  }) async {
    try {
      final form = FormData.fromMap({
        'archivo': MultipartFile.fromBytes(bytes, filename: nombreArchivo),
        'momento': momento.value,
        'item_id': ?itemId,
        if (descripcion != null && descripcion.isNotEmpty)
          'descripcion': descripcion,
      });
      final res = await _dio.post(
        '/api/v1/mis-prestadores/$prestadorId/ordenes/$ordenId/fotos',
        data: form,
      );
      return OrdenFoto.fromJson(res.data as Map<String, dynamic>);
    } on ApiException {
      rethrow;
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      throw const UnknownException();
    } catch (e) {
      throw UnknownException('Error inesperado: $e');
    }
  }

  /// Lista las fotos de una orden (cliente dueno o admin).
  Future<List<OrdenFoto>> listarFotosDeMiOrden(
    String ordenId, {
    MomentoFoto? momento,
  }) async {
    try {
      final res = await _dio.get(
        '/api/v1/mis-ordenes/$ordenId/fotos',
        queryParameters: {if (momento != null) 'momento': momento.value},
      );
      final list = res.data as List<dynamic>;
      return list
          .map((f) => OrdenFoto.fromJson(f as Map<String, dynamic>))
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

  /// Lista las fotos de una orden (prestador dueno o admin).
  Future<List<OrdenFoto>> listarFotosDeOrdenPrestador(
    String prestadorId,
    String ordenId, {
    MomentoFoto? momento,
  }) async {
    try {
      final res = await _dio.get(
        '/api/v1/mis-prestadores/$prestadorId/ordenes/$ordenId/fotos',
        queryParameters: {if (momento != null) 'momento': momento.value},
      );
      final list = res.data as List<dynamic>;
      return list
          .map((f) => OrdenFoto.fromJson(f as Map<String, dynamic>))
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

  /// Elimina (soft) una foto de una orden propia (cliente).
  Future<void> eliminarFotoDeMiOrden(String ordenId, String fotoId) async {
    try {
      await _dio.delete('/api/v1/mis-ordenes/$ordenId/fotos/$fotoId');
    } on ApiException {
      rethrow;
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      throw const UnknownException();
    } catch (e) {
      throw UnknownException('Error inesperado: $e');
    }
  }

  /// Elimina (soft) una foto de una orden (prestador).
  Future<void> eliminarFotoDeOrdenPrestador(
    String prestadorId,
    String ordenId,
    String fotoId,
  ) async {
    try {
      await _dio.delete(
        '/api/v1/mis-prestadores/$prestadorId/ordenes/$ordenId/fotos/$fotoId',
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
  // =========================================================
  // M5.3: Reportes del taller
  // =========================================================

  /// Obtiene el reporte del taller (JSON) en el rango dado.
  Future<ReportePrestador> obtenerReporte(
    String prestadorId, {
    DateTime? desde,
    DateTime? hasta,
  }) async {
    try {
      final res = await _dio.get(
        '/api/v1/mis-prestadores/$prestadorId/reportes',
        queryParameters: {
          if (desde != null) 'desde': _fmtFecha(desde),
          if (hasta != null) 'hasta': _fmtFecha(hasta),
        },
      );
      return ReportePrestador.fromJson(res.data as Map<String, dynamic>);
    } on ApiException {
      rethrow;
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      throw const UnknownException();
    } catch (e) {
      throw UnknownException('Error inesperado: $e');
    }
  }

  /// Descarga el reporte en CSV (bytes).
  Future<Uint8List> descargarReporteCsv(
    String prestadorId, {
    DateTime? desde,
    DateTime? hasta,
  }) async {
    try {
      final res = await _dio.get<List<int>>(
        '/api/v1/mis-prestadores/$prestadorId/reportes.csv',
        queryParameters: {
          if (desde != null) 'desde': _fmtFecha(desde),
          if (hasta != null) 'hasta': _fmtFecha(hasta),
        },
        options: Options(responseType: ResponseType.bytes),
      );
      return Uint8List.fromList(res.data ?? const <int>[]);
    } on ApiException {
      rethrow;
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      throw const UnknownException();
    } catch (e) {
      throw UnknownException('Error inesperado: $e');
    }
  }

  String _fmtFecha(DateTime d) =>
      '${d.year.toString().padLeft(4, "0")}-'
      '${d.month.toString().padLeft(2, "0")}-'
      '${d.day.toString().padLeft(2, "0")}';

  // =========================================================
  // M6: Reviews
  // =========================================================

  /// Cliente crea una review de una orden entregada.
  Future<Review> crearReview(
    String ordenId, {
    required int rating,
    String? comentario,
  }) async {
    try {
      final res = await _dio.post(
        '/api/v1/mis-ordenes/$ordenId/review',
        data: {
          'rating': rating,
          if (comentario != null && comentario.isNotEmpty)
            'comentario': comentario,
        },
      );
      return Review.fromJson(res.data as Map<String, dynamic>);
    } on ApiException {
      rethrow;
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      throw const UnknownException();
    } catch (e) {
      throw UnknownException('Error inesperado: $e');
    }
  }

  /// Devuelve la review de una orden (o null si aun no califico).
  Future<Review?> obtenerMiReview(String ordenId) async {
    try {
      final res = await _dio.get('/api/v1/mis-ordenes/$ordenId/review');
      if (res.data == null) return null;
      return Review.fromJson(res.data as Map<String, dynamic>);
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
