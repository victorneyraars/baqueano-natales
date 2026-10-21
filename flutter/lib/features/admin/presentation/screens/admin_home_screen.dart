/// Pantalla Home del panel admin.
///
/// Se muestra cuando el flavor es `admin` (AppConfig.appType == admin)
/// o cuando el usuario logueado tiene rol `admin`.
///
/// Secciones:
/// - Bienvenida con info del admin
/// - Gestión: Prestadores, Comercios, Usuarios (próx.)
/// - Configuración: Categorías de oficio, Categorías de comercio
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:baqueano_natales/core/services/app_update_service.dart';
import 'package:baqueano_natales/main_admin.dart' show scaffoldMessengerKey;

import 'package:baqueano_natales/features/auth/data/auth_notifier.dart';
import 'package:baqueano_natales/features/comercios/data/comercio_providers.dart';
import 'package:baqueano_natales/features/comercios/domain/comercio.dart';
import 'package:baqueano_natales/features/prestadores/data/prestador_providers.dart';
import 'package:baqueano_natales/features/social/data/social_providers.dart';
import 'package:baqueano_natales/features/prestadores/domain/prestador.dart';

class AdminHomeScreen extends ConsumerWidget {
  const AdminHomeScreen({super.key});

  Future<void> _handleLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Estás seguro de que querés cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(authNotifierProvider.notifier).logout();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    final user = authState.user;
    final theme = Theme.of(context);

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Contar prestadores pendientes (para badge)
    final prestadoresPendientesAsync = ref.watch(
      adminPrestadoresProvider(
        const AdminPrestadoresParams(estado: EstadoPrestador.pendiente),
      ),
    );
    final prestadoresPendientesCount = prestadoresPendientesAsync.maybeWhen(
      data: (p) => p.meta.total,
      orElse: () => 0,
    );

    // Contar comercios pendientes (para badge)
    final comerciosPendientesAsync = ref.watch(
      adminComerciosProvider(
        const AdminComerciosParams(estado: EstadoComercio.pendiente),
      ),
    );
    final comerciosPendientesCount = comerciosPendientesAsync.maybeWhen(
      data: (p) => p.meta.total,
      orElse: () => 0,
    );

