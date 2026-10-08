/// Repositorio de autenticación.
///
/// Encapsula las llamadas HTTP al backend (login con Google, obtener
/// usuario actual, logout). No maneja estado, solo hace las llamadas
/// y devuelve los datos o lanza ApiException.
///
/// Usa google_sign_in 6.x con la API clásica:
/// - GoogleSignIn() (no singleton)
/// - signIn() directo (sin initialize)
/// - authentication → idToken + accessToken
/// - serverClientId OBLIGATORIO para obtener idToken en Android
library;

import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';
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
  })  : _dio = dio ?? DioClient.instance,
        _firebaseAuth = firebaseAuth ?? fb.FirebaseAuth.instance,
        _googleSignIn = googleSignIn ??
            GoogleSignIn(
              scopes: ['email', 'profile'],
              serverClientId: AppConfig.googleServerClientId,
            );

  final Dio _dio;
  final fb.FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;

  /// Inicia sesión con Google.
  ///
  /// Flujo (google_sign_in 6.x):
  /// 1. signIn() → GoogleSignInAccount
  /// 2. authentication → idToken + accessToken
  /// 3. Crear credencial de Firebase.
  /// 4. Firebase Auth → idToken de Firebase.
  /// 5. Enviar al backend (/api/v1/auth/google).
  /// 6. Guardar JWT en storage seguro.
  Future<User> loginWithGoogle() async {
    try {
      debugPrint('[AuthRepo] Paso 1: signIn()');
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      debugPrint('[AuthRepo] signIn() → $googleUser');

      if (googleUser == null) {
        throw const UnknownException('Login cancelado por el usuario.');
      }

      debugPrint('[AuthRepo] Paso 2: authentication');
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      debugPrint('[AuthRepo] idToken null? ${googleAuth.idToken == null}');
      debugPrint(
          '[AuthRepo] accessToken null? ${googleAuth.accessToken == null}');

      if (googleAuth.idToken == null) {
        throw const UnknownException(
          'No se pudo obtener el idToken de Google.',
        );
      }

      debugPrint('[AuthRepo] Paso 3: credencial Firebase');
      final credential = fb.GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
        accessToken: googleAuth.accessToken,
      );

      debugPrint('[AuthRepo] Paso 4: signInWithCredential');
      final userCredential =
          await _firebaseAuth.signInWithCredential(credential);

      debugPrint('[AuthRepo] Paso 5: getIdToken Firebase');
      final firebaseIdToken = await userCredential.user?.getIdToken();
      if (firebaseIdToken == null) {
        throw const UnknownException(
          'No se pudo obtener el token de Firebase.',
        );
      }

      debugPrint('[AuthRepo] Paso 6: POST backend');
      final response = await _dio.post(
        '/api/v1/auth/google',
        data: {'id_token': firebaseIdToken},
      );
      debugPrint('[AuthRepo] Backend respondió ${response.statusCode}');

      if (response.statusCode != 200) {
        throw ServerException('Error del backend: ${response.statusCode}');
      }

      final data = response.data as Map<String, dynamic>;
      final accessTokenJwt = data['access_token'] as String;
      final userJson = data['user'] as Map<String, dynamic>;
      final user = User.fromJson(userJson);

      await SecureStorageService.saveAccessToken(accessTokenJwt);
      await SecureStorageService.saveUserId(user.id);
      await SecureStorageService.saveUserRole(user.role);

      return user;
    } on ApiException {
      rethrow;
    } on DioException catch (e) {
      if (e.error is ApiException) {
        throw e.error as ApiException;
      }
      throw const UnknownException();
    } catch (e) {
      debugPrint('[AuthRepo] ERROR: $e');
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
        throw ServerException('Error del backend: ${response.statusCode}');
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