/// Pantalla admin: dashboard de estadisticas de notificaciones.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:baqueano_natales/features/notificaciones/data/notificaciones_providers.dart';

class AdminNotificacionesStatsScreen extends ConsumerWidget {
  const AdminNotificacionesStatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(statsNotificacionesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Estadisticas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(statsNotificacionesProvider),
          ),
        ],
      ),
      body: async.when(
        data: (stats) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(statsNotificacionesProvider),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _MetricRow(
                cards: [
                  _MetricCard(
                    titulo: 'Total',
                    valor: '${stats.total}',
                    icon: Icons.notifications,
                    color: Colors.blue,
                  ),
                  _MetricCard(
                    titulo: 'Abiertas',
                    valor: '${stats.abiertas}',
                    icon: Icons.mark_email_read,
                    color: Colors.green,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _MetricRow(
                cards: [
                  _MetricCard(
                    titulo: 'Delivery rate',
                    valor:
                        '${(stats.deliveryRate * 100).toStringAsFixed(1)}%',
                    icon: Icons.local_shipping,
                    color: Colors.teal,
                  ),
                  _MetricCard(
                    titulo: 'Open rate',
                    valor: '${(stats.openRate * 100).toStringAsFixed(1)}%',
                    icon: Icons.visibility,
                    color: Colors.purple,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text('Por estado',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              ...stats.porEstado.map(
                (e) => ListTile(
                  dense: true,
                  title: Text(e.estado),
                  trailing: Text('${e.count}',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 16),
              Text('Por tipo',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              ...stats.porTipo.map(
                (e) => ListTile(
                  dense: true,
                  title: Text(e.tipo),
                  trailing: Text('${e.count}',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 16),
              if (stats.top5.isNotEmpty) ...[
                Text('Top 5 por aperturas',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                ...stats.top5.map(
                  (t) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      dense: true,
                      title: Text(t.titulo,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                        '${t.abiertas}/${t.total} abiertas '
                        '(${(t.openRate * 100).toStringAsFixed(0)}%)',
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Error: $e'),
          ),
        ),
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.cards});
  final List<_MetricCard> cards;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: cards
          .expand((c) => [Expanded(child: c), const SizedBox(width: 8)])
          .take(cards.length * 2 - 1)
          .toList(),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.titulo,
    required this.valor,
    required this.icon,
    required this.color,
  });
  final String titulo;
  final String valor;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 8),
            Text(
              valor,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(titulo, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
