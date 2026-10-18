/// Router central de la aplicaciÃ³n.
///
/// Detecta el flavor (client o admin) vÃ­a `AppConfig.appType`:
/// - `client`: redirige `/home` â†’ HomeScreen (client normal)
/// - `admin`:  redirige `/home` â†’ AdminHomeScreen (panel morado)
///
/// Las rutas de `/admin/*` solo son accesibles desde el flavor admin
/// (o desde client si el usuario logueado tiene rol admin).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:baqueano_natales/core/config/app_config.dart';
import 'package:baqueano_natales/features/admin/presentation/screens/admin_categorias_comercio_screen.dart';
import 'package:baqueano_natales/features/admin/presentation/screens/admin_categorias_oficio_screen.dart';
import 'package:baqueano_natales/features/admin/presentation/screens/admin_comercios_screen.dart';
import 'package:baqueano_natales/features/admin/presentation/screens/admin_detalle_comercio_screen.dart';
import 'package:baqueano_natales/features/admin/presentation/screens/admin_detalle_prestador_screen.dart';
import 'package:baqueano_natales/features/admin/presentation/screens/admin_home_screen.dart';
import 'package:baqueano_natales/features/ops_admin/presentation/screens/ops_estado_screen.dart';
import 'package:baqueano_natales/features/ops_admin/presentation/screens/ops_release_screen.dart';
import 'package:baqueano_natales/features/admin/presentation/screens/admin_prestadores_screen.dart';
import 'package:baqueano_natales/features/social/presentation/screens/admin_social_cuentas_screen.dart';
import 'package:baqueano_natales/features/social/presentation/screens/admin_social_config_screen.dart';
import 'package:baqueano_natales/features/social/presentation/screens/admin_social_publicaciones_screen.dart';
import 'package:baqueano_natales/features/social/presentation/screens/mis_publicaciones_screen.dart';
import 'package:baqueano_natales/features/promocion/presentation/screens/admin_promocion_editor_screen.dart';
import 'package:baqueano_natales/features/promocion/presentation/screens/admin_promocion_galeria_screen.dart';
import 'package:baqueano_natales/features/notificaciones/presentation/screens/admin_notificaciones_composer_screen.dart';
import 'package:baqueano_natales/features/notificaciones/presentation/screens/admin_notificaciones_historial_screen.dart';
import 'package:baqueano_natales/features/notificaciones/presentation/screens/admin_notificaciones_stats_screen.dart';
import 'package:baqueano_natales/features/analytics/presentation/screens/stats_screen.dart';
import 'package:baqueano_natales/features/notificaciones/presentation/screens/mis_notificaciones_screen.dart';
import 'package:baqueano_natales/features/notificaciones/presentation/screens/preferencias_notificacion_screen.dart';
import 'package:baqueano_natales/features/auth/data/auth_notifier.dart';
import 'package:baqueano_natales/features/auth/presentation/login_screen.dart';
import 'package:baqueano_natales/features/auth/presentation/splash_screen.dart';
import 'package:baqueano_natales/features/comercios/presentation/screens/detalle_comercio_screen.dart';
import 'package:baqueano_natales/features/comercios/presentation/screens/editor_horarios_screen.dart';
import 'package:baqueano_natales/features/comercios/presentation/screens/detalle_mi_comercio_screen.dart';
import 'package:baqueano_natales/features/comercios/presentation/screens/formulario_comercio_screen.dart';
import 'package:baqueano_natales/features/comercios/presentation/screens/lista_comercios_screen.dart';
import 'package:baqueano_natales/features/comercios/presentation/screens/mis_comercios_screen.dart';
import 'package:baqueano_natales/features/home/presentation/home_screen.dart';
import 'package:baqueano_natales/features/oficios/presentation/screens/mis_vehiculos_screen.dart';
import 'package:baqueano_natales/features/oficios/presentation/screens/mis_recordatorios_screen.dart';
import 'package:baqueano_natales/features/oficios/presentation/screens/formulario_vehiculo_screen.dart';
import 'package:baqueano_natales/features/oficios/presentation/screens/mis_ordenes_screen.dart';
import 'package:baqueano_natales/features/oficios/presentation/screens/detalle_mi_orden_screen.dart';
import 'package:baqueano_natales/features/oficios/presentation/screens/galeria_fotos_screen.dart';
import 'package:baqueano_natales/features/oficios/presentation/screens/crear_review_screen.dart';
import 'package:baqueano_natales/features/oficios/presentation/screens/reportes_taller_screen.dart';
import 'package:baqueano_natales/features/oficios/presentation/screens/ordenes_taller_screen.dart';
import 'package:baqueano_natales/features/oficios/presentation/screens/detalle_orden_taller_screen.dart';
import 'package:baqueano_natales/features/oficios/presentation/screens/formulario_orden_screen.dart';
import 'package:baqueano_natales/features/oficios/presentation/screens/mis_turnos_screen.dart';
import 'package:baqueano_natales/features/oficios/presentation/screens/detalle_mi_turno_screen.dart';
import 'package:baqueano_natales/features/oficios/presentation/screens/agenda_taller_screen.dart';
import 'package:baqueano_natales/features/oficios/presentation/screens/detalle_turno_taller_screen.dart';
import 'package:baqueano_natales/features/oficios/presentation/screens/reservar_turno_screen.dart';
import 'package:baqueano_natales/features/prestadores/presentation/screens/detalle_mi_prestador_screen.dart';
import 'package:baqueano_natales/features/prestadores/presentation/screens/reviews_prestador_screen.dart';
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

