/// Modelo de comercio.
///
/// Unifica las 3 variantes del backend:
/// - ComercioPublicoResponse (listado público)
/// - ComercioDetalleResponse (detalle público con horarios)
/// - ComercioPrivadoResponse (dueño/admin, con estado y metadata)
///
/// Los campos exclusivos del privado (estado, motivo_rechazo, activo)
/// son nullables para permitir el parseo de las 3 variantes.
library;

import 'package:flutter/foundation.dart';

import 'package:baqueano_natales/features/comercios/domain/categoria.dart';
import 'package:baqueano_natales/features/comercios/domain/horario.dart';

/// Estado del comercio en el flujo de verificación.
enum EstadoComercio {
  borrador,
  pendiente,
  verificado,
  rechazado,
  suspendido;

  static EstadoComercio fromString(String? value) {
    switch (value) {
      case 'borrador':
        return EstadoComercio.borrador;
      case 'pendiente':
        return EstadoComercio.pendiente;
      case 'verificado':
        return EstadoComercio.verificado;
      case 'rechazado':
        return EstadoComercio.rechazado;
      case 'suspendido':
        return EstadoComercio.suspendido;
      default:
        return EstadoComercio.borrador;
    }
  }

  String get label {
    switch (this) {
      case EstadoComercio.borrador:
        return 'Borrador';
      case EstadoComercio.pendiente:
        return 'Pendiente';
      case EstadoComercio.verificado:
        return 'Verificado';
      case EstadoComercio.rechazado:
        return 'Rechazado';
      case EstadoComercio.suspendido:
        return 'Suspendido';
    }
  }
}

class Comercio {
  const Comercio({
    required this.id,
    required this.slug,
    required this.nombre,
    this.descripcionCorta,
    this.descripcionLarga,
    this.categoria,
    this.categoriaId,
    required this.direccion,
    required this.ciudad,
    required this.region,
    this.latitud,
    this.longitud,
    this.referencia,
    this.logoUrl,
    this.portadaUrl,
    this.telefono,
    this.whatsapp,
    this.email,
    this.sitioWeb,
    this.estado,
    this.motivoRechazo,
    this.destacado = false,
    this.verificadoEn,
    this.verificadoPorId,
    this.activo = true,
    this.aceptaDelivery = false,
    this.aceptaRetiro = true,
    this.costoEnvioClp = 0,
    this.pedidoMinimoClp = 0,
    this.radioEntregaKm,
    this.tiempoPreparacionMin,
    this.ratingPromedio = 0,
    this.totalResenas = 0,
    this.propietarioId,
    this.createdAt,
    this.updatedAt,
    this.horarios = const [],
  });

  final String id;
  final String slug;
  final String nombre;
  final String? descripcionCorta;
  final String? descripcionLarga;
  final Categoria? categoria;
  final String? categoriaId;
  final String direccion;
  final String ciudad;
  final String region;
  final double? latitud;
  final double? longitud;
  final String? referencia;
  final String? logoUrl;
  final String? portadaUrl;
  final String? telefono;
  final String? whatsapp;
  final String? email;
  final String? sitioWeb;

  final EstadoComercio? estado;
  final String? motivoRechazo;
  final bool destacado;
  final DateTime? verificadoEn;
  final String? verificadoPorId;
  final bool activo;

  final bool aceptaDelivery;
  final bool aceptaRetiro;
  final int costoEnvioClp;
  final int pedidoMinimoClp;
  final double? radioEntregaKm;
  final int? tiempoPreparacionMin;

  final double ratingPromedio;
  final int totalResenas;

  final String? propietarioId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  final List<Horario> horarios;

  // =========================================================
  // Helpers
  // =========================================================

  String get nombreConCategoria {
    if (categoria == null) return nombre;
    return '$nombre · ${categoria!.nombre}';
  }

  String get costoEnvioLegible {
    if (!aceptaDelivery) return 'Sin delivery';
    if (costoEnvioClp == 0) return 'Envío gratis';
    return 'Envío \$${costoEnvioClp.toString()}';
  }

  String get ratingLegible => ratingPromedio.toStringAsFixed(1);

  bool get esPublico => estado == EstadoComercio.verificado && activo;

