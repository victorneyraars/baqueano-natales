/// Entry point de la app Admin (Baqueano Admin).
///
/// El environment (dev/prod) se inyecta con --dart-define-from-file:
///   flutter run --flavor adminDev  -t lib/main_admin.dart --dart-define-from-file=dart_defines/admin_dev.json
///   flutter run --flavor adminProd -t lib/main_admin.dart --dart-define-from-file=dart_defines/admin_prod.json
library;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:baqueano_natales/core/config/app_config.dart';
import 'package:baqueano_natales/core/theme/app_theme.dart';
import 'package:baqueano_natales/shared/router/app_router.dart';

Future<void> main() async {
  AppConfig.init(type: AppType.admin);

  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  runApp(
    const ProviderScope(
      child: BaqueanoAdminApp(),
    ),
  );
}

class BaqueanoAdminApp extends ConsumerWidget {
  const BaqueanoAdminApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

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