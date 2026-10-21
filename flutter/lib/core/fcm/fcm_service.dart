/// Servicio de Firebase Cloud Messaging (FCM).
library;

import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:baqueano_natales/core/network/dio_client.dart';
import 'package:baqueano_natales/core/storage/secure_storage.dart';

const _canalId = 'baqueano_default';
const _canalNombre = 'Notificaciones de Baqueano';
const _canalDescripcion = 'Recordatorios, promociones y avisos';

/// Ventana en la que un mismo tap se considera duplicado.
///
/// Cubre hot restart (el plugin nativo cachea `getInitialMessage` y Dart
/// pierde su estado en memoria). 30s es suficiente para el caso dev y
/// no bloquea un cold start legitimo del mismo mensaje.
const _dedupWindowMs = 30 * 1000;

/// Limite del set in-session para no crecer indefinidamente.
const _dedupSetMaxSize = 30;

class FcmService {
  FcmService({
    FirebaseMessaging? messaging,
    Dio? dio,
    void Function(String path)? onDeepLink,
  }) : _messaging = messaging ?? FirebaseMessaging.instance,
       _dio = dio ?? DioClient.instance,
       // ignore: prefer_initializing_formals
       _onDeepLink = onDeepLink;

  final FirebaseMessaging _messaging;
  final Dio _dio;
  final void Function(String path)? _onDeepLink;
  final _localNotif = FlutterLocalNotificationsPlugin();

  /// Message keys procesados en esta sesion (FIFO acotado).
  ///
  /// Static a proposito: tras hot restart, el plugin nativo de
  /// flutter_local_notifications puede retener un callback al isolate
  /// viejo y quedar 2 instancias de FcmService vivas. El Set compartido
  /// garantiza que ambas deduplican entre si.
  static final Set<String> _procesadosEnSesion = <String>{};

  Future<void> inicializar() async {
    const androidInit = AndroidInitializationSettings(
      '@drawable/ic_notification',
    );
    const initSettings = InitializationSettings(android: androidInit);

    await _localNotif.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (response) {
        final logId = response.payload;
        if (logId == null || logId.isEmpty) return;
        _procesarTapLocal(logId);
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
          AndroidFlutterLocalNotificationsPlugin
        >()
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
      _procesarTapFcm(message);
    });

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('[FCM] tap (terminated): data=${initialMessage.data}');
      _procesarTapFcm(initialMessage);
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
    // El payload del banner local es el logId: al tocar, el callback
    // `onDidReceiveNotificationResponse` lo usa para deduplicar y
    // reportar la apertura.
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
          icon: '@drawable/ic_notification',
        ),
      ),
      payload: logId,
    );
  }

  /// Key canonica para deduplicar un tap.
  ///
  /// Usa `notification_log_id` (que identifica univocamente cada envio y
  /// esta disponible en los 3 paths: banner local, `onMessageOpenedApp`
  /// y `getInitialMessage`). Fallback a `messageId` de FCM si el logId
  /// no esta (no deberia pasar en el flujo normal).
  String _messageKey(RemoteMessage message) {
    final logId = message.data['notification_log_id']?.toString();
    if (logId != null && logId.isNotEmpty) return 'log:$logId';
    final id = message.messageId;
    if (id != null && id.isNotEmpty) return 'msg:$id';
    final tipo = message.data['tipo']?.toString() ?? '';
    final sentTime = message.sentTime?.millisecondsSinceEpoch ?? 0;
    return 'fb:$tipo|$sentTime';
  }

  /// Registra el key en el set in-session SIN await intermedio.
  ///
  /// Devuelve `true` si era nuevo (se agrego), `false` si ya estaba.
  /// Este metodo es **sincrono** a proposito: entre el `contains` y el
  /// `add` no debe haber un `await`, porque dos eventos casi simultaneos
  /// (`onDidReceiveNotificationResponse` + `onMessageOpenedApp`) entrarian
  /// en paralelo y ambos pasarian el check.
  bool _registrarEnSesionSync(String key) {
    if (_procesadosEnSesion.contains(key)) return false;
    _procesadosEnSesion.add(key);
    if (_procesadosEnSesion.length > _dedupSetMaxSize) {
      _procesadosEnSesion.remove(_procesadosEnSesion.first);
    }
    return true;
  }

  /// Devuelve `true` si el tap ya fue procesado (in-session o persistente).
  ///
  /// Si devuelve `false`, deja el tap marcado como procesado antes de
  /// retornar (in-session + persistente).
  Future<bool> _yaProcesado(String key) async {
    // 1. Check + add SINCRONO: elimina el race entre los paths que
    //    disparan casi simultaneamente.
    if (!_registrarEnSesionSync(key)) {
      debugPrint('[FCM] dedup in-session: $key');
      return true;
    }

    // 2. Check persistente (cubre hot restart, donde el set se vacia
    //    pero el plugin nativo re-entrega getInitialMessage).
    final ultimo = await SecureStorageService.getFcmTap();
    if (ultimo != null && ultimo.messageKey == key) {
      final ahoraMs = DateTime.now().millisecondsSinceEpoch;
      if (ahoraMs - ultimo.timestampMs < _dedupWindowMs) {
        debugPrint('[FCM] dedup persistente: $key');
        return true;
      }
    }

    // 3. Persistir para la proxima sesion.
    await SecureStorageService.saveFcmTap(
      key,
      DateTime.now().millisecondsSinceEpoch,
    );
    return false;
  }

  /// Path del banner local (`flutter_local_notifications`).
  ///
  /// El payload es el logId directamente (no tenemos el RemoteMessage).
  Future<void> _procesarTapLocal(String logId) async {
    final key = 'log:$logId';
    if (await _yaProcesado(key)) return;
    await _reportarAperturaPorId(logId);
  }

  /// Path de FCM (`onMessageOpenedApp` + `getInitialMessage`).
  Future<void> _procesarTapFcm(RemoteMessage message) async {
    final key = _messageKey(message);
    if (await _yaProcesado(key)) return;

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
