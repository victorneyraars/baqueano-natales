/// Wrapper sobre flutter_secure_storage.
///
/// Provee acceso tipado y centralizado al almacenamiento seguro
/// (Android Keystore / iOS Keychain). Usado para guardar el JWT.
library;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  SecureStorageService._();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(),
  );

  // Claves conocidas
  static const _keyAccessToken = 'access_token';
  static const _keyUserId = 'user_id';
  static const _keyUserRole = 'user_role';

  /// Guarda el token de acceso (JWT).
  static Future<void> saveAccessToken(String token) async {
    await _storage.write(key: _keyAccessToken, value: token);
  }

  /// Lee el token de acceso.
  static Future<String?> getAccessToken() async {
    return _storage.read(key: _keyAccessToken);
  }

  /// Guarda el ID del usuario.
  static Future<void> saveUserId(String userId) async {
    await _storage.write(key: _keyUserId, value: userId);
  }

  /// Lee el ID del usuario.
  static Future<String?> getUserId() async {
    return _storage.read(key: _keyUserId);
  }

  /// Guarda el rol del usuario.
  static Future<void> saveUserRole(String role) async {
    await _storage.write(key: _keyUserRole, value: role);
  }

  /// Lee el rol del usuario.
  static Future<String?> getUserRole() async {
    return _storage.read(key: _keyUserRole);
  }

  /// Verifica si hay un token guardado.
  static Future<bool> hasAccessToken() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }

  /// Limpia TODOS los datos almacenados (logout).
  static Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}