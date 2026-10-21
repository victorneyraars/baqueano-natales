/// Provider y notifier de autenticación.
///
/// Gestiona el estado global de la sesión del usuario:
/// - Estado inicial (cargando, logueado, no logueado)
/// - Login con Google
/// - Logout
/// - Restauración de sesión al arrancar
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:baqueano_natales/core/network/api_exceptions.dart';
import 'package:baqueano_natales/features/auth/data/auth_repository.dart';
import 'package:baqueano_natales/core/fcm/fcm_providers.dart';
import 'package:baqueano_natales/features/auth/domain/user.dart';

/// Estado de autenticación.
enum AuthStatus {
  /// No se conoce todavía (arranque inicial).
  unknown,

  /// Cargando (login en proceso).
  loading,

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
  Future<void> logout() async {
    state = const AuthState.loading();
    await _repository.logout();
    state = const AuthState.unauthenticated();
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
