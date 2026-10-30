/// Resultado de consultar una patente en Boostr (via backend).
///
/// Wrapper del endpoint `/api/v1/integrations/patente/{patente}`.
/// Desempaca el doble anidamiento { cached, data: { status, data: {...} } }.
class PatenteLookupResult {
  const PatenteLookupResult({
    required this.patente,
    required this.encontrado,
    this.marca,
    this.modelo,
    this.anio,
    this.tipoRaw,
    this.categoria,
    this.color,
    this.mensaje,
  });

  final String patente;
  final bool encontrado;
  final String? marca;
  final String? modelo;
  final int? anio;
  final String? tipoRaw;
  final String? categoria;
  final String? color;
  final String? mensaje;

  factory PatenteLookupResult.fromJson(
    String patente,
    Map<String, dynamic> json,
  ) {
    final inner = json['data'];
    if (inner is! Map<String, dynamic>) {
      return PatenteLookupResult(
        patente: patente,
        encontrado: false,
        mensaje: 'Respuesta inválida del servidor',
      );
    }

    final status = inner['status'];
    if (status != 'success') {
      return PatenteLookupResult(
        patente: patente,
        encontrado: false,
        mensaje: (inner['message'] as String?) ?? 'No encontrada',
      );
    }

    final data = inner['data'];
    if (data is! Map<String, dynamic>) {
      return PatenteLookupResult(
        patente: patente,
        encontrado: false,
        mensaje: 'Sin datos del vehículo',
      );
    }

    final tipoRaw = data['type'] as String?;
    return PatenteLookupResult(
      patente: patente,
      encontrado: true,
      marca: _nullableStr(data['make']),
      modelo: _nullableStr(data['model']),
      anio: _toInt(data['year']),
      tipoRaw: tipoRaw,
      categoria: _mapCategoria(tipoRaw),
      color: _nullableStr(data['color']),
    );
  }

  static String? _nullableStr(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  static int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  /// Mapea el tipo Boostr a las categorías del form.
  static String? _mapCategoria(String? tipo) {
    final t = (tipo ?? '').toUpperCase();
    if (t.isEmpty) return null;
    if (t.contains('SUV') ||
        t.contains('JEEP') ||
        t.contains('STATION WAGON')) {
      return 'SUV';
    }
    if (t.contains('SEDAN')) return 'SEDAN';
    if (t.contains('PICKUP') ||
        t.contains('CAMIONETA') ||
        t.contains('CAMION')) {
      return 'PICKUP';
    }
    if (t.contains('FURGON') || t.contains('VAN') || t.contains('MINIBUS')) {
      return 'FURGONETA';
    }
    return null;
  }
}
