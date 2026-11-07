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
  }) : _dio = dio ?? DioClient.instance,
       _firebaseAuth = firebaseAuth ?? fb.FirebaseAuth.instance,
       _googleSignIn =
           googleSignIn ??
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
        '[AuthRepo] accessToken null? ${googleAuth.accessToken == null}',
      );

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
      final userCredential = await _firebaseAuth.signInWithCredential(
        credential,
      );

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
  ///
  /// Por qué cada paso va en su propio try/catch:
  ///
  /// Si Firebase falla (ej. sin red), NO queremos que un fallo de ese
  /// servicio impida que se ejecute el signOut de Google o la limpieza
  /// del storage local. El usuario debe quedar deslogueado del dispositivo
  /// aunque los servicios externos no respondan.
  ///
  /// Por qué NO se propaga ninguna excepción:
  ///
  /// El logout es una operación "best-effort" desde el punto de vista del
  /// usuario. Si no se puede cerrar la sesión en Firebase, igual la
  /// limpiamos localmente y el próximo login vuelve a autenticar. Si
  /// propagamos el error, el AuthNotifier no puede garantizar el estado
  /// unauthenticated y el usuario queda en un estado zombie.
  Future<void> logout() async {
    // 1. Desregistrar token FCM (best-effort): si el dispositivo deja de
    //    recibir notificaciones del usuario anterior, mejor. No rompe el
    //    flujo si falla (ej. sin red).
    try {
      await _dio.delete('/api/v1/usuarios/me/fcm-token');
    } catch (e) {
      debugPrint('[AuthRepo] Error desregistrando FCM: $e');
    }

    // 2. Cerrar sesión en Firebase (best-effort).
    try {
      await _firebaseAuth.signOut();
    } catch (e) {
      debugPrint('[AuthRepo] Error Firebase signOut: $e');
    }

    // 3. Cerrar sesión en Google (best-effort).
    try {
      await _googleSignIn.signOut();
    } catch (e) {
      debugPrint('[AuthRepo] Error Google signOut: $e');
    }

    // 4. Limpiar storage local: CRÍTICO. Si esto falla, el token
    //    quedaría en Keystore y el próximo restoreSession volvería a
    //    autenticar al usuario. No lo atrapamos: si falla, el error
    //    sube y el usuario ve un snackbar, pero al menos se entera.
    await SecureStorageService.clearAll();
  }

  /// Registra el token FCM del dispositivo en el backend.
  ///
  /// Requiere JWT valido (llamar despues del login).
  /// Best-effort: si falla, solo loguea; no rompe el flujo de auth.
  Future<void> registrarFcmToken(String token) async {
    try {
      await _dio.post('/api/v1/usuarios/me/fcm-token', data: {'token': token});
      debugPrint('[AuthRepo] FCM token registrado en backend');
    } catch (e) {
      debugPrint('[AuthRepo] Error registrando FCM token: $e');
    }
  }

  /// Verifica si hay una sesión activa (JWT guardado).
  Future<bool> hasActiveSession() async {
    return SecureStorageService.hasAccessToken();
  }
}
