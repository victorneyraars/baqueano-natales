/// Servicio de Firebase Cloud Messaging (FCM).
///
/// Encapsula:
/// - Inicializacion (listeners foreground + background).
/// - Solicitud de permiso runtime (Android 13+).
/// - Obtencion del token FCM del dispositivo.
library;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class FcmService {
  FcmService({FirebaseMessaging? messaging})
      : _messaging = messaging ?? FirebaseMessaging.instance;

  final FirebaseMessaging _messaging;

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
    });

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
}
