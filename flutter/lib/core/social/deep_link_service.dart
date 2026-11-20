import 'dart:async';

import 'package:app_links/app_links.dart';

/// Servicio centralizado para manejar deep links de la app.
class DeepLinkService {
  DeepLinkService._();
  static final DeepLinkService instance = DeepLinkService._();

  final AppLinks _appLinks = AppLinks();
  bool _initialConsumed = false;

  /// Stream de URIs entrantes (mientras la app esta en foreground).
  Stream<Uri> get stream => _appLinks.uriLinkStream;

  /// Devuelve el URI inicial una sola vez (si la app arranco desde un deep link).
  Future<Uri?> getInitial() async {
    if (_initialConsumed) return null;
    _initialConsumed = true;
    return _appLinks.getInitialLink();
  }

  /// Si el URI es `baqueano://oauth/facebook?token_ref=XXX`,
  /// devuelve el `token_ref` recortado y no vacío. Si no, devuelve null.
  static String? extractFacebookTokenRef(Uri uri) {
    if (uri.scheme != 'baqueano') return null;
    if (uri.host != 'oauth') return null;
    final path = uri.path.startsWith('/') ? uri.path.substring(1) : uri.path;
    if (path != 'facebook') return null;
    final tokenRef = uri.queryParameters['token_ref']?.trim();
    if (tokenRef == null || tokenRef.isEmpty) return null;
    return tokenRef;
  }
}
