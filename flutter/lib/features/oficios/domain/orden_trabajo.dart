/// Orden de trabajo: vincula cliente + prestador + objeto_servicio.
///
/// Es el objeto central del modulo oficios. Ciclo completo de estados
/// administrado por la state machine del backend.
library;

import 'orden_historial.dart';
import 'orden_item.dart';

enum EstadoOrden {
  ingresado('ingresado', 'Ingresado'),
  diagnosticando('diagnosticando', 'Diagnosticando'),
  presupuestado('presupuestado', 'Presupuestado'),
  aprobado('aprobado', 'Aprobado'),
  rechazado('rechazado', 'Rechazado'),
  enProceso('en_proceso', 'En proceso'),
  listo('listo', 'Listo'),
  entregado('entregado', 'Entregado'),
  cancelado('cancelado', 'Cancelado'),
  garantia('garantia', 'Garantia');

  const EstadoOrden(this.value, this.label);
  final String value;
  final String label;

  static EstadoOrden fromValue(String? v) {
    return EstadoOrden.values.firstWhere(
      (e) => e.value == v,
      orElse: () => EstadoOrden.ingresado,
    );
  }

  /// Color sugerido para badges (hex).
  String get colorHex {
    switch (this) {
      case EstadoOrden.ingresado:
        return '#64748b';
      case EstadoOrden.diagnosticando:
        return '#0891b2';
      case EstadoOrden.presupuestado:
        return '#f97316';
      case EstadoOrden.aprobado:
        return '#16a34a';
      case EstadoOrden.rechazado:
        return '#dc2626';
      case EstadoOrden.enProceso:
        return '#eab308';
      case EstadoOrden.listo:
        return '#7c3aed';
      case EstadoOrden.entregado:
        return '#0ea5e9';
      case EstadoOrden.cancelado:
        return '#6b7280';
      case EstadoOrden.garantia:
        return '#db2777';
    }
  }
}

enum PrioridadOrden {
  baja('baja', 'Baja'),
  normal('normal', 'Normal'),
  alta('alta', 'Alta'),
  urgente('urgente', 'Urgente');

  const PrioridadOrden(this.value, this.label);
  final String value;
  final String label;

  static PrioridadOrden fromValue(String? v) {
    return PrioridadOrden.values.firstWhere(
      (p) => p.value == v,
      orElse: () => PrioridadOrden.normal,
    );
  }

  String get colorHex {
    switch (this) {
      case PrioridadOrden.baja:
        return '#64748b';
      case PrioridadOrden.normal:
        return '#0891b2';
      case PrioridadOrden.alta:
        return '#f97316';
      case PrioridadOrden.urgente:
        return '#dc2626';
    }
  }
}

class OrdenTrabajo {
  const OrdenTrabajo({
    required this.id,
    required this.numero,
    required this.clienteId,
    required this.prestadorId,
    required this.objetoId,
    required this.estado,
    required this.prioridad,
    required this.fechaIngreso,
    required this.totalPresupuesto,
    required this.totalAprobado,
    this.diagnosticoInicial,
    this.notasCliente,
    this.notasInternas,
    this.fechaEstimadaEntrega,
    this.fechaEntregaReal,
    this.kmIngreso,
    this.kmSalida,
    this.items = const [],
    this.historial = const [],
  });

  final String id;
  final String numero;
  final String clienteId;
  final String prestadorId;
  final String objetoId;
  final EstadoOrden estado;
  final PrioridadOrden prioridad;
  final DateTime fechaIngreso;
  final double totalPresupuesto;
  final double totalAprobado;

  final String? diagnosticoInicial;
  final String? notasCliente;
  final String? notasInternas;
  final DateTime? fechaEstimadaEntrega;
  final DateTime? fechaEntregaReal;
  final int? kmIngreso;
  final int? kmSalida;

  final List<OrdenItem> items;
  final List<OrdenHistorialEvento> historial;

  bool get tieneItems => items.isNotEmpty;
  bool get aprobacionPendiente =>
      estado == EstadoOrden.presupuestado &&
      items.any((i) => i.aprobado == null);

  factory OrdenTrabajo.fromJson(Map<String, dynamic> json) {
    return OrdenTrabajo(
      id: json['id'] as String,
      numero: json['numero'] as String,
      clienteId: json['cliente_id'] as String,
      prestadorId: json['prestador_id'] as String,
      objetoId: json['objeto_servicio_id'] as String,
      estado: EstadoOrden.fromValue(json['estado'] as String?),
      prioridad: PrioridadOrden.fromValue(json['prioridad'] as String?),
      fechaIngreso: DateTime.parse(json['fecha_ingreso'] as String),
      totalPresupuesto: _toDouble(json['total_presupuesto']),
      totalAprobado: _toDouble(json['total_aprobado']),
      diagnosticoInicial: json['diagnostico_inicial'] as String?,
      notasCliente: json['notas_cliente'] as String?,
      notasInternas: json['notas_internas'] as String?,
      fechaEstimadaEntrega: json['fecha_estimada_entrega'] != null
          ? DateTime.tryParse(json['fecha_estimada_entrega'] as String)
          : null,
      fechaEntregaReal: json['fecha_entrega_real'] != null
          ? DateTime.tryParse(json['fecha_entrega_real'] as String)
          : null,
      kmIngreso: json['km_ingreso'] as int?,
      kmSalida: json['km_salida'] as int?,
      items:
          (json['items'] as List<dynamic>?)
              ?.map((i) => OrdenItem.fromJson(i as Map<String, dynamic>))
              .toList() ??
          const [],
      historial:
          (json['historial'] as List<dynamic>?)
              ?.map(
                (h) => OrdenHistorialEvento.fromJson(h as Map<String, dynamic>),
              )
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toCreateJson() {
    return {
      'cliente_id': clienteId,
      'objeto_servicio_id': objetoId,
      if (diagnosticoInicial != null) 'diagnostico_inicial': diagnosticoInicial,
      if (notasCliente != null) 'notas_cliente': notasCliente,
      if (notasInternas != null) 'notas_internas': notasInternas,
      'prioridad': prioridad.value,
      if (fechaEstimadaEntrega != null)
        'fecha_estimada_entrega': fechaEstimadaEntrega!.toIso8601String(),
      if (kmIngreso != null) 'km_ingreso': kmIngreso,
    };
  }
}

double _toDouble(dynamic v) {
  if (v == null) return 0.0;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0.0;
  return 0.0;
}
