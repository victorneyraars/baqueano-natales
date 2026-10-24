/// Entry point de la app Cliente.
///
/// El tipo (client) y el environment (dev/prod) se combinan en el flavor:
///   flutter run --flavor clientDev  -t lib/main_client.dart --dart-define-from-file=dart_defines/client_dev.json
///   flutter run --flavor clientProd -t lib/main_client.dart --dart-define-from-file=dart_defines/client_prod.json
library;

import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:baqueano_natales/core/config/app_config.dart';
import 'package:baqueano_natales/core/fcm/fcm_providers.dart';
import 'package:baqueano_natales/features/auth/data/auth_notifier.dart';
import 'package:baqueano_natales/core/theme/app_theme.dart';
import 'package:baqueano_natales/shared/router/app_router.dart';
import 'package:baqueano_natales/core/services/app_update_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  final localNotif = FlutterLocalNotificationsPlugin();
  const initSettings = InitializationSettings(
    android: AndroidInitializationSettings('@drawable/ic_notification'),
  );
  await localNotif.initialize(settings: initSettings);
  await localNotif
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(
        const AndroidNotificationChannel(
          'baqueano_turnos_v6',
          'Notificaciones de Baqueano',
          description: 'Recordatorios, promociones y avisos',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
        ),
      );
  final titulo =
      message.data['titulo']?.toString() ??
      message.notification?.title ??
      'Baqueano';
  final body =
      message.data['body']?.toString() ?? message.notification?.body ?? '';
  final logId = message.data['notification_log_id']?.toString();
  final tipo = message.data['tipo']?.toString() ?? '';
  final esNuevoTurno = tipo == 'turno_nuevo';
  final fotoUrl = esNuevoTurno
      ? (message.data['cliente_foto_url']?.toString() ?? '')
      : (message.data['prestador_foto_url']?.toString() ?? '');
  AndroidBitmap<Object>? largeIcon;
  if (fotoUrl.isNotEmpty) {
    try {
      final r = await http
          .get(Uri.parse(fotoUrl))
          .timeout(const Duration(seconds: 3));
      if (r.statusCode == 200) largeIcon = ByteArrayAndroidBitmap(r.bodyBytes);
    } catch (_) {}
  }
  final servicioNombre =
      message.data['servicio_nombre']?.toString() ??
      message.data['servicio_alias']?.toString() ??
      '';
  final nombreActor = esNuevoTurno
      ? (message.data['cliente_nombre']?.toString() ?? '')
      : (message.data['prestador_nombre']?.toString() ?? '');
  final nombreLabel = esNuevoTurno ? 'Cliente' : 'Prestador';
  final fechaHora = message.data['fecha_hora']?.toString() ?? '';

  final detalleLines = <String>[];
  if (servicioNombre.isNotEmpty) detalleLines.add('Servicio: $servicioNombre');
  if (nombreActor.isNotEmpty) detalleLines.add('$nombreLabel: $nombreActor');
  if (fechaHora.isNotEmpty) detalleLines.add('Fecha: $fechaHora');
  final detalle = detalleLines.join('\n');

  final dedupKey =
      message.messageId ??
      '${message.data['titulo'] ?? ''}|${message.data['body'] ?? ''}';
  final notifId = dedupKey.hashCode;
  await localNotif.show(
    id: notifId,
    title: titulo,
    body: body,
    notificationDetails: NotificationDetails(
      android: AndroidNotificationDetails(
        'baqueano_turnos_v6',
        'Notificaciones de Baqueano',
        importance: Importance.max,
        priority: Priority.max,
        icon: '@drawable/ic_notification',
        largeIcon: largeIcon,
        fullScreenIntent: true,
        category: AndroidNotificationCategory.call,
        visibility: NotificationVisibility.public,
        playSound: true,
        enableVibration: true,
        styleInformation: BigTextStyleInformation(
          detalle,
          contentTitle: titulo,
          summaryText: body,
        ),
        actions: <AndroidNotificationAction>[
          const AndroidNotificationAction(
            'aceptar',
            'Aceptar',
            showsUserInterface: true,
            cancelNotification: true,
          ),
          const AndroidNotificationAction(
            'rechazar',
            'Rechazar',
            showsUserInterface: true,
            cancelNotification: true,
          ),
        ],
      ),
    ),
    payload: jsonEncode({
      'log_id': logId ?? '',
      'turno_id': message.data['turno_id']?.toString() ?? '',
      'prestador_id': message.data['prestador_id']?.toString() ?? '',
    }),
  );
}

Future<void> main() async {
  // 1. Binding primero (canal con código nativo)
  WidgetsFlutterBinding.ensureInitialized();
  // 2. Firebase inicializado antes del handler
  await Firebase.initializeApp();

  // 3. Crear canal v6 síncronamente antes de runApp
  final localNotif = FlutterLocalNotificationsPlugin();
  const androidInit = AndroidInitializationSettings(
    '@drawable/ic_notification',
  );
  await localNotif.initialize(
    settings: const InitializationSettings(android: androidInit),
  );
  await localNotif
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(
        const AndroidNotificationChannel(
          'baqueano_turnos_v6',
          'Notificaciones de Baqueano',
          description: 'Recordatorios, promociones y avisos',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
        ),
      );

  // 4. Handler de background de FCM
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  // 4. Configuración de la app
  AppConfig.init(type: AppType.client);
  // 5. Arranque
  runApp(const ProviderScope(child: BaqueanoClientApp()));
}

final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

class BaqueanoClientApp extends ConsumerStatefulWidget {
  const BaqueanoClientApp({super.key});

  @override
  ConsumerState<BaqueanoClientApp> createState() => _BaqueanoClientAppState();
}

class _BaqueanoClientAppState extends ConsumerState<BaqueanoClientApp>
    with WidgetsBindingObserver {
  bool _navScheduled = false;
  DateTime? _lastCheck;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final now = DateTime.now();
      if (_lastCheck == null ||
          now.difference(_lastCheck!) > const Duration(minutes: 5)) {
        _lastCheck = now;
        _checkUpdatesSilently();
      }
    }
  }

  Future<void> _checkUpdatesSilently() async {
    if (!mounted) return;
    await AppUpdateService.checkForUpdates(
      ref.read(routerProvider),
      scaffoldMessengerKey,
      forceShow: false,
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final fcm = ref.read(fcmServiceProvider);
      await fcm.inicializar();

      // Delay de 2 segundos para que la UI se estabilice antes de mostrar el diálogo
      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        await AppUpdateService.checkForUpdates(
          ref.read(routerProvider),
          scaffoldMessengerKey,
        );
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final pending = ref.watch(pendingNavigationProvider);
    final authState = ref.watch(authNotifierProvider);

    final listoParaNavegar =
        pending != null && pending.isNotEmpty && authState.isAuthenticated;

    if (listoParaNavegar && !_navScheduled) {
      _navScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        debugPrint('[DeepLink] navegando a: $pending');
        router.push(pending);
        ref.read(pendingNavigationProvider.notifier).set(null);
        _navScheduled = false;
      });
    }

    return MaterialApp.router(
      scaffoldMessengerKey: scaffoldMessengerKey,
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
