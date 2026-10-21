/// Entry point de la app Admin (Baqueano Admin).
library;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:baqueano_natales/core/config/app_config.dart';
import 'package:baqueano_natales/core/services/app_update_service.dart';
import 'package:baqueano_natales/core/theme/app_theme.dart';
import 'package:baqueano_natales/shared/router/app_router.dart';

Future<void> main() async {
  AppConfig.init(type: AppType.admin);
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const ProviderScope(child: BaqueanoAdminApp()));
}

final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

class BaqueanoAdminApp extends ConsumerStatefulWidget {
  const BaqueanoAdminApp({super.key});

  @override
  ConsumerState<BaqueanoAdminApp> createState() => _BaqueanoAdminAppState();
}

class _BaqueanoAdminAppState extends ConsumerState<BaqueanoAdminApp>
    with WidgetsBindingObserver {
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
      // Delay de 2 segundos para estabilizar la UI antes del diálogo
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
