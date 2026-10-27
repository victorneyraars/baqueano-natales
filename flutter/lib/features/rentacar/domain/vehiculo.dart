/// Modelo de un vehículo de Rent a Car.
class Vehiculo {
  const Vehiculo({
    required this.id,
    required this.prestadorId,
    required this.patente,
    required this.marca,
    required this.modelo,
    required this.anio,
    required this.categoria,
    required this.precioDia,
    required this.disponible,
    this.imagenUrl,
  });

  final String id;
  final String prestadorId;
  final String patente;
  final String marca;
  final String modelo;
  final int anio;
  final String categoria;
  final double precioDia;
  final bool disponible;
  final String? imagenUrl;

  factory Vehiculo.fromJson(Map<String, dynamic> json) => Vehiculo(
    id: json['id'] as String,
    prestadorId: json['prestador_id'] as String,
    patente: json['patente'] as String,
    marca: json['marca'] as String,
    modelo: json['modelo'] as String,
    anio: (json['anio'] as num).toInt(),
    categoria: json['categoria'] as String,
    precioDia: (json['precio_dia'] as num).toDouble(),
    disponible: json['disponible'] as bool? ?? true,
    imagenUrl: json['imagen_url'] as String?,
  );
}
