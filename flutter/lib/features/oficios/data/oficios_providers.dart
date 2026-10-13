/// Providers de Riverpod para el modulo oficios (mecanica).
///
/// Expone:
/// - Repositorio (inyectable para tests).
/// - Categorias de mecanica (publico).
/// - Mis vehiculos (cliente).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:baqueano_natales/features/oficios/data/oficios_repository.dart';
import 'package:baqueano_natales/features/oficios/domain/garantia.dart';
import 'package:baqueano_natales/features/oficios/domain/mecanica_categoria.dart';
import 'package:baqueano_natales/features/oficios/domain/recordatorio.dart';
import 'package:baqueano_natales/features/oficios/domain/cliente_busqueda.dart';
import 'package:baqueano_natales/features/oficios/domain/orden_foto.dart';
import 'package:baqueano_natales/features/oficios/domain/orden_trabajo.dart';
import 'package:baqueano_natales/features/oficios/domain/reporte_taller.dart';
import 'package:baqueano_natales/features/prestadores/domain/review.dart';
import 'package:baqueano_natales/features/oficios/domain/turno.dart';
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

// =========================================================
// M3: Turnos del cliente
// =========================================================
final misTurnosProvider =
    FutureProvider.family<List<Turno>, String?>((ref, estado) async {
  final repo = ref.watch(oficiosRepositoryProvider);
  return repo.listarMisTurnos(estado: estado);
});

final miTurnoDetalleProvider =
    FutureProvider.family<Turno, String>((ref, turnoId) async {
  final repo = ref.watch(oficiosRepositoryProvider);
  return repo.detalleMiTurno(turnoId);
});

// =========================================================
// M3: Turnos del prestador
// =========================================================
class TurnosPrestadorParams {
  const TurnosPrestadorParams({
    required this.prestadorId,
    this.estado,
  });

  final String prestadorId;
  final String? estado;

  @override
  bool operator ==(Object other) =>
      other is TurnosPrestadorParams &&
      other.prestadorId == prestadorId &&
      other.estado == estado;

  @override
  int get hashCode => Object.hash(prestadorId, estado);
}

final turnosPrestadorProvider =
    FutureProvider.family<List<Turno>, TurnosPrestadorParams>(
        (ref, params) async {
  final repo = ref.watch(oficiosRepositoryProvider);
  return repo.listarTurnosPrestador(
    params.prestadorId,
    estado: params.estado,
  );
});

class TurnoPrestadorDetalleParams {
  const TurnoPrestadorDetalleParams({
    required this.prestadorId,
    required this.turnoId,
  });

  final String prestadorId;
  final String turnoId;

  @override
  bool operator ==(Object other) =>
      other is TurnoPrestadorDetalleParams &&
      other.prestadorId == prestadorId &&
      other.turnoId == turnoId;

  @override
  int get hashCode => Object.hash(prestadorId, turnoId);
}

final turnoPrestadorDetalleProvider =
    FutureProvider.family<Turno, TurnoPrestadorDetalleParams>(
        (ref, params) async {
  final repo = ref.watch(oficiosRepositoryProvider);
  return repo.detalleTurnoPrestador(params.prestadorId, params.turnoId);
});

// =========================================================
// M4: Garantias
// =========================================================
final garantiaDeMiOrdenProvider =
    FutureProvider.family<Garantia?, String>((ref, ordenId) async {
  final repo = ref.watch(oficiosRepositoryProvider);
  return repo.obtenerGarantiaDeMiOrden(ordenId);
});

class GarantiaPrestadorParams {
  const GarantiaPrestadorParams({
    required this.prestadorId,
    required this.ordenId,
  });

  final String prestadorId;
  final String ordenId;

  @override
  bool operator ==(Object other) =>
      other is GarantiaPrestadorParams &&
      other.prestadorId == prestadorId &&
      other.ordenId == ordenId;

  @override
  int get hashCode => Object.hash(prestadorId, ordenId);
}

