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