    // Contar cuentas sociales conectadas (para badge informativo)
    final cuentasSocialesAsync = ref.watch(cuentasSocialesProvider);
    final cuentasSocialesCount = cuentasSocialesAsync.maybeWhen(
      data: (p) => p.meta.total,
      orElse: () => 0,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel de administración'),
        actions: [
          IconButton(
            icon: const Icon(Icons.system_update),
            tooltip: 'Buscar actualización',
            onPressed: () => AppUpdateService.checkForUpdates(
              GoRouter.of(context),
              scaffoldMessengerKey,
              forceShow: true,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
            onPressed: () => _handleLogout(context, ref),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(authNotifierProvider.notifier).restoreSession();
          ref.invalidate(adminPrestadoresProvider);
          ref.invalidate(adminComerciosProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // --- Bienvenida ---
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: theme.colorScheme.primaryContainer,
                      child: Text(
                        user.iniciales,
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '¡Hola, ${user.nombre ?? 'Admin'}!',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user.email ?? 'Sin email',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Chip(
                            label: Text(user.role.toUpperCase()),
                            visualDensity: VisualDensity.compact,
                            backgroundColor: Colors.purple.shade100,
                            labelStyle: TextStyle(
                              color: Colors.purple.shade900,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // --- Gestión ---
            Text(
              'Gestión',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            _AdminCard(
              icon: Icons.calendar_month,
              title: 'Agenda de Turnos',
              subtitle: 'Ver y confirmar reservas entrantes',
              onTap: () => context.push(
                '/mis-prestadores/aaaaaaaa-1111-4111-8111-aaaaaaaaaaaa/turnos',
              ),
            ),
            _AdminCard(
              icon: Icons.science,
              title: 'Laboratorio de APIs',
              subtitle: 'Validar RUT y Patentes (Boostr)',
              onTap: () => context.push('/admin/api-lab'),
            ),

            _AdminCard(
              icon: Icons.handyman,
              title: 'Prestadores',
              subtitle: prestadoresPendientesCount > 0
                  ? '$prestadoresPendientesCount pendiente(s) de revisión'
                  : 'Verificar, rechazar, gestionar oficios',
              onTap: () => context.push('/admin/prestadores'),
              badge: prestadoresPendientesCount > 0
                  ? '$prestadoresPendientesCount'
                  : null,
            ),

            _AdminCard(
              icon: Icons.storefront,
              title: 'Comercios',
              subtitle: comerciosPendientesCount > 0
                  ? '$comerciosPendientesCount pendiente(s) de revisión'
                  : 'Verificar, rechazar, gestionar comercios',
              onTap: () => context.push('/admin/comercios'),
              badge: comerciosPendientesCount > 0
                  ? '$comerciosPendientesCount'
                  : null,
            ),

            _AdminCard(
              icon: Icons.share,
              title: 'Redes sociales',
              subtitle: cuentasSocialesCount > 0
                  ? '$cuentasSocialesCount cuenta(s) conectada(s)'
                  : 'Conectar Facebook e Instagram',
              onTap: () => context.push('/admin/social/cuentas'),
              badge: cuentasSocialesCount > 0 ? '$cuentasSocialesCount' : null,
            ),

            _AdminCard(
              icon: Icons.tune,
              title: 'Configuracion de redes',
              subtitle: 'Auto-publish, redes activas, destino',
              onTap: () => context.push('/admin/social/config'),
            ),

            _AdminCard(
              icon: Icons.queue,
              title: 'Cola de publicaciones',
              subtitle: 'Ver historial y errores',
              onTap: () => context.push('/admin/social/publicaciones'),
            ),

            _AdminCard(
              icon: Icons.auto_awesome,
              title: 'Afiches para redes',
              subtitle: 'Generar promociones SVG',
              onTap: () => context.push('/admin/promocion'),
            ),

            _AdminCard(
              icon: Icons.notifications_active,
              title: 'Enviar notificacion',
              subtitle: 'Composer: push a un segmento',
              onTap: () => context.push('/admin/notificaciones'),
            ),

            _AdminCard(
              icon: Icons.history,
              title: 'Historial de notificaciones',
              subtitle: 'Filtros por tipo, estado y fecha',
              onTap: () => context.push('/admin/notificaciones/historial'),
            ),

            _AdminCard(
              icon: Icons.analytics,
              title: 'Stats de notificaciones',
              subtitle: 'Delivery rate, open rate, top 5',
              onTap: () => context.push('/admin/notificaciones/stats'),
            ),

            _AdminCard(
              icon: Icons.analytics_outlined,
              title: 'Estadísticas Web',
              subtitle: 'Visitas, páginas y fuentes de tráfico',
              onTap: () => context.push('/admin/stats'),
            ),
            const SizedBox(height: 12),
            _AdminCard(
              icon: Icons.monitor_heart,
              title: 'Ops Dashboard',
              subtitle: 'CI/CD, runs de GitHub, releases en Play',
              onTap: () => context.push('/admin/ops'),
            ),
            const _AdminCard(
              icon: Icons.people_outline,
              title: 'Usuarios',
              subtitle: 'Pr?ximamente',
            ),

            const SizedBox(height: 24),

            // --- Configuración ---
            Text(
              'Configuración',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            _AdminCard(
              icon: Icons.category_outlined,
              title: 'Categorías de oficio',
              subtitle: 'Crear, editar y desactivar categorías',
              onTap: () => context.push('/admin/categorias-oficio'),
            ),

            _AdminCard(
              icon: Icons.category,
              title: 'Categorías de comercio',
              subtitle: 'Crear, editar y desactivar categorías',
              onTap: () => context.push('/admin/categorias-comercio'),
            ),

            const SizedBox(height: 24),

            // --- Análisis ---
            Text(
              'Análisis',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            const _AdminCard(
              icon: Icons.insights,
              title: 'Estadísticas globales',
              subtitle: 'Próximamente',
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _AdminCard extends StatelessWidget {
  const _AdminCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.badge,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final disponible = onTap != null;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Badge(
          isLabelVisible: badge != null,
          label: badge != null ? Text(badge!) : null,
          child: Icon(
            icon,
            color: disponible
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: disponible ? null : theme.colorScheme.onSurfaceVariant,
          ),
        ),
        subtitle: Text(subtitle),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 14,
          color: disponible
              ? null
              : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
        ),
        onTap:
            onTap ??
            () {
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('Próximamente')));
            },
      ),
    );
  }
}
