/// Stats del dashboard del prestador.
class StatsRentacar {
  const StatsRentacar({
    required this.vehiculosTotal,
    required this.vehiculosDisponibles,
    required this.reservasTotal,
    required this.reservasPendientes,
    required this.reservasConfirmadas,
    required this.reservasEnCurso,
    required this.reservasCompletadas,
    required this.ingresosTotales,
    required this.ingresosMesActual,
  });

  final int vehiculosTotal;
  final int vehiculosDisponibles;
  final int reservasTotal;
  final int reservasPendientes;
  final int reservasConfirmadas;
  final int reservasEnCurso;
  final int reservasCompletadas;
  final double ingresosTotales;
  final double ingresosMesActual;

  factory StatsRentacar.fromJson(Map<String, dynamic> json) {
    return StatsRentacar(
      vehiculosTotal: (json['vehiculos_total'] as num).toInt(),
      vehiculosDisponibles: (json['vehiculos_disponibles'] as num).toInt(),
      reservasTotal: (json['reservas_total'] as num).toInt(),
      reservasPendientes: (json['reservas_pendientes'] as num).toInt(),
      reservasConfirmadas: (json['reservas_confirmadas'] as num).toInt(),
      reservasEnCurso: (json['reservas_en_curso'] as num).toInt(),
      reservasCompletadas: (json['reservas_completadas'] as num).toInt(),
      ingresosTotales: (json['ingresos_totales'] as num).toDouble(),
      ingresosMesActual: (json['ingresos_mes_actual'] as num).toDouble(),
    );
  }
}
