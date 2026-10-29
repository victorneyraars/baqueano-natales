import 'package:flutter/material.dart';
import 'package:baqueano_natales/features/prestadores/domain/perfil_negocio.dart';

/// Sección: reservas y mensajería.
class SeccionReserva extends StatefulWidget {
  const SeccionReserva({
    super.key,
    required this.initialValue,
    required this.onChanged,
  });

  final ReservaConfig? initialValue;
  final ValueChanged<ReservaConfig> onChanged;

  @override
  State<SeccionReserva> createState() => _SeccionReservaState();
}

class _SeccionReservaState extends State<SeccionReserva> {
  late final TextEditingController _url;
  late bool _mensajeria;
  late final TextEditingController _tiempo;

  @override
  void initState() {
    super.initState();
    final r = widget.initialValue;
    _url = TextEditingController(text: r?.bookingUrl ?? '');
    _mensajeria = r?.mensajeriaHabilitada ?? false;
    _tiempo = TextEditingController(
      text: r?.tiempoRespuestaHoras?.toString() ?? '',
    );
    _url.addListener(_emitir);
    _tiempo.addListener(_emitir);
  }

  void _emitir() {
    widget.onChanged(
      ReservaConfig(
        bookingUrl: _url.text.trim().isEmpty ? null : _url.text.trim(),
        mensajeriaHabilitada: _mensajeria,
        tiempoRespuestaHoras: int.tryParse(_tiempo.text.trim()),
      ),
    );
  }

  @override
  void dispose() {
    _url.dispose();
    _tiempo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Reservas y mensajería', style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          'Link de reserva visible en Google Business Profile.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _url,
          decoration: const InputDecoration(labelText: 'URL de reserva'),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          title: const Text('Permitir mensajería'),
          value: _mensajeria,
          onChanged: (v) {
            setState(() => _mensajeria = v);
            _emitir();
          },
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _tiempo,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Tiempo de respuesta (horas)',
          ),
        ),
      ],
    );
  }
}
