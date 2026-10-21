/// Providers de FCM (Riverpod).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:baqueano_natales/core/fcm/fcm_service.dart';

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
  );
});
