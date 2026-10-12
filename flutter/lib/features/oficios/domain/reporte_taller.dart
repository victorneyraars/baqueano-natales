/// Modelos de reportes del taller (M5.3).
///
/// Espejo de los schemas Pydantic de backend:
/// - ReportePrestador
/// - ReporteKPIs
/// - ReporteSerieMes
/// - ReporteTopServicio
/// - ReporteTopCliente
library;

class ReporteKPIs {
  const ReporteKPIs({
    required this.totalOrdenes,
    required this.ordenesPorEstado,
    required this.ingresosTotales,
    required this.ticketPromedio,
    required this.tasaAprobacionItems,
    this.duracionPromedioDias,
  });

  final int totalOrdenes;
  final Map<String, int> ordenesPorEstado;
  final double ingresosTotales;
  final double ticketPromedio;
  final double tasaAprobacionItems;
  final double? duracionPromedioDias;

  factory ReporteKPIs.fromJson(Map<String, dynamic> json) {
    final rawEstados = json['ordenes_por_estado'] as Map<String, dynamic>? ?? {};
    return ReporteKPIs(
      totalOrdenes: (json['total_ordenes'] as num?)?.toInt() ?? 0,
      ordenesPorEstado: rawEstados.map(
        (k, v) => MapEntry(k, (v as num).toInt()),
      ),
      ingresosTotales: (json['ingresos_totales'] as num?)?.toDouble() ?? 0.0,
      ticketPromedio: (json['ticket_promedio'] as num?)?.toDouble() ?? 0.0,
      tasaAprobacionItems:
          (json['tasa_aprobacion_items'] as num?)?.toDouble() ?? 0.0,
      duracionPromedioDias:
          (json['duracion_promedio_dias'] as num?)?.toDouble(),
    );
  }
}

class ReporteSerieMes {
  const ReporteSerieMes({
    required this.mes,
    required this.ordenes,
    required this.ingresos,
  });

  /// Formato YYYY-MM.
  final String mes;
  final int ordenes;
  final double ingresos;

  factory ReporteSerieMes.fromJson(Map<String, dynamic> json) {
    return ReporteSerieMes(
      mes: json['mes'] as String,
      ordenes: (json['ordenes'] as num?)?.toInt() ?? 0,
      ingresos: (json['ingresos'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class ReporteTopServicio {
  const ReporteTopServicio({
    required this.descripcion,
    required this.cantidad,
    required this.ingresosTotales,
  });

  final String descripcion;
  final int cantidad;
  final double ingresosTotales;

  factory ReporteTopServicio.fromJson(Map<String, dynamic> json) {
    return ReporteTopServicio(
      descripcion: json['descripcion'] as String,
      cantidad: (json['cantidad'] as num?)?.toInt() ?? 0,
      ingresosTotales:
          (json['ingresos_totales'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class ReporteTopCliente {
  const ReporteTopCliente({
    required this.clienteId,
    required this.ordenes,
    required this.ingresosTotales,
    this.clienteNombre,
  });

  final String clienteId;
  final String? clienteNombre;
  final int ordenes;
  final double ingresosTotales;

  factory ReporteTopCliente.fromJson(Map<String, dynamic> json) {
    return ReporteTopCliente(
      clienteId: json['cliente_id'] as String,
      clienteNombre: json['cliente_nombre'] as String?,
      ordenes: (json['ordenes'] as num?)?.toInt() ?? 0,
      ingresosTotales:
          (json['ingresos_totales'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class ReportePrestador {
  const ReportePrestador({
    required this.prestadorId,
    required this.desde,
    required this.hasta,
    required this.generadoEn,
    required this.kpis,
    required this.serieMensual,
    required this.topServicios,
    required this.topClientes,
  });

  final String prestadorId;
  final DateTime desde;
  final DateTime hasta;
  final DateTime generadoEn;
  final ReporteKPIs kpis;
  final List<ReporteSerieMes> serieMensual;
  final List<ReporteTopServicio> topServicios;
  final List<ReporteTopCliente> topClientes;

  factory ReportePrestador.fromJson(Map<String, dynamic> json) {
    return ReportePrestador(
      prestadorId: json['prestador_id'] as String,
      desde: DateTime.parse(json['desde'] as String),
      hasta: DateTime.parse(json['hasta'] as String),
      generadoEn: DateTime.parse(json['generado_en'] as String).toLocal(),
      kpis: ReporteKPIs.fromJson(json['kpis'] as Map<String, dynamic>),
      serieMensual: (json['serie_mensual'] as List<dynamic>? ?? [])
          .map((x) => ReporteSerieMes.fromJson(x as Map<String, dynamic>))
          .toList(),
      topServicios: (json['top_servicios'] as List<dynamic>? ?? [])
          .map((x) => ReporteTopServicio.fromJson(x as Map<String, dynamic>))
          .toList(),
      topClientes: (json['top_clientes'] as List<dynamic>? ?? [])
          .map((x) => ReporteTopCliente.fromJson(x as Map<String, dynamic>))
          .toList(),
    );
  }
}