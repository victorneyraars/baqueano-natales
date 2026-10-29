import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:baqueano_natales/features/rentacar/data/rentacar_providers.dart';
import 'package:baqueano_natales/features/rentacar/domain/config_rentacar.dart';

class ConfigRentacarScreen extends ConsumerStatefulWidget {
  const ConfigRentacarScreen({super.key});
  @override
  ConsumerState<ConfigRentacarScreen> createState() =>
      _ConfigRentacarScreenState();
}

class _ConfigRentacarScreenState extends ConsumerState<ConfigRentacarScreen> {
  bool? _efectivo;
  bool? _transferencia;
  bool? _mercadopago;
  String? _depositoTipo;
  TextEditingController? _depositoCtrl;
  bool? _conductorOn;
  TextEditingController? _conductorCtrl;
  bool _guardando = false;
  bool _inicializado = false;

  void _init(ConfigRentacar c) {
    if (_inicializado) return;
    _efectivo = c.aceptaEfectivo;
    _transferencia = c.aceptaTransferencia;
    _mercadopago = c.aceptaMercadopago;
    _depositoTipo = c.depositoTipo;
    _depositoCtrl = TextEditingController(text: c.depositoValor.toString());
    _conductorOn = c.conductorAdicionalHabilitado;
    _conductorCtrl = TextEditingController(
      text: c.conductorAdicionalTarifa.toString(),
    );
    _inicializado = true;
  }

  @override
  void dispose() {
    _depositoCtrl?.dispose();
    _conductorCtrl?.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    try {
      final repo = ref.read(rentacarRepositoryProvider);
      await repo.actualizarConfig({
        'metodos_pago': {
          'efectivo': _efectivo ?? false,
          'transferencia': _transferencia ?? false,
          'mercadopago': _mercadopago ?? false,
        },
        'deposito': {
          'tipo': _depositoTipo ?? 'porcentaje',
          'valor': num.tryParse(_depositoCtrl?.text ?? '0') ?? 0,
        },
        'conductor_adicional': {
          'habilitado': _conductorOn ?? false,
          'tarifa_por_dia': num.tryParse(_conductorCtrl?.text ?? '0') ?? 0,
        },
      });
      ref.invalidate(miConfigRentacarProvider);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Configuración guardada')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error al guardar: $e')));
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncConfig = ref.watch(miConfigRentacarProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Configuración')),
      body: asyncConfig.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Error: $e', textAlign: TextAlign.center),
          ),
        ),
        data: (config) {
          _init(config);
          return _buildForm();
        },
      ),
    );
  }

  Widget _buildForm() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Métodos de pago'),
        const SizedBox(height: 8),
        SwitchListTile(
          title: const Text('Efectivo'),
          value: _efectivo ?? false,
          onChanged: (v) => setState(() => _efectivo = v),
        ),
        SwitchListTile(
          title: const Text('Transferencia'),
          value: _transferencia ?? false,
          onChanged: (v) => setState(() => _transferencia = v),
        ),
        SwitchListTile(
          title: const Text('MercadoPago'),
          value: _mercadopago ?? false,
          onChanged: (v) => setState(() => _mercadopago = v),
        ),
        const SizedBox(height: 24),
        const Text('Depósito de garantía'),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'porcentaje', label: Text('%')),
            ButtonSegment(value: 'monto_fijo', label: Text('CLP')),
          ],
          selected: {_depositoTipo ?? 'porcentaje'},
          onSelectionChanged: (s) => setState(() => _depositoTipo = s.first),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _depositoCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Valor'),
        ),
        const SizedBox(height: 24),
        const Text('Conductor adicional'),
        const SizedBox(height: 8),
        SwitchListTile(
          title: const Text('Permitir conductor adicional'),
          value: _conductorOn ?? false,
          onChanged: (v) => setState(() => _conductorOn = v),
        ),
        if (_conductorOn == true) ...[
          const SizedBox(height: 8),
          TextField(
            controller: _conductorCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Tarifa por día (CLP)',
            ),
          ),
        ],
        const SizedBox(height: 32),
        FilledButton.icon(
          onPressed: _guardando ? null : _guardar,
          icon: _guardando
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save),
          label: Text(_guardando ? 'Guardando...' : 'Guardar'),
        ),
      ],
    );
  }
}
