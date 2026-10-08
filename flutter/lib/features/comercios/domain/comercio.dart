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

import 'package:baqueano_natales/features/comercios/domain/categoria.dart';
import 'package:baqueano_natales/features/comercios/domain/horario.dart';

/// Estado del comercio en el flujo de verificación.
enum EstadoComercio {
  borrador,
  pendiente,
  verificado,
  rechazado,
  suspendido;

  /// Parsea desde string del backend.
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

  /// Nombre legible en español.
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
    // Estado (solo en privado/admin)
    this.estado,
    this.motivoRechazo,
    this.destacado = false,
    this.verificadoEn,
    this.verificadoPorId,
    this.activo = true,
    // Delivery
    this.aceptaDelivery = false,
    this.aceptaRetiro = true,
    this.costoEnvioClp = 0,
    this.pedidoMinimoClp = 0,
    this.radioEntregaKm,
    this.tiempoPreparacionMin,
    // Stats
    this.ratingPromedio = 0,
    this.totalResenas = 0,
    // Metadata
    this.propietarioId,
    this.createdAt,
    this.updatedAt,
    // Horarios (solo en detalle/privado)
    this.horarios = const [],
  });

  final String id; // UUID
  final String slug;
  final String nombre;
  final String? descripcionCorta;
  final String? descripcionLarga;
  final Categoria? categoria;
  final String? categoriaId; // solo viene en respuestas admin
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

  // Estado
  final EstadoComercio? estado;
  final String? motivoRechazo;
  final bool destacado;
  final DateTime? verificadoEn;
  final String? verificadoPorId;
  final bool activo;

  // Delivery
  final bool aceptaDelivery;
  final bool aceptaRetiro;
  final int costoEnvioClp;
  final int pedidoMinimoClp;
  final double? radioEntregaKm;
  final int? tiempoPreparacionMin;

  // Stats
  final double ratingPromedio;
  final int totalResenas;

  // Metadata
  final String? propietarioId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Horarios
  final List<Horario> horarios;

  // =========================================================
  // Helpers
  // =========================================================

  /// Nombre corto para mostrar (nombre + categoría).
  String get nombreConCategoria {
    if (categoria == null) return nombre;
    return '$nombre · ${categoria!.nombre}';
  }

  /// Rango de precio legible.
  String get costoEnvioLegible {
    if (!aceptaDelivery) return 'Sin delivery';
    if (costoEnvioClp == 0) return 'Envío gratis';
    return 'Envío \$${costoEnvioClp.toString()}';
  }

  /// Rating con 1 decimal.
  String get ratingLegible => ratingPromedio.toStringAsFixed(1);

  /// ¿Está verificado públicamente?
  bool get esPublico => estado == EstadoComercio.verificado && activo;

  factory Comercio.fromJson(Map<String, dynamic> json) {
    return Comercio(
      id: json['id'] as String,
      slug: json['slug'] as String,
      nombre: json['nombre'] as String,
      descripcionCorta: json['descripcion_corta'] as String?,
      descripcionLarga: json['descripcion_larga'] as String?,
      categoria: json['categoria'] != null
          ? Categoria.fromJson(json['categoria'] as Map<String, dynamic>)
          : null,
      categoriaId: json['categoria_id'] as String?,
      direccion: json['direccion'] as String,
      ciudad: json['ciudad'] as String? ?? 'Puerto Natales',
      region: json['region'] as String? ?? 'Magallanes',
      latitud: _toDouble(json['latitud']),
      longitud: _toDouble(json['longitud']),
      referencia: json['referencia'] as String?,
      logoUrl: json['logo_url'] as String?,
      portadaUrl: json['portada_url'] as String?,
      telefono: json['telefono'] as String?,
      whatsapp: json['whatsapp'] as String?,
      email: json['email'] as String?,
      sitioWeb: json['sitio_web'] as String?,
      estado: json['estado'] != null
          ? EstadoComercio.fromString(json['estado'] as String?)
          : null,
      motivoRechazo: json['motivo_rechazo'] as String?,
      destacado: json['destacado'] as bool? ?? false,
      verificadoEn: json['verificado_en'] != null
          ? DateTime.parse(json['verificado_en'] as String)
          : null,
      verificadoPorId: json['verificado_por_id'] as String?,
      activo: json['activo'] as bool? ?? true,
      aceptaDelivery: json['acepta_delivery'] as bool? ?? false,
      aceptaRetiro: json['acepta_retiro'] as bool? ?? true,
      costoEnvioClp: (json['costo_envio_clp'] as num?)?.toInt() ?? 0,
      pedidoMinimoClp: (json['pedido_minimo_clp'] as num?)?.toInt() ?? 0,
      radioEntregaKm: _toDouble(json['radio_entrega_km']),
      tiempoPreparacionMin: (json['tiempo_preparacion_min'] as num?)?.toInt(),
      ratingPromedio: _toDouble(json['rating_promedio']) ?? 0,
      totalResenas: (json['total_resenas'] as num?)?.toInt() ?? 0,
      propietarioId: json['propietario_id'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      horarios: (json['horarios'] as List<dynamic>?)
              ?.map((h) => Horario.fromJson(h as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

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

  /// Convierte num/string/null a double?.
  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  @override
  String toString() => 'Comercio($slug, estado=$estado)';
}