/// Pantalla prestador: detalle de una orden con editor de items y estados.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:baqueano_natales/core/network/api_exceptions.dart';
import 'package:baqueano_natales/features/oficios/data/oficios_providers.dart';
import 'package:baqueano_natales/features/oficios/domain/garantia.dart';
import 'package:baqueano_natales/features/oficios/domain/orden_historial.dart';
import 'package:baqueano_natales/features/oficios/domain/orden_item.dart';
import 'package:baqueano_natales/features/oficios/domain/orden_trabajo.dart';
import 'package:baqueano_natales/features/oficios/presentation/widgets/garantia_card.dart';

class DetalleOrdenTallerScreen extends ConsumerStatefulWidget {
  const DetalleOrdenTallerScreen({
    super.key,
    required this.prestadorId,
    required this.ordenId,
  });

  final String prestadorId;
  final String ordenId;

  @override
  ConsumerState<DetalleOrdenTallerScreen> createState() =>
      _DetalleOrdenTallerScreenState();
}

class _DetalleOrdenTallerScreenState
    extends ConsumerState<DetalleOrdenTallerScreen> {
  bool _procesando = false;

  @override
  Widget build(BuildContext context) {
    final params = OrdenPrestadorDetalleParams(
      prestadorId: widget.prestadorId,
      ordenId: widget.ordenId,
    );
    final async = ref.watch(ordenPrestadorDetalleProvider(params));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Orden'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                ref.invalidate(ordenPrestadorDetalleProvider(params)),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorView(
          error: e,
          onRetry: () =>
              ref.invalidate(ordenPrestadorDetalleProvider(params)),
        ),
        data: (orden) => _Contenido(
          orden: orden,
          prestadorId: widget.prestadorId,
          procesando: _procesando,
          onAgregarItem: () => _agregarItem(orden),
          onEliminarItem: (itemId) => _eliminarItem(orden, itemId),
          onCambiarEstado: (estado) => _cambiarEstado(orden, estado),
          onAbrirModalGarantia: _abrirModalGarantia,
        ),
      ),
    );
  }

  Future<void> _agregarItem(OrdenTrabajo orden) async {
    final result = await showModalBottomSheet<OrdenItem>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _ModalItemForm(),
    );
    if (result == null) return;

    setState(() => _procesando = true);
    try {
      final repo = ref.read(oficiosRepositoryProvider);
      await repo.agregarItem(widget.prestadorId, orden.id, result);
      ref.invalidate(ordenPrestadorDetalleProvider(
        OrdenPrestadorDetalleParams(
          prestadorId: widget.prestadorId,
          ordenId: orden.id,
        ),
      ));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Item agregado')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.message}')),
      );
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  Future<void> _eliminarItem(OrdenTrabajo orden, String itemId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar item'),
        content: const Text('Seguro que queres eliminar este item?'),
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

    setState(() => _procesando = true);
    try {
      final repo = ref.read(oficiosRepositoryProvider);
      await repo.eliminarItem(widget.prestadorId, orden.id, itemId);
      ref.invalidate(ordenPrestadorDetalleProvider(
        OrdenPrestadorDetalleParams(
          prestadorId: widget.prestadorId,
          ordenId: orden.id,
        ),
      ));
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.message}')),
      );
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  Future<void> _abrirModalGarantia(OrdenTrabajo orden) async {
    // Obtener garantia existente si hay
    Garantia? existente;
    try {
      final repo = ref.read(oficiosRepositoryProvider);
      existente = await repo.obtenerGarantiaDeOrdenPrestador(
        widget.prestadorId,
        orden.id,
      );
    } catch (_) {
      existente = null;
    }
    if (!mounted) return;

    final result = await showModalBottomSheet<_GarantiaFormResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ModalGarantiaForm(existente: existente),
    );
    if (result == null) return;

    setState(() => _procesando = true);
    try {
      final repo = ref.read(oficiosRepositoryProvider);
      await repo.crearGarantiaDeOrden(
        widget.prestadorId,
        orden.id,
        tipo: result.tipo.value,
        duracionDias: result.duracionDias,
        cobertura: result.cobertura,
        condiciones: result.condiciones,
      );
      ref.invalidate(garantiaPrestadorProvider(
        GarantiaPrestadorParams(
          prestadorId: widget.prestadorId,
          ordenId: orden.id,
        ),
      ));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Garantia guardada')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.message}')),
      );
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  Future<void> _cambiarEstado(OrdenTrabajo orden, EstadoOrden nuevo) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Cambiar a ${nuevo.label}?'),
        content: Text('La orden pasara al estado "${nuevo.label}".'),
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
      await repo.cambiarEstado(
        widget.prestadorId,
        orden.id,
        nuevo.value,
      );
      ref.invalidate(ordenPrestadorDetalleProvider(
        OrdenPrestadorDetalleParams(
          prestadorId: widget.prestadorId,
          ordenId: orden.id,
        ),
      ));
      ref.invalidate(ordenesPrestadorProvider(
        OrdenesPrestadorParams(prestadorId: widget.prestadorId),
      ));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Estado actualizado a ${nuevo.label}')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.message}')),
      );
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }
}

