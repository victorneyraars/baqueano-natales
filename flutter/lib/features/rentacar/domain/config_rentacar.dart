/// Configuración del prestador de rent a car.
class ConfigRentacar {
  const ConfigRentacar({
    required this.id,
    required this.prestadorId,
    required this.metodosPago,
    required this.deposito,
    required this.conductorAdicional,
    required this.categorias,
  });

  final String id;
  final String prestadorId;
  final Map<String, dynamic> metodosPago;
  final Map<String, dynamic> deposito;
  final Map<String, dynamic> conductorAdicional;
  final List<dynamic> categorias;

  factory ConfigRentacar.fromJson(Map<String, dynamic> json) {
    return ConfigRentacar(
      id: json['id'] as String,
      prestadorId: json['prestador_id'] as String,
      metodosPago: Map<String, dynamic>.from(
        json['metodos_pago'] as Map? ?? {},
      ),
      deposito: Map<String, dynamic>.from(json['deposito'] as Map? ?? {}),
      conductorAdicional: Map<String, dynamic>.from(
        json['conductor_adicional'] as Map? ?? {},
      ),
      categorias: (json['categorias'] as List?) ?? [],
    );
  }

  // Getters de conveniencia para la UI
  bool get aceptaEfectivo => metodosPago['efectivo'] == true;
  bool get aceptaTransferencia => metodosPago['transferencia'] == true;
  bool get aceptaMercadopago => metodosPago['mercadopago'] == true;

  String get depositoTipo => deposito['tipo'] as String? ?? 'porcentaje';
  num get depositoValor => deposito['valor'] as num? ?? 20;

  bool get conductorAdicionalHabilitado =>
      conductorAdicional['habilitado'] == true;
  num get conductorAdicionalTarifa =>
      conductorAdicional['tarifa_por_dia'] as num? ?? 5000;
}
