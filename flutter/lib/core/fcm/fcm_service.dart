/// Servicio de Firebase Cloud Messaging (FCM).
///
/// Encapsula:
/// - Inicializacion (listeners foreground + background).
/// - Solicitud de permiso runtime (Android 13+).
/// - Obtencion del token FCM del dispositivo.
/// - Banner en foreground (flutter_local_notifications).
/// - Reporte de apertura al backend (analytics).
library;

import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:baqueano_natales/core/network/dio_client.dart';

/// ID del canal Android. Debe matchear el meta-data del AndroidManifest
/// (com.google.firebase.messaging.default_notification_channel_id).
const _canalId = 'baqueano_default';
const _canalNombre = 'Notificaciones de Baqueano';
const _canalDescripcion = 'Recordatorios, promociones y avisos';

class FcmService {
  FcmService({FirebaseMessaging? messaging, Dio? dio})
      : _messaging = messaging ?? FirebaseMessaging.instance,
        _dio = dio ?? DioClient.instance;

  final FirebaseMessaging _messaging;
  final Dio _dio;
  final _localNotif = FlutterLocalNotificationsPlugin();

  /// Inicializa FCM + el plugin de notificaciones locales.
  /// Llamar UNA VEZ al arranque de la app (en main).
  Future<void> inicializar() async {
    // === Setup flutter_local_notifications ===
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);

    await _localNotif.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (response) {
        final logId = response.payload;
        if (logId != null && logId.isNotEmpty) {
          _reportarAperturaPorId(logId);
        }
      },
    );

    // Canal Android (obligatorio en Android 8+)
    const channel = AndroidNotificationChannel(
      _canalId,
      _canalNombre,
      description: _canalDescripcion,
      importance: Importance.high,
    );
    await _localNotif
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // === FCM listeners ===
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint(
        '[FCM] foreground: title=${message.notification?.title} '
        'data=${message.data}',
      );
      _mostrarBannerLocal(message);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('[FCM] tap (background): data=${message.data}');
      final logId = message.data['notification_log_id'];
      if (logId != null) {
        _reportarAperturaPorId(logId.toString());
      }
    });

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('[FCM] tap (terminated): data=${initialMessage.data}');
      final logId = initialMessage.data['notification_log_id'];
      if (logId != null) {
        _reportarAperturaPorId(logId.toString());
      }
    }

    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

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

  Future<void> _mostrarBannerLocal(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) {
      return;
    }
    final logId = message.data['notification_log_id']?.toString();

    await _localNotif.show(
      id: notification.hashCode,
      title: notification.title ?? 'Baqueano',
      body: notification.body ?? '',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _canalId,
          _canalNombre,
          channelDescription: _canalDescripcion,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      payload: logId,
    );
  }

  Future<void> _reportarAperturaPorId(String logId) async {
    if (logId.isEmpty) return;
    try {
      await _dio.post('/api/v1/notificaciones/$logId/abierta');
      debugPrint('[FCM] apertura reportada: log_id=$logId');
    } catch (e) {
      debugPrint('[FCM] error reportando apertura: $e');
    }
  }
}
