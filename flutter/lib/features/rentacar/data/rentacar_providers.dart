/// Providers de Riverpod para el módulo rentacar.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:baqueano_natales/features/rentacar/data/rentacar_repository.dart';
import 'package:baqueano_natales/features/rentacar/domain/vehiculo.dart';
import 'package:baqueano_natales/features/rentacar/domain/reserva.dart';
import 'package:baqueano_natales/features/rentacar/domain/stats_rentacar.dart';
import 'package:baqueano_natales/features/rentacar/domain/config_rentacar.dart';

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

// =========================================================
// Reservas del prestador
// =========================================================
final misReservasRentacarProvider =
    FutureProvider.family<List<Reserva>, String?>((ref, estado) async {
      final repo = ref.watch(rentacarRepositoryProvider);
      return repo.listarReservas(estado: estado);
    });

// =========================================================
// Stats del dashboard
// =========================================================
final misStatsRentacarProvider = FutureProvider<StatsRentacar>((ref) async {
  final repo = ref.watch(rentacarRepositoryProvider);
  return repo.obtenerStats();
});

// =========================================================
// Config del prestador
// =========================================================
final miConfigRentacarProvider = FutureProvider<ConfigRentacar>((ref) async {
  final repo = ref.watch(rentacarRepositoryProvider);
  return repo.obtenerConfig();
});

// =========================================================
// Reserva individual (para detalle con refetch)
// =========================================================
final reservaRentacarProvider = FutureProvider.family<Reserva, String>((
  ref,
  id,
) async {
  final repo = ref.watch(rentacarRepositoryProvider);
  return repo.obtenerReserva(id);
});
