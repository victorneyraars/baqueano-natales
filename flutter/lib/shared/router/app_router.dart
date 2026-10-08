/// Router central de la aplicación.
///
/// Usa GoRouter con un `refreshListenable` que escucha el estado de
/// autenticación. Cuando el estado cambia, el router reevalúa la ruta
/// y redirige según corresponda:
/// - AuthStatus.unknown         → /splash (cargando)
/// - AuthStatus.unauthenticated → /login
/// - AuthStatus.authenticated   → /home
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:baqueano_natales/features/auth/data/auth_notifier.dart';
import 'package:baqueano_natales/features/auth/presentation/login_screen.dart';
import 'package:baqueano_natales/features/auth/presentation/splash_screen.dart';
import 'package:baqueano_natales/features/home/presentation/home_screen.dart';

/// Escucha cambios en el provider de auth y notifica al router.
class _AuthChangeNotifier extends ChangeNotifier {
  _AuthChangeNotifier(Ref ref) {
    ref.listen<AuthState>(authNotifierProvider, (previous, next) {
      if (previous?.status != next.status) {
        notifyListeners();
      }
    });
  }
}

/// Provider del router.
final routerProvider = Provider<GoRouter>((ref) {
  final authChangeNotifier = _AuthChangeNotifier(ref);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: authChangeNotifier,
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final authState = ref.read(authNotifierProvider);
      final location = state.matchedLocation;

      switch (authState.status) {
        case AuthStatus.unknown:
          // Estamos cargando la sesión: quedarse en splash.
          return location == '/splash' ? null : '/splash';

        case AuthStatus.loading:
          // Operación en curso (login/logout): mostrar splash.
          return location == '/splash' ? null : '/splash';

        case AuthStatus.unauthenticated:
          // Sin sesión: ir a login.
          return location == '/login' ? null : '/login';

        case AuthStatus.authenticated:
          // Con sesión: si está en splash o login, ir a home.
          if (location == '/home') return null;
          return '/home';
      }
    },
    routes: [
      GoRoute(
        path: '/splash',
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/home',
        name: 'home',
        builder: (context, state) => const HomeScreen(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Error')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Ruta no encontrada: ${state.uri}',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.go('/splash'),
                child: const Text('Volver al inicio'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
});