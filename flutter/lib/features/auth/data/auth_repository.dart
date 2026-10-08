/// Repositorio de autenticación.
///
/// Encapsula las llamadas HTTP al backend (login con Google, obtener
/// usuario actual, logout). No maneja estado, solo hace las llamadas
/// y devuelve los datos o lanza ApiException.
///
/// Usa google_sign_in 7.x con la nueva API:
/// - GoogleSignIn.instance (singleton)
/// - initialize() obligatorio antes de authenticate()
/// - authenticate() para identidad
/// - authorizationClient.authorizeScopes() para accessToken
library;

import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:google_sign_in/google_sign_in.dart';

import 'package:baqueano_natales/core/config/app_config.dart';
import 'package:baqueano_natales/core/network/api_exceptions.dart';
import 'package:baqueano_natales/core/network/dio_client.dart';
import 'package:baqueano_natales/core/storage/secure_storage.dart';
import 'package:baqueano_natales/features/auth/domain/user.dart';

class AuthRepository {
  AuthRepository({
    Dio? dio,
    fb.FirebaseAuth? firebaseAuth,
    GoogleSignIn? googleSignIn,
    String? serverClientId,
  })  : _dio = dio ?? DioClient.instance,
        _firebaseAuth = firebaseAuth ?? fb.FirebaseAuth.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn.instance,
        _serverClientId =
            serverClientId ?? AppConfig.googleServerClientId;

  final Dio _dio;
  final fb.FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;
  final String _serverClientId;

  bool _initialized = false;

  /// Inicializa el plugin de Google Sign-In.
  ///
  /// Debe llamarse UNA SOLA VEZ antes de authenticate().
  /// La v7 requiere inicialización explícita con serverClientId.
  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    await _googleSignIn.initialize(
      serverClientId: _serverClientId,
    );
    _initialized = true;
  }

  /// Inicia sesión con Google.
  ///
  /// Flujo (google_sign_in 7.x):
  /// 1. Asegurar inicialización de GoogleSignIn.
  /// 2. authenticate() → identidad del usuario (idToken).
  /// 3. authorizeScopes() → accessToken con permisos.
  /// 4. Crear credencial de Firebase con idToken + accessToken.
  /// 5. Firebase Auth → idToken de Firebase.
  /// 6. Enviar al backend (/api/v1/auth/google).
  /// 7. Guardar JWT en storage seguro.
  ///
  /// Devuelve el User autenticado.
  ///
  /// Lanza ApiException si algo falla.
  Future<User> loginWithGoogle() async {
    try {
      // 1. Inicialización
      await _ensureInitialized();

      // 2. Autenticación (identidad)
      final GoogleSignInAccount googleUser =
          await _googleSignIn.authenticate();

      // 3. Autorización (permisos + accessToken)
      final clientAuth =
          await googleUser.authorizationClient.authorizeScopes([
        'email',
        'profile',
      ]);

      // 4. Credencial de Firebase
      final credential = fb.GoogleAuthProvider.credential(
        idToken: googleUser.authentication.idToken,
        accessToken: clientAuth.accessToken,
      );

      // 5. Login en Firebase
      final userCredential =
          await _firebaseAuth.signInWithCredential(credential);

      // 6. Obtener idToken de Firebase
      final firebaseIdToken = await userCredential.user?.getIdToken();
      if (firebaseIdToken == null) {
        throw const UnknownException(
          'No se pudo obtener el token de Firebase.',
        );
      }

      // 7. Enviar al backend
      final response = await _dio.post(
        '/api/v1/auth/google',
        data: {'id_token': firebaseIdToken},
      );

      if (response.statusCode != 200) {
        throw ServerException(
          'Error del backend: ${response.statusCode}',
        );
      }

      final data = response.data as Map<String, dynamic>;
      final accessTokenJwt = data['access_token'] as String;
      final userJson = data['user'] as Map<String, dynamic>;
      final user = User.fromJson(userJson);

      // 8. Guardar en storage seguro
      await SecureStorageService.saveAccessToken(accessTokenJwt);
      await SecureStorageService.saveUserId(user.id);
      await SecureStorageService.saveUserRole(user.role);

      return user;
    } on GoogleSignInException catch (e) {
      // Manejo específico de errores de Google Sign-In v7
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw const UnknownException('Login cancelado por el usuario.');
      }
      if (e.code == GoogleSignInExceptionCode.clientConfigurationError) {
        throw const UnknownException(
          'Error de configuración. Contactá al soporte.',
        );
      }
      throw UnknownException(
        'Error de Google Sign-In: ${e.description ?? e.code.name}',
      );
    } on ApiException {
      rethrow;
    } on DioException catch (e) {
      if (e.error is ApiException) {
        throw e.error as ApiException;
      }
      throw const UnknownException();
    } catch (e) {
      throw UnknownException('Error inesperado: $e');
    }
  }

  /// Obtiene el usuario actual desde el backend.
  ///
  /// Requiere un JWT válido guardado.
  Future<User> getCurrentUser() async {
    try {
      final response = await _dio.get('/api/v1/auth/me');

      if (response.statusCode != 200) {
        throw ServerException(
          'Error del backend: ${response.statusCode}',
        );
      }

      final userJson = response.data as Map<String, dynamic>;
      return User.fromJson(userJson);
    } on ApiException {
      rethrow;
    } on DioException catch (e) {
      if (e.error is ApiException) {
        throw e.error as ApiException;
      }
      throw const UnknownException();
    } catch (e) {
      throw UnknownException('Error inesperado: $e');
    }
  }

  /// Cierra la sesión en Firebase, Google y borra el JWT local.
  Future<void> logout() async {
    try {
      await _firebaseAuth.signOut();
      await _googleSignIn.signOut();
    } catch (_) {
      // Ignorar errores al cerrar sesión en los servicios externos
    } finally {
      await SecureStorageService.clearAll();
    }
  }

  /// Verifica si hay una sesión activa (JWT guardado).
  Future<bool> hasActiveSession() async {
    return SecureStorageService.hasAccessToken();
  }
}