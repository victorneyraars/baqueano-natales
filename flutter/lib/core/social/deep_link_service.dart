import 'dart:async';

import 'package:app_links/app_links.dart';

/// Servicio centralizado para manejar deep links de la app.
///
/// Uso:
/// ```dart
/// final sub = DeepLinkService.instance.stream.listen((uri) {
///   // procesar el uri
/// });
/// ```
class DeepLinkService {
  DeepLinkService._();
  static final DeepLinkService instance = DeepLinkService._();

  final AppLinks _appLinks = AppLinks();

  /// Stream de URIs entrantes (mientras la app esta en foreground).
  Stream<Uri> get stream => _appLinks.uriLinkStream;

  /// Devuelve el URI inicial (si la app arranco desde un deep link).
  Future<Uri?> getInitial() => _appLinks.getInitialLink();

  /// Si el URI es `baqueano://oauth/facebook?token_ref=XXX`,
  /// devuelve el `token_ref`. Si no, devuelve null.
  static String? extractFacebookTokenRef(Uri uri) {
    if (uri.scheme != 'baqueano') return null;
    if (uri.host != 'oauth') return null;
    // El path puede ser 'facebook' o '/facebook' segun el SO
    final path = uri.path.startsWith('/') ? uri.path.substring(1) : uri.path;
    if (path != 'facebook') return null;
    return uri.queryParameters['token_ref'];
  }
}