class _Contenido extends StatelessWidget {
  const _Contenido({
    required this.orden,
    required this.prestadorId,
    required this.procesando,
    required this.onAgregarItem,
    required this.onEliminarItem,
    required this.onCambiarEstado,
    required this.onAbrirModalGarantia,
  });

  final OrdenTrabajo orden;
  final String prestadorId;
  final bool procesando;
  final VoidCallback onAgregarItem;
  final void Function(String itemId) onEliminarItem;
  final void Function(EstadoOrden nuevo) onCambiarEstado;
  final void Function(OrdenTrabajo orden) onAbrirModalGarantia;

  bool get _puedeEditarItems =>
      orden.estado == EstadoOrden.ingresado ||
      orden.estado == EstadoOrden.diagnosticando;

  List<EstadoOrden> get _transicionesDisponibles {
    switch (orden.estado) {
      case EstadoOrden.ingresado:
        return [EstadoOrden.diagnosticando, EstadoOrden.cancelado];
      case EstadoOrden.diagnosticando:
        return [EstadoOrden.presupuestado, EstadoOrden.cancelado];
      case EstadoOrden.aprobado:
        return [EstadoOrden.enProceso, EstadoOrden.cancelado];
      case EstadoOrden.enProceso:
        return [EstadoOrden.listo, EstadoOrden.cancelado];
      case EstadoOrden.listo:
        return [EstadoOrden.entregado];
      case EstadoOrden.entregado:
        return [EstadoOrden.garantia];
      default:
        return const [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _hexToColor(orden.estado.colorHex);

    return Stack(
      children: [
        ListView(
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
                      'Ingresada ${_formatFechaHora(orden.fechaIngreso)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (orden.diagnosticoInicial != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Diagnostico:',
                        style: theme.textTheme.labelMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(orden.diagnosticoInicial!),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Items
            Row(
              children: [
                Text(
                  'Presupuesto',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (_puedeEditarItems)
                  TextButton.icon(
                    onPressed: procesando ? null : onAgregarItem,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Agregar'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (!orden.tieneItems)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'Sin items todavia.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              ...orden.items.map((it) => _ItemRow(
                    item: it,
                    puedeEditar: _puedeEditarItems,
                    procesando: procesando,
                    onEliminar: () => onEliminarItem(it.id),
                  )),

            if (orden.tieneItems) ...[
              const SizedBox(height: 12),
              _TotalesCard(orden: orden),
            ],

            const SizedBox(height: 16),

            // Acciones de estado
            if (_transicionesDisponibles.isNotEmpty) ...[
              Text(
                'Acciones',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _transicionesDisponibles
                    .map((e) => FilledButton.tonal(
                          onPressed: procesando
                              ? null
                              : () => onCambiarEstado(e),
                          child: Text('Pasar a ${e.label}'),
                        ))
                    .toList(),
              ),
            ],

            const SizedBox(height: 24),

            // Garantia (si la orden esta entregada)
            if (orden.estado == EstadoOrden.entregado) ...[
              const SizedBox(height: 16),
              _GarantiaPrestadorWrapper(
                prestadorId: prestadorId,
                ordenId: orden.id,
                onCrearEditar: () => onAbrirModalGarantia(orden),
              ),
            ],

            // Timeline
            if (orden.historial.isNotEmpty) ...[
              Text(
                'Historial',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ...orden.historial.map((ev) => _TimelineRow(evento: ev)),
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

class _ItemRow extends StatelessWidget {
  const _ItemRow({
    required this.item,
    required this.puedeEditar,
    required this.procesando,
    required this.onEliminar,
  });

  final OrdenItem item;
  final bool puedeEditar;
  final bool procesando;
  final VoidCallback onEliminar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.descripcion,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${item.tipo.label} - ${item.cantidad.toStringAsFixed(0)} x ${_formatCLP(item.precioUnitario)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (item.aprobado != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      item.aprobado == true
                          ? 'Aprobado por el cliente'
                          : 'Rechazado por el cliente',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: item.aprobado == true
                            ? Colors.green.shade700
                            : Colors.red.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _formatCLP(item.subtotal),
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            if (puedeEditar)
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                onPressed: procesando ? null : onEliminar,
              ),
          ],
        ),
      ),
    );
  }
}

class _TotalesCard extends StatelessWidget {
  const _TotalesCard({required this.orden});
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
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
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
                Text(evento.descripcion),
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

// =========================================================
// Modal para agregar item
// =========================================================
class _ModalItemForm extends StatefulWidget {
  const _ModalItemForm();

  @override
  State<_ModalItemForm> createState() => _ModalItemFormState();
}

class _ModalItemFormState extends State<_ModalItemForm> {
  final _formKey = GlobalKey<FormState>();
  final _descCtrl = TextEditingController();
  final _cantCtrl = TextEditingController(text: '1');
  final _precioCtrl = TextEditingController(text: '0');
  TipoItemOrden _tipo = TipoItemOrden.servicio;

  @override
  void dispose() {
    _descCtrl.dispose();
    _cantCtrl.dispose();
    _precioCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.of(context).viewInsets;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + insets.bottom),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Nuevo item',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<TipoItemOrden>(
              initialValue: _tipo,
              decoration: const InputDecoration(
                labelText: 'Tipo',
                border: OutlineInputBorder(),
              ),
              items: TipoItemOrden.values
                  .map((t) => DropdownMenuItem(
                        value: t,
                        child: Text(t.label),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _tipo = v);
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descCtrl,
              decoration: const InputDecoration(
                labelText: 'Descripcion',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Requerido' : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _cantCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Cantidad',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      final n = double.tryParse(v?.trim() ?? '');
                      if (n == null || n <= 0) return 'Invalido';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _precioCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Precio unitario (CLP)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      final n = double.tryParse(v?.trim() ?? '');
                      if (n == null || n < 0) return 'Invalido';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _guardar,
              child: const Text('Agregar'),
            ),
          ],
        ),
      ),
    );
  }

  void _guardar() {
    if (!_formKey.currentState!.validate()) return;
    final item = OrdenItem(
      id: '',
      tipo: _tipo,
      descripcion: _descCtrl.text.trim(),
      cantidad: double.parse(_cantCtrl.text.trim()),
      precioUnitario: double.parse(_precioCtrl.text.trim()),
      subtotal: 0,
      ordenDisplay: 0,
    );
    Navigator.of(context).pop(item);
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

String _formatFechaHora(DateTime d) =>
    '${d.day}/${d.month}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

// =========================================================
// Garantia (prestador)
// =========================================================
class _GarantiaPrestadorWrapper extends ConsumerWidget {
  const _GarantiaPrestadorWrapper({
    required this.prestadorId,
    required this.ordenId,
    required this.onCrearEditar,
  });

  final String prestadorId;
  final String ordenId;
  final VoidCallback onCrearEditar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final params = GarantiaPrestadorParams(
      prestadorId: prestadorId,
      ordenId: ordenId,
    );
    final async = ref.watch(garantiaPrestadorProvider(params));
    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => const SizedBox.shrink(),
      data: (g) {
        if (g == null) {
          return GarantiaCard(
            garantia: null,
            onCrear: onCrearEditar,
          );
        }
        return GarantiaCard(
          garantia: g,
          onEditar: onCrearEditar,
        );
      },
    );
  }
}


// =========================================================
// Modal para crear/editar garantia
// =========================================================
class _ModalGarantiaForm extends StatefulWidget {
  const _ModalGarantiaForm({this.existente});
  final Garantia? existente;

  @override
  State<_ModalGarantiaForm> createState() => _ModalGarantiaFormState();
}

class _ModalGarantiaFormState extends State<_ModalGarantiaForm> {
  final _formKey = GlobalKey<FormState>();
  final _diasCtrl = TextEditingController();
  final _coberturaCtrl = TextEditingController();
  final _condicionesCtrl = TextEditingController();
  TipoGarantia _tipo = TipoGarantia.completo;

  @override
  void initState() {
    super.initState();
    if (widget.existente != null) {
      _diasCtrl.text = widget.existente!.duracionDias.toString();
      _coberturaCtrl.text = widget.existente!.cobertura ?? '';
      _condicionesCtrl.text = widget.existente!.condiciones ?? '';
      _tipo = widget.existente!.tipo;
    } else {
      _diasCtrl.text = '30';
    }
  }

  @override
  void dispose() {
    _diasCtrl.dispose();
    _coberturaCtrl.dispose();
    _condicionesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.of(context).viewInsets;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + insets.bottom),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.existente == null ? 'Crear garantia' : 'Editar garantia',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<TipoGarantia>(
              initialValue: _tipo,
              decoration: const InputDecoration(
                labelText: 'Tipo',
                border: OutlineInputBorder(),
              ),
              items: TipoGarantia.values
                  .map((t) => DropdownMenuItem(
                        value: t,
                        child: Text(t.label),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _tipo = v);
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _diasCtrl,
              decoration: const InputDecoration(
                labelText: 'Duracion (dias)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              validator: (v) {
                final n = int.tryParse(v?.trim() ?? '');
                if (n == null || n < 1) return 'Invalido';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _coberturaCtrl,
              decoration: const InputDecoration(
                labelText: 'Cobertura (opcional)',
                hintText: 'Que cubre la garantia',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _condicionesCtrl,
              decoration: const InputDecoration(
                labelText: 'Condiciones (opcional)',
                hintText: 'Que NO cubre',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _guardar,
              child: Text(widget.existente == null ? 'Crear' : 'Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  void _guardar() {
    if (!_formKey.currentState!.validate()) return;
    final result = _GarantiaFormResult(
      tipo: _tipo,
      duracionDias: int.parse(_diasCtrl.text.trim()),
      cobertura: _coberturaCtrl.text.trim().isEmpty
          ? null
          : _coberturaCtrl.text.trim(),
      condiciones: _condicionesCtrl.text.trim().isEmpty
          ? null
          : _condicionesCtrl.text.trim(),
    );
    Navigator.of(context).pop(result);
  }
}

class _GarantiaFormResult {
  const _GarantiaFormResult({
    required this.tipo,
    required this.duracionDias,
    this.cobertura,
    this.condiciones,
  });
  final TipoGarantia tipo;
  final int duracionDias;
  final String? cobertura;
  final String? condiciones;
}