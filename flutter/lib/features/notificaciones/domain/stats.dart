/// Modelos de estadisticas de notificaciones.
library;

class StatsNotificacion {
  const StatsNotificacion({
    required this.total,
    required this.enviadas,
    required this.entregadas,
    required this.abiertas,
    required this.fallidas,
    required this.skipped,
    required this.deliveryRate,
    required this.openRate,
    required this.porEstado,
    required this.porTipo,
    required this.top5,
  });

  final int total;
  final int enviadas;
  final int entregadas;
  final int abiertas;
  final int fallidas;
  final int skipped;
  final double deliveryRate;
  final double openRate;
  final List<EstadoCount> porEstado;
  final List<TipoCount> porTipo;
  final List<TopNotificacion> top5;

  factory StatsNotificacion.fromJson(Map<String, dynamic> json) {
    return StatsNotificacion(
      total: (json['total'] as num).toInt(),
      enviadas: (json['enviadas'] as num).toInt(),
      entregadas: (json['entregadas'] as num).toInt(),
      abiertas: (json['abiertas'] as num).toInt(),
      fallidas: (json['fallidas'] as num).toInt(),
      skipped: (json['skipped'] as num).toInt(),
      deliveryRate: (json['delivery_rate'] as num).toDouble(),
      openRate: (json['open_rate'] as num).toDouble(),
      porEstado: (json['por_estado'] as List)
          .map((e) => EstadoCount.fromJson(e as Map<String, dynamic>))
          .toList(),
      porTipo: (json['por_tipo'] as List)
          .map((e) => TipoCount.fromJson(e as Map<String, dynamic>))
          .toList(),
      top5: (json['top_5'] as List)
          .map((e) => TopNotificacion.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class EstadoCount {
  const EstadoCount({required this.estado, required this.count});
  final String estado;
  final int count;

  factory EstadoCount.fromJson(Map<String, dynamic> json) => EstadoCount(
    estado: json['estado'] as String,
    count: (json['count'] as num).toInt(),
  );
}

class TipoCount {
  const TipoCount({required this.tipo, required this.count});
  final String tipo;
  final int count;

  factory TipoCount.fromJson(Map<String, dynamic> json) => TipoCount(
    tipo: json['tipo'] as String,
    count: (json['count'] as num).toInt(),
  );
}

class TopNotificacion {
  const TopNotificacion({
    required this.titulo,
    required this.total,
    required this.abiertas,
    required this.openRate,
  });
  final String titulo;
  final int total;
  final int abiertas;
  final double openRate;

  factory TopNotificacion.fromJson(Map<String, dynamic> json) =>
      TopNotificacion(
        titulo: json['titulo'] as String,
        total: (json['total'] as num).toInt(),
        abiertas: (json['abiertas'] as num).toInt(),
        openRate: (json['open_rate'] as num).toDouble(),
      );
}
