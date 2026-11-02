/// Providers de Riverpod para el módulo rentacar.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:baqueano_natales/features/rentacar/data/rentacar_repository.dart';
import 'package:baqueano_natales/features/rentacar/domain/vehiculo.dart';
import 'package:baqueano_natales/features/rentacar/domain/reserva.dart';
import 'package:baqueano_natales/features/rentacar/domain/stats_rentacar.dart';
import 'package:baqueano_natales/features/rentacar/domain/config_rentacar.dart';
import 'package:baqueano_natales/features/rentacar/domain/bloqueo.dart';

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

// =========================================================
// Bloqueos de disponibilidad (Fase 1.1)
// =========================================================
//
// Key: record con (vehiculoId, mes). El mes se normaliza al dia 1
// para que el cache funcione por mes calendario.
typedef BloqueosKey = ({String vehiculoId, DateTime mes});

final bloqueosRentacarProvider =
    FutureProvider.family<List<Bloqueo>, BloqueosKey>((ref, key) async {
      final repo = ref.watch(rentacarRepositoryProvider);
      final mes = DateTime(key.mes.year, key.mes.month, 1);
      // Rango: 1er dia del mes -> 1er dia del mes siguiente (exclusivo)
      final desde = mes;
      final hasta = DateTime(mes.year, mes.month + 1, 1);
      return repo.listarBloqueos(key.vehiculoId, desde, hasta);
    });
