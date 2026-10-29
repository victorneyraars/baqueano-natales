import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:baqueano_natales/core/theme/app_theme_extension.dart';
import 'package:baqueano_natales/features/rentacar/data/rentacar_providers.dart';

class StatsRentacarScreen extends ConsumerWidget {
  const StatsRentacarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncStats = ref.watch(misStatsRentacarProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Estadísticas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(misStatsRentacarProvider),
          ),
        ],
      ),
      body: asyncStats.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Error: $e', textAlign: TextAlign.center),
          ),
        ),
        data: (stats) {
          final ext = Theme.of(context).extension<AppThemeExtension>()!;
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(misStatsRentacarProvider);
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _KpiCard(
                  label: 'Ingresos del mes',
                  value: _formatoCLP(stats.ingresosMesActual),
                  color: ext.rentacarAccent,
                ),
                const SizedBox(height: 12),
                _KpiCard(
                  label: 'Ingresos totales',
                  value: _formatoCLP(stats.ingresosTotales),
                  color: ext.success,
                ),
                _EstadoTile(
                  label: 'Pendientes',
                  count: stats.reservasPendientes,
                  color: ext.reservaPendiente,
                ),
                _EstadoTile(
                  label: 'Confirmadas',
                  count: stats.reservasConfirmadas,
                  color: ext.reservaConfirmada,
                ),
                _EstadoTile(
                  label: 'En curso',
                  count: stats.reservasEnCurso,
                  color: ext.reservaEnCurso,
                ),
                _EstadoTile(
                  label: 'Completadas',
                  count: stats.reservasCompletadas,
                  color: ext.reservaCompletada,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: theme.textTheme.bodySmall),
            const SizedBox(height: 8),
            Text(
              value,
              style: theme.textTheme.headlineLarge?.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

class _EstadoTile extends StatelessWidget {
  const _EstadoTile({
    required this.label,
    required this.count,
    required this.color,
  });

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: theme.textTheme.bodyLarge)),
          Text('$count', style: theme.textTheme.titleMedium),
        ],
      ),
    );
  }
}

String _formatoCLP(double monto) {
  final n = monto.toInt().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < n.length; i++) {
    if (i > 0 && (n.length - i) % 3 == 0) buffer.write('.');
    buffer.write(n[i]);
  }
  return '\$${buffer.toString()}';
}
