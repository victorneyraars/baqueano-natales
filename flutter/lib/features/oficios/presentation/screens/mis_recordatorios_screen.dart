/// Pantalla cliente: gestion de recordatorios de un vehiculo.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:baqueano_natales/core/network/api_exceptions.dart';
import 'package:baqueano_natales/features/oficios/data/oficios_providers.dart';
import 'package:baqueano_natales/features/oficios/domain/recordatorio.dart';

class MisRecordatoriosScreen extends ConsumerStatefulWidget {
  const MisRecordatoriosScreen({
    super.key,
    required this.objetoId,
    this.vehiculoNombre,
  });

  final String objetoId;
  final String? vehiculoNombre;

  @override
  ConsumerState<MisRecordatoriosScreen> createState() =>
      _MisRecordatoriosScreenState();
}

class _MisRecordatoriosScreenState
    extends ConsumerState<MisRecordatoriosScreen> {
  bool _incluirEnviados = false;
  bool _procesando = false;

  @override
  Widget build(BuildContext context) {
    final params = RecordatoriosParams(
      objetoId: widget.objetoId,
      incluirEnviados: _incluirEnviados,
    );
    final async = ref.watch(recordatoriosProvider(params));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recordatorios'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(recordatoriosProvider(params)),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _procesando ? null : _nuevoRecordatorio,
        icon: const Icon(Icons.add),
        label: const Text('Nuevo'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('Mostrar enviados'),
                  selected: _incluirEnviados,
                  onSelected: (v) =>
                      setState(() => _incluirEnviados = v),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _ErrorView(
                error: e,
                onRetry: () => ref.invalidate(recordatoriosProvider(params)),
              ),
              data: (recs) {
                if (recs.isEmpty) return const _EmptyView();
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: recs.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _RecordatorioCard(
                    recordatorio: recs[i],
                    onEliminar: _procesando
                        ? null
                        : () => _confirmarEliminar(recs[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _nuevoRecordatorio() async {
    final result = await showModalBottomSheet<Recordatorio>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ModalRecordatorioForm(objetoId: widget.objetoId),
    );
    if (result == null) return;

    setState(() => _procesando = true);
    try {
      final repo = ref.read(oficiosRepositoryProvider);
      await repo.crearRecordatorio(result);
      ref.invalidate(recordatoriosProvider(
        RecordatoriosParams(
          objetoId: widget.objetoId,
          incluirEnviados: _incluirEnviados,
        ),
      ));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recordatorio creado')),
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

  Future<void> _confirmarEliminar(Recordatorio r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar recordatorio'),
        content: Text('Seguro que queres eliminar "${r.mensaje}"?'),
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
      await repo.eliminarRecordatorio(widget.objetoId, r.id);
      ref.invalidate(recordatoriosProvider(
        RecordatoriosParams(
          objetoId: widget.objetoId,
          incluirEnviados: _incluirEnviados,
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
}

class _RecordatorioCard extends StatelessWidget {
  const _RecordatorioCard({
    required this.recordatorio,
    required this.onEliminar,
  });

  final Recordatorio recordatorio;
  final VoidCallback? onEliminar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = recordatorio;
    final icono = switch (r.tipo) {
      TipoRecordatorio.km => Icons.speed,
      TipoRecordatorio.fecha => Icons.calendar_today,
      TipoRecordatorio.evento => Icons.event_note,
    };
    final color = r.enviado
        ? Colors.grey
        : theme.colorScheme.primary;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icono, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r.mensaje,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${r.tipo.label} - ${r.condicionDisplay}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (r.enviado && r.fechaEnvio != null)
                    Text(
                      'Enviado ${_formatFecha(r.fechaEnvio!)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                ],
              ),
            ),
            if (!r.enviado && onEliminar != null)
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: onEliminar,
              ),
          ],
        ),
      ),
    );
  }
}

class _ModalRecordatorioForm extends StatefulWidget {
  const _ModalRecordatorioForm({required this.objetoId});
  final String objetoId;

  @override
  State<_ModalRecordatorioForm> createState() => _ModalRecordatorioFormState();
}

class _ModalRecordatorioFormState extends State<_ModalRecordatorioForm> {
  final _formKey = GlobalKey<FormState>();
  final _mensajeCtrl = TextEditingController();
  final _kmCtrl = TextEditingController();
  final _descripcionCtrl = TextEditingController();

  TipoRecordatorio _tipo = TipoRecordatorio.km;
  DateTime? _fecha;

  @override
  void dispose() {
    _mensajeCtrl.dispose();
    _kmCtrl.dispose();
    _descripcionCtrl.dispose();
    super.dispose();
  }

  Future<void> _elegirFecha() async {
    final ahora = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: ahora.add(const Duration(days: 90)),
      firstDate: ahora,
      lastDate: ahora.add(const Duration(days: 3650)),
    );
    if (d != null) setState(() => _fecha = d);
  }

  void _guardar() {
    if (!_formKey.currentState!.validate()) return;

    Map<String, dynamic> condicion;
    switch (_tipo) {
      case TipoRecordatorio.km:
        condicion = {'km_umbral': int.parse(_kmCtrl.text.trim())};
      case TipoRecordatorio.fecha:
        if (_fecha == null) return;
        condicion = {'fecha': _fecha!.toIso8601String().split('T').first};
      case TipoRecordatorio.evento:
        condicion = {'descripcion': _descripcionCtrl.text.trim()};
    }

    final rec = Recordatorio(
      id: '',
      objetoId: widget.objetoId,
      tipo: _tipo,
      condicion: condicion,
      mensaje: _mensajeCtrl.text.trim(),
      enviado: false,
      activo: true,
      createdAt: DateTime.now(),
    );
    Navigator.of(context).pop(rec);
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
              'Nuevo recordatorio',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<TipoRecordatorio>(
              initialValue: _tipo,
              decoration: const InputDecoration(
                labelText: 'Tipo de recordatorio',
                border: OutlineInputBorder(),
              ),
              items: TipoRecordatorio.values
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
              controller: _mensajeCtrl,
              decoration: const InputDecoration(
                labelText: 'Mensaje',
                hintText: 'Ej: Cambio de aceite',
                border: OutlineInputBorder(),
              ),
              maxLength: 255,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Requerido' : null,
            ),
            const SizedBox(height: 12),
            if (_tipo == TipoRecordatorio.km)
              TextFormField(
                controller: _kmCtrl,
                decoration: const InputDecoration(
                  labelText: 'A los cuantos km',
                  hintText: 'Ej: 10000',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (v) {
                  final n = int.tryParse(v?.trim() ?? '');
                  if (n == null || n <= 0) return 'Invalido';
                  return null;
                },
              ),
            if (_tipo == TipoRecordatorio.fecha)
              OutlinedButton.icon(
                onPressed: _elegirFecha,
                icon: const Icon(Icons.calendar_today),
                label: Text(
                  _fecha == null
                      ? 'Elegir fecha'
                      : '${_fecha!.day}/${_fecha!.month}/${_fecha!.year}',
                ),
              ),
            if (_tipo == TipoRecordatorio.evento)
              TextFormField(
                controller: _descripcionCtrl,
                decoration: const InputDecoration(
                  labelText: 'Descripcion del evento',
                  border: OutlineInputBorder(),
                ),
                maxLength: 255,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Requerido' : null,
              ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _guardar,
              child: const Text('Crear recordatorio'),
            ),
          ],
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
            Icon(Icons.notifications_none,
                size: 72, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            Text('Sin recordatorios',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Crea recordatorios por km o fecha para no olvidarte del mantenimiento.',
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
            Text('$error', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }
}

String _formatFecha(DateTime d) =>
    '${d.day}/${d.month}/${d.year}';