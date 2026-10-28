import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:baqueano_natales/features/rentacar/data/rentacar_providers.dart';
import 'package:baqueano_natales/features/rentacar/domain/reserva.dart';

class MisReservasRentacarScreen extends ConsumerStatefulWidget {
  const MisReservasRentacarScreen({super.key});

  @override
  ConsumerState<MisReservasRentacarScreen> createState() =>
      _MisReservasRentacarScreenState();
}

class _MisReservasRentacarScreenState
    extends ConsumerState<MisReservasRentacarScreen> {
  String? _estadoFiltro;

  static const _tabs = [
    (null, 'Todas'),
    ('pendiente', 'Pendientes'),
    ('confirmada', 'Confirmadas'),
    ('en_curso', 'En curso'),
    ('completada', 'Completadas'),
    ('cancelada', 'Canceladas'),
  ];

  @override
  Widget build(BuildContext context) {
    final asyncReservas = ref.watch(misReservasRentacarProvider(_estadoFiltro));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reservas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(misReservasRentacarProvider(_estadoFiltro));
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterChips(),
          Expanded(
            child: asyncReservas.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _buildError(e),
              data: (reservas) {
                if (reservas.isEmpty) return _buildEmpty();
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(misReservasRentacarProvider(_estadoFiltro));
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: reservas.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, i) => _ReservaCard(
                      reserva: reservas[i],
                      onRefresh: () {
                        ref.invalidate(
                          misReservasRentacarProvider(_estadoFiltro),
                        );
                      },
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

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: _tabs.map((tab) {
          final (value, label) = tab;
          final selected = _estadoFiltro == value;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(label),
              selected: selected,
              onSelected: (_) {
                setState(() => _estadoFiltro = value);
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildError(Object e) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 12),
            Text('Error: $e', textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () {
                ref.invalidate(misReservasRentacarProvider(_estadoFiltro));
              },
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.event_busy_outlined, size: 64),
            const SizedBox(height: 16),
            Text(
              'Sin reservas',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              _estadoFiltro != null
                  ? 'No hay reservas en estado "${_tabs.firstWhere((t) => t.$1 == _estadoFiltro).$2}".'
                  : 'Aun no tienes reservas.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ReservaCard extends StatelessWidget {
  const _ReservaCard({required this.reserva, required this.onRefresh});

  final Reserva reserva;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(
          '/mis-reservas-rentacar/${reserva.id}',
          extra: reserva,
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _buildImagen(theme),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            reserva.vehiculoDescripcion,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        _buildEstadoChip(theme),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (reserva.nombreCliente != null)
                      Text(
                        reserva.nombreCliente!,
                        style: theme.textTheme.bodySmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 4),
                    Text(
                      '${_formatFecha(reserva.fechaInicio)} al ${_formatFecha(reserva.fechaFin)}',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '\$${reserva.precioTotal.toStringAsFixed(0)} · ${reserva.diasTotales} dias',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }

  String _formatFecha(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  Widget _buildImagen(ThemeData theme) {
    if (reserva.vehiculoImagenUrl != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          reserva.vehiculoImagenUrl!,
          width: 64,
          height: 64,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _iconoFallback(theme),
        ),
      );
    }
    return _iconoFallback(theme);
  }

  Widget _iconoFallback(ThemeData theme) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.directions_car, size: 32),
    );
  }

  Widget _buildEstadoChip(ThemeData theme) {
    final (color, label) = switch (reserva.estado) {
      'pendiente' => (Colors.orange, 'Pendiente'),
      'confirmada' => (Colors.blue, 'Confirmada'),
      'en_curso' => (Colors.purple, 'En curso'),
      'completada' => (Colors.green, 'Completada'),
      'cancelada' => (Colors.red, 'Cancelada'),
      _ => (Colors.grey, reserva.estado),
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
