import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:baqueano_natales/features/prestadores/domain/transparencia.dart';

/// Seccion: transparencia para el sitio web (deposito, km, combustible, etc).
///
/// Persiste en perfil_negocio.transparencia (JSONB del backend).
/// El backend tiene defaults regionales; aqui solo se persiste lo que el
/// prestador configura explicitamente.
class SeccionTransparencia extends StatefulWidget {
  const SeccionTransparencia({
    super.key,
    required this.initialValue,
    required this.onChanged,
  });

  final Transparencia? initialValue;
  final ValueChanged<Transparencia> onChanged;

  @override
  State<SeccionTransparencia> createState() => _SeccionTransparenciaState();
}

class _SeccionTransparenciaState extends State<SeccionTransparencia> {
  late bool _visible;
  late final TextEditingController _depositoCtrl = TextEditingController();
  late final TextEditingController _kmDiaCtrl = TextEditingController();
  late final TextEditingController _edadCtrl = TextEditingController();
  late final TextEditingController _cancelacionDetalleCtrl =
      TextEditingController();
  late final TextEditingController _notasExtraCtrl = TextEditingController();
  String? _kilometraje;
  String? _combustible;
  String? _cancelacion;
  String? _licencia;

  static const _kmOptions = [
    ('ilimitado', 'Ilimitado'),
    ('limitado_dia', 'Limitado por día'),
    ('limitado_total', 'Limitado total'),
  ];

  static const _combOptions = [
    ('lleno_lleno', 'Lleno / Lleno'),
    ('lleno_vacio', 'Lleno / Vacío'),
    ('cargo_por_uso', 'Cargo por uso'),
  ];

  static const _cancOptions = [
    ('gratis_48h', 'Gratis hasta 48h antes'),
    ('gratis_24h', 'Gratis hasta 24h antes'),
    ('no_reembolsable', 'No reembolsable'),
    ('personalizada', 'Personalizada'),
  ];

  static const _licOptions = [
    ('chilena_o_internacional', 'Chilena o internacional'),
    ('solo_chilena', 'Solo chilena'),
    ('solo_internacional', 'Solo internacional'),
  ];

  @override
  void initState() {
    super.initState();
    final t = widget.initialValue;
    _visible = t?.visible ?? true;
    _depositoCtrl.text = t?.depositoClp?.toString() ?? '';
    _kmDiaCtrl.text = t?.kilometrajeKmDia?.toString() ?? '';
    _edadCtrl.text = t?.edadMinima?.toString() ?? '';
    _cancelacionDetalleCtrl.text = t?.cancelacionDetalle ?? '';
    _notasExtraCtrl.text = t?.notasExtra ?? '';
    _kilometraje = t?.kilometraje;
    _combustible = t?.combustible;
    _cancelacion = t?.cancelacion;
    _licencia = t?.licenciaRequerida;
  }

  String _nullIfEmpty(String s) => s.trim().isEmpty ? '' : s.trim();

  void _notify() {
    widget.onChanged(
      Transparencia(
        visible: _visible,
        depositoClp: int.tryParse(_depositoCtrl.text.trim()),
        kilometraje: _kilometraje,
        kilometrajeKmDia:
            _kilometraje == 'limitado_dia' || _kilometraje == 'limitado_total'
            ? int.tryParse(_kmDiaCtrl.text.trim())
            : null,
        combustible: _combustible,
        cancelacion: _cancelacion,
        cancelacionDetalle: _cancelacion == 'personalizada'
            ? _nullIfEmpty(_cancelacionDetalleCtrl.text)
            : null,
        edadMinima: int.tryParse(_edadCtrl.text.trim()),
        licenciaRequerida: _licencia,
        notasExtra: _nullIfEmpty(_notasExtraCtrl.text).isEmpty
            ? null
            : _notasExtraCtrl.text.trim(),
      ),
    );
  }

