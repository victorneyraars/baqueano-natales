import 'package:flutter/material.dart';
import 'package:baqueano_natales/features/prestadores/domain/perfil_negocio.dart';

/// Sección: horario semanal estructurado por día.
///
/// MVP: 1 rango por día (abre-cierra). Si en el futuro se necesitan
/// múltiples rangos (ej. mañana/tarde), se agrega el botón "+" aquí.
class SeccionHorario extends StatefulWidget {
  const SeccionHorario({
    super.key,
    required this.initialValue,
    required this.onChanged,
  });

  final HorarioSemanal? initialValue;
  final ValueChanged<HorarioSemanal> onChanged;

  @override
  State<SeccionHorario> createState() => _SeccionHorarioState();
}

class _SeccionHorarioState extends State<SeccionHorario> {
  late Map<String, List<HorarioRango>> _dias;

  static const _nombresDias = [
    ('lunes', 'Lunes'),
    ('martes', 'Martes'),
    ('miercoles', 'Miércoles'),
    ('jueves', 'Jueves'),
    ('viernes', 'Viernes'),
    ('sabado', 'Sábado'),
    ('domingo', 'Domingo'),
  ];

  @override
  void initState() {
    super.initState();
    final h = widget.initialValue;
    _dias = {
      'lunes': List.from(h?.lunes ?? const []),
      'martes': List.from(h?.martes ?? const []),
      'miercoles': List.from(h?.miercoles ?? const []),
      'jueves': List.from(h?.jueves ?? const []),
      'viernes': List.from(h?.viernes ?? const []),
      'sabado': List.from(h?.sabado ?? const []),
      'domingo': List.from(h?.domingo ?? const []),
    };
  }

  void _notify() {
    widget.onChanged(
      HorarioSemanal(
        lunes: _dias['lunes']!,
        martes: _dias['martes']!,
        miercoles: _dias['miercoles']!,
        jueves: _dias['jueves']!,
        viernes: _dias['viernes']!,
        sabado: _dias['sabado']!,
        domingo: _dias['domingo']!,
      ),
    );
  }

  Future<void> _seleccionarHora(String key, int index, bool esAbre) async {
    final actual = _dias[key]![index];
    final partes = (esAbre ? actual.abre : actual.cierra).split(':');
    final inicial = TimeOfDay(
      hour: int.tryParse(partes.first) ?? 9,
      minute: partes.length > 1 ? int.tryParse(partes[1]) ?? 0 : 0,
    );
    final picked = await showTimePicker(context: context, initialTime: inicial);
    if (picked == null) return;
    final hh = picked.hour.toString().padLeft(2, '0');
    final mm = picked.minute.toString().padLeft(2, '0');
    final valor = '$hh:$mm';
    setState(() {
      _dias[key]![index] = esAbre
          ? HorarioRango(abre: valor, cierra: actual.cierra)
          : HorarioRango(abre: actual.abre, cierra: valor);
    });
    _notify();
  }

  void _toggleDia(String key, bool abierto) {
    setState(() {
      if (abierto) {
        _dias[key] = [const HorarioRango(abre: '09:00', cierra: '18:00')];
      } else {
        _dias[key] = [];
      }
    });
    _notify();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Horario de atención', style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          'Días y horarios visibles en la web, Google y WhatsApp.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        for (final entry in _nombresDias) ...[
          _buildDia(theme, entry.$1, entry.$2),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _buildDia(ThemeData theme, String key, String label) {
    final rangos = _dias[key]!;
    final abierto = rangos.isNotEmpty;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(label, style: theme.textTheme.bodyLarge)),
                Switch(value: abierto, onChanged: (v) => _toggleDia(key, v)),
              ],
            ),
            if (abierto)
              for (var i = 0; i < rangos.length; i++)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.access_time, size: 16),
                          label: Text(rangos[i].abre),
                          onPressed: () => _seleccionarHora(key, i, true),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text('a'),
                      ),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.access_time, size: 16),
                          label: Text(rangos[i].cierra),
                          onPressed: () => _seleccionarHora(key, i, false),
                        ),
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
