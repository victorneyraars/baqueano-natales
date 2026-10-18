/// Pantalla de estadísticas (Web Analytics).
///
/// Muestra:
/// - Selector de sitio (todos / sealquilamarido / baqueano)
/// - Selector de período (7/14/30 días)
/// - Cards de resumen
/// - Gráfico de barras por día
/// - Top páginas, referrers, países
/// - Pull-to-refresh
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:baqueano_natales/core/network/api_exceptions.dart';
import 'package:baqueano_natales/features/analytics/data/analytics_providers.dart';
import 'package:baqueano_natales/features/analytics/domain/stats_response.dart';
import 'package:baqueano_natales/features/analytics/domain/top_item.dart';
import 'package:baqueano_natales/features/analytics/domain/visita_dia.dart';

class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen> {
  int _days = 7;
  String? _hostname;

  @override
  Widget build(BuildContext context) {
    final asyncStats = ref.watch(
      adminStatsProvider((days: _days, hostname: _hostname)),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Estadísticas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(
                adminStatsProvider((days: _days, hostname: _hostname)),
              );
            },
            tooltip: 'Refrescar',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(
            adminStatsProvider((days: _days, hostname: _hostname)),
          );
          await Future.delayed(const Duration(milliseconds: 300));
        },
        child: asyncStats.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) => _ErrorView(
            error: e,
            onRetry: () => ref.invalidate(
              adminStatsProvider((days: _days, hostname: _hostname)),
            ),
          ),
          data: (stats) => _StatsBody(
            stats: stats,
            days: _days,
            hostname: _hostname,
            onDaysChanged: (d) => setState(() => _days = d),
            onHostnameChanged: (h) => setState(() => _hostname = h),
          ),
        ),
      ),
    );
  }
}

class _StatsBody extends StatelessWidget {
  const _StatsBody({
    required this.stats,
    required this.days,
    required this.hostname,
    required this.onDaysChanged,
    required this.onHostnameChanged,
  });

  final StatsResponse stats;
  final int days;
  final String? hostname;
  final ValueChanged<int> onDaysChanged;
  final ValueChanged<String?> onHostnameChanged;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SiteSelector(selected: hostname, onChanged: onHostnameChanged),
        const SizedBox(height: 12),
        _PeriodSelector(days: days, onChanged: onDaysChanged),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _SummaryCard(
                icon: Icons.people_outline,
                label: 'Visitas',
                value: stats.totalVisits.toString(),
                color: Colors.blue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SummaryCard(
                icon: Icons.visibility_outlined,
                label: 'Vistas',
                value: stats.totalPageviews.toString(),
                color: Colors.green,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        if (stats.byDay.isNotEmpty) ...[
          Text(
            'Visitas por día',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          _BarChart(byDay: stats.byDay),
          const SizedBox(height: 24),
        ],
        if (stats.topPages.isNotEmpty)
          _TopSection(
            title: 'Páginas más visitadas',
            icon: Icons.description_outlined,
            items: stats.topPages,
          ),
        if (stats.topReferrers.isNotEmpty)
          _TopSection(
            title: 'Fuentes de tráfico',
            icon: Icons.link,
            items: stats.topReferrers,
          ),
        if (stats.topCountries.isNotEmpty)
          _TopSection(
            title: 'Países',
            icon: Icons.public,
            items: stats.topCountries,
          ),
        const SizedBox(height: 40),
      ],
    );
  }
}

class _SiteSelector extends StatelessWidget {
  const _SiteSelector({required this.selected, required this.onChanged});

  final String? selected;
  final ValueChanged<String?> onChanged;

  static const _sites = <(String?, String)>[
    (null, 'Todos'),
    ('sealquilamarido.com', 'Se Alquila Marido'),
    ('www.baqueanonatales.com', 'Baqueano'),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _sites.map((site) {
        final (hostname, label) = site;
        final isSelected = selected == hostname;
        return ChoiceChip(
          label: Text(label),
          selected: isSelected,
          onSelected: (_) => onChanged(hostname),
        );
      }).toList(),
    );
  }
}

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({required this.days, required this.onChanged});

  final int days;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: [7, 14, 30].map((d) {
        final selected = d == days;
        return ChoiceChip(
          label: Text('$d días'),
          selected: selected,
          onSelected: (_) => onChanged(d),
        );
      }).toList(),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Text(label, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BarChart extends StatelessWidget {
  const _BarChart({required this.byDay});

  final List<VisitaDia> byDay;

  @override
  Widget build(BuildContext context) {
    final maxVisits = byDay.map((d) => d.visits).fold<int>(1, (a, b) => a > b ? a : b);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: 180,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: byDay.map((d) {
              final ratio = d.visits / maxVisits;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        d.visits.toString(),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 4),
                      Container(
                        height: 120 * ratio,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _dayLabel(d.date),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  String _dayLabel(DateTime date) {
    const days = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
    return days[date.weekday - 1];
  }
}

class _TopSection extends StatelessWidget {
  const _TopSection({
    required this.title,
    required this.icon,
    required this.items,
  });

  final String title;
  final IconData icon;
  final List<TopItem> items;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: items.map((item) {
                return ListTile(
                  dense: true,
                  title: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: Text(
                    item.count.toString(),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                );
              }).toList(),
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
    final message = error is ApiException
        ? (error as ApiException).message
        : 'Error cargando estadísticas';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
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