final garantiaPrestadorProvider =
    FutureProvider.family<Garantia?, GarantiaPrestadorParams>(
        (ref, params) async {
  final repo = ref.watch(oficiosRepositoryProvider);
  return repo.obtenerGarantiaDeOrdenPrestador(
    params.prestadorId,
    params.ordenId,
  );
});

// =========================================================
// M4: Recordatorios
// =========================================================
class RecordatoriosParams {
  const RecordatoriosParams({
    required this.objetoId,
    this.incluirEnviados = false,
  });

  final String objetoId;
  final bool incluirEnviados;

  @override
  bool operator ==(Object other) =>
      other is RecordatoriosParams &&
      other.objetoId == objetoId &&
      other.incluirEnviados == incluirEnviados;

  @override
  int get hashCode => Object.hash(objetoId, incluirEnviados);
}

final recordatoriosProvider =
    FutureProvider.family<List<Recordatorio>, RecordatoriosParams>(
        (ref, params) async {
  final repo = ref.watch(oficiosRepositoryProvider);
  return repo.listarRecordatorios(
    params.objetoId,
    incluirEnviados: params.incluirEnviados,
  );
});

// =========================================================
// M5.1: Fotos de orden
// =========================================================
class FotosDeMiOrdenParams {
  const FotosDeMiOrdenParams({required this.ordenId, this.momento});

  final String ordenId;
  final MomentoFoto? momento;

  @override
  bool operator ==(Object other) =>
      other is FotosDeMiOrdenParams &&
      other.ordenId == ordenId &&
      other.momento == momento;

  @override
  int get hashCode => Object.hash(ordenId, momento);
}

final fotosDeMiOrdenProvider =
    FutureProvider.family<List<OrdenFoto>, FotosDeMiOrdenParams>(
        (ref, params) async {
  final repo = ref.watch(oficiosRepositoryProvider);
  return repo.listarFotosDeMiOrden(
    params.ordenId,
    momento: params.momento,
  );
});

class FotosDeOrdenPrestadorParams {
  const FotosDeOrdenPrestadorParams({
    required this.prestadorId,
    required this.ordenId,
    this.momento,
  });

  final String prestadorId;
  final String ordenId;
  final MomentoFoto? momento;

  @override
  bool operator ==(Object other) =>
      other is FotosDeOrdenPrestadorParams &&
      other.prestadorId == prestadorId &&
      other.ordenId == ordenId &&
      other.momento == momento;

  @override
  int get hashCode => Object.hash(prestadorId, ordenId, momento);
}

final fotosDeOrdenPrestadorProvider =
    FutureProvider.family<List<OrdenFoto>, FotosDeOrdenPrestadorParams>(
        (ref, params) async {
  final repo = ref.watch(oficiosRepositoryProvider);
  return repo.listarFotosDeOrdenPrestador(
    params.prestadorId,
    params.ordenId,
    momento: params.momento,
  );
});

// =========================================================
// M5.3: Reportes del taller
// =========================================================
class ReportePrestadorParams {
  const ReportePrestadorParams({
    required this.prestadorId,
    this.desde,
    this.hasta,
  });

  final String prestadorId;
  final DateTime? desde;
  final DateTime? hasta;

  @override
  bool operator ==(Object other) =>
      other is ReportePrestadorParams &&
      other.prestadorId == prestadorId &&
      other.desde == desde &&
      other.hasta == hasta;

  @override
  int get hashCode => Object.hash(prestadorId, desde, hasta);
}

final reportePrestadorProvider =
    FutureProvider.family<ReportePrestador, ReportePrestadorParams>(
        (ref, params) async {
  final repo = ref.watch(oficiosRepositoryProvider);
  return repo.obtenerReporte(
    params.prestadorId,
    desde: params.desde,
    hasta: params.hasta,
  );
});

// =========================================================
// M6: Review de una orden (o null si aun no califico)
// =========================================================
final miReviewProvider =
    FutureProvider.family<Review?, String>((ref, ordenId) async {
  final repo = ref.watch(oficiosRepositoryProvider);
  return repo.obtenerMiReview(ordenId);
});
