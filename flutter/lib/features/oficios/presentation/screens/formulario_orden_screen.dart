/// Pantalla prestador: crear una orden nueva.
///
/// Version MVP: el prestador ingresa manualmente los IDs de cliente y
/// objeto_servicio. Una iteracion futura agregara busqueda/seleccion.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:baqueano_natales/core/network/api_exceptions.dart';
import 'package:baqueano_natales/features/oficios/data/oficios_providers.dart';
import 'package:baqueano_natales/features/oficios/domain/orden_trabajo.dart';

class FormularioOrdenScreen extends ConsumerStatefulWidget {
  const FormularioOrdenScreen({super.key, required this.prestadorId});

  final String prestadorId;

  @override
  ConsumerState<FormularioOrdenScreen> createState() =>
      _FormularioOrdenScreenState();
}

class _FormularioOrdenScreenState
    extends ConsumerState<FormularioOrdenScreen> {
  final _formKey = GlobalKey<FormState>();
  final _clienteIdCtrl = TextEditingController();
  final _objetoIdCtrl = TextEditingController();
  final _diagnosticoCtrl = TextEditingController();
  final _kmCtrl = TextEditingController();

  PrioridadOrden _prioridad = PrioridadOrden.normal;
  bool _guardando = false;

  @override
  void dispose() {
    _clienteIdCtrl.dispose();
    _objetoIdCtrl.dispose();
    _diagnosticoCtrl.dispose();
    _kmCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _guardando = true);
    final repo = ref.read(oficiosRepositoryProvider);

    try {
      final nueva = OrdenTrabajo(
        id: '',
        numero: '',
        clienteId: _clienteIdCtrl.text.trim(),
        prestadorId: widget.prestadorId,
        objetoId: _objetoIdCtrl.text.trim(),
        estado: EstadoOrden.ingresado,
        prioridad: _prioridad,
        fechaIngreso: DateTime.now(),
        totalPresupuesto: 0,
        totalAprobado: 0,
        diagnosticoInicial: _diagnosticoCtrl.text.trim().isEmpty
            ? null
            : _diagnosticoCtrl.text.trim(),
        kmIngreso: int.tryParse(_kmCtrl.text.trim()),
      );

      final creada = await repo.crearOrden(widget.prestadorId, nueva);
      ref.invalidate(ordenesPrestadorProvider(
        OrdenesPrestadorParams(prestadorId: widget.prestadorId),
      ));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Orden ${creada.numero} creada')),
      );
      context.pop();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nueva orden')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Aviso MVP
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'MVP: ingresa manualmente los IDs de cliente y vehiculo. '
                      'La busqueda se agregara en una proxima version.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            Text(
              'Cliente',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _clienteIdCtrl,
              decoration: const InputDecoration(
                labelText: 'UUID del cliente *',
                hintText: 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Requerido' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _objetoIdCtrl,
              decoration: const InputDecoration(
                labelText: 'UUID del objeto de servicio (vehiculo) *',
                hintText: 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Requerido' : null,
            ),

            const SizedBox(height: 20),
            Text(
              'Orden',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<PrioridadOrden>(
              initialValue: _prioridad,
              decoration: const InputDecoration(
                labelText: 'Prioridad',
                border: OutlineInputBorder(),
              ),
              items: PrioridadOrden.values
                  .map((p) => DropdownMenuItem(
                        value: p,
                        child: Text(p.label),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _prioridad = v);
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _diagnosticoCtrl,
              decoration: const InputDecoration(
                labelText: 'Diagnostico inicial',
                hintText: 'Ej: Ruido en la suspension delantera',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _kmCtrl,
              decoration: const InputDecoration(
                labelText: 'Kilometraje de ingreso',
                hintText: 'Ej: 45000',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),

            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _guardando ? null : _guardar,
              icon: _guardando
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              label: const Text('Crear orden'),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}