import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:baqueano_natales/features/prestadores/data/prestador_providers.dart';
import 'package:baqueano_natales/features/prestadores/domain/prestador.dart';
import 'package:baqueano_natales/features/home/presentation/widgets/home_card.dart';

/// Cuerpo del home en modo Prestador.
///
/// Soporta múltiples prestadores (uno por vertical). Si el usuario tiene
/// más de uno, muestra un selector en el header para cambiar entre ellos.
class HomePrestadorBody extends ConsumerStatefulWidget {
  const HomePrestadorBody({super.key});

  @override
  ConsumerState<HomePrestadorBody> createState() => _HomePrestadorBodyState();
}

class _HomePrestadorBodyState extends ConsumerState<HomePrestadorBody> {
  String? _selectedPrestadorId;

  @override
  Widget build(BuildContext context) {
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
                    'Aún no tienes un taller registrado',
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

        // Resolver el prestador seleccionado (o el primero por defecto)
        final selected = prestadores.firstWhere(
          (p) => p.id == _selectedPrestadorId,
          orElse: () => prestadores.first,
        );

        final prestadorId = selected.id;
        final categoriaSlug = selected.categoria.slug;

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(misPrestadoresProvider);
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Selector de vertical (solo si hay más de 1 prestador)
              if (prestadores.length > 1) ...[
                _SelectorVertical(
                  prestadores: prestadores,
                  selected: selected,
                  onChanged: (p) => setState(() => _selectedPrestadorId = p.id),
                ),
                const SizedBox(height: 12),
              ],

              // Card del prestador seleccionado
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
                              _iconoCategoria(categoriaSlug),
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
                                  selected.nombre,
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    _EstadoBadge(
                                      estado:
                                          selected.estado ??
                                          EstadoPrestador.borrador,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      selected.categoria.nombre,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (selected.totalResenas > 0) ...[
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
                              selected.calificacionPromedio.toStringAsFixed(1),
                              style: theme.textTheme.bodyMedium,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '(${selected.totalResenas} reseñas)',
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
              _MenuPorCategoria(
                prestadorId: prestadorId,
                categoriaSlug: categoriaSlug,
                theme: theme,
              ),
            ],
          ),
        );
      },
    );
  }

  IconData _iconoCategoria(String slug) {
    switch (slug) {
      case 'arriendo-vehiculos':
        return Icons.directions_car;
      case 'mecanica-automotriz':
        return Icons.handyman;
      default:
        return Icons.storefront;
    }
  }
}

// =========================================================
// Menú dinámico por categoría
// =========================================================
class _MenuPorCategoria extends StatelessWidget {
  const _MenuPorCategoria({
    required this.prestadorId,
    required this.categoriaSlug,
    required this.theme,
  });

  final String prestadorId;
  final String categoriaSlug;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    // Acciones comunes a TODAS las categorías
    final comunes = [
      HomeCard(
        icon: Icons.edit_outlined,
        title: 'Editar mi perfil',
        subtitle: 'Datos, foto y horarios',
        onTap: () => context.push('/mis-prestadores/$prestadorId/editar'),
      ),
    ];

    // Acciones específicas por categoría
    switch (categoriaSlug) {
      case 'mecanica-automotriz':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _tituloSeccion('Gestión de mi taller'),
            HomeCard(
              icon: Icons.calendar_month,
              title: 'Mi agenda',
              subtitle: 'Turnos, reservas y disponibilidad',
              onTap: () => context.push('/mis-prestadores/$prestadorId/turnos'),
            ),
            HomeCard(
              icon: Icons.assignment_outlined,
              title: 'Mis órdenes de trabajo',
              subtitle: 'Órdenes generadas por tus servicios',
              onTap: () =>
                  context.push('/mis-prestadores/$prestadorId/ordenes'),
            ),
            HomeCard(
              icon: Icons.rate_review_outlined,
              title: 'Mis reseñas',
              subtitle: 'Opiniones de tus clientes',
              onTap: () =>
                  context.push('/mis-prestadores/$prestadorId/reviews'),
            ),
            HomeCard(
              icon: Icons.bar_chart,
              title: 'Mis reportes',
              subtitle: 'Métricas y estadísticas',
              onTap: () =>
                  context.push('/mis-prestadores/$prestadorId/reportes'),
            ),
            const SizedBox(height: 24),
            _tituloSeccion('Mi perfil de prestador'),
            HomeCard(
              icon: Icons.tune,
              title: 'Servicios y precios',
              subtitle: 'Catálogo del taller',
              onTap: () =>
                  context.push('/mis-prestadores/$prestadorId/modalidades'),
            ),
            ...comunes,
          ],
        );

      case 'arriendo-vehiculos':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _tituloSeccion('Gestión de mi flota'),
            HomeCard(
              icon: Icons.directions_car_outlined,
              title: 'Mi flota de vehículos',
              subtitle: 'Administrar vehículos, precios y disponibilidad',
              onTap: () => context.push('/mis-vehiculos-rentacar'),
            ),
            HomeCard(
              icon: Icons.event_note_outlined,
              title: 'Reservas',
              subtitle: 'Ver y gestionar reservas de clientes',
              onTap: () => context.push('/mis-reservas-rentacar'),
            ),
            HomeCard(
              icon: Icons.analytics_outlined,
              title: 'Estadísticas',
              subtitle: 'Ingresos, reservas y disponibilidad',
              onTap: () => context.push('/mis-stats-rentacar'),
            ),
            HomeCard(
              icon: Icons.settings_outlined,
              title: 'Configuración',
              subtitle: 'Métodos de pago, depósito y conductor adicional',
              onTap: () => context.push('/mis-config-rentacar'),
            ),
            HomeCard(
              icon: Icons.palette_outlined,
              title: 'Kit de marca',
              subtitle: 'Logos, favicons e iconos — individual o ZIP',
              onTap: () => context.push('/mis-brand-kit/vasquez'),
            ),
            const SizedBox(height: 24),
            _tituloSeccion('Mi perfil de prestador'),
            ...comunes,
          ],
        );

      default:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _tituloSeccion('Gestión'),
            const SizedBox(height: 8),
            Text(
              'No hay acciones específicas para esta categoría todavía.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            _tituloSeccion('Mi perfil de prestador'),
            ...comunes,
          ],
        );
    }
  }

  Widget _tituloSeccion(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

// =========================================================
// Selector de vertical (dropdown)
// =========================================================
class _SelectorVertical extends StatelessWidget {
  const _SelectorVertical({
    required this.prestadores,
    required this.selected,
    required this.onChanged,
  });

  final List<Prestador> prestadores;
  final Prestador selected;
  final ValueChanged<Prestador> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Icon(Icons.swap_horiz, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<Prestador>(
                  value: selected,
                  isExpanded: true,
                  items: prestadores
                      .map(
                        (p) => DropdownMenuItem(
                          value: p,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                p.nombre,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                p.categoria.nombre,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (p) {
                    if (p != null) onChanged(p);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =========================================================
// Badge de estado
// =========================================================
class _EstadoBadge extends StatelessWidget {
  const _EstadoBadge({required this.estado});

  final EstadoPrestador estado;

  @override
  Widget build(BuildContext context) {
    final (Color color, String label) = switch (estado) {
      EstadoPrestador.verificado => (Colors.green, 'Verificado'),
      EstadoPrestador.pendiente => (Colors.orange, 'Pendiente de verificación'),
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
