/// Configuración central de la aplicación.
///
/// Define URLs, constantes y el tipo de app (client/admin) en runtime.
/// Los valores de entorno se inyectan por `--dart-define-from-file` al compilar.
library;

import 'package:flutter/foundation.dart';

enum AppType { client, admin }

enum Environment { dev, prod }

class AppConfig {
  AppConfig._();

  /// Tipo de app (client o admin). Se inicializa en el main correspondiente.
  static late AppType appType;

  /// Entorno actual (dev o prod).
  ///
  /// Se deriva de `String.fromEnvironment('ENVIRONMENT')` inyectado por
  /// `--dart-define-from-file`. Default: dev.
  static late Environment environment;

  /// URL base del backend.
  ///
  /// Se inyecta con `--dart-define-from-file` (clave `API_URL`). Si no
  /// se inyecta, cae a un default seguro según `environment`.
  static String get apiBaseUrl {
    const url = String.fromEnvironment('API_URL');
    if (url.isNotEmpty) return url;
    return environment == Environment.prod
        ? 'https://api.baqueanonatales.com'
        : 'https://api-dev.baqueanonatales.com';
  }

  /// Web Client ID de Firebase (necesario para Google Sign-In).
  static const String googleServerClientId =
      '1072830106109-c1b5cktisbj3khu8s9jmf7crn8ni0dh7.apps.googleusercontent.com';

  /// Nombre visible de la app según el tipo.
  static String get appName {
    switch (appType) {
      case AppType.client:
        return 'Baqueano Natales';
      case AppType.admin:
        return 'Baqueano Admin';
    }
  }

  /// Inicializa la configuración global.
  ///
  /// Debe llamarse como PRIMERA línea del main() de cada entry point.
  /// Si no se pasa `env`, se deriva de `--dart-define=ENVIRONMENT`.
  static void init({
    required AppType type,
    Environment? env,
  }) {
    appType = type;
    if (env != null) {
      environment = env;
    } else {
      const envStr = String.fromEnvironment('ENVIRONMENT', defaultValue: 'dev');
      environment = envStr == 'prod' ? Environment.prod : Environment.dev;
    }
    if (kDebugMode) {
      debugPrint(
        '[AppConfig] type=$appType, env=$environment, api=$apiBaseUrl',
      );
    }
  }
}