/// Pantalla prestador: lista de ordenes del taller.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:baqueano_natales/features/oficios/data/oficios_providers.dart';
import 'package:baqueano_natales/features/oficios/domain/orden_trabajo.dart';

class OrdenesTallerScreen extends ConsumerStatefulWidget {
  const OrdenesTallerScreen({super.key, required this.prestadorId});

  final String prestadorId;

  @override
  ConsumerState<OrdenesTallerScreen> createState() =>
      _OrdenesTallerScreenState();
}

class _OrdenesTallerScreenState extends ConsumerState<OrdenesTallerScreen> {
  String? _estadoFiltro;

  @override
  Widget build(BuildContext context) {
    final params = OrdenesPrestadorParams(
      prestadorId: widget.prestadorId,
      estado: _estadoFiltro,
    );
    final async = ref.watch(ordenesPrestadorProvider(params));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ordenes del taller'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(ordenesPrestadorProvider(params)),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(
          '/mis-prestadores/${widget.prestadorId}/ordenes/nueva',
        ),
        icon: const Icon(Icons.add),
        label: const Text('Nueva orden'),
      ),
      body: Column(
        children: [
          _FiltrosEstado(
            seleccionado: _estadoFiltro,
            onCambio: (e) => setState(() => _estadoFiltro = e),
          ),
          const Divider(height: 1),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _ErrorView(
                error: e,
                onRetry: () => ref.invalidate(ordenesPrestadorProvider(params)),
              ),
              data: (ordenes) {
                if (ordenes.isEmpty) return const _EmptyView();
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(ordenesPrestadorProvider(params));
                    await ref.read(ordenesPrestadorProvider(params).future);
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: ordenes.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (_, i) => _OrdenCard(
                      orden: ordenes[i],
                      onTap: () => context.push(
                        '/mis-prestadores/${widget.prestadorId}/ordenes/${ordenes[i].id}',
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FiltrosEstado extends StatelessWidget {
  const _FiltrosEstado({required this.seleccionado, required this.onCambio});
  final String? seleccionado;
  final ValueChanged<String?> onCambio;

  @override
  Widget build(BuildContext context) {
    final opciones = <MapEntry<String?, String>>[
      const MapEntry(null, 'Todas'),
      const MapEntry('ingresado', 'Ingresadas'),
      const MapEntry('diagnosticando', 'Diagnosticando'),
      const MapEntry('presupuestado', 'Presupuestadas'),
      const MapEntry('aprobado', 'Aprobadas'),
      const MapEntry('en_proceso', 'En proceso'),
      const MapEntry('listo', 'Listas'),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: opciones.map((op) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(op.value),
              selected: seleccionado == op.key,
              onSelected: (_) => onCambio(op.key),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _OrdenCard extends StatelessWidget {
  const _OrdenCard({required this.orden, required this.onTap});
  final OrdenTrabajo orden;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _hexToColor(orden.estado.colorHex);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      orden.numero,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: color),
                    ),
                    child: Text(
                      orden.estado.label,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: color,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              if (orden.diagnosticoInicial != null) ...[
                const SizedBox(height: 8),
                Text(
                  orden.diagnosticoInicial!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.attach_money,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatCLP(orden.totalPresupuesto),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _formatFecha(orden.fechaIngreso),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.assignment_outlined,
              size: 72,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'No hay ordenes',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Crea la primera orden con el boton de abajo.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
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
            Text(error.toString(), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }
}

Color _hexToColor(String hex) {
  final h = hex.replaceFirst('#', '');
  return Color(int.parse('FF$h', radix: 16));
}

String _formatCLP(double valor) {
  final s = valor.toStringAsFixed(0);
  return '\$${s.replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';
}

String _formatFecha(DateTime d) => '${d.day}/${d.month}/${d.year}';
