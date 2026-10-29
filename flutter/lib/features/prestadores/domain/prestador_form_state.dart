import 'perfil_negocio.dart';
import 'prestador.dart';

/// Estado completo e inmutable del formulario de prestador.
///
/// Concentra:
/// - Campos planos editables (nombre, categoría, contacto, redes)
/// - Campos nuevos (razón social, RUT, GBP place_id, precio_desde)
/// - PerfilNegocio (JSONB con datos estructurados para GBP/JSON-LD)
///
/// Uso desde el form (estado local, no Riverpod):
///   PrestadorFormState _state = PrestadorFormState.fromPrestador(p);
///   _state = _state.copyWith(nombre: nuevoNombre);
///   await repo.editarPrestador(id: id, cambios: _state.toJson());
class PrestadorFormState {
  const PrestadorFormState({
    this.nombre = '',
    this.categoriaId,
    this.descripcion,
    this.aniosExperiencia,
    this.telefono,
    this.whatsapp,
    this.whatsappMensaje,
    this.email,
    this.sitioWeb,
    this.razonSocial,
    this.rutEmpresa,
    this.gbpPlaceId,
    this.gbpMapsUrl,
    this.precioDesde,
    this.brandKitSlug,
    this.especialidades = const [],
    this.perfilNegocio = const PerfilNegocio(),
  });

  final String nombre;
  final String? categoriaId;
  final String? descripcion;
  final int? aniosExperiencia;
  final String? telefono;
  final String? whatsapp;
  final String? whatsappMensaje;
  final String? email;
  final String? sitioWeb;
  final String? razonSocial;
  final String? rutEmpresa;
  final String? gbpPlaceId;
  final String? gbpMapsUrl;
  final double? precioDesde;
  final String? brandKitSlug;
  final List<String> especialidades;
  final PerfilNegocio perfilNegocio;

  /// Construye el estado inicial desde un Prestador cargado del backend.
  ///
  /// Maneja dos casos:
  /// - Prestador con perfil_negocio cargado (formato nuevo)
  /// - Prestador con solo campos planos (formato legacy)
  factory PrestadorFormState.fromPrestador(Prestador p) {
    return PrestadorFormState(
      nombre: p.nombre,
      categoriaId: p.categoriaId,
      descripcion: p.descripcion,
      aniosExperiencia: p.aniosExperiencia,
      telefono: p.telefono,
      whatsapp: p.whatsapp,
      whatsappMensaje: p.whatsappMensaje,
      email: p.email,
      sitioWeb: p.sitioWeb,
      razonSocial: p.razonSocial,
      rutEmpresa: p.rutEmpresa,
      gbpPlaceId: p.gbpPlaceId,
      gbpMapsUrl: p.gbpMapsUrl,
      precioDesde: p.precioDesde,
      brandKitSlug: p.brandKitSlug,
      especialidades: p.especialidades ?? const [],
      perfilNegocio: p.perfilNegocio ?? const PerfilNegocio(),
    );
  }

  /// Payload para PATCH /api/v1/mis-prestadores/{id}.
  ///
  /// Solo envía campos no-null (el backend interpreta ausencia = no cambiar).
  /// NOTA: enviar `perfil_negocio` aunque esté vacío limpia el perfil si se
  /// cargó algo antes. Si querés conservar, no lo mandes cuando esté vacío.
  Map<String, dynamic> toJson() {
    return {
      if (nombre.isNotEmpty) 'nombre': nombre,
      if (categoriaId != null) 'categoria_id': categoriaId,
      if (descripcion != null) 'descripcion': descripcion,
      if (aniosExperiencia != null) 'anios_experiencia': aniosExperiencia,
      if (telefono != null) 'telefono': telefono,
      if (whatsapp != null) 'whatsapp': whatsapp,
      if (whatsappMensaje != null) 'whatsapp_mensaje': whatsappMensaje,
      if (email != null) 'email': email,
      if (sitioWeb != null) 'sitio_web': sitioWeb,
      if (razonSocial != null) 'razon_social': razonSocial,
      if (rutEmpresa != null) 'rut_empresa': rutEmpresa,
      if (gbpPlaceId != null) 'gbp_place_id': gbpPlaceId,
      if (gbpMapsUrl != null) 'gbp_maps_url': gbpMapsUrl,
      if (precioDesde != null) 'precio_desde': precioDesde,
      if (brandKitSlug != null) 'brand_kit_slug': brandKitSlug,
      if (especialidades.isNotEmpty) 'especialidades': especialidades,
      'perfil_negocio': perfilNegocio.toJson(),
    };
  }

  /// copyWith inmutable. Si un campo no se pasa, mantiene el actual.
  PrestadorFormState copyWith({
    String? nombre,
    String? categoriaId,
    String? descripcion,
    int? aniosExperiencia,
    String? telefono,
    String? whatsapp,
    String? whatsappMensaje,
    String? email,
    String? sitioWeb,
    String? razonSocial,
    String? rutEmpresa,
    String? gbpPlaceId,
    String? gbpMapsUrl,
    double? precioDesde,
    String? brandKitSlug,
    List<String>? especialidades,
    PerfilNegocio? perfilNegocio,
  }) {
    return PrestadorFormState(
      nombre: nombre ?? this.nombre,
      categoriaId: categoriaId ?? this.categoriaId,
      descripcion: descripcion ?? this.descripcion,
      aniosExperiencia: aniosExperiencia ?? this.aniosExperiencia,
      telefono: telefono ?? this.telefono,
      whatsapp: whatsapp ?? this.whatsapp,
      whatsappMensaje: whatsappMensaje ?? this.whatsappMensaje,
      email: email ?? this.email,
      sitioWeb: sitioWeb ?? this.sitioWeb,
      razonSocial: razonSocial ?? this.razonSocial,
      rutEmpresa: rutEmpresa ?? this.rutEmpresa,
      gbpPlaceId: gbpPlaceId ?? this.gbpPlaceId,
      gbpMapsUrl: gbpMapsUrl ?? this.gbpMapsUrl,
      precioDesde: precioDesde ?? this.precioDesde,
      brandKitSlug: brandKitSlug ?? this.brandKitSlug,
      especialidades: especialidades ?? this.especialidades,
      perfilNegocio: perfilNegocio ?? this.perfilNegocio,
    );
  }
}
