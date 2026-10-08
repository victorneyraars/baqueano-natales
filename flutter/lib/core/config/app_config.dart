/// Configuración central de la aplicación.
///
/// Define URLs, constantes y el tipo de app (client/admin) en runtime.
/// Este archivo es la ÚNICA fuente de verdad para configuración.
library;

import 'package:flutter/foundation.dart';

enum AppType { client, admin }

enum Environment { dev, prod }

class AppConfig {
  AppConfig._();

  /// Tipo de app (client o admin). Se inicializa en el main correspondiente.
  static late AppType appType;

  /// Entorno actual (dev o prod).
  static late Environment environment;

  /// URL base del backend.
  ///
  /// - dev:  apunta al server nuevo (104.129.59.151) con cert autofirmado.
  /// - prod: apunta a api.baqueanonatales.com (cuando se haga el cutover DNS).
  static String get apiBaseUrl {
    switch (environment) {
      case Environment.dev:
        return 'https://104.129.59.151';
      case Environment.prod:
        return 'https://api.baqueanonatales.com';
    }
  }
  /// Web Client ID de Firebase (necesario para Google Sign-In v7).
  /// Se obtiene de google-services.json (bloque con client_type: 3).
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
  static void init({
    required AppType type,
    Environment env = Environment.dev,
  }) {
    appType = type;
    environment = env;
    if (kDebugMode) {
      debugPrint(
        '[AppConfig] type=$appType, env=$environment, api=$apiBaseUrl',
      );
    }
  }
}