  // =========================================================
  // fromJson — DEFENSIVO
  // =========================================================
  factory Comercio.fromJson(Map<String, dynamic> json) {
    try {
      return Comercio(
        id: _str(json, 'id'),
        slug: _str(json, 'slug'),
        nombre: _str(json, 'nombre'),
        descripcionCorta: _strOrNull(json, 'descripcion_corta'),
        descripcionLarga: _strOrNull(json, 'descripcion_larga'),
        categoria: _categoriaFromJson(json['categoria']),
        categoriaId: _strOrNull(json, 'categoria_id'),
        direccion: _str(json, 'direccion'),
        ciudad: _strOr(json, 'ciudad', 'Puerto Natales'),
        region: _strOr(json, 'region', 'Magallanes'),
        latitud: _toDouble(json['latitud']),
        longitud: _toDouble(json['longitud']),
        referencia: _strOrNull(json, 'referencia'),
        logoUrl: _strOrNull(json, 'logo_url'),
        portadaUrl: _strOrNull(json, 'portada_url'),
        telefono: _strOrNull(json, 'telefono'),
        whatsapp: _strOrNull(json, 'whatsapp'),
        email: _strOrNull(json, 'email'),
        sitioWeb: _strOrNull(json, 'sitio_web'),
        estado: json['estado'] != null
            ? EstadoComercio.fromString(json['estado'].toString())
            : null,
        motivoRechazo: _strOrNull(json, 'motivo_rechazo'),
        destacado: (json['destacado'] as bool?) ?? false,
        verificadoEn: _dateOrNull(json['verificado_en']),
        verificadoPorId: _strOrNull(json, 'verificado_por_id'),
        activo: (json['activo'] as bool?) ?? true,
        aceptaDelivery: (json['acepta_delivery'] as bool?) ?? false,
        aceptaRetiro: (json['acepta_retiro'] as bool?) ?? true,
        costoEnvioClp: _toInt(json['costo_envio_clp']) ?? 0,
        pedidoMinimoClp: _toInt(json['pedido_minimo_clp']) ?? 0,
        radioEntregaKm: _toDouble(json['radio_entrega_km']),
        tiempoPreparacionMin: _toInt(json['tiempo_preparacion_min']),
        ratingPromedio: _toDouble(json['rating_promedio']) ?? 0,
        totalResenas: _toInt(json['total_resenas']) ?? 0,
        propietarioId: _strOrNull(json, 'propietario_id'),
        createdAt: _dateOrNull(json['created_at']),
        updatedAt: _dateOrNull(json['updated_at']),
        horarios: _horariosFromJson(json['horarios']),
      );
    } catch (e, st) {
      // Log detallado del fallo para debug
      debugPrint('[Comercio.fromJson] ❌ Parse error: $e');
      debugPrint('[Comercio.fromJson] Stack: $st');
      debugPrint('[Comercio.fromJson] JSON crudo: $json');
      rethrow;
    }
  }

  // ---------------------------------------------------------
  // Helpers de parseo defensivo
  // ---------------------------------------------------------
  static String _str(Map<String, dynamic> json, String key) {
    final v = json[key];
    if (v is String && v.isNotEmpty) return v;
    if (v == null) {
      debugPrint('[Comercio] Campo requerido "$key" es null');
      return '';
    }
    return v.toString();
  }

  static String _strOr(Map<String, dynamic> json, String key, String fallback) {
    final v = json[key];
    if (v is String && v.isNotEmpty) return v;
    return fallback;
  }

  static String? _strOrNull(Map<String, dynamic> json, String key) {
    final v = json[key];
    if (v == null) return null;
    if (v is String) return v.isEmpty ? null : v;
    return v.toString();
  }

  static int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  static DateTime? _dateOrNull(dynamic v) {
    if (v == null) return null;
    if (v is String && v.isNotEmpty) {
      try {
        return DateTime.parse(v);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  static Categoria? _categoriaFromJson(dynamic v) {
    if (v == null) return null;
    if (v is Map<String, dynamic>) {
      try {
        return Categoria.fromJson(v);
      } catch (e) {
        debugPrint('[Comercio] Error parseando categoria: $e');
        return null;
      }
    }
    return null;
  }

  static List<Horario> _horariosFromJson(dynamic v) {
    if (v == null) return const [];
    if (v is List) {
      final result = <Horario>[];
      for (final item in v) {
        try {
          if (item is Map<String, dynamic>) {
            result.add(Horario.fromJson(item));
          }
        } catch (e) {
          debugPrint('[Comercio] Error parseando horario: $e');
        }
      }
      return result;
    }
    return const [];
  }

  // =========================================================
  // toJson
  // =========================================================
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'slug': slug,
      'nombre': nombre,
      'descripcion_corta': descripcionCorta,
      'descripcion_larga': descripcionLarga,
      'categoria': categoria?.toJson(),
      'categoria_id': categoriaId,
      'direccion': direccion,
      'ciudad': ciudad,
      'region': region,
      'latitud': latitud,
      'longitud': longitud,
      'referencia': referencia,
      'logo_url': logoUrl,
      'portada_url': portadaUrl,
      'telefono': telefono,
      'whatsapp': whatsapp,
      'email': email,
      'sitio_web': sitioWeb,
      'estado': estado?.name,
      'motivo_rechazo': motivoRechazo,
      'destacado': destacado,
      'verificado_en': verificadoEn?.toIso8601String(),
      'verificado_por_id': verificadoPorId,
      'activo': activo,
      'acepta_delivery': aceptaDelivery,
      'acepta_retiro': aceptaRetiro,
      'costo_envio_clp': costoEnvioClp,
      'pedido_minimo_clp': pedidoMinimoClp,
      'radio_entrega_km': radioEntregaKm,
      'tiempo_preparacion_min': tiempoPreparacionMin,
      'rating_promedio': ratingPromedio,
      'total_resenas': totalResenas,
      'propietario_id': propietarioId,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'horarios': horarios.map((h) => h.toJson()).toList(),
    };
  }

  @override
  String toString() => 'Comercio($slug, estado=$estado)';
}
