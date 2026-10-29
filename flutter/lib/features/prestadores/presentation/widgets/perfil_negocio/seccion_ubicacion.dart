import 'package:flutter/material.dart';
import 'package:baqueano_natales/features/prestadores/domain/perfil_negocio.dart';

/// Sección: dirección estructurada (postal) + coordenadas geo.
///
/// Dirección: calle, número, unidad, comuna, región, país, CP, referencia.
/// Coordenadas: lat/lng opcionales para Google Maps y JSON-LD geo.
class SeccionUbicacion extends StatefulWidget {
  const SeccionUbicacion({
    super.key,
    required this.initialDireccion,
    required this.initialCoordenadas,
    required this.onDireccionChanged,
    required this.onCoordenadasChanged,
  });

  final DireccionEstructurada? initialDireccion;
  final Coordenadas? initialCoordenadas;
  final ValueChanged<DireccionEstructurada> onDireccionChanged;
  final ValueChanged<Coordenadas?> onCoordenadasChanged;

  @override
  State<SeccionUbicacion> createState() => _SeccionUbicacionState();
}

class _SeccionUbicacionState extends State<SeccionUbicacion> {
  late final TextEditingController _calle;
  late final TextEditingController _numero;
  late final TextEditingController _unidad;
  late final TextEditingController _comuna;
  late final TextEditingController _region;
  late final TextEditingController _codigoPostal;
  late final TextEditingController _referencia;
  late final TextEditingController _lat;
  late final TextEditingController _lng;

  @override
  void initState() {
    super.initState();
    final d = widget.initialDireccion;
    final c = widget.initialCoordenadas;
    _calle = TextEditingController(text: d?.calle ?? '');
    _numero = TextEditingController(text: d?.numero ?? '');
    _unidad = TextEditingController(text: d?.unidad ?? '');
    _comuna = TextEditingController(text: d?.comuna ?? 'Puerto Natales');
    _region = TextEditingController(text: d?.region ?? 'Magallanes');
    _codigoPostal = TextEditingController(text: d?.codigoPostal ?? '');
    _referencia = TextEditingController(text: d?.referencia ?? '');
    _lat = TextEditingController(
      text: c != null && c.isValid ? c.lat.toString() : '',
    );
    _lng = TextEditingController(
      text: c != null && c.isValid ? c.lng.toString() : '',
    );
    for (final ctrl in [
      _calle,
      _numero,
      _unidad,
      _comuna,
      _region,
      _codigoPostal,
      _referencia,
    ]) {
      ctrl.addListener(_emitirDireccion);
    }
    _lat.addListener(_emitirCoordenadas);
    _lng.addListener(_emitirCoordenadas);
  }

  void _emitirDireccion() {
    widget.onDireccionChanged(
      DireccionEstructurada(
        calle: _calle.text.trim().isEmpty ? null : _calle.text.trim(),
        numero: _numero.text.trim().isEmpty ? null : _numero.text.trim(),
        unidad: _unidad.text.trim().isEmpty ? null : _unidad.text.trim(),
        comuna: _comuna.text.trim().isEmpty ? null : _comuna.text.trim(),
        region: _region.text.trim().isEmpty ? null : _region.text.trim(),
        codigoPostal: _codigoPostal.text.trim().isEmpty
            ? null
            : _codigoPostal.text.trim(),
        referencia: _referencia.text.trim().isEmpty
            ? null
            : _referencia.text.trim(),
      ),
    );
  }

  void _emitirCoordenadas() {
    final lat = double.tryParse(_lat.text.trim());
    final lng = double.tryParse(_lng.text.trim());
    if (lat == null || lng == null) {
      widget.onCoordenadasChanged(null);
      return;
    }
    widget.onCoordenadasChanged(Coordenadas(lat: lat, lng: lng));
  }

  @override
  void dispose() {
    _calle.dispose();
    _numero.dispose();
    _unidad.dispose();
    _comuna.dispose();
    _region.dispose();
    _codigoPostal.dispose();
    _referencia.dispose();
    _lat.dispose();
    _lng.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Dirección del local', style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          'Datos postales consistentes con Google Business y JSON-LD.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              flex: 3,
              child: TextField(
                controller: _calle,
                decoration: const InputDecoration(labelText: 'Calle'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _numero,
                decoration: const InputDecoration(labelText: 'Número'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _unidad,
                decoration: const InputDecoration(labelText: 'Unidad'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _comuna,
                decoration: const InputDecoration(labelText: 'Comuna'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _region,
                decoration: const InputDecoration(labelText: 'Región'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _codigoPostal,
          decoration: const InputDecoration(labelText: 'Código postal'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _referencia,
          decoration: const InputDecoration(
            labelText: 'Referencia (opcional)',
            hintText: 'Frente a la plaza, al lado del supermercado',
          ),
        ),
        const SizedBox(height: 24),
        Text('Coordenadas (opcional)', style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          'Ubicación precisa para Google Maps y SEO local.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _lat,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Latitud',
                  hintText: '-51.7269',
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _lng,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Longitud',
                  hintText: '-72.5042',
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
