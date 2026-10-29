import 'package:flutter/material.dart';
import 'package:baqueano_natales/features/prestadores/domain/perfil_negocio.dart';

/// Sección: atributos GBP (chips multi-select por grupo).
///
/// 5 grupos: pagos, servicios, accesibilidad, comodidades, planificación.
/// Cada chip se togglea y emite el AtributosGbp completo actualizado.
class SeccionAtributos extends StatefulWidget {
  const SeccionAtributos({
    super.key,
    required this.initialValue,
    required this.onChanged,
  });

  final AtributosGbp? initialValue;
  final ValueChanged<AtributosGbp> onChanged;

  @override
  State<SeccionAtributos> createState() => _SeccionAtributosState();
}

class _SeccionAtributosState extends State<SeccionAtributos> {
  late Set<String> _pagos;
  late Set<String> _servicios;
  late Set<String> _accesibilidad;
  late Set<String> _comodidades;
  late Set<String> _planificacion;

  static const _pagosOpts = [
    ('efectivo', 'Efectivo'),
    ('tarjeta_credito', 'Tarjeta de crédito'),
    ('tarjeta_debito', 'Tarjeta de débito'),
    ('transferencia', 'Transferencia'),
    ('mercadopago', 'MercadoPago'),
    ('cheque', 'Cheque'),
  ];

  static const _serviciosOpts = [
    ('reserva_online', 'Reserva online'),
    ('entrega_domicilio', 'Entrega a domicilio'),
    ('retiro_en_local', 'Retiro en local'),
    ('atencion_24h', 'Atención 24h'),
    ('presupuesto_sin_costo', 'Presupuesto sin costo'),
  ];

  static const _accesibilidadOpts = [
    ('estacionamiento_accesible', 'Estacionamiento accesible'),
    ('entrada_accesible', 'Entrada accesible'),
    ('bano_accesible', 'Baño accesible'),
  ];

  static const _comodidadesOpts = [
    ('wifi', 'Wi-Fi'),
    ('estacionamiento', 'Estacionamiento'),
    ('estacionamiento_gratis', 'Estacionamiento gratis'),
    ('sala_espera', 'Sala de espera'),
    ('cafeteria', 'Cafetería'),
  ];

  static const _planificacionOpts = [
    ('requiere_cita', 'Requiere cita'),
    ('acepta_reservas', 'Acepta reservas'),
    ('atencion_inmediata', 'Atención inmediata'),
  ];

  @override
  void initState() {
    super.initState();
    final a = widget.initialValue;
    _pagos = Set.from(a?.pagos ?? const []);
    _servicios = Set.from(a?.servicios ?? const []);
    _accesibilidad = Set.from(a?.accesibilidad ?? const []);
    _comodidades = Set.from(a?.comodidades ?? const []);
    _planificacion = Set.from(a?.planificacion ?? const []);
  }

  void _emitir() {
    widget.onChanged(
      AtributosGbp(
        pagos: _pagos.toList()..sort(),
        servicios: _servicios.toList()..sort(),
        accesibilidad: _accesibilidad.toList()..sort(),
        comodidades: _comodidades.toList()..sort(),
        planificacion: _planificacion.toList()..sort(),
      ),
    );
  }

  void _toggle(Set<String> set, String id) {
    setState(() {
      if (set.contains(id)) {
        set.remove(id);
      } else {
        set.add(id);
      }
    });
    _emitir();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Atributos del negocio', style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          'Aparacen como filtros y badges en Google Business y la web.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        _grupo(theme, 'Métodos de pago', _pagosOpts, _pagos),
        const SizedBox(height: 16),
        _grupo(theme, 'Servicios', _serviciosOpts, _servicios),
        const SizedBox(height: 16),
        _grupo(theme, 'Accesibilidad', _accesibilidadOpts, _accesibilidad),
        const SizedBox(height: 16),
        _grupo(theme, 'Comodidades', _comodidadesOpts, _comodidades),
        const SizedBox(height: 16),
        _grupo(theme, 'Planificación', _planificacionOpts, _planificacion),
      ],
    );
  }

  Widget _grupo(
    ThemeData theme,
    String titulo,
    List<(String, String)> opciones,
    Set<String> seleccionados,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titulo, style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final opt in opciones)
              FilterChip(
                label: Text(opt.$2),
                selected: seleccionados.contains(opt.$1),
                onSelected: (_) => _toggle(seleccionados, opt.$1),
              ),
          ],
        ),
      ],
    );
  }
}
