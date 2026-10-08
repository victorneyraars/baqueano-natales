/// Entry point de la app Cliente (Baqueano Natales).
///
/// Este main:
/// 1. Configura el tipo de app (client) y entorno (dev).
/// 2. Inicializa Firebase.
/// 3. Arranca la app con ProviderScope (Riverpod).
library;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:baqueano_natales/core/config/app_config.dart';
import 'package:baqueano_natales/core/theme/app_theme.dart';
import 'package:baqueano_natales/shared/router/app_router.dart';

Future<void> main() async {
  // 1. Configuración ANTES que nada
  AppConfig.init(
    type: AppType.client,
    env: Environment.dev, // TODO: cambiar a prod cuando hagamos cutover
  );

  // 2. Inicializar Flutter bindings (necesario para Firebase)
  WidgetsFlutterBinding.ensureInitialized();

  // 3. Inicializar Firebase
  await Firebase.initializeApp();

  // 4. Arrancar la app
  runApp(
    const ProviderScope(
      child: BaqueanoClientApp(),
    ),
  );
}

class BaqueanoClientApp extends ConsumerWidget {
  const BaqueanoClientApp({super.key});

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