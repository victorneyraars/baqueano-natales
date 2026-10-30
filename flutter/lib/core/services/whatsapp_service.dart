import 'package:url_launcher/url_launcher.dart';

/// Servicio de WhatsApp compartido por toda la app.
///
/// Reglas:
/// - SIEMPRE LaunchMode.externalApplication (regla #6 del proyecto)
/// - Encoding via Uri.replace(queryParameters) evita bugs de doble-encoding
/// - interpolate() reemplaza {var} con valores; deja intactos los placeholders
///   sin valor (util para debug)
class WhatsAppService {
  WhatsAppService._();

  /// Abre WhatsApp con un mensaje pre-cargado.
  /// Devuelve true si el lanzamiento fue exitoso.
  static Future<bool> open({
    required String phoneDigits,
    required String message,
  }) async {
    if (phoneDigits.isEmpty) return false;
    final uri = Uri.parse('https://wa.me/$phoneDigits')
        .replace(queryParameters: {'text': message});
    if (!await canLaunchUrl(uri)) return false;
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  /// Reemplaza {var} en el template. Si una variable falta, deja {var}
  /// intacto (mejor que un string vacio silencioso).
  static String interpolate(String template, Map<String, String> vars) {
    if (vars.isEmpty) return template;
    return template.replaceAllMapped(
      RegExp(r'\{(\w+)\}'),
      (m) => vars[m.group(1)] ?? m.group(0)!,
    );
  }
}
