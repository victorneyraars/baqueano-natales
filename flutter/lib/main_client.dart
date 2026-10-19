/// Entry point de la app Cliente.
///
/// El tipo (client) y el environment (dev/prod) se combinan en el flavor:
///   flutter run --flavor clientDev  -t lib/main_client.dart --dart-define-from-file=dart_defines/client_dev.json
///   flutter run --flavor clientProd -t lib/main_client.dart --dart-define-from-file=dart_defines/client_prod.json
library;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:baqueano_natales/core/config/app_config.dart';
import 'package:baqueano_natales/core/fcm/fcm_providers.dart';
import 'package:baqueano_natales/features/auth/data/auth_notifier.dart';
import 'package:baqueano_natales/core/theme/app_theme.dart';
import 'package:baqueano_natales/shared/router/app_router.dart';
import 'package:baqueano_natales/core/services/app_update_service.dart';

Future<void> main() async {
  AppConfig.init(type: AppType.client);

  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  runApp(
    const ProviderScope(
      child: BaqueanoClientApp(),
    ),
  );
}

class BaqueanoClientApp extends ConsumerStatefulWidget {
  const BaqueanoClientApp({super.key});

  @override
  ConsumerState<BaqueanoClientApp> createState() =>
      _BaqueanoClientAppState();
}

class _BaqueanoClientAppState extends ConsumerState<BaqueanoClientApp> {
  bool _navScheduled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final fcm = ref.read(fcmServiceProvider);
      await fcm.inicializar();
      // Check de actualización pasando el router
      await AppUpdateService.checkForUpdates(ref.read(routerProvider));
    });
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
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}

