import 'package:flutter/material.dart';
import 'package:baqueano_natales/features/prestadores/domain/perfil_negocio.dart';

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

  static const _rango24Horas = HorarioRango(abre: '00:00', cierra: '23:59');
  static const _rangoNormal = HorarioRango(abre: '09:00', cierra: '18:00');

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

  bool _esDia24Horas(List<HorarioRango> rangos) {
    if (rangos.isEmpty) return false;
    final r = rangos.first;
    return r.abre == '00:00' && (r.cierra == '23:59' || r.cierra == '24:00');
  }

  bool get _esSemana24x7 =>
      _nombresDias.every((d) => _esDia24Horas(_dias[d.$1]!));

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

  void _aplicar24x7() {
    setState(() {
      for (final d in _nombresDias) {
        _dias[d.$1] = [_rango24Horas];
      }
    });
    _notify();
  }

  void _aplicarHorarioComercial() {
    setState(() {
      for (final d in _nombresDias) {
        if (d.$1 == 'sabado' || d.$1 == 'domingo') {
          _dias[d.$1] = [];
        } else {
          _dias[d.$1] = [_rangoNormal];
        }
      }
    });
    _notify();
  }

  void _toggle24HorasDia(String key, bool activar24h) {
    setState(() {
      _dias[key] = [activar24h ? _rango24Horas : _rangoNormal];
    });
    _notify();
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
      _dias[key] = abierto ? [_rangoNormal] : [];
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
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilterChip(
              avatar: const Icon(Icons.all_inclusive, size: 16),
              label: const Text('Abierto 24/7'),
              selected: _esSemana24x7,
              onSelected: (_) => _aplicar24x7(),
            ),
            ActionChip(
              avatar: const Icon(Icons.schedule, size: 16),
              label: const Text('Lun–Vie 09:00 a 18:00'),
              onPressed: _aplicarHorarioComercial,
            ),
          ],
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
    final es24h = _esDia24Horas(rangos);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(label, style: theme.textTheme.bodyLarge)),
                if (abierto) ...[
                  FilterChip(
                    label: const Text('24 horas'),
                    selected: es24h,
                    visualDensity: VisualDensity.compact,
                    onSelected: (v) => _toggle24HorasDia(key, v),
                  ),
                  const SizedBox(width: 8),
                ],
                Switch(value: abierto, onChanged: (v) => _toggleDia(key, v)),
              ],
            ),
            if (abierto && es24h)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Abierto 24 horas (00:00 – 23:59)',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            if (abierto && !es24h)
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
