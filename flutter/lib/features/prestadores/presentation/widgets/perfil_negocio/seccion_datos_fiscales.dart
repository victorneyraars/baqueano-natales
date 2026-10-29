import 'package:flutter/material.dart';

/// Sección: datos fiscales del negocio (razón social + RUT).
class SeccionDatosFiscales extends StatelessWidget {
  const SeccionDatosFiscales({
    super.key,
    required this.initialRazonSocial,
    required this.initialRut,
    required this.initialPrecioDesde,
    required this.onRazonSocialChanged,
    required this.onRutChanged,
    required this.onPrecioDesdeChanged,
  });

  final String? initialRazonSocial;
  final String? initialRut;
  final double? initialPrecioDesde;
  final ValueChanged<String?> onRazonSocialChanged;
  final ValueChanged<String?> onRutChanged;
  final ValueChanged<double?> onPrecioDesdeChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Datos fiscales', style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          'Razón social y RUT (requeridos por GBP y Schema.org taxID).',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        TextFormField(
          initialValue: initialRazonSocial,
          decoration: const InputDecoration(
            labelText: 'Razón social',
            hintText: 'Rent a Car Vásquez SpA',
          ),
          onChanged: (v) =>
              onRazonSocialChanged(v.trim().isEmpty ? null : v.trim()),
        ),
        const SizedBox(height: 8),
        TextFormField(
          initialValue: initialRut,
          decoration: const InputDecoration(
            labelText: 'RUT empresa',
            hintText: '76.543.210-K',
          ),
          onChanged: (v) => onRutChanged(v.trim().isEmpty ? null : v.trim()),
        ),
        const SizedBox(height: 8),
        TextFormField(
          initialValue: initialPrecioDesde?.toString(),
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Precio desde (CLP)'),
          onChanged: (v) => onPrecioDesdeChanged(double.tryParse(v.trim())),
        ),
      ],
    );
  }
}
