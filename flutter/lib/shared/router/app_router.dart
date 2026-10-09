/// Router central de la aplicación.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:baqueano_natales/features/auth/data/auth_notifier.dart';
import 'package:baqueano_natales/features/auth/presentation/login_screen.dart';
import 'package:baqueano_natales/features/auth/presentation/splash_screen.dart';
import 'package:baqueano_natales/features/comercios/presentation/screens/detalle_comercio_screen.dart';
import 'package:baqueano_natales/features/comercios/presentation/screens/detalle_mi_comercio_screen.dart';
import 'package:baqueano_natales/features/comercios/presentation/screens/formulario_comercio_screen.dart';
import 'package:baqueano_natales/features/comercios/presentation/screens/lista_comercios_screen.dart';
import 'package:baqueano_natales/features/comercios/presentation/screens/mis_comercios_screen.dart';
import 'package:baqueano_natales/features/home/presentation/home_screen.dart';
import 'package:baqueano_natales/features/prestadores/presentation/screens/detalle_mi_prestador_screen.dart';
import 'package:baqueano_natales/features/prestadores/presentation/screens/detalle_prestador_screen.dart';
import 'package:baqueano_natales/features/prestadores/presentation/screens/editor_servicios_screen.dart';
import 'package:baqueano_natales/features/prestadores/presentation/screens/formulario_prestador_screen.dart';
import 'package:baqueano_natales/features/prestadores/presentation/screens/lista_prestadores_screen.dart';
import 'package:baqueano_natales/features/prestadores/presentation/screens/mis_prestadores_screen.dart';

class _AuthChangeNotifier extends ChangeNotifier {
  _AuthChangeNotifier(Ref ref) {
    ref.listen<AuthState>(authNotifierProvider, (previous, next) {
      if (previous?.status != next.status) {
        notifyListeners();
      }
    });
  }
}

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
        case AuthStatus.loading:
          return location == '/splash' ? null : '/splash';

        case AuthStatus.unauthenticated:
          if (location == '/login') return null;
          return '/login';

        case AuthStatus.authenticated:
          if (location == '/splash' || location == '/login') {
            return '/home';
          }
          return null;
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

      // =========================================================
      // Comercios — público
      // =========================================================
      GoRoute(
        path: '/comercios',
        name: 'comercios',
        builder: (context, state) => const ListaComerciosScreen(),
      ),
      GoRoute(
        path: '/comercios/:slug',
        name: 'comercio-detalle',
        builder: (context, state) {
          final slug = state.pathParameters['slug']!;
          return DetalleComercioScreen(slug: slug);
        },
      ),

      // =========================================================
      // Comercios — dueño (mis comercios)
      // =========================================================
      GoRoute(
        path: '/mis-comercios',
        name: 'mis-comercios',
        builder: (context, state) => const MisComerciosScreen(),
      ),
      GoRoute(
        path: '/mis-comercios/nuevo',
        name: 'mis-comercios-nuevo',
        builder: (context, state) => const FormularioComercioScreen(),
      ),
      GoRoute(
        path: '/mis-comercios/:id',
        name: 'mi-comercio-detalle',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return DetalleMiComercioScreen(id: id);
        },
      ),
      GoRoute(
        path: '/mis-comercios/:id/editar',
        name: 'mi-comercio-editar',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return FormularioComercioScreen(comercioId: id);
        },
      ),

      // =========================================================
      // Prestadores — público
      // =========================================================
      GoRoute(
        path: '/prestadores',
        name: 'prestadores',
        builder: (context, state) => const ListaPrestadoresScreen(),
      ),
      GoRoute(
        path: '/prestadores/:slug',
        name: 'prestador-detalle',
        builder: (context, state) {
          final slug = state.pathParameters['slug']!;
          return DetallePrestadorScreen(slug: slug);
        },
      ),

      // =========================================================
      // Prestadores — dueño (mis prestadores)
      // =========================================================
      GoRoute(
        path: '/mis-prestadores',
        name: 'mis-prestadores',
        builder: (context, state) => const MisPrestadoresScreen(),
      ),
      GoRoute(
        path: '/mis-prestadores/nuevo',
        name: 'mis-prestadores-nuevo',
        builder: (context, state) => const FormularioPrestadorScreen(),
      ),
      GoRoute(
        path: '/mis-prestadores/:id',
        name: 'mi-prestador-detalle',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return DetalleMiPrestadorScreen(id: id);
        },
      ),
      GoRoute(
        path: '/mis-prestadores/:id/editar',
        name: 'mi-prestador-editar',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return FormularioPrestadorScreen(prestadorId: id);
        },
      ),
      GoRoute(
        path: '/mis-prestadores/:id/servicios',
        name: 'mi-prestador-servicios',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return EditorServiciosScreen(prestadorId: id);
        },
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