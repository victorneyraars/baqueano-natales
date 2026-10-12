/// Servicio de Firebase Cloud Messaging (FCM).
///
/// Encapsula:
/// - Inicializacion (listeners foreground + background).
/// - Solicitud de permiso runtime (Android 13+).
/// - Obtencion del token FCM del dispositivo.
/// - Reporte de apertura al backend (analytics).
library;

import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'package:baqueano_natales/core/network/dio_client.dart';

class FcmService {
  FcmService({FirebaseMessaging? messaging, Dio? dio})
      : _messaging = messaging ?? FirebaseMessaging.instance,
        _dio = dio ?? DioClient.instance;

  final FirebaseMessaging _messaging;
  final Dio _dio;

  /// Inicializa FCM: listeners de mensajes + presentacion en foreground.
  /// Llamar UNA VEZ al arranque de la app (en main).
  Future<void> inicializar() async {
    // Mensajes recibidos con la app en foreground.
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint(
        '[FCM] foreground: title=${message.notification?.title} '
        'data=${message.data}',
      );
    });

    // Usuario toco la notificacion (app estaba en background).
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('[FCM] tap (background): data=${message.data}');
      _reportarApertura(message);
    });

    // Si la app estaba terminada y se abrio desde una notif, esto la trae.
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('[FCM] tap (terminated): data=${initialMessage.data}');
      _reportarApertura(initialMessage);
    }

    // Mostrar notificacion tambien con la app en foreground.
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  /// Solicita permiso runtime y devuelve el token FCM, o null si no se otorgo.
  ///
  /// Llamar DESPUES del login (necesita que el usuario este autenticado
  /// para que el backend asocie el token al usuario correcto).
  Future<String?> solicitarPermisoYObtenerToken() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus != AuthorizationStatus.authorized) {
      debugPrint('[FCM] permiso no otorgado: ${settings.authorizationStatus}');
      return null;
    }

    final token = await _messaging.getToken();
    debugPrint('[FCM] token obtenido: ${token?.substring(0, 20)}...');
    return token;
  }

  /// Reporta la apertura al backend (analytics). Best-effort: no lanza.
  ///
  /// El backend incluye `notification_log_id` en el payload del push.
  /// Si no esta, no podemos reportar (notif antigua o tipo no FCM).
  Future<void> _reportarApertura(RemoteMessage message) async {
    final logId = message.data['notification_log_id'];
    if (logId == null || logId.toString().isEmpty) {
      return;
    }
    try {
      await _dio.post('/api/v1/notificaciones/$logId/abierta');
      debugPrint('[FCM] apertura reportada: log_id=$logId');
    } catch (e) {
      // Best-effort: no rompe el flujo si falla el reporte
      debugPrint('[FCM] error reportando apertura: $e');
    }
  }
}
