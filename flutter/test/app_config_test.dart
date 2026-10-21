import 'package:flutter_test/flutter_test.dart';
import 'package:baqueano_natales/core/config/app_config.dart';

void main() {
  group('AppConfig', () {
    test('init configura correctamente el tipo de app y el entorno', () {
      // 1. Inicializar con un tipo y entorno específicos
      AppConfig.init(type: AppType.client, env: Environment.staging);

      // 2. Verificar que los valores se asignaron correctamente
      expect(AppConfig.appType, equals(AppType.client));
      expect(AppConfig.environment, equals(Environment.staging));

      // 3. Verificar que la URL base es la correcta para staging (api-dev)
      expect(AppConfig.apiBaseUrl, equals('https://api-dev.baqueanonatales.com'));
    });

    test('apiBaseUrl devuelve api de producción cuando el entorno es prod', () {
      AppConfig.init(type: AppType.admin, env: Environment.prod);
      
      expect(AppConfig.appType, equals(AppType.admin));
      expect(AppConfig.environment, equals(Environment.prod));
      expect(AppConfig.apiBaseUrl, equals('https://api.baqueanonatales.com'));
    });
  });
}
