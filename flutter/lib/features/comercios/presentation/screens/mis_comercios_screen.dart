/// Pantalla "Mis comercios" (dueño).
///
/// Lista todos los comercios del usuario autenticado (cualquier estado).
/// Permite:
/// - Crear un nuevo comercio (FAB).
/// - Tocar una card para ver el detalle propio.
/// - Ver el estado de cada comercio (borrador/pendiente/verificado/etc).
/// - Ver el motivo de rechazo si aplica.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:baqueano_natales/features/comercios/data/comercio_providers.dart';
import 'package:baqueano_natales/features/comercios/domain/comercio.dart';

class MisComerciosScreen extends ConsumerWidget {
  const MisComerciosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncComercios = ref.watch(misComerciosProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Mis comercios')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/mis-comercios/nuevo'),
        icon: const Icon(Icons.add),
        label: const Text('Nuevo'),
      ),
      body: asyncComercios.when(
        data: (comercios) {
          if (comercios.isEmpty) return const _EmptyState();
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(misComerciosProvider);
            },
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: comercios.length,
              itemBuilder: (context, index) {
                final c = comercios[index];
                return _MiComercioCard(
                  comercio: c,
                  onTap: () => context.push('/mis-comercios/${c.id}'),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorState(
          error: e.toString(),
          onRetry: () => ref.invalidate(misComerciosProvider),
        ),
      ),
    );
  }
}

class _MiComercioCard extends StatelessWidget {
  const _MiComercioCard({required this.comercio, this.onTap});

  final Comercio comercio;
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
                            comercio.nombre,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _EstadoBadge(estado: comercio.estado),
                      ],
                    ),
                    if (comercio.categoria != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        comercio.categoria!.nombre,
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
                            comercio.direccion,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (comercio.estado == EstadoComercio.rechazado &&
                        comercio.motivoRechazo != null) ...[
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
                                comercio.motivoRechazo!,
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
    if (comercio.logoUrl != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          comercio.logoUrl!,
          width: 56,
          height: 56,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _thumbPlaceholder(theme),
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
      child: Icon(
        Icons.storefront,
        color: theme.colorScheme.onPrimaryContainer,
      ),
    );
  }
}

class _EstadoBadge extends StatelessWidget {
  const _EstadoBadge({required this.estado});

  final EstadoComercio? estado;

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
      case EstadoComercio.verificado:
        return (Colors.green.shade800, Colors.green.shade50);
      case EstadoComercio.pendiente:
        return (Colors.orange.shade800, Colors.orange.shade50);
      case EstadoComercio.rechazado:
        return (Colors.red.shade800, Colors.red.shade50);
      case EstadoComercio.suspendido:
        return (Colors.grey.shade800, Colors.grey.shade200);
      case EstadoComercio.borrador:
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
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.storefront_outlined,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'Aún no tenés comercios',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Creá tu primer comercio con el botón +.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
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