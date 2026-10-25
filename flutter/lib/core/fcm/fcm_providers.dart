/// Providers de FCM (Riverpod).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:baqueano_natales/core/fcm/fcm_service.dart';
import 'package:baqueano_natales/features/oficios/data/oficios_providers.dart';

/// Notifier de la ruta pendiente de navegacion (deep link desde una notif).
class PendingNavigation extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? path) => state = path;
}

/// Ruta pendiente de navegacion.
///
/// El FcmService la setea al tocar una notif. El widget raiz la observa
/// y navega via GoRouter, luego la limpia (vuelve a null).
final pendingNavigationProvider = NotifierProvider<PendingNavigation, String?>(
  PendingNavigation.new,
);

/// Provider del servicio FCM (singleton).
final fcmServiceProvider = Provider<FcmService>((ref) {
  return FcmService(
    onDeepLink: (path) {
      ref.read(pendingNavigationProvider.notifier).set(path);
    },
    onRefreshNeeded: () {
      // Refrescar lista de turnos si el usuario está en la pantalla.
      // Ignora errores si el provider no está montado aún.
      try {
        ref.invalidate(misTurnosProvider(null));
      } catch (_) {}
    },
  );
});
