/// Providers de FCM (Riverpod).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:baqueano_natales/core/fcm/fcm_service.dart';

/// Provider del servicio FCM (singleton).
final fcmServiceProvider = Provider<FcmService>((ref) {
  return FcmService();
});