/// Path del Home segÃºn el flavor.
/// - Admin: `/admin/home`
/// - Client: `/home`
String _homePathForFlavor() {
  return AppConfig.appType == AppType.admin ? '/admin/home' : '/home';
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
      final homePath = _homePathForFlavor();

      switch (authState.status) {
        case AuthStatus.unknown:
        case AuthStatus.loading:
          return location == '/splash' ? null : '/splash';

        case AuthStatus.unauthenticated:
          if (location == '/login') return null;
          return '/login';

        case AuthStatus.authenticated:
          // Si estÃ¡ en splash o login, redirigir al home del flavor
          if (location == '/splash' || location == '/login') {
            return homePath;
          }
          // Si en flavor admin estÃ¡ en /home (client), redirigir a /admin/home
          if (AppConfig.appType == AppType.admin && location == '/home') {
            return '/admin/home';
          }
          return null;
      }
    },
    routes: [
      // =========================================================
      // Rutas base
      // =========================================================
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

      // =========================================================
      // Home client (para flavor client)
      // =========================================================
      GoRoute(
        path: '/home',
        name: 'home',
        builder: (context, state) => const HomeScreen(),
      ),

      // =========================================================
      // Home admin (para flavor admin)
      // =========================================================
      GoRoute(
        path: '/admin/home',
        name: 'admin-home',
        builder: (context, state) => const AdminHomeScreen(),
      ),

      // =========================================================
      // Admin â€” Prestadores
      // =========================================================
      GoRoute(
        path: '/admin/prestadores',
        name: 'admin-prestadores',
        builder: (context, state) => const AdminPrestadoresScreen(),
      ),
      GoRoute(
        path: '/admin/prestadores/:id',
        name: 'admin-prestador-detalle',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return AdminDetallePrestadorScreen(id: id);
        },
      ),

      // =========================================================
      // Admin â€” CategorÃ­as de oficio
      // =========================================================
      GoRoute(
        path: '/admin/categorias-oficio',
        name: 'admin-categorias-oficio',
        builder: (context, state) => const AdminCategoriasOficioScreen(),
      ),

      // =========================================================
      // Admin - Promocion (afiches SVG)
      // =========================================================
      GoRoute(
        path: '/admin/promocion',
        name: 'admin-promocion',
        builder: (context, state) => const AdminPromocionGaleriaScreen(),
      ),
      GoRoute(
        path: '/admin/promocion/editor/:plantillaId',
        name: 'admin-promocion-editor',
        builder: (context, state) {
          final id = state.pathParameters['plantillaId']!;
          return AdminPromocionEditorScreen(plantillaId: id);
        },
      ),

      // =========================================================
      // Admin â€” Comercios
      // =========================================================
      GoRoute(
        path: '/admin/comercios',
        name: 'admin-comercios',
        builder: (context, state) => const AdminComerciosScreen(),
      ),
      GoRoute(
        path: '/admin/comercios/:id',
        name: 'admin-comercio-detalle',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return AdminDetalleComercioScreen(id: id);
        },
      ),

      // =========================================================
      // Admin â€” CategorÃ­as de comercio
      // =========================================================
      GoRoute(
        path: '/admin/categorias-comercio',
        name: 'admin-categorias-comercio',
        builder: (context, state) => const AdminCategoriasComercioScreen(),
      ),

      // =========================================================
      // Admin - Redes sociales
      // =========================================================
      GoRoute(
        path: '/admin/social/cuentas',
        name: 'admin-social-cuentas',
        builder: (context, state) => const AdminSocialCuentasScreen(),
      ),

      GoRoute(
        path: '/admin/social/config',
        name: 'admin-social-config',
        builder: (context, state) => const AdminSocialConfigScreen(),
      ),

      GoRoute(
        path: '/admin/social/publicaciones',
        name: 'admin-social-publicaciones',
        builder: (context, state) =>
            const AdminSocialPublicacionesScreen(),
      ),

      // Admin - Notificaciones
      GoRoute(
        path: '/admin/notificaciones',
        name: 'admin-notificaciones-composer',
        builder: (context, state) =>
            const AdminNotificacionesComposerScreen(),
      ),
      GoRoute(
        path: '/admin/notificaciones/historial',
        name: 'admin-notificaciones-historial',
        builder: (context, state) =>
            const AdminNotificacionesHistorialScreen(),
      ),
      GoRoute(
        path: '/admin/notificaciones/stats',
        name: 'admin-notificaciones-stats',
        builder: (context, state) =>
            const AdminNotificacionesStatsScreen(),
        ),

        // Admin - Ops Dashboard (GitHub Actions + Play Console)
        GoRoute(
          path: '/admin/ops',
          name: 'admin-ops',
          builder: (context, state) => const OpsEstadoScreen(),
        ),

        // Admin - Ops Release (crear tag + disparar workflow)
        GoRoute(
          path: '/admin/ops/release',
          name: 'admin-ops-release',
          builder: (context, state) => const OpsReleaseScreen(),

        // Admin - Analytics (Cloudflare Web Analytics)
        GoRoute(
          path: '/admin/stats',
          name: 'admin-stats',
          builder: (context, state) => const StatsScreen(),
        ),

      // =========================================================
      // Comercios â€” pÃºblico
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
      // Comercios â€” dueÃ±o (mis comercios)
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
      GoRoute(
        path: '/mis-comercios/:id/horarios',
        name: 'mi-comercio-horarios',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return EditorHorariosScreen(comercioId: id);
        },
      ),

      // =========================================================
      // Prestadores â€” pÃºblico
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
      // Prestadores â€” dueÃ±o (mis prestadores)
      // =========================================================
        GoRoute(
          path: '/mis-vehiculos',
          name: 'mis-vehiculos',
          builder: (context, state) => const MisVehiculosScreen(),
        ),
        GoRoute(
          path: '/mis-vehiculos/nuevo',
          name: 'mis-vehiculos-nuevo',
          builder: (context, state) => const FormularioVehiculoScreen(),
        ),
        GoRoute(
          path: '/mis-vehiculos/:id/recordatorios',
          name: 'mis-recordatorios',
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            return MisRecordatoriosScreen(objetoId: id);
          },
        ),        GoRoute(
          path: '/mis-vehiculos/:id/editar',
          name: 'mi-vehiculo-editar',
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            return FormularioVehiculoScreen(objetoId: id);
          },
        ),
        GoRoute(
          path: '/mis-turnos',
          name: 'mis-turnos',
          builder: (context, state) => const MisTurnosScreen(),
        ),
        GoRoute(
          path: '/mis-turnos/:id',
          name: 'mi-turno-detalle',
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            return DetalleMiTurnoScreen(turnoId: id);
          },
        ),

        // Notificaciones del usuario
        GoRoute(
          path: '/mis-notificaciones',
          name: 'mis-notificaciones',
          builder: (context, state) => const MisNotificacionesScreen(),
        ),
        GoRoute(
          path: '/mis-notificaciones/preferencias',
          name: 'mis-notificaciones-preferencias',
          builder: (context, state) =>
              const PreferenciasNotificacionScreen(),
        ),
        GoRoute(
          path: '/mis-prestadores/:id/turnos',
          name: 'agenda-taller',
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            return AgendaTallerScreen(prestadorId: id);
          },
        ),
        GoRoute(
          path: '/mis-prestadores/:id/turnos/:tid',
          name: 'turno-taller-detalle',
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            final tid = state.pathParameters['tid']!;
            return DetalleTurnoTallerScreen(
              prestadorId: id,
              turnoId: tid,
            );
          },
        ),
        GoRoute(
          path: '/mis-prestadores/:id/reservar',
          name: 'reservar-turno',
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            final nombre = state.uri.queryParameters['nombre'];
            return ReservarTurnoScreen(
              prestadorId: id,
              prestadorNombre: nombre,
            );
          },
        ),
      GoRoute(
        path: '/mis-prestadores',
        name: 'mis-prestadores',
        builder: (context, state) => const MisPrestadoresScreen(),
      ),
        GoRoute(
          path: '/mis-ordenes',
          name: 'mis-ordenes',
          builder: (context, state) => const MisOrdenesScreen(),
        ),
        GoRoute(
          path: '/mis-ordenes/:id',
          name: 'mi-orden-detalle',
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            return DetalleMiOrdenScreen(ordenId: id);
          },
        ),

      GoRoute(
        path: '/mis-ordenes/:id/review',
        name: 'mi-orden-review',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return CrearReviewScreen(ordenId: id);
        },
      ),
        GoRoute(
          path: '/mis-ordenes/:id/fotos',
          name: 'mi-orden-fotos',
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            return GaleriaFotosScreen(ordenId: id);
          },
        ),
        GoRoute(
          path: '/mis-prestadores/:id/ordenes',
          name: 'ordenes-taller',
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            return OrdenesTallerScreen(prestadorId: id);
          },
        ),
        GoRoute(
          path: '/mis-prestadores/:id/ordenes/nueva',
          name: 'orden-taller-nueva',
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            return FormularioOrdenScreen(prestadorId: id);
          },
        ),
        GoRoute(
          path: '/mis-prestadores/:id/ordenes/:oid',
          name: 'orden-taller-detalle',
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            final oid = state.pathParameters['oid']!;
            return DetalleOrdenTallerScreen(prestadorId: id, ordenId: oid);
          },
        ),
        GoRoute(
          path: '/mis-prestadores/:id/ordenes/:oid/fotos',
          name: 'orden-taller-fotos',
          builder: (context, state) {
            final pid = state.pathParameters['id']!;
            final oid = state.pathParameters['oid']!;
            return GaleriaFotosScreen(ordenId: oid, prestadorId: pid);
          },
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
        path: '/mis-prestadores/:id/reportes',
        name: 'mi-prestador-reportes',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return ReportesTallerScreen(prestadorId: id);
        },
      ),

      GoRoute(
        path: '/mis-prestadores/:id/reviews',
        name: 'mi-prestador-reviews',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return ReviewsPrestadorScreen(prestadorId: id);
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
      GoRoute(
        path: '/mis-prestadores/:id/publicaciones',
        name: 'mis-prestador-publicaciones',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return MisPublicacionesScreen(prestadorId: id);
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
