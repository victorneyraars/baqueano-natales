/// Modelo de prestador de oficios.
///
/// Unifica las 3 variantes del backend:
/// - PrestadorPublicoResponse (listado público)
/// - PrestadorDetalleResponse (detalle público con galería)
/// - PrestadorPrivadoResponse (dueño/admin, con estado y metadata)
///
/// Los campos exclusivos del privado (usuario_id, estado, activo)
/// son nullables para permitir el parseo de las 3 variantes.
library;

import 'package:flutter/foundation.dart';

import 'package:baqueano_natales/features/prestadores/domain/categoria_oficio.dart';
import 'package:baqueano_natales/features/prestadores/domain/foto_trabajo.dart';

/// Estado del prestador en el flujo de verificación.
enum EstadoPrestador {
  borrador,
  pendiente,
  verificado,
  rechazado,
  suspendido;

  static EstadoPrestador fromString(String? value) {
    switch (value) {
      case 'borrador':
        return EstadoPrestador.borrador;
      case 'pendiente':
        return EstadoPrestador.pendiente;
      case 'verificado':
        return EstadoPrestador.verificado;
      case 'rechazado':
        return EstadoPrestador.rechazado;
      case 'suspendido':
        return EstadoPrestador.suspendido;
      default:
        return EstadoPrestador.borrador;
    }
  }

  String get label {
    switch (this) {
      case EstadoPrestador.borrador:
        return 'Borrador';
      case EstadoPrestador.pendiente:
        return 'Pendiente';
      case EstadoPrestador.verificado:
        return 'Verificado';
      case EstadoPrestador.rechazado:
        return 'Rechazado';
      case EstadoPrestador.suspendido:
        return 'Suspendido';
    }
  }
}

class Prestador {
  const Prestador({
    required this.id,
    required this.slug,
    required this.nombre,
    this.descripcion,
    required this.categoria,
    this.categoriaId,
    this.telefono,
    this.whatsapp,
    this.email,
    this.sitioWeb,
    required this.comuna,
    required this.region,
    this.direccion,
    this.latitud,
    this.longitud,
    this.radioCoberturaKm,
    this.atiendeDomicilio = false,
    this.atiendeLocal = true,
    this.atiendeEmergencias = false,
    this.horarioDescripcion,
    this.fotoUrl,
    // Estado (solo en privado/admin)
    this.usuarioId,
    this.estado,
    this.motivoRechazo,
    this.destacado = false,
    this.verificado = false,
    this.verificadoEn,
    this.verificadoPorId,
    this.activo = true,
    // JSONB
    this.especialidades,
    this.datosExtra,
    // Stats
    this.calificacionPromedio = 0,
    this.totalResenas = 0,
    // Metadata
    this.createdAt,
    this.updatedAt,
    // Galería (solo en detalle/privado)
    this.fotosTrabajos = const [],
  });

  final String id;
  final String slug;
  final String nombre;
  final String? descripcion;
  final CategoriaOficio categoria;
  final String? categoriaId;
  final String? telefono;
  final String? whatsapp;
  final String? email;
  final String? sitioWeb;
  final String comuna;
  final String region;
  final String? direccion;
  final double? latitud;
  final double? longitud;
  final double? radioCoberturaKm;

  final bool atiendeDomicilio;
  final bool atiendeLocal;
  final bool atiendeEmergencias;
  final String? horarioDescripcion;
  final String? fotoUrl;

  final String? usuarioId;
  final EstadoPrestador? estado;
  final String? motivoRechazo;
  final bool destacado;
  final bool verificado;
  final DateTime? verificadoEn;
  final String? verificadoPorId;
  final bool activo;

  final List<String>? especialidades;
  final Map<String, dynamic>? datosExtra;

  final double calificacionPromedio;
  final int totalResenas;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  final List<FotoTrabajo> fotosTrabajos;

  // =========================================================
  // Helpers
  // =========================================================

  /// Rating con 1 decimal.
  String get ratingLegible => calificacionPromedio.toStringAsFixed(1);

  /// ¿Es público (verificado y activo)?
  bool get esPublico => estado == EstadoPrestador.verificado && activo;

  /// Modalidades en formato legible.
  List<String> get modalidades {
    final r = <String>[];
    if (atiendeDomicilio) r.add('A domicilio');
    if (atiendeLocal) r.add('En local');
    if (atiendeEmergencias) r.add('Emergencias');
    return r;
  }

  /// Primera letra(s) para avatar por defecto.
  String get iniciales {
    final partes = nombre.trim().split(RegExp(r'\s+'));
    if (partes.isEmpty) return '?';
    if (partes.length == 1) {
      return partes[0].isNotEmpty ? partes[0][0].toUpperCase() : '?';
    }
    final a = partes[0].isNotEmpty ? partes[0][0] : '';
    final b = partes[1].isNotEmpty ? partes[1][0] : '';
    return '$a$b'.toUpperCase();
  }

