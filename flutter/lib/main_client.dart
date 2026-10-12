/// Entry point de la app Cliente.
library;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:baqueano_natales/core/config/app_config.dart';
import 'package:baqueano_natales/core/fcm/fcm_providers.dart';
import 'package:baqueano_natales/features/auth/data/auth_notifier.dart';
import 'package:baqueano_natales/core/theme/app_theme.dart';
import 'package:baqueano_natales/shared/router/app_router.dart';

Future<void> main() async {
  AppConfig.init(
    type: AppType.client,
    env: Environment.dev,
  );

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
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final pending = ref.watch(pendingNavigationProvider);
    final authState = ref.watch(authNotifierProvider);

    // Deep link: esperar a que la sesion este autenticada antes de navegar.
    // Si no, el router (que tiene guard de auth) redirige a /home y se pierde.
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
