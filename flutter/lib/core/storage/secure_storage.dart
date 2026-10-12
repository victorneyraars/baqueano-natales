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
  static const _keyLastFcmTap = 'last_fcm_tap';

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

  /// Guarda el ultimo tap de notificacion FCM procesado.
  ///
  /// Formato: `<messageKey>|<timestampMs>`. `messageKey` puede contener
  /// pipes (fallback `tipo|logId|sentTimeMs`), por eso parseamos con
  /// `lastIndexOf('|')` en `getFcmTap`.
  static Future<void> saveFcmTap(String messageKey, int timestampMs) async {
    await _storage.write(
      key: _keyLastFcmTap,
      value: '$messageKey|$timestampMs',
    );
  }

  /// Lee el ultimo tap de notificacion FCM procesado.
  ///
  /// Devuelve `null` si nunca se proceso un tap o si el valor guardado
  /// esta corrupto. El caller decide la ventana temporal para deduplicar.
  static Future<({String messageKey, int timestampMs})?> getFcmTap() async {
    final raw = await _storage.read(key: _keyLastFcmTap);
    if (raw == null || raw.isEmpty) return null;
    final idx = raw.lastIndexOf('|');
    if (idx <= 0) return null;
    final messageKey = raw.substring(0, idx);
    final timestampMs = int.tryParse(raw.substring(idx + 1));
    if (timestampMs == null) return null;
    return (messageKey: messageKey, timestampMs: timestampMs);
  }

  /// Limpia TODOS los datos almacenados (logout).
  static Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}