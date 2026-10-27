/// Providers de Riverpod para el módulo rentacar.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:baqueano_natales/features/rentacar/data/rentacar_repository.dart';
import 'package:baqueano_natales/features/rentacar/domain/vehiculo.dart';

// =========================================================
// Repositorio (inyectable para tests)
// =========================================================
final rentacarRepositoryProvider = Provider<RentacarRepository>((ref) {
  return RentacarRepository();
});

// =========================================================
// Listado de mis vehículos (propietario/prestador)
// =========================================================
final misVehiculosRentacarProvider = FutureProvider<List<Vehiculo>>((
  ref,
) async {
  final repo = ref.watch(rentacarRepositoryProvider);
  return repo.listarMisVehiculos();
});
