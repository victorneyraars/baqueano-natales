/// Pantalla "Mis prestadores" (dueño).
///
/// Lista todos los prestadores del usuario autenticado (cualquier estado).
/// Permite:
/// - Crear un nuevo prestador (FAB).
/// - Tocar una card para ver el detalle propio.
/// - Ver el estado de cada prestador (borrador/pendiente/verificado/etc).
/// - Ver el motivo de rechazo si aplica.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:baqueano_natales/features/prestadores/data/prestador_providers.dart';
import 'package:baqueano_natales/features/prestadores/domain/prestador.dart';

class MisPrestadoresScreen extends ConsumerWidget {
  const MisPrestadoresScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncPrestadores = ref.watch(misPrestadoresProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Mis oficios')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/mis-prestadores/nuevo'),
        icon: const Icon(Icons.add),
        label: const Text('Nuevo'),
      ),
      body: asyncPrestadores.when(
        data: (prestadores) {
          if (prestadores.isEmpty) return const _EmptyState();
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(misPrestadoresProvider);
            },
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: prestadores.length,
              itemBuilder: (context, index) {
                final p = prestadores[index];
                return _MiPrestadorCard(
                  prestador: p,
                  onTap: () => context.push('/mis-prestadores/${p.id}'),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorState(
          error: e.toString(),
          onRetry: () => ref.invalidate(misPrestadoresProvider),
        ),
      ),
    );
  }
}

class _MiPrestadorCard extends StatelessWidget {
  const _MiPrestadorCard({required this.prestador, this.onTap});

  final Prestador prestador;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _thumb(theme),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            prestador.nombre,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _EstadoBadge(estado: prestador.estado),
                      ],
                    ),
                    if (prestador.categoria.nombre.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        prestador.categoria.nombre,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            prestador.comuna,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (prestador.servicios.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.list_alt_outlined,
                            size: 12,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${prestador.servicios.length} servicio(s)',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (prestador.estado == EstadoPrestador.rechazado &&
                        prestador.motivoRechazo != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 14,
                              color: Colors.red.shade700,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                prestador.motivoRechazo!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.red.shade800,
                                ),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _thumb(ThemeData theme) {
    if (prestador.fotoUrl != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          prestador.fotoUrl!,
          width: 56,
          height: 56,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _thumbPlaceholder(theme),
        ),
      );
    }
    return _thumbPlaceholder(theme);
  }

  Widget _thumbPlaceholder(ThemeData theme) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          prestador.iniciales,
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onPrimaryContainer,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class _EstadoBadge extends StatelessWidget {
  const _EstadoBadge({required this.estado});

  final EstadoPrestador? estado;

  @override
  Widget build(BuildContext context) {
    final (color, bg) = _colors();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        estado?.label ?? '-',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  (Color, Color) _colors() {
    switch (estado) {
      case EstadoPrestador.verificado:
        return (Colors.green.shade800, Colors.green.shade50);
      case EstadoPrestador.pendiente:
        return (Colors.orange.shade800, Colors.orange.shade50);
      case EstadoPrestador.rechazado:
        return (Colors.red.shade800, Colors.red.shade50);
      case EstadoPrestador.suspendido:
        return (Colors.grey.shade800, Colors.grey.shade200);
      case EstadoPrestador.borrador:
      default:
        return (Colors.blueGrey.shade800, Colors.blueGrey.shade50);
    }
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.handyman_outlined,
                size: 56,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Ofrece tus servicios',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Crea tu perfil de prestador para que los clientes te '
              'encuentren, te contacten y agenden turnos.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            _StepItem(
              numero: 1,
              titulo: 'Crea tu perfil',
              descripcion: 'Nombre, categoria, especialidades.',
              theme: theme,
            ),
            const SizedBox(height: 12),
            _StepItem(
              numero: 2,
              titulo: 'Carga tus servicios',
              descripcion: 'Con precios y duraciones estimadas.',
              theme: theme,
            ),
            const SizedBox(height: 12),
            _StepItem(
              numero: 3,
              titulo: 'Enviar a revision',
              descripcion: 'Un admin lo verifica y ya apareces publico.',
              theme: theme,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () => context.push('/mis-prestadores/nuevo'),
              icon: const Icon(Icons.add),
              label: const Text('Crear mi primer perfil'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
                textStyle: theme.textTheme.titleMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepItem extends StatelessWidget {
  const _StepItem({
    required this.numero,
    required this.titulo,
    required this.descripcion,
    required this.theme,
  });

  final int numero;
  final String titulo;
  final String descripcion;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            shape: BoxShape.circle,
          ),
          child: Text(
            '$numero',
            style: TextStyle(
              color: theme.colorScheme.onPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                descripcion,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error al cargar', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(error, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