  // =========================================================
  // fromJson — DEFENSIVO
  // =========================================================
  factory Prestador.fromJson(Map<String, dynamic> json) {
    try {
      return Prestador(
        id: _str(json, 'id'),
        slug: _str(json, 'slug'),
        nombre: _str(json, 'nombre'),
        descripcion: _strOrNull(json, 'descripcion'),
        categoria: _categoriaFromJson(json['categoria']) ??
            _categoriaFallback(),
        categoriaId: _strOrNull(json, 'categoria_id'),
        telefono: _strOrNull(json, 'telefono'),
        whatsapp: _strOrNull(json, 'whatsapp'),
        email: _strOrNull(json, 'email'),
        sitioWeb: _strOrNull(json, 'sitio_web'),
        comuna: _strOr(json, 'comuna', 'Puerto Natales'),
        region: _strOr(json, 'region', 'Magallanes'),
        direccion: _strOrNull(json, 'direccion'),
        latitud: _toDouble(json['latitud']),
        longitud: _toDouble(json['longitud']),
        radioCoberturaKm: _toDouble(json['radio_cobertura_km']),
        atiendeDomicilio: (json['atiende_domicilio'] as bool?) ?? false,
        atiendeLocal: (json['atiende_local'] as bool?) ?? true,
        atiendeEmergencias:
            (json['atiende_emergencias'] as bool?) ?? false,
        horarioDescripcion: _strOrNull(json, 'horario_descripcion'),
        fotoUrl: _strOrNull(json, 'foto_url'),
        usuarioId: _strOrNull(json, 'usuario_id'),
        estado: json['estado'] != null
            ? EstadoPrestador.fromString(json['estado'].toString())
            : null,
        motivoRechazo: _strOrNull(json, 'motivo_rechazo'),
        destacado: (json['destacado'] as bool?) ?? false,
        verificado: (json['verificado'] as bool?) ?? false,
        verificadoEn: _dateOrNull(json['verificado_en']),
        verificadoPorId: _strOrNull(json, 'verificado_por_id'),
        activo: (json['activo'] as bool?) ?? true,
        especialidades: _listString(json['especialidades']),
        datosExtra: _mapOrNull(json['datos_extra']),
        calificacionPromedio: _toDouble(json['calificacion_promedio']) ?? 0,
        totalResenas: _toInt(json['total_resenas']) ?? 0,
        createdAt: _dateOrNull(json['created_at']),
        updatedAt: _dateOrNull(json['updated_at']),
        fotosTrabajos: _fotosFromJson(json['fotos_trabajos']),
      );
    } catch (e, st) {
      debugPrint('[Prestador.fromJson] ❌ Parse error: $e');
      debugPrint('[Prestador.fromJson] Stack: $st');
      debugPrint('[Prestador.fromJson] JSON crudo: $json');
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
      debugPrint('[Prestador] Campo requerido "$key" es null');
      return '';
    }
    return v.toString();
  }

  static String _strOr(
    Map<String, dynamic> json,
    String key,
    String fallback,
  ) {
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

  static List<String>? _listString(dynamic v) {
    if (v == null) return null;
    if (v is List) {
      final out = <String>[];
      for (final item in v) {
        if (item is String && item.isNotEmpty) out.add(item);
      }
      return out.isEmpty ? null : out;
    }
    return null;
  }

  static Map<String, dynamic>? _mapOrNull(dynamic v) {
    if (v == null) return null;
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return Map<String, dynamic>.from(v);
    return null;
  }

  static CategoriaOficio? _categoriaFromJson(dynamic v) {
    if (v == null) return null;
    if (v is Map<String, dynamic>) {
      try {
        return CategoriaOficio.fromJson(v);
      } catch (e) {
        debugPrint('[Prestador] Error parseando categoria: $e');
        return null;
      }
    }
    return null;
  }

  static CategoriaOficio _categoriaFallback() {
    return const CategoriaOficio(
      id: '',
      nombre: 'Sin categoría',
      slug: 'sin-categoria',
      orden: 9999,
      activo: true,
    );
  }

  static List<FotoTrabajo> _fotosFromJson(dynamic v) {
    if (v == null) return const [];
    if (v is List) {
      final result = <FotoTrabajo>[];
      for (final item in v) {
        try {
          if (item is Map<String, dynamic>) {
            result.add(FotoTrabajo.fromJson(item));
          }
        } catch (e) {
          debugPrint('[Prestador] Error parseando foto: $e');
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
      'descripcion': descripcion,
      'categoria': categoria.toJson(),
      'categoria_id': categoriaId,
      'telefono': telefono,
      'whatsapp': whatsapp,
      'email': email,
      'sitio_web': sitioWeb,
      'comuna': comuna,
      'region': region,
      'direccion': direccion,
      'latitud': latitud,
      'longitud': longitud,
      'radio_cobertura_km': radioCoberturaKm,
      'atiende_domicilio': atiendeDomicilio,
      'atiende_local': atiendeLocal,
      'atiende_emergencias': atiendeEmergencias,
      'horario_descripcion': horarioDescripcion,
      'foto_url': fotoUrl,
      'usuario_id': usuarioId,
      'estado': estado?.name,
      'motivo_rechazo': motivoRechazo,
      'destacado': destacado,
      'verificado': verificado,
      'verificado_en': verificadoEn?.toIso8601String(),
      'verificado_por_id': verificadoPorId,
      'activo': activo,
      'especialidades': especialidades,
      'datos_extra': datosExtra,
      'calificacion_promedio': calificacionPromedio,
      'total_resenas': totalResenas,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'fotos_trabajos': fotosTrabajos.map((f) => f.toJson()).toList(),
    };
  }

  @override
  String toString() => 'Prestador($slug, estado=$estado)';
}