/// Pantalla prestador: crear una orden nueva.
///
/// El prestador busca el cliente por nombre/email (con debounce) y luego
/// elige uno de sus vehiculos. Ya no se piden UUIDs manuales.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:baqueano_natales/core/network/api_exceptions.dart';
import 'package:baqueano_natales/features/oficios/data/oficios_providers.dart';
import 'package:baqueano_natales/features/oficios/domain/cliente_busqueda.dart';
import 'package:baqueano_natales/features/oficios/domain/orden_trabajo.dart';
import 'package:baqueano_natales/features/oficios/domain/vehiculo.dart';

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
  final _searchCtrl = TextEditingController();
  final _diagnosticoCtrl = TextEditingController();
  final _kmCtrl = TextEditingController();

  Timer? _debounce;
  String _queryCliente = '';

  ClienteBusqueda? _clienteSel;
  Vehiculo? _vehiculoSel;

  PrioridadOrden _prioridad = PrioridadOrden.normal;
  bool _guardando = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _diagnosticoCtrl.dispose();
    _kmCtrl.dispose();
    super.dispose();
  }

  void _onBuscar(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _queryCliente = value);
    });
  }

  void _seleccionarCliente(ClienteBusqueda c) {
    setState(() {
      _clienteSel = c;
      _vehiculoSel = null;
      _searchCtrl.text = c.nombreDisplay;
      _queryCliente = '';
    });
    FocusScope.of(context).unfocus();
  }

  void _limpiarCliente() {
    setState(() {
      _clienteSel = null;
      _vehiculoSel = null;
      _searchCtrl.clear();
      _queryCliente = '';
    });
  }

  Future<void> _guardar() async {
    if (_clienteSel == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona un cliente')),
      );
      return;
    }
    if (_vehiculoSel == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona un vehiculo')),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() => _guardando = true);
    final repo = ref.read(oficiosRepositoryProvider);

    try {
      final nueva = OrdenTrabajo(
        id: '',
        numero: '',
        clienteId: _clienteSel!.id,
        prestadorId: widget.prestadorId,
        objetoId: _vehiculoSel!.objetoId,
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
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Nueva orden')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // --- Cliente ---
            Text(
              'Cliente',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            if (_clienteSel == null)
              _BuscadorCliente(
                controller: _searchCtrl,
                query: _queryCliente,
                prestadorId: widget.prestadorId,
                onChanged: _onBuscar,
                onSeleccion: _seleccionarCliente,
              )
            else
              _ClienteChip(
                cliente: _clienteSel!,
                onLimpiar: _limpiarCliente,
              ),

            const SizedBox(height: 20),

            // --- Vehiculo ---
            Text(
              'Vehiculo',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            if (_clienteSel == null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Primero selecciona un cliente.',
                  style: theme.textTheme.bodySmall,
                ),
              )
            else
              _SelectorVehiculo(
                prestadorId: widget.prestadorId,
                clienteId: _clienteSel!.id,
                seleccionado: _vehiculoSel,
                onSeleccion: (v) => setState(() => _vehiculoSel = v),
              ),

            const SizedBox(height: 20),

            // --- Orden ---
            Text(
              'Orden',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
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

// =========================================================
// Buscador de cliente con dropdown de resultados
// =========================================================
class _BuscadorCliente extends ConsumerWidget {
  const _BuscadorCliente({
    required this.controller,
    required this.query,
    required this.prestadorId,
    required this.onChanged,
    required this.onSeleccion,
  });

  final TextEditingController controller;
  final String query;
  final String prestadorId;
  final ValueChanged<String> onChanged;
  final ValueChanged<ClienteBusqueda> onSeleccion;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final params = BusquedaClientesParams(
      prestadorId: prestadorId,
      query: query,
    );
    final async = query.trim().length >= 2
        ? ref.watch(busquedaClientesProvider(params))
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: controller,
          onChanged: onChanged,
          decoration: const InputDecoration(
            labelText: 'Buscar cliente por nombre o email',
            hintText: 'Min 2 caracteres',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
            helperText: 'Ej: juan, perez, juan@mail.com',
          ),
        ),
        if (async != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: async.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(12),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(12),
                child: Text('Error: $e'),
              ),
              data: (clientes) {
                if (clientes.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('Sin resultados'),
                  );
                }
                return Card(
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: clientes
                        .map((c) => ListTile(
                              leading: const CircleAvatar(
                                child: Icon(Icons.person),
                              ),
                              title: Text(c.nombreDisplay),
                              subtitle:
                                  c.email != null ? Text(c.email!) : null,
                              onTap: () => onSeleccion(c),
                            ))
                        .toList(),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

// =========================================================
// Chip del cliente seleccionado
// =========================================================
class _ClienteChip extends StatelessWidget {
  const _ClienteChip({required this.cliente, required this.onLimpiar});

  final ClienteBusqueda cliente;
  final VoidCallback onLimpiar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const CircleAvatar(child: Icon(Icons.person)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cliente.nombreDisplay,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (cliente.email != null)
                    Text(
                      cliente.email!,
                      style: theme.textTheme.bodySmall,
                    ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Cambiar cliente',
              onPressed: onLimpiar,
            ),
          ],
        ),
      ),
    );
  }
}

// =========================================================
// Selector de vehiculo del cliente
// =========================================================
class _SelectorVehiculo extends ConsumerWidget {
  const _SelectorVehiculo({
    required this.prestadorId,
    required this.clienteId,
    required this.seleccionado,
    required this.onSeleccion,
  });

  final String prestadorId;
  final String clienteId;
  final Vehiculo? seleccionado;
  final ValueChanged<Vehiculo> onSeleccion;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final params = VehiculosDeClienteParams(
      prestadorId: prestadorId,
      clienteId: clienteId,
    );
    final async = ref.watch(vehiculosDeClienteProvider(params));

    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(12),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(12),
        child: Text('Error: $e'),
      ),
      data: (vehiculos) {
        if (vehiculos.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_outlined),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Este cliente no tiene vehiculos registrados. '
                    'Pedile que los agregue en "Mis vehiculos".',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          );
        }
        return DropdownButtonFormField<Vehiculo>(
          initialValue: seleccionado,
          decoration: const InputDecoration(
            labelText: 'Vehiculo del cliente',
            border: OutlineInputBorder(),
          ),
          items: vehiculos
              .map((v) => DropdownMenuItem(
                    value: v,
                    child: Text(
                      v.nombreDisplay,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ))
              .toList(),
          onChanged: (v) {
            if (v != null) onSeleccion(v);
          },
        );
      },
    );
  }
}