/// Pantalla Home.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:baqueano_natales/features/auth/data/auth_notifier.dart';
import 'package:baqueano_natales/features/notificaciones/data/notificaciones_providers.dart';
import 'package:baqueano_natales/core/services/app_update_service.dart';
import 'package:baqueano_natales/main_client.dart' show scaffoldMessengerKey;
import 'package:baqueano_natales/core/widgets/version_badge.dart';
import 'package:baqueano_natales/features/settings/presentation/about_screen.dart';

// Feature flags para el MVP mecánica-first.
// Cambiar a true cuando se implementen las verticales correspondientes.
const _showComercios = false;
const _showOficios = false;
const _showProximamente = false;

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inicio'),
        actions: [
          const Center(child: VersionBadge()),
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'Acerca de',
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const AboutScreen())),
          ),
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
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // --- Tarjeta de bienvenida ---
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: theme.colorScheme.primaryContainer,
                      child: Text(
                        user.iniciales,
                        style: theme.textTheme.headlineSmall?.copyWith(
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
                            '¡Hola, ${user.nombre ?? 'Usuario'}!',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user.email ?? user.phone ?? 'Sin contacto',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Chip(
                                label: Text(user.role.toUpperCase()),
                                visualDensity: VisualDensity.compact,
                                backgroundColor:
                                    theme.colorScheme.secondaryContainer,
                              ),
                              if (user.verificado) ...[
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.verified,
                                  size: 20,
                                  color: theme.colorScheme.primary,
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // --- Mi actividad ---
            Text(
              'Mi actividad',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            if (_showComercios)
              _FeatureCard(
                icon: Icons.storefront,
                title: 'Mis comercios',
                subtitle: 'Gestioná tus locales y servicios',
                onTap: () => context.push('/mis-comercios'),
              ),
            if (_showOficios)
              _FeatureCard(
                icon: Icons.handyman,
                title: 'Mis oficios',
                subtitle: 'Gestioná tus perfiles de prestador',
                onTap: () => context.push('/mis-prestadores'),
              ),
            _FeatureCard(
              icon: Icons.calendar_month,
              title: 'Mi taller',
              subtitle: 'Agenda y reservas del taller',
              onTap: () => context.push(
                '/mis-prestadores/aaaaaaaa-1111-4111-8111-aaaaaaaaaaaa/turnos',
              ),
            ),
            _FeatureCard(
              icon: Icons.directions_car_outlined,
              title: 'Mis vehiculos',
              subtitle: 'Gestiona tus autos y su historial',
              onTap: () => context.push('/mis-vehiculos'),
            ),
            _FeatureCard(
              icon: Icons.receipt_long_outlined,
              title: 'Mis ordenes',
              subtitle: 'Servicios agendados con talleres',
              onTap: () => context.push('/mis-ordenes'),
            ),
            _FeatureCard(
              icon: Icons.event_available_outlined,
              title: 'Mis turnos',
              subtitle: 'Reservas con talleres y oficios',
              onTap: () => context.push('/mis-turnos'),
            ),

            const _NotificacionesHomeCard(),

            const SizedBox(height: 24),

            // --- Descubrí ---
            Text(
              'Descubrí',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            if (_showComercios)
              _FeatureCard(
                icon: Icons.explore,
                title: 'Comercios',
                subtitle: 'Explorá locales y servicios de Puerto Natales',
                onTap: () => context.push('/comercios'),
              ),
            _FeatureCard(
              icon: Icons.build_circle_outlined,
              title: 'Mecánicos',
              subtitle: 'Encontrá mecánicos en Puerto Natales',
              onTap: () => context.push('/prestadores'),
            ),

            if (_showProximamente) ...[
              const SizedBox(height: 24),

              Text(
                'Próximamente',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              const _FeatureCard(
                icon: Icons.map,
                title: 'Mapa en vivo',
                subtitle: 'Vehículos cercanos y pedidos',
              ),
              const _FeatureCard(
                icon: Icons.local_shipping,
                title: 'Delivery',
                subtitle: 'Pedidos a domicilio',
              ),
              const _FeatureCard(
                icon: Icons.qr_code,
                title: 'Carta QR',
                subtitle: 'Menús interactivos de comercios',
              ),
              const _FeatureCard(
                icon: Icons.redeem,
                title: 'Recompensas',
                subtitle: 'Acumulá puntos y canjeá beneficios',
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final disponible = onTap != null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(
          icon,
          color: disponible
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
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

/// Card "Mis notificaciones" en el Home con badge de no leidas.
class _NotificacionesHomeCard extends ConsumerWidget {
  const _NotificacionesHomeCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final async = ref.watch(misNotificacionesProvider);

    // Solo cuenta notifs que fueron enviadas/entregadas y el user NO abrio.
    // Excluye skipped (preferencia/quiet_hours/rate_limit) y fallidas.
    const estadosNoLeidos = {'enviada', 'entregada', 'impresa'};
    final noLeidas = async.maybeWhen(
      data: (items) =>
          items.where((n) => estadosNoLeidos.contains(n.estado)).length,
      orElse: () => 0,
    );

    final hasBadge = noLeidas > 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Badge(
          isLabelVisible: hasBadge,
          label: hasBadge ? Text('$noLeidas') : null,
          child: Icon(
            Icons.notifications_outlined,
            color: theme.colorScheme.primary,
          ),
        ),
        title: const Text(
          'Mis notificaciones',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          hasBadge ? '$noLeidas sin leer' : 'Recordatorios y avisos recientes',
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14),
        onTap: () => context.push('/mis-notificaciones'),
      ),
    );
  }
}
