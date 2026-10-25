/// Pantalla cliente: detalle de un turno con opcion de cancelar.
library;

import 'package:flutter/material.dart';
import 'package:baqueano_natales/core/widgets/version_badge.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:baqueano_natales/core/network/api_exceptions.dart';
import 'package:baqueano_natales/features/oficios/data/oficios_providers.dart';
import 'package:baqueano_natales/features/oficios/domain/turno.dart';

class DetalleMiTurnoScreen extends ConsumerStatefulWidget {
  const DetalleMiTurnoScreen({super.key, required this.turnoId});

  final String turnoId;

  @override
  ConsumerState<DetalleMiTurnoScreen> createState() =>
      _DetalleMiTurnoScreenState();
}

class _DetalleMiTurnoScreenState extends ConsumerState<DetalleMiTurnoScreen> {
  bool _procesando = false;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(miTurnoDetalleProvider(widget.turnoId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle del turno'),
        actions: appBarActionsWithBadge(
          extra: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () =>
                  ref.invalidate(miTurnoDetalleProvider(widget.turnoId)),
            ),
          ],
        ),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text('$e', textAlign: TextAlign.center),
          ),
        ),
        data: (turno) {
          final color = _hexToColor(turno.estado.colorHex);
          final puedeCancelar =
              turno.estado == EstadoTurno.pendiente ||
              turno.estado == EstadoTurno.confirmado;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
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
                              _formatFechaHora(turno.fechaInicio),
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.bold),
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
                              turno.estado.label,
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(
                                    color: color,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _Fila(
                        icon: Icons.timer,
                        label: 'Duracion',
                        value: '${turno.duracionMin} minutos',
                      ),
                      if (turno.motivo != null)
                        _Fila(
                          icon: Icons.notes,
                          label: 'Motivo',
                          value: turno.motivo!,
                        ),
                      if (turno.notasCliente != null)
                        _Fila(
                          icon: Icons.sticky_note_2_outlined,
                          label: 'Tus notas',
                          value: turno.notasCliente!,
                        ),
                      if (turno.notasPrestador != null)
                        _Fila(
                          icon: Icons.message_outlined,
                          label: 'Notas del taller',
                          value: turno.notasPrestador!,
                        ),
                      if (turno.ordenId != null)
                        _Fila(
                          icon: Icons.receipt_long,
                          label: 'Orden vinculada',
                          value: turno.ordenId!,
                        ),
                    ],
                  ),
                ),
              ),
              if (turno.vehiculo != null) ...[
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Vehiculo',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        _Fila(
                          icon: Icons.directions_car,
                          label: 'Vehiculo',
                          value: turno.vehiculo!.descripcion,
                        ),
                        if (turno.vehiculo!.color != null)
                          _Fila(
                            icon: Icons.palette,
                            label: 'Color',
                            value: turno.vehiculo!.color!,
                          ),
                      ],
                    ),
                  ),
                ),
              ],
              if (turno.hasReview) ...[
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.check_circle,
                              color: Colors.green,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Ya calificaste este servicio',
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            for (var i = 0; i < 5; i++)
                              Icon(
                                i < (turno.reviewRating ?? 0)
                                    ? Icons.star
                                    : Icons.star_border,
                                color: Colors.amber[700],
                                size: 22,
                              ),
                          ],
                        ),
                        if (turno.reviewComentario != null &&
                            turno.reviewComentario!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            '"${turno.reviewComentario}"',
                            style: TextStyle(
                              fontSize: 13,
                              fontStyle: FontStyle.italic,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ] else if (turno.ordenId != null) ...[
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Calificar servicio',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Tu opinion ayuda a otros usuarios a elegir mejor.',
                          style: TextStyle(fontSize: 13),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: () => context.push(
                            '/mis-ordenes/${turno.ordenId}/review',
                          ),
                          icon: const Icon(Icons.star_outline),
                          label: const Text('Calificar servicio'),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(double.infinity, 44),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              if (puedeCancelar) ...[
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _procesando ? null : () => _cancelar(turno),
                  icon: _procesando
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.cancel_outlined),
                  label: const Text('Cancelar turno'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                    foregroundColor: Colors.red.shade700,
                  ),
                ),
              ],
              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }

  Future<void> _cancelar(Turno turno) async {
    final motivoCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar turno?'),
        content: TextField(
          controller: motivoCtrl,
          decoration: const InputDecoration(
            labelText: 'Motivo (opcional)',
            border: OutlineInputBorder(),
          ),
          maxLines: 2,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Cancelar turno'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _procesando = true);
    try {
      final repo = ref.read(oficiosRepositoryProvider);
      await repo.cancelarTurno(
        turno.id,
        motivo: motivoCtrl.text.trim().isEmpty ? null : motivoCtrl.text.trim(),
      );
      ref.invalidate(miTurnoDetalleProvider(turno.id));
      ref.invalidate(misTurnosProvider(null));
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Turno cancelado')));
      context.pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: ${e.message}')));
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }
}

class _Fila extends StatelessWidget {
  const _Fila({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.labelSmall),
                Text(value, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Color _hexToColor(String hex) {
  final h = hex.replaceFirst('#', '');
  return Color(int.parse('FF$h', radix: 16));
}

String _formatFechaHora(DateTime d) =>
    '${d.day}/${d.month}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
