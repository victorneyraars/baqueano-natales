/// Provider y notifier de autenticación.
///
/// Gestiona el estado global de la sesión del usuario:
/// - Estado inicial (cargando, logueado, no logueado)
/// - Login con Google
/// - Logout
/// - Restauración de sesión al arrancar
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:baqueano_natales/core/storage/secure_storage.dart';

import 'package:baqueano_natales/core/network/api_exceptions.dart';
import 'package:baqueano_natales/features/auth/data/auth_repository.dart';
import 'package:baqueano_natales/core/fcm/fcm_providers.dart';
import 'package:baqueano_natales/features/auth/domain/user.dart';

/// Estado de autenticación.
enum AuthStatus {
  /// No se conoce todavía (arranque inicial).
  unknown,

  /// Restaurando sesión desde storage al arrancar la app.
  ///
  /// IMPORTANTE: NO usar este estado durante login o logout. El router
  /// redirige a /splash cuando ve `loading`, y el SplashScreen dispara
  /// `restoreSession()`. Si lo usamos en logout, se produce una race
  /// condition: restoreSession re-autentica al usuario mientras el
  /// logout todavía no limpió el storage.
  loading,

  /// Cerrando sesión (operación intermedia entre authenticated y
  /// unauthenticated). El router NO debe pasar por /splash acá.
  loggingOut,

  /// Usuario autenticado.
  authenticated,

  /// Usuario no autenticado.
  unauthenticated,
}

/// Estado inmutable de la autenticación.
class AuthState {
  const AuthState({required this.status, this.user, this.errorMessage});

  final AuthStatus status;
  final User? user;
  final String? errorMessage;

  const AuthState.unknown() : this(status: AuthStatus.unknown);

  const AuthState.loading() : this(status: AuthStatus.loading);

  const AuthState.loggingOut() : this(status: AuthStatus.loggingOut);

  const AuthState.unauthenticated({String? error})
    : this(status: AuthStatus.unauthenticated, errorMessage: error);

  const AuthState.authenticated(User user)
    : this(status: AuthStatus.authenticated, user: user);

  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get isLoading => status == AuthStatus.loading;
}

/// Provider del repositorio (inyectable para tests).
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

/// Notifier del estado de autenticación.
class AuthNotifier extends Notifier<AuthState> {
  late final AuthRepository _repository;

  @override
  AuthState build() {
    _repository = ref.read(authRepositoryProvider);
    return const AuthState.unknown();
  }

  /// Intenta restaurar la sesión al arrancar la app.
  ///
  /// Si hay un JWT guardado, pide el usuario al backend.
  /// Si falla, limpia la sesión.
  Future<void> restoreSession() async {
    state = const AuthState.loading();

    try {
      final hasSession = await _repository.hasActiveSession();
      if (!hasSession) {
        state = const AuthState.unauthenticated();
        return;
      }

      final user = await _repository.getCurrentUser();
      state = AuthState.authenticated(user);
      _registrarFcmAsync();
    } on UnauthorizedException {
      // Token expirado → limpiar sesión
      await _repository.logout();
      state = const AuthState.unauthenticated();
    } catch (e) {
      // Cualquier otro error → limpiar sesión por seguridad
      await _repository.logout();
      state = const AuthState.unauthenticated();
    }
  }

  /// Inicia sesión con Google.
  Future<void> loginWithGoogle() async {
    state = const AuthState.loading();

    try {
      final user = await _repository.loginWithGoogle();
      state = AuthState.authenticated(user);
      _registrarFcmAsync();
    } on ApiException catch (e) {
      state = AuthState.unauthenticated(error: e.message);
    } catch (e) {
      state = AuthState.unauthenticated(error: 'Error inesperado: $e');
    }
  }

  /// Cierra la sesión.
  ///
  /// Por qué usamos `loggingOut` en vez de `loading`:
  ///
  /// El router redirige a /splash cuando ve `loading`. El SplashScreen
  /// dispara `restoreSession()` en initState. Si usáramos `loading`
  /// durante logout, la secuencia sería:
  ///
  ///   logout() → state = loading() → router /splash
  ///            → SplashScreen.initState → restoreSession()
  ///            → hasActiveSession()=true (token aún no borrado)
  ///            → getCurrentUser()=200 → state = authenticated()
  ///            → router /home → usuario vuelve al home
  ///
  /// Con `loggingOut` el router va directo a /login, sin pasar por
  /// splash, y restoreSession() no se dispara.
  ///
  /// Por qué `try/finally`:
  ///
  /// Aunque `_repository.logout()` lance (ej. storage corrupto), el
  /// usuario DEBE quedar deslogueado. Si no garantizamos el estado
  /// unauthenticated, queda en un estado zombie donde ve home pero
  /// las requests fallan con 401.
  ///
  /// Por qué chequeo de idempotencia:
  ///
  /// Si el usuario clickea "Cerrar sesión" dos veces rápido (o el
  /// PopupMenu + diálogo disparan doble), la segunda llamada no debe
  /// re-disparar el flujo ni sobreescribir el estado final.
  Future<void> logout() async {
    if (state.status == AuthStatus.loggingOut) {
      debugPrint('[AuthNotifier] logout() ya en curso, ignorando');
      return;
    }
    state = const AuthState.loggingOut();
    try {
      await _repository.logout();
    } catch (e) {
      // No propagamos: el finally garantiza unauthenticated.
      debugPrint('[AuthNotifier] Error durante logout: $e');
    } finally {
      // clearActiveMode es local (SharedPreferences), no puede fallar
      // por red. Si fallara, igual queremos pasar a unauthenticated.
      try {
        await SecureStorageService.clearActiveMode();
      } catch (e) {
        debugPrint('[AuthNotifier] Error clearActiveMode: $e');
      }
      state = const AuthState.unauthenticated();
    }
  }

  /// Pide permiso + registra el token FCM (fire-and-forget, no bloquea).
  void _registrarFcmAsync() {
    Future.microtask(() async {
      try {
        final fcm = ref.read(fcmServiceProvider);
        final token = await fcm.solicitarPermisoYObtenerToken();
        if (token != null) {
          await _repository.registrarFcmToken(token);
        }
      } catch (_) {
        // Best-effort: no rompe el flujo de auth
      }
    });
  }

  /// Limpia el mensaje de error (útil después de mostrarlo).
  void clearError() {
    if (state.errorMessage != null) {
      state = const AuthState.unauthenticated();
    }
  }
}

/// Provider del AuthNotifier (global).
final authNotifierProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);
