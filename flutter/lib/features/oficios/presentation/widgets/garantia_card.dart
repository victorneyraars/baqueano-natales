/// Widget reusable para mostrar una garantia en el detalle de una orden.
///
/// Se usa en el detalle del cliente (solo lectura) y del prestador (con
/// boton para crear/editar si no existe o si el prestador quiere ajustarla).
library;

import 'package:flutter/material.dart';

import 'package:baqueano_natales/features/oficios/domain/garantia.dart';

class GarantiaCard extends StatelessWidget {
  const GarantiaCard({
    super.key,
    required this.garantia,
    this.onEditar,
    this.onCrear,
  });

  /// Si es null, se muestra el empty state con boton "Crear" (si onCrear != null).
  final Garantia? garantia;

  /// Callback para editar (prestador).
  final VoidCallback? onEditar;

  /// Callback para crear cuando no existe (prestador).
  final VoidCallback? onCrear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (garantia == null) {
      if (onCrear == null) return const SizedBox.shrink();
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.verified_outlined,
                      color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Text(
                    'Sin garantia',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Esta orden no tiene garantia asociada. Podes crearla con el boton de abajo.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: onCrear,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Crear garantia'),
              ),
            ],
          ),
        ),
      );
    }

    final g = garantia!;
    final vigente = g.vigente;
    final color = vigente ? Colors.green : Colors.grey;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  vigente ? Icons.verified : Icons.verified_outlined,
                  color: color.shade700,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Garantia ${g.tipo.label}',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                if (vigente)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${g.diasRestantes} dias restantes',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: color.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Vencida',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                if (onEditar != null)
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    tooltip: 'Editar garantia',
                    onPressed: onEditar,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            _Fila(
              icon: Icons.calendar_today,
              label: 'Vigencia',
              value:
                  '${_formatFecha(g.fechaInicio)} - ${_formatFecha(g.fechaFin)}',
            ),
            _Fila(
              icon: Icons.timer_outlined,
              label: 'Duracion',
              value: '${g.duracionDias} dias',
            ),
            if (g.cobertura != null)
              _Fila(
                icon: Icons.check_circle_outline,
                label: 'Cobertura',
                value: g.cobertura!,
              ),
            if (g.condiciones != null)
              _Fila(
                icon: Icons.info_outline,
                label: 'Condiciones',
                value: g.condiciones!,
              ),
          ],
        ),
      ),
    );
  }
}

class _Fila extends StatelessWidget {
  const _Fila({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: theme.textTheme.bodySmall,
                children: [
                  TextSpan(
                    text: '$label: ',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: value),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatFecha(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';