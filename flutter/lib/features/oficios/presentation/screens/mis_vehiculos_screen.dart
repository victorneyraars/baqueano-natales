/// Pantalla cliente: lista de mis vehiculos.
///
/// Permite ver, agregar, editar y eliminar (soft) vehiculos propios.
/// Cada vehiculo es un `objeto_servicio` de tipo VEHICULO.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:baqueano_natales/features/oficios/data/oficios_providers.dart';
import 'package:baqueano_natales/features/oficios/domain/vehiculo.dart';

class MisVehiculosScreen extends ConsumerWidget {
  const MisVehiculosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(misVehiculosProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis vehiculos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refrescar',
            onPressed: () => ref.invalidate(misVehiculosProvider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/mis-vehiculos/nuevo'),
        icon: const Icon(Icons.add),
        label: const Text('Agregar'),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorView(
          error: e,
          onRetry: () => ref.invalidate(misVehiculosProvider),
        ),
        data: (vehiculos) {
          if (vehiculos.isEmpty) {
            return _EmptyView(
              onAdd: () => context.push('/mis-vehiculos/nuevo'),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(misVehiculosProvider);
              await ref.read(misVehiculosProvider.future);
            },
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: vehiculos.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (_, i) => _VehiculoCard(
                vehiculo: vehiculos[i],
                onTap: () => context.push(
                  '/mis-vehiculos/${vehiculos[i].objetoId}/editar',
                ),
                onDelete: () => _confirmarEliminar(
                  context,
                  ref,
                  vehiculos[i],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmarEliminar(
    BuildContext context,
    WidgetRef ref,
    Vehiculo vehiculo,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar vehiculo'),
        content: Text(
          'Estas seguro de eliminar "${vehiculo.nombreDisplay}"? '
          'Se puede volver a registrar despues.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      final repo = ref.read(oficiosRepositoryProvider);
      await repo.eliminarVehiculo(vehiculo.objetoId);
      ref.invalidate(misVehiculosProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vehiculo eliminado')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }
}

class _VehiculoCard extends StatelessWidget {
  const _VehiculoCard({
    required this.vehiculo,
    required this.onTap,
    required this.onDelete,
  });

  final Vehiculo vehiculo;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  IconData get _icono {
    switch (vehiculo.tipoVehiculo) {
      case TipoVehiculo.moto:
        return Icons.two_wheeler;
      case TipoVehiculo.camion:
        return Icons.local_shipping;
      case TipoVehiculo.suv:
      case TipoVehiculo.camioneta:
        return Icons.directions_car_filled;
      case TipoVehiculo.sedan:
      case TipoVehiculo.otro:
        return Icons.directions_car;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _icono,
                  size: 32,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vehiculo.nombreDisplay,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${vehiculo.patente} - ${vehiculo.anio}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${vehiculo.kilometrajeActual} km',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Eliminar',
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.directions_car_outlined,
              size: 72,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'Aun no tenes vehiculos',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Agrega tu auto para poder agendar servicios y ver su historial.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Agregar vehiculo'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});
  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text(
              error.toString(),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onRetry,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}