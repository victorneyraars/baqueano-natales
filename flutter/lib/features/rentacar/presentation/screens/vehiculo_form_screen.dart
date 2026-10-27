import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:baqueano_natales/core/network/api_exceptions.dart';
import 'package:baqueano_natales/features/rentacar/data/rentacar_providers.dart';
import 'package:baqueano_natales/features/rentacar/domain/vehiculo.dart';

class VehiculoFormScreen extends ConsumerStatefulWidget {
  const VehiculoFormScreen({super.key, this.vehiculo});

  final Vehiculo? vehiculo;

  @override
  ConsumerState<VehiculoFormScreen> createState() => _VehiculoFormScreenState();
}

class _VehiculoFormScreenState extends ConsumerState<VehiculoFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _patenteCtrl;
  late final TextEditingController _marcaCtrl;
  late final TextEditingController _modeloCtrl;
  late final TextEditingController _anioCtrl;
  late final TextEditingController _precioCtrl;
  String _categoria = 'SUV';
  bool _disponible = true;
  bool _loading = false;

  static const _categorias = ['SUV', 'SEDAN', 'PICKUP', 'FURGONETA'];

  @override
  void initState() {
    super.initState();
    final v = widget.vehiculo;
    _patenteCtrl = TextEditingController(text: v?.patente ?? '');
    _marcaCtrl = TextEditingController(text: v?.marca ?? '');
    _modeloCtrl = TextEditingController(text: v?.modelo ?? '');
    _anioCtrl = TextEditingController(text: v?.anio.toString() ?? '');
    _precioCtrl = TextEditingController(
      text: v?.precioDia.toStringAsFixed(0) ?? '',
    );
    _categoria = v?.categoria ?? 'SUV';
    _disponible = v?.disponible ?? true;
  }

  @override
  void dispose() {
    _patenteCtrl.dispose();
    _marcaCtrl.dispose();
    _modeloCtrl.dispose();
    _anioCtrl.dispose();
    _precioCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final payload = {
        'patente': _patenteCtrl.text.trim().toUpperCase(),
        'marca': _marcaCtrl.text.trim(),
        'modelo': _modeloCtrl.text.trim(),
        'anio': int.parse(_anioCtrl.text.trim()),
        'categoria': _categoria,
        'precio_dia': double.parse(_precioCtrl.text.trim()),
        'disponible': _disponible,
      };
      final repo = ref.read(rentacarRepositoryProvider);
      if (widget.vehiculo == null) {
        await repo.crearVehiculo(payload);
      } else {
        await repo.actualizarVehiculo(widget.vehiculo!.id, payload);
      }
      ref.invalidate(misVehiculosRentacarProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.vehiculo == null
                  ? 'Vehiculo creado'
                  : 'Vehiculo actualizado',
            ),
            backgroundColor: Colors.green,
          ),
        );
        context.pop();
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.message}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.vehiculo != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Editar vehiculo' : 'Nuevo vehiculo'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _patenteCtrl,
              decoration: const InputDecoration(
                labelText: 'Patente',
                hintText: 'BBCC12',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.characters,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Requerido' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _marcaCtrl,
              decoration: const InputDecoration(
                labelText: 'Marca',
                hintText: 'Toyota',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Requerido' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _modeloCtrl,
              decoration: const InputDecoration(
                labelText: 'Modelo',
                hintText: 'RAV4',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Requerido' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _anioCtrl,
              decoration: const InputDecoration(
                labelText: 'Año',
                hintText: '2023',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Requerido';
                final n = int.tryParse(v);
                if (n == null || n < 1990 || n > 2030) return 'Año invalido';
                return null;
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _categoria,
              decoration: const InputDecoration(
                labelText: 'Categoria',
                border: OutlineInputBorder(),
              ),
              items: _categorias
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => setState(() => _categoria = v ?? 'SUV'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _precioCtrl,
              decoration: const InputDecoration(
                labelText: 'Precio por dia (CLP)',
                hintText: '45000',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Requerido';
                final n = double.tryParse(v);
                if (n == null || n <= 0) return 'Precio invalido';
                return null;
              },
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text('Disponible para reservas'),
              value: _disponible,
              onChanged: (v) => setState(() => _disponible = v),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _loading ? null : _guardar,
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(isEdit ? 'Guardar cambios' : 'Crear vehiculo'),
            ),
          ],
        ),
      ),
    );
  }
}
