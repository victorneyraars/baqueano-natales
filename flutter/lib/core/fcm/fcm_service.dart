/// Servicio de Firebase Cloud Messaging (FCM).
library;

import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:baqueano_natales/core/network/dio_client.dart';

const _canalId = 'baqueano_default';
const _canalNombre = 'Notificaciones de Baqueano';
const _canalDescripcion = 'Recordatorios, promociones y avisos';

class FcmService {
  FcmService({
    FirebaseMessaging? messaging,
    Dio? dio,
    void Function(String path)? onDeepLink,
  })  : _messaging = messaging ?? FirebaseMessaging.instance,
        _dio = dio ?? DioClient.instance,
        // ignore: prefer_initializing_formals
        _onDeepLink = onDeepLink;

  final FirebaseMessaging _messaging;
  final Dio _dio;
  final void Function(String path)? _onDeepLink;
  final _localNotif = FlutterLocalNotificationsPlugin();

  Future<void> inicializar() async {
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

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint(
        '[FCM] foreground: title=${message.notification?.title} '
        'data=${message.data}',
      );
      _mostrarBannerLocal(message);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('[FCM] tap (background): data=${message.data}');
      _procesarTap(message);
    });

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('[FCM] tap (terminated): data=${initialMessage.data}');
      _procesarTap(initialMessage);
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
    if (notification == null) return;
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

  Future<void> _procesarTap(RemoteMessage message) async {
    final logId = message.data['notification_log_id']?.toString();
    if (logId != null && logId.isNotEmpty) {
      await _reportarAperturaPorId(logId);
    }
    final path = _resolverRuta(message);
    if (path != null && _onDeepLink != null) {
      _onDeepLink(path);
    }
  }

  String? _resolverRuta(RemoteMessage message) {
    final tipo = message.data['tipo'] as String?;
    if (tipo == null) return null;

    switch (tipo) {
      case 'recordatorio':
        final objId = message.data['objeto_servicio_id']?.toString();
        if (objId != null && objId.isNotEmpty) {
          return '/mis-vehiculos/$objId/recordatorios';
        }
        return '/mis-vehiculos';
      case 'campana':
        final ordenId = message.data['orden_id']?.toString();
        if (ordenId != null && ordenId.isNotEmpty) {
          return '/mis-ordenes/$ordenId';
        }
        return '/mis-notificaciones';
      case 'sistema':
      case 'promocion':
      default:
        return '/mis-notificaciones';
    }
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
