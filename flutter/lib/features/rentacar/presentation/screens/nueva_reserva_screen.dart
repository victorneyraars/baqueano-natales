import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:baqueano_natales/features/rentacar/data/rentacar_providers.dart';
import 'package:baqueano_natales/features/rentacar/domain/vehiculo.dart';

class NuevaReservaScreen extends ConsumerStatefulWidget {
  const NuevaReservaScreen({super.key});

  @override
  ConsumerState<NuevaReservaScreen> createState() => _NuevaReservaScreenState();
}

class _NuevaReservaScreenState extends ConsumerState<NuevaReservaScreen> {
  String? _vehiculoId;
  Vehiculo? _vehiculoSel;
  DateTimeRange? _rango;
  String _metodoPago = 'efectivo';
  final _nombreCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _precioCtrl = TextEditingController();
  bool _enviando = false;
  bool _precioEditado = false;

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _emailCtrl.dispose();
    _telefonoCtrl.dispose();
    _precioCtrl.dispose();
    super.dispose();
  }

  int get _dias {
    if (_rango == null) return 0;
    final d = _rango!.end.difference(_rango!.start).inDays;
    return d == 0 ? 1 : d;
  }

  void _recalcularPrecio() {
    if (_precioEditado || _vehiculoSel == null || _rango == null) return;
    final total = _dias * _vehiculoSel!.precioDia;
    _precioCtrl.text = total.toStringAsFixed(0);
  }

  Future<void> _seleccionarFechas() async {
    final ahora = DateTime.now();
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(ahora.year, ahora.month, ahora.day),
      lastDate: ahora.add(const Duration(days: 730)),
      initialDateRange: _rango,
      helpText: 'Seleccionar fechas',
      saveText: 'Confirmar',
    );
    if (r != null) {
      setState(() {
        _rango = r;
        _recalcularPrecio();
      });
    }
  }

  Future<void> _guardar() async {
    if (_vehiculoId == null) {
      _snack('Selecciona un vehiculo');
      return;
    }
    if (_rango == null) {
      _snack('Selecciona las fechas');
      return;
    }
    final precio = double.tryParse(_precioCtrl.text.trim());
    if (precio == null || precio <= 0) {
      _snack('Precio total invalido');
      return;
    }
    setState(() => _enviando = true);
    try {
      final payload = {
        'vehiculo_id': _vehiculoId,
        'fecha_inicio': _rango!.start.toIso8601String(),
        'fecha_fin': _rango!.end.toIso8601String(),
        'metodo_pago': _metodoPago,
        'precio_total': precio,
        'nombre_cliente': _nombreCtrl.text.trim().isEmpty
            ? null
            : _nombreCtrl.text.trim(),
        'email_cliente': _emailCtrl.text.trim().isEmpty
            ? null
            : _emailCtrl.text.trim(),
        'telefono_cliente': _telefonoCtrl.text.trim().isEmpty
            ? null
            : _telefonoCtrl.text.trim(),
        'estado': 'confirmada',
      };
      await ref
          .read(rentacarRepositoryProvider)
          .crearReservaPropietario(payload);
      if (!mounted) return;
      context.pop(true);
    } catch (e) {
      if (!mounted) return;
      _snack('Error: $e');
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, "0")}/${d.month.toString().padLeft(2, "0")}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final asyncVehiculos = ref.watch(misVehiculosRentacarProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Nueva reserva')),
      body: asyncVehiculos.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (vehiculos) {
          if (vehiculos.isEmpty) {
            return const Center(child: Text('No tienes vehiculos registrados'));
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              DropdownButtonFormField<String>(
                initialValue: _vehiculoId,
                decoration: const InputDecoration(
                  labelText: 'Vehiculo',
                  border: OutlineInputBorder(),
                ),
                items: vehiculos
                    .map(
                      (v) => DropdownMenuItem(
                        value: v.id,
                        child: Text('${v.marca} ${v.modelo} - ${v.patente}'),
                      ),
                    )
                    .toList(),
                onChanged: (id) {
                  if (id == null) return;
                  final v = vehiculos.firstWhere((x) => x.id == id);
                  setState(() {
                    _vehiculoId = id;
                    _vehiculoSel = v;
                    _precioEditado = false;
                    _recalcularPrecio();
                  });
                },
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _seleccionarFechas,
                icon: const Icon(Icons.calendar_today),
                label: Text(
                  _rango == null
                      ? 'Seleccionar fechas'
                      : '${_fmt(_rango!.start)} -> ${_fmt(_rango!.end)} ($_dias dias)',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nombreCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nombre cliente (opcional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email (opcional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _telefonoCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Telefono (opcional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _metodoPago,
                decoration: const InputDecoration(
                  labelText: 'Metodo de pago',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'efectivo', child: Text('Efectivo')),
                  DropdownMenuItem(
                    value: 'transferencia',
                    child: Text('Transferencia'),
                  ),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _metodoPago = v);
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _precioCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Precio total (CLP)',
                  helperText: 'Autocalculado. Editable para descuentos.',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.attach_money),
                ),
                onChanged: (_) => _precioEditado = true,
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _precioEditado = false;
                    _recalcularPrecio();
                  });
                },
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Recalcular precio'),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _enviando ? null : _guardar,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _enviando
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Confirmar reserva'),
              ),
            ],
          );
        },
      ),
    );
  }
}
