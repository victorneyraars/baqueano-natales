/// Pantalla cliente: detalle de una orden con aprobacion de items y timeline.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:baqueano_natales/core/network/api_exceptions.dart';
import 'package:baqueano_natales/features/oficios/data/oficios_providers.dart';
import 'package:baqueano_natales/features/oficios/domain/orden_historial.dart';
import 'package:baqueano_natales/features/oficios/domain/orden_item.dart';
import 'package:baqueano_natales/features/oficios/domain/orden_trabajo.dart';
import 'package:baqueano_natales/features/oficios/presentation/widgets/garantia_card.dart';

class DetalleMiOrdenScreen extends ConsumerStatefulWidget {
  const DetalleMiOrdenScreen({super.key, required this.ordenId});

  final String ordenId;

  @override
  ConsumerState<DetalleMiOrdenScreen> createState() =>
      _DetalleMiOrdenScreenState();
}

class _DetalleMiOrdenScreenState extends ConsumerState<DetalleMiOrdenScreen> {
  /// Estado local de seleccion de items (para aprobacion por item).
  /// Se inicializa a partir de los `aprobado` del backend.
  final Map<String, bool> _seleccion = {};
  bool _seleccionInicializada = false;
  bool _guardando = false;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(miOrdenDetalleProvider(widget.ordenId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle de orden'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                ref.invalidate(miOrdenDetalleProvider(widget.ordenId)),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorView(
          error: e,
          onRetry: () =>
              ref.invalidate(miOrdenDetalleProvider(widget.ordenId)),
        ),
        data: (orden) {
          // Inicializar seleccion la primera vez que llega la orden
          if (!_seleccionInicializada) {
            for (final it in orden.items) {
              _seleccion[it.id] = it.aprobado ?? true;
            }
            _seleccionInicializada = true;
          }
          return _Contenido(
            orden: orden,
            seleccion: _seleccion,
            guardando: _guardando,
            onToggleItem: (itemId, valor) =>
                setState(() => _seleccion[itemId] = valor),
            onAprobar: () => _aprobar(orden),
          );
        },
      ),
    );
  }

  Future<void> _aprobar(OrdenTrabajo orden) async {
    // Verificar si hay algo seleccionado
    final hayAlguno = _seleccion.values.any((v) => v == true);
    if (!hayAlguno) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Rechazar todo?'),
          content: const Text(
            'No aprobaste ningun item. La orden quedara como rechazada.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Rechazar todo'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }

    setState(() => _guardando = true);
    try {
      final repo = ref.read(oficiosRepositoryProvider);
      final items = _seleccion.entries
          .map((e) => {'item_id': e.key, 'aprobado': e.value})
          .toList();

      final aprobados = _seleccion.values.where((v) => v).length;
      final todos = aprobados == _seleccion.length;
      final ninguno = aprobados == 0;

      await repo.aprobarPresupuesto(
        orden.id,
        aprobarTodos: todos,
        items: ninguno || todos ? null : items,
      );

      ref.invalidate(miOrdenDetalleProvider(orden.id));
      ref.invalidate(misOrdenesProvider(null));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Respuesta enviada')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.message}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error inesperado: $e')),
      );
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }
}

class _Contenido extends StatelessWidget {
  const _Contenido({
    required this.orden,
    required this.seleccion,
    required this.guardando,
    required this.onToggleItem,
    required this.onAprobar,
  });

  final OrdenTrabajo orden;
  final Map<String, bool> seleccion;
  final bool guardando;
  final void Function(String itemId, bool valor) onToggleItem;
  final VoidCallback onAprobar;

  bool get _puedeAprobar => orden.estado == EstadoOrden.presupuestado;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _hexToColor(orden.estado.colorHex);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Header
        Card(
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
                        style: theme.textTheme.titleLarge?.copyWith(
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
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: color,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Ingresada ${_formatFecha(orden.fechaIngreso)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (orden.diagnosticoInicial != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Diagnostico:',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(orden.diagnosticoInicial!),
                ],
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Items
        if (orden.tieneItems) ...[
          Text(
            'Presupuesto',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          ...orden.items.map((it) => _ItemCard(
                item: it,
                seleccionado: seleccion[it.id] ?? false,
                modoAprobacion: _puedeAprobar,
                onToggle: (v) => onToggleItem(it.id, v),
              )),
          const SizedBox(height: 12),
          _TotalCard(orden: orden),
        ],

        if (_puedeAprobar) ...[
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: guardando ? null : onAprobar,
            icon: guardando
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            label: const Text('Enviar respuesta'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
        ],

        const SizedBox(height: 24),

        // Garantia (si la orden esta entregada)
        if (orden.estado == EstadoOrden.entregado) ...[
          const SizedBox(height: 16),
          _GarantiaSectionWrapper(ordenId: orden.id),
        ],

        // Timeline
        if (orden.historial.isNotEmpty) ...[
          Text(
            'Historial',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ...orden.historial.map((ev) => _TimelineRow(evento: ev)),
        ],

        const SizedBox(height: 32),
      ],
    );
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({
    required this.item,
    required this.seleccionado,
    required this.modoAprobacion,
    required this.onToggle,
  });

  final OrdenItem item;
  final bool seleccionado;
  final bool modoAprobacion;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorAprobado = item.aprobado == true
        ? Colors.green
        : (item.aprobado == false ? Colors.red : null);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            if (modoAprobacion)
              Checkbox(
                value: seleccionado,
                onChanged: (v) => onToggle(v ?? false),
              )
            else if (colorAprobado != null)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Icon(
                  item.aprobado == true
                      ? Icons.check_circle
                      : Icons.cancel,
                  color: colorAprobado,
                  size: 24,
                ),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.descripcion,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${item.tipo.label} - ${item.cantidad.toStringAsFixed(0)} x ${_formatCLP(item.precioUnitario)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _formatCLP(item.subtotal),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TotalCard extends StatelessWidget {
  const _TotalCard({required this.orden});
  final OrdenTrabajo orden;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total presupuesto'),
                Text(
                  _formatCLP(orden.totalPresupuesto),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            if (orden.totalAprobado > 0) ...[
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total aprobado'),
                  Text(
                    _formatCLP(orden.totalAprobado),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.evento});
  final OrdenHistorialEvento evento;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 6, right: 12),
            decoration: const BoxDecoration(
              color: Colors.blueGrey,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  evento.descripcion,
                  style: theme.textTheme.bodyMedium,
                ),
                Text(
                  _formatFechaHora(evento.createdAt),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
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

Color _hexToColor(String hex) {
  final h = hex.replaceFirst('#', '');
  return Color(int.parse('FF$h', radix: 16));
}

String _formatCLP(double valor) {
  final s = valor.toStringAsFixed(0);
  return '\$${s.replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';
}

String _formatFecha(DateTime d) => '${d.day}/${d.month}/${d.year}';

String _formatFechaHora(DateTime d) =>
    '${d.day}/${d.month}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

// =========================================================
// Wrapper que carga la garantia del provider
// =========================================================
class _GarantiaSectionWrapper extends ConsumerWidget {
  const _GarantiaSectionWrapper({required this.ordenId});
  final String ordenId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(garantiaDeMiOrdenProvider(ordenId));
    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => const SizedBox.shrink(),
      data: (g) {
        if (g == null) return const SizedBox.shrink();
        return GarantiaCard(garantia: g);
      },
    );
  }
}