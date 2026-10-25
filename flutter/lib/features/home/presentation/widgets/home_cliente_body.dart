import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:baqueano_natales/features/auth/data/auth_notifier.dart';
import 'package:baqueano_natales/features/notificaciones/data/notificaciones_providers.dart';
import 'package:baqueano_natales/features/home/presentation/widgets/home_card.dart';

/// Cuerpo del home en modo Cliente.
class HomeClienteBody extends ConsumerWidget {
  const HomeClienteBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    final user = authState.user;
    final theme = Theme.of(context);
    if (user == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(authNotifierProvider.notifier).restoreSession();
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Mi actividad',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          HomeCard(
            icon: Icons.calendar_month,
            title: 'Mis turnos',
            subtitle: 'Reservas con talleres y oficios',
            onTap: () => context.push('/mis-turnos'),
          ),
          HomeCard(
            icon: Icons.directions_car_outlined,
            title: 'Mis vehiculos',
            subtitle: 'Gestiona tus autos y su historial',
            onTap: () => context.push('/mis-vehiculos'),
          ),
          HomeCard(
            icon: Icons.receipt_long_outlined,
            title: 'Mis ordenes',
            subtitle: 'Servicios agendados con talleres',
            onTap: () => context.push('/mis-ordenes'),
          ),
          const _NotificacionesHomeCard(),
          const SizedBox(height: 24),
          Text(
            'Descubrí',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          HomeCard(
            icon: Icons.build_circle_outlined,
            title: 'Mecánicos',
            subtitle: 'Encontrá mecánicos en Puerto Natales',
            onTap: () => context.push('/prestadores'),
          ),
        ],
      ),
    );
  }
}

class _NotificacionesHomeCard extends ConsumerWidget {
  const _NotificacionesHomeCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final async = ref.watch(misNotificacionesProvider);
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
        subtitle: Text(hasBadge ? '$noLeidas sin leer' : 'Todo al día'),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14),
        onTap: () => context.push('/mis-notificaciones'),
      ),
    );
  }
}
