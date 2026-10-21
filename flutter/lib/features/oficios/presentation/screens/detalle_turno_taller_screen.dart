/// Pantalla prestador: detalle del turno con acciones (confirmar, rechazar, etc).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:baqueano_natales/core/network/api_exceptions.dart';
import 'package:baqueano_natales/features/oficios/data/oficios_providers.dart';
import 'package:baqueano_natales/features/oficios/domain/turno.dart';

class DetalleTurnoTallerScreen extends ConsumerStatefulWidget {
  const DetalleTurnoTallerScreen({
    super.key,
    required this.prestadorId,
    required this.turnoId,
  });

  final String prestadorId;
  final String turnoId;

  @override
  ConsumerState<DetalleTurnoTallerScreen> createState() =>
      _DetalleTurnoTallerScreenState();
}

class _DetalleTurnoTallerScreenState
    extends ConsumerState<DetalleTurnoTallerScreen> {
  bool _procesando = false;

  @override
  Widget build(BuildContext context) {
    final params = TurnoPrestadorDetalleParams(
      prestadorId: widget.prestadorId,
      turnoId: widget.turnoId,
    );
    final async = ref.watch(turnoPrestadorDetalleProvider(params));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Turno'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                ref.invalidate(turnoPrestadorDetalleProvider(params)),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text('$e', textAlign: TextAlign.center),
          ),
        ),
        data: (turno) => _Contenido(
          turno: turno,
          procesando: _procesando,
          onCambiarEstado: (estado) => _cambiarEstado(turno, estado),
          onRechazar: () => _rechazar(turno),
        ),
      ),
    );
  }

  Future<void> _cambiarEstado(Turno turno, EstadoTurno nuevo) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Marcar como ${nuevo.label}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _procesando = true);
    try {
      final repo = ref.read(oficiosRepositoryProvider);
      await repo.cambiarEstadoTurno(widget.prestadorId, turno.id, nuevo.value);
      _invalidar();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Turno ${nuevo.label.toLowerCase()}')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: ${e.message}')));
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  Future<void> _rechazar(Turno turno) async {
    final motivoCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rechazar turno?'),
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
            child: const Text('Rechazar'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _procesando = true);
    try {
      final repo = ref.read(oficiosRepositoryProvider);
      await repo.rechazarTurno(
        widget.prestadorId,
        turno.id,
        motivo: motivoCtrl.text.trim().isEmpty ? null : motivoCtrl.text.trim(),
      );
      _invalidar();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Turno rechazado')));
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: ${e.message}')));
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  void _invalidar() {
    ref.invalidate(
      turnoPrestadorDetalleProvider(
        TurnoPrestadorDetalleParams(
          prestadorId: widget.prestadorId,
          turnoId: widget.turnoId,
        ),
      ),
    );
    ref.invalidate(
      turnosPrestadorProvider(
        TurnosPrestadorParams(prestadorId: widget.prestadorId),
      ),
    );
  }
}

class _Contenido extends StatelessWidget {
  const _Contenido({
    required this.turno,
    required this.procesando,
    required this.onCambiarEstado,
    required this.onRechazar,
  });

  final Turno turno;
  final bool procesando;
  final void Function(EstadoTurno) onCambiarEstado;
  final VoidCallback onRechazar;

  List<Widget> _acciones() {
    switch (turno.estado) {
      case EstadoTurno.pendiente:
        return [
          FilledButton.icon(
            onPressed: procesando
                ? null
                : () => onCambiarEstado(EstadoTurno.confirmado),
            icon: const Icon(Icons.check),
            label: const Text('Confirmar'),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: procesando ? null : onRechazar,
            icon: const Icon(Icons.close),
            label: const Text('Rechazar'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red.shade700,
            ),
          ),
        ];
      case EstadoTurno.confirmado:
        return [
          FilledButton.tonal(
            onPressed: procesando
                ? null
                : () => onCambiarEstado(EstadoTurno.enCurso),
            child: const Text('Marcar en curso'),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: procesando
                ? null
                : () => onCambiarEstado(EstadoTurno.noAsistio),
            child: const Text('No asistio'),
          ),
        ];
      case EstadoTurno.enCurso:
        return [
          FilledButton.icon(
            onPressed: procesando
                ? null
                : () => onCambiarEstado(EstadoTurno.completado),
            icon: const Icon(Icons.done_all),
            label: const Text('Completar'),
          ),
        ];
      default:
        return const [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _hexToColor(turno.estado.colorHex);
    final acciones = _acciones();

    return Stack(
      children: [
        ListView(
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
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
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
                            turno.estado.label,
                            style: theme.textTheme.labelMedium?.copyWith(
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
                        label: 'Notas del cliente',
                        value: turno.notasCliente!,
                      ),
                    if (turno.notasPrestador != null)
                      _Fila(
                        icon: Icons.message_outlined,
                        label: 'Tus notas',
                        value: turno.notasPrestador!,
                      ),
                  ],
                ),
              ),
            ),
            if (turno.cliente != null) ...[
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cliente',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _Fila(
                        icon: Icons.person,
                        label: 'Nombre',
                        value: turno.cliente!.nombreCompleto,
                      ),
                      _Fila(
                        icon: Icons.email,
                        label: 'Email',
                        value: turno.cliente!.email,
                      ),
                      if (turno.cliente!.phone != null)
                        _Fila(
                          icon: Icons.phone,
                          label: 'Telefono',
                          value: turno.cliente!.phone!,
                        ),
                    ],
                  ),
                ),
              ),
            ],
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
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
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
            if (acciones.isNotEmpty) ...[
              const SizedBox(height: 16),
              Wrap(spacing: 8, runSpacing: 8, children: acciones),
            ],
            const SizedBox(height: 32),
          ],
        ),
        if (procesando)
          const Positioned.fill(
            child: ColoredBox(
              color: Colors.black26,
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
      ],
    );
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