  void _applyRegionalDefaults() {
    final d = Transparencia.regionalDefaults();
    setState(() {
      _visible = d.visible;
      _depositoCtrl.text = d.depositoClp?.toString() ?? '';
      _kilometraje = d.kilometraje;
      _combustible = d.combustible;
      _cancelacion = d.cancelacion;
      _edadCtrl.text = d.edadMinima?.toString() ?? '';
      _licencia = d.licenciaRequerida;
      _kmDiaCtrl.text = '';
      _cancelacionDetalleCtrl.text = '';
    });
    _notify();
  }

  @override
  void dispose() {
    _depositoCtrl.dispose();
    _kmDiaCtrl.dispose();
    _edadCtrl.dispose();
    _cancelacionDetalleCtrl.dispose();
    _notasExtraCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('Mostrar transparencia en el sitio web'),
          subtitle: const Text(
            'Depósito, kilometraje, combustible y cancelación visibles en tu web',
          ),
          value: _visible,
          onChanged: (v) {
            setState(() => _visible = v);
            _notify();
          },
        ),
        if (_visible) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _applyRegionalDefaults,
            icon: const Icon(Icons.auto_fix_high, size: 18),
            label: const Text('Usar sugerencia regional'),
          ),
          const SizedBox(height: 8),
          _buildNumField(
            label: 'Depósito (CLP)',
            controller: _depositoCtrl,
            hint: 'Ej: 100000',
            suffix: 'CLP',
          ),
          const SizedBox(height: 12),
          _buildDropdown(
            label: 'Kilometraje',
            value: _kilometraje,
            options: _kmOptions,
            onChanged: (v) {
              setState(() => _kilometraje = v);
              _notify();
            },
          ),
          if (_kilometraje == 'limitado_dia' ||
              _kilometraje == 'limitado_total') ...[
            const SizedBox(height: 8),
            _buildNumField(
              label: 'Km permitidos',
              controller: _kmDiaCtrl,
              hint: 'Ej: 200',
              suffix: 'km',
            ),
          ],
          const SizedBox(height: 12),
          _buildDropdown(
            label: 'Combustible',
            value: _combustible,
            options: _combOptions,
            onChanged: (v) {
              setState(() => _combustible = v);
              _notify();
            },
          ),
          const SizedBox(height: 12),
          _buildDropdown(
            label: 'Política de cancelación',
            value: _cancelacion,
            options: _cancOptions,
            onChanged: (v) {
              setState(() => _cancelacion = v);
              _notify();
            },
          ),
          if (_cancelacion == 'personalizada') ...[
            const SizedBox(height: 8),
            TextFormField(
              controller: _cancelacionDetalleCtrl,
              decoration: const InputDecoration(
                labelText: 'Detalle de la cancelación',
                hintText: 'Ej: 50% hasta 7 días antes',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => _notify(),
            ),
          ],
          const SizedBox(height: 12),
          _buildNumField(
            label: 'Edad mínima',
            controller: _edadCtrl,
            hint: 'Ej: 21',
            suffix: 'años',
          ),
          const SizedBox(height: 12),
          _buildDropdown(
            label: 'Licencia de conducir',
            value: _licencia,
            options: _licOptions,
            onChanged: (v) {
              setState(() => _licencia = v);
              _notify();
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _notasExtraCtrl,
            decoration: const InputDecoration(
              labelText: 'Notas extra (opcional)',
              hintText:
                  'Ej: Se solicita tarjeta de crédito a nombre del titular',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
            onChanged: (_) => _notify(),
          ),
          const SizedBox(height: 8),
          Text(
            'Los cambios se reflejan en tu web al guardar.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
          ),
        ],
      ],
    );
  }

  Widget _buildNumField({
    required String label,
    required TextEditingController controller,
    String? hint,
    String? suffix,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        suffixText: suffix,
        border: const OutlineInputBorder(),
      ),
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onChanged: (_) => _notify(),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<(String, String)> options,
    required ValueChanged<String?> onChanged,
  }) {
    final safeValue = options.any((o) => o.$1 == value) ? value : null;
    return DropdownButtonFormField<String>(
      key: ValueKey<String?>(safeValue),
      initialValue: safeValue,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: options
          .map((o) => DropdownMenuItem(value: o.$1, child: Text(o.$2)))
          .toList(),
      onChanged: onChanged,
    );
  }
}
