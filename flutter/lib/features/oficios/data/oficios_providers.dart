/// Providers de Riverpod para el modulo oficios (mecanica).
///
/// Expone:
/// - Repositorio (inyectable para tests).
/// - Categorias de mecanica (publico).
/// - Mis vehiculos (cliente).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:baqueano_natales/features/oficios/data/oficios_repository.dart';
import 'package:baqueano_natales/features/oficios/domain/mecanica_categoria.dart';
import 'package:baqueano_natales/features/oficios/domain/cliente_busqueda.dart';
import 'package:baqueano_natales/features/oficios/domain/orden_trabajo.dart';
import 'package:baqueano_natales/features/oficios/domain/vehiculo.dart';

// =========================================================
// Repositorio
// =========================================================
final oficiosRepositoryProvider = Provider<OficiosRepository>((ref) {
  return OficiosRepository();
});

// =========================================================
// Categorias de mecanica (publico)
// =========================================================
final categoriasMecanicaProvider =
    FutureProvider<List<MecanicaCategoria>>((ref) async {
  final repo = ref.watch(oficiosRepositoryProvider);
  return repo.listarCategoriasMecanica();
});

// =========================================================
// Mis vehiculos (cliente)
// =========================================================
final misVehiculosProvider = FutureProvider<List<Vehiculo>>((ref) async {
  final repo = ref.watch(oficiosRepositoryProvider);
  return repo.listarMisVehiculos();
});

/// Detalle de un vehiculo por su objeto_servicio_id.
final vehiculoDetalleProvider =
    FutureProvider.family<Vehiculo, String>((ref, objetoId) async {
  final repo = ref.watch(oficiosRepositoryProvider);
  return repo.obtenerVehiculo(objetoId);
});

// =========================================================
// M2: Ordenes del prestador
// =========================================================
class OrdenesPrestadorParams {
  const OrdenesPrestadorParams({
    required this.prestadorId,
    this.estado,
  });

  final String prestadorId;
  final String? estado;

  @override
  bool operator ==(Object other) =>
      other is OrdenesPrestadorParams &&
      other.prestadorId == prestadorId &&
      other.estado == estado;

  @override
  int get hashCode => Object.hash(prestadorId, estado);
}

final ordenesPrestadorProvider =
    FutureProvider.family<List<OrdenTrabajo>, OrdenesPrestadorParams>(
        (ref, params) async {
  final repo = ref.watch(oficiosRepositoryProvider);
  return repo.listarOrdenesPrestador(
    params.prestadorId,
    estado: params.estado,
  );
});

class OrdenPrestadorDetalleParams {
  const OrdenPrestadorDetalleParams({
    required this.prestadorId,
    required this.ordenId,
  });

  final String prestadorId;
  final String ordenId;

  @override
  bool operator ==(Object other) =>
      other is OrdenPrestadorDetalleParams &&
      other.prestadorId == prestadorId &&
      other.ordenId == ordenId;

  @override
  int get hashCode => Object.hash(prestadorId, ordenId);
}

final ordenPrestadorDetalleProvider =
    FutureProvider.family<OrdenTrabajo, OrdenPrestadorDetalleParams>(
        (ref, params) async {
  final repo = ref.watch(oficiosRepositoryProvider);
  return repo.detalleOrdenPrestador(params.prestadorId, params.ordenId);
});

// =========================================================
// M2: Ordenes del cliente
// =========================================================
final misOrdenesProvider =
    FutureProvider.family<List<OrdenTrabajo>, String?>((ref, estado) async {
  final repo = ref.watch(oficiosRepositoryProvider);
  return repo.listarMisOrdenes(estado: estado);
});

final miOrdenDetalleProvider =
    FutureProvider.family<OrdenTrabajo, String>((ref, ordenId) async {
  final repo = ref.watch(oficiosRepositoryProvider);
  return repo.detalleMiOrden(ordenId);
});

// =========================================================
// M2+: Busqueda de clientes (para crear ordenes)
// =========================================================
class BusquedaClientesParams {
  const BusquedaClientesParams({
    required this.prestadorId,
    required this.query,
  });

  final String prestadorId;
  final String query;

  @override
  bool operator ==(Object other) =>
      other is BusquedaClientesParams &&
      other.prestadorId == prestadorId &&
      other.query == query;

  @override
  int get hashCode => Object.hash(prestadorId, query);
}

/// Busca clientes por query (nombre/email).
/// Devuelve [] si query < 2 chars (evita llamar al backend).
final busquedaClientesProvider =
    FutureProvider.family<List<ClienteBusqueda>, BusquedaClientesParams>(
        (ref, params) async {
  if (params.query.trim().length < 2) return [];
  final repo = ref.watch(oficiosRepositoryProvider);
  return repo.buscarClientes(params.prestadorId, params.query);
});

/// Vehiculos de un cliente (para elegir al crear orden).
final vehiculosDeClienteProvider =
    FutureProvider.family<List<Vehiculo>, VehiculosDeClienteParams>(
        (ref, params) async {
  final repo = ref.watch(oficiosRepositoryProvider);
  return repo.listarVehiculosDeCliente(
    params.prestadorId,
    params.clienteId,
  );
});

class VehiculosDeClienteParams {
  const VehiculosDeClienteParams({
    required this.prestadorId,
    required this.clienteId,
  });

  final String prestadorId;
  final String clienteId;

  @override
  bool operator ==(Object other) =>
      other is VehiculosDeClienteParams &&
      other.prestadorId == prestadorId &&
      other.clienteId == clienteId;

  @override
  int get hashCode => Object.hash(prestadorId, clienteId);
}