import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:baqueano_natales/features/rentacar/data/rentacar_providers.dart';
import 'package:baqueano_natales/features/rentacar/domain/reserva.dart';

class ReservaDetalleScreen extends ConsumerWidget {
  const ReservaDetalleScreen({super.key, required this.reservaId});

  final String reservaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncReserva = ref.watch(reservaRentacarProvider(reservaId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle de reserva'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(reservaRentacarProvider(reservaId));
            },
          ),
        ],
      ),
      body: asyncReserva.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('Error al cargar la reserva'),
          ),
        ),
        data: (reserva) => _ReservaBody(
          reserva: reserva,
          onRefresh: () => ref.invalidate(reservaRentacarProvider(reservaId)),
        ),
      ),
    );
  }
}

class _ReservaBody extends ConsumerStatefulWidget {
  const _ReservaBody({required this.reserva, required this.onRefresh});

  final Reserva reserva;
  final VoidCallback onRefresh;

  @override
  ConsumerState<_ReservaBody> createState() => _ReservaBodyState();
}

class _ReservaBodyState extends ConsumerState<_ReservaBody> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final r = widget.reserva;
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildVehiculo(r, theme),
        const SizedBox(height: 16),
        _buildEstado(r, theme),
        const SizedBox(height: 16),
        _buildCliente(r, theme),
        const SizedBox(height: 16),
        _buildFechas(r, theme),
        const SizedBox(height: 24),
        _buildAcciones(r, theme),
      ],
    );
  }

  Widget _buildVehiculo(Reserva r, ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            if (r.vehiculoImagenUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  r.vehiculoImagenUrl!,
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => _iconoVacio(theme),
                ),
              )
            else
              _iconoVacio(theme),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r.vehiculoDescripcion,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (r.vehiculoPatente != null)
                    Text(
                      'Patente: ${r.vehiculoPatente}',
                      style: theme.textTheme.bodyMedium,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconoVacio(ThemeData theme) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.directions_car, size: 40),
    );
  }

  Widget _buildEstado(Reserva r, ThemeData theme) {
    final (color, label) = switch (r.estado) {
      'pendiente' => (Colors.orange, 'Pendiente'),
      'confirmada' => (Colors.blue, 'Confirmada'),
      'en_curso' => (Colors.purple, 'En curso'),
      'completada' => (Colors.green, 'Completada'),
      'cancelada' => (Colors.red, 'Cancelada'),
      _ => (Colors.grey, r.estado),
    };
    return Card(
      color: color.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.circle, size: 12, color: color),
            const SizedBox(width: 12),
            Text(
              'Estado: $label',
              style: theme.textTheme.titleMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCliente(Reserva r, ThemeData theme) {
    return Card(
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
            _fila(theme, 'Nombre', r.nombreCliente ?? '-'),
            _fila(theme, 'Email', r.emailCliente ?? '-'),
            _fila(theme, 'Telefono', r.telefonoCliente ?? '-'),
            _fila(theme, 'Metodo pago', r.metodoPago),
          ],
        ),
      ),
    );
  }

  Widget _buildFechas(Reserva r, ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Fechas y precio',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            _fila(theme, 'Inicio', _formatFecha(r.fechaInicio)),
            _fila(theme, 'Fin', _formatFecha(r.fechaFin)),
            _fila(theme, 'Dias', '${r.diasTotales}'),
            _fila(theme, 'Total', '\$${r.precioTotal.toStringAsFixed(0)}'),
            if (r.estado == 'pendiente' || r.estado == 'confirmada') ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _loading ? null : () => _abrirEditarFechas(r),
                icon: const Icon(Icons.edit_calendar),
                label: const Text('Editar fechas y precio'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAcciones(Reserva r, ThemeData theme) {
    final transiciones = r.transicionesValidas;
    if (transiciones.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Acciones disponibles',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        ...transiciones.map((estado) {
          final (label, color, icon) = _estiloAccion(estado);
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: FilledButton.icon(
              onPressed: _loading ? null : () => _cambiarEstado(estado),
              icon: Icon(icon),
              label: Text(label),
              style: FilledButton.styleFrom(backgroundColor: color),
            ),
          );
        }),
      ],
    );
  }

  (String, Color, IconData) _estiloAccion(String estado) {
    return switch (estado) {
      'confirmada' => ('Confirmar reserva', Colors.blue, Icons.check),
      'en_curso' => ('Iniciar alquiler', Colors.purple, Icons.play_arrow),
      'completada' => ('Marcar como completada', Colors.green, Icons.done_all),
      'cancelada' => ('Cancelar reserva', Colors.red, Icons.cancel),
      _ => (estado, Colors.grey, Icons.help_outline),
    };
  }

  Widget _fila(ThemeData theme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatFecha(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  Future<void> _abrirEditarFechas(Reserva r) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: _EditarFechasBottomSheet(reserva: r),
      ),
    );
    if (ok == true && mounted) {
      widget.onRefresh();
      ref.invalidate(reservaRentacarProvider(widget.reserva.id));
      ref.invalidate(misReservasRentacarProvider);
    }
  }

  Future<void> _cambiarEstado(String nuevoEstado) async {
    setState(() => _loading = true);
    try {
      final repo = ref.read(rentacarRepositoryProvider);
      await repo.cambiarEstadoReserva(widget.reserva.id, nuevoEstado);
      widget.onRefresh();
      // Invalidar TODAS las variantes del provider de lista (family)
      ref.invalidate(misReservasRentacarProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Estado actualizado'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

class _EditarFechasBottomSheet extends ConsumerStatefulWidget {
  const _EditarFechasBottomSheet({required this.reserva});
  final Reserva reserva;

  @override
  ConsumerState<_EditarFechasBottomSheet> createState() =>
      _EditarFechasBottomSheetState();
}

class _EditarFechasBottomSheetState
    extends ConsumerState<_EditarFechasBottomSheet> {
  late DateTime _inicio;
  late DateTime _fin;
  late TextEditingController _precioCtrl;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _inicio = widget.reserva.fechaInicio;
    _fin = widget.reserva.fechaFin;
    _precioCtrl = TextEditingController(
      text: widget.reserva.precioTotal.toStringAsFixed(0),
    );
  }

  @override
  void dispose() {
    _precioCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFecha({required bool isInicio}) async {
    final ahora = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: isInicio ? _inicio : _fin,
      firstDate: DateTime(ahora.year - 1),
      lastDate: ahora.add(const Duration(days: 730)),
    );
    if (picked == null) return;
    setState(() {
      if (isInicio) {
        _inicio = DateTime(picked.year, picked.month, picked.day);
        if (!_fin.isAfter(_inicio)) {
          _fin = _inicio.add(const Duration(days: 1));
        }
      } else {
        _fin = DateTime(picked.year, picked.month, picked.day);
      }
    });
  }

  Future<void> _guardar() async {
    if (!_fin.isAfter(_inicio)) {
      _snack('Fecha fin debe ser posterior a inicio', Colors.orange);
      return;
    }
    final precio = double.tryParse(_precioCtrl.text.trim());
    if (precio == null || precio <= 0) {
      _snack('Precio invalido', Colors.orange);
      return;
    }
    setState(() => _guardando = true);
    try {
      await ref.read(rentacarRepositoryProvider).modificarReservaPropietario(
        widget.reserva.id,
        {
          'fecha_inicio': _inicio.toIso8601String(),
          'fecha_fin': _fin.toIso8601String(),
          'precio_total': precio,
        },
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      _snack('Error: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, "0")}/${d.month.toString().padLeft(2, "0")}/${d.year}';

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Editar fechas y precio',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('Fecha inicio'),
              subtitle: Text(_fmt(_inicio)),
              onTap: () => _pickFecha(isInicio: true),
            ),
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('Fecha fin'),
              subtitle: Text(_fmt(_fin)),
              onTap: () => _pickFecha(isInicio: false),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _precioCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Precio total (CLP)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.attach_money),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _guardando ? null : _guardar,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _guardando
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Guardar cambios'),
            ),
          ],
        ),
      ),
    );
  }
}
