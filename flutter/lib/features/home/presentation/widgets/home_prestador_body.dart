import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:baqueano_natales/features/prestadores/data/prestador_providers.dart';
import 'package:baqueano_natales/features/prestadores/domain/prestador.dart';
import 'package:baqueano_natales/features/home/presentation/widgets/home_card.dart';

/// Cuerpo del home en modo Prestador.
class HomePrestadorBody extends ConsumerWidget {
  const HomePrestadorBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final asyncPrestadores = ref.watch(misPrestadoresProvider);

    return asyncPrestadores.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 12),
              Text('Error cargando tu taller: $e'),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => ref.invalidate(misPrestadoresProvider),
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      ),
      data: (prestadores) {
        if (prestadores.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.storefront, size: 64),
                  const SizedBox(height: 16),
                  Text(
                    'Aun no tienes un taller registrado',
                    style: theme.textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    icon: const Icon(Icons.add),
                    onPressed: () => context.push('/mis-prestadores/nuevo'),
                    label: const Text('Crear mi taller'),
                  ),
                ],
              ),
            ),
          );
        }

        final p = prestadores.first;
        final prestadorId = p.id;

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(misPrestadoresProvider);
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: theme.colorScheme.primaryContainer,
                            child: Icon(
                              Icons.handyman,
                              color: theme.colorScheme.onPrimaryContainer,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p.nombre,
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                _EstadoBadge(
                                  estado: p.estado ?? EstadoPrestador.borrador,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (p.totalResenas > 0) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(
                              Icons.star,
                              size: 16,
                              color: Colors.amber,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              p.calificacionPromedio.toStringAsFixed(1),
                              style: theme.textTheme.bodyMedium,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '(${p.totalResenas} resenas)',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Gestion de mi taller',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              HomeCard(
                icon: Icons.calendar_month,
                title: 'Mi agenda',
                subtitle: 'Turnos, reservas y disponibilidad',
                onTap: () =>
                    context.push('/mis-prestadores/$prestadorId/turnos'),
              ),
              HomeCard(
                icon: Icons.assignment_outlined,
                title: 'Mis ordenes de trabajo',
                subtitle: 'Ordenes generadas por tus servicios',
                onTap: () =>
                    context.push('/mis-prestadores/$prestadorId/ordenes'),
              ),
              HomeCard(
                icon: Icons.rate_review_outlined,
                title: 'Mis resenas',
                subtitle: 'Opiniones de tus clientes',
                onTap: () =>
                    context.push('/mis-prestadores/$prestadorId/reviews'),
              ),
              HomeCard(
                icon: Icons.bar_chart,
                title: 'Mis reportes',
                subtitle: 'Metricas y estadisticas',
                onTap: () =>
                    context.push('/mis-prestadores/$prestadorId/reportes'),
              ),
              const SizedBox(height: 24),
              Text(
                'Mi perfil de prestador',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              HomeCard(
                icon: Icons.edit_outlined,
                title: 'Editar mi perfil',
                subtitle: 'Datos del taller, foto y horarios',
                onTap: () =>
                    context.push('/mis-prestadores/$prestadorId/editar'),
              ),
              HomeCard(
                icon: Icons.tune,
                title: 'Servicios y precios',
                subtitle: 'Catalogo del taller',
                onTap: () =>
                    context.push('/mis-prestadores/$prestadorId/modalidades'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _EstadoBadge extends StatelessWidget {
  final EstadoPrestador estado;
  const _EstadoBadge({required this.estado});

  @override
  Widget build(BuildContext context) {
    final (Color color, String label) = switch (estado) {
      EstadoPrestador.verificado => (Colors.green, 'Verificado'),
      EstadoPrestador.pendiente => (Colors.orange, 'Pendiente de verificacion'),
      EstadoPrestador.borrador => (Colors.grey, 'Borrador'),
      EstadoPrestador.rechazado => (Colors.red, 'Rechazado'),
      EstadoPrestador.suspendido => (Colors.red, 'Suspendido'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
