/// Pantalla Home.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:baqueano_natales/features/auth/data/auth_notifier.dart';

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
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inicio'),
        actions: [
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

            _FeatureCard(
              icon: Icons.storefront,
              title: 'Mis comercios',
              subtitle: 'Gestioná tus locales y servicios',
              onTap: () => context.push('/mis-comercios'),
            ),
            _FeatureCard(
              icon: Icons.handyman,
              title: 'Mis oficios',
              subtitle: 'Gestioná tus perfiles de prestador',
              onTap: () => context.push('/mis-prestadores'),
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

            const SizedBox(height: 24),

            // --- Descubrí ---
            Text(
              'Descubrí',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            _FeatureCard(
              icon: Icons.explore,
              title: 'Comercios',
              subtitle: 'Explorá locales y servicios de Puerto Natales',
              onTap: () => context.push('/comercios'),
            ),
            _FeatureCard(
              icon: Icons.build_circle_outlined,
              title: 'Oficios y servicios',
              subtitle: 'Mecánicos, gasfiteres, electricistas y más',
              onTap: () => context.push('/prestadores'),
            ),

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
        onTap: onTap ??
            () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Próximamente')),
              );
            },
      ),
    );
  }
}