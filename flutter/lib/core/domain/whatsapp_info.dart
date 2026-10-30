import 'package:baqueano_natales/core/services/whatsapp_service.dart';

/// Info de WhatsApp de un prestador.
///
/// El backend expone este objeto en /perfil-completo y /prestadores/{slug}
/// bajo la clave whatsapp_info (y como whatsapp top-level en perfil-completo).
class WhatsAppInfo {
  final String phoneE164;
  final String phoneDigits;
  final Map<String, String> templates;

  const WhatsAppInfo({
    required this.phoneE164,
    required this.phoneDigits,
    required this.templates,
  });

  factory WhatsAppInfo.fromJson(Map<String, dynamic> json) {
    final e164 = json['phone_e164'] is String
        ? json['phone_e164'] as String
        : '';
    final digits = json['phone_digits'] is String
        ? json['phone_digits'] as String
        : '';
    final raw = json['templates'];
    final templates = <String, String>{};
    if (raw is Map) {
      for (final entry in raw.entries) {
        if (entry.key is String && entry.value is String) {
          templates[entry.key as String] = entry.value as String;
        }
      }
    }
    return WhatsAppInfo(
      phoneE164: e164,
      phoneDigits: digits,
      templates: templates,
    );
  }

  /// Fallback hardcodeado (mismo que rentacarvasquez-web).
  factory WhatsAppInfo.fallback() => const WhatsAppInfo(
    phoneE164: '+56941721688',
    phoneDigits: '56941721688',
    templates: {
      'home': 'Hola, vengo de rentacarvasquez.com. Quiero consultar por arriendo de un vehiculo.',
      'vehiculo':
          'Hola, me interesa el {marca} {modelo} ({patente}). Esta disponible?',
      'reserva': 'Hola, quiero consultar por mi reserva.',
      'app': 'Hola, vengo desde la app Baqueano. Quiero consultar.',
      '_default': 'Hola, quiero hacer una consulta.',
    },
  );

  bool get isConfigured => phoneDigits.isNotEmpty && templates.isNotEmpty;

  /// Mensaje interpolado para el contexto dado.
  /// Fallback: template '_default' o string vacio.
  String messageFor(String context, [Map<String, String> vars = const {}]) {
    final template = templates[context] ?? templates['_default'] ?? '';
    return WhatsAppService.interpolate(template, vars);
  }

  /// URL wa.me final (o null si no hay telefono).
  Uri? uriFor(String context, [Map<String, String> vars = const {}]) {
    if (phoneDigits.isEmpty) return null;
    final msg = messageFor(context, vars);
    return Uri.parse('https://wa.me/$phoneDigits')
        .replace(queryParameters: {'text': msg});
  }

  Map<String, dynamic> toJson() => {
    'phone_e164': phoneE164,
    'phone_digits': phoneDigits,
    'templates': templates,
  };
}
