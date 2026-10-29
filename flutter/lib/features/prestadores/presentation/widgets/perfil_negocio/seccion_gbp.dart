import 'package:flutter/material.dart';

/// Sección: datos de Google Business Profile.
///
/// StatefulWidget con TextEditingController para evitar problemas de
/// layout cuando se expande dentro de ExpansionTile(maintainState: true).
class SeccionGbp extends StatefulWidget {
  const SeccionGbp({
    super.key,
    required this.initialPlaceId,
    required this.initialMapsUrl,
    required this.onPlaceIdChanged,
    required this.onMapsUrlChanged,
  });

  final String? initialPlaceId;
  final String? initialMapsUrl;
  final ValueChanged<String?> onPlaceIdChanged;
  final ValueChanged<String?> onMapsUrlChanged;

  @override
  State<SeccionGbp> createState() => _SeccionGbpState();
}

class _SeccionGbpState extends State<SeccionGbp> {
  late final TextEditingController _placeIdCtrl;
  late final TextEditingController _mapsUrlCtrl;

  @override
  void initState() {
    super.initState();
    _placeIdCtrl = TextEditingController(text: widget.initialPlaceId ?? '');
    _mapsUrlCtrl = TextEditingController(text: widget.initialMapsUrl ?? '');
    _placeIdCtrl.addListener(_emit);
    _mapsUrlCtrl.addListener(_emit);
  }

  void _emit() {
    widget.onPlaceIdChanged(
      _placeIdCtrl.text.trim().isEmpty ? null : _placeIdCtrl.text.trim(),
    );
    widget.onMapsUrlChanged(
      _mapsUrlCtrl.text.trim().isEmpty ? null : _mapsUrlCtrl.text.trim(),
    );
  }

  @override
  void dispose() {
    _placeIdCtrl.dispose();
    _mapsUrlCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Google Business Profile', style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          'Vinculá el negocio para sincronización automática de NAP.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _placeIdCtrl,
          decoration: const InputDecoration(
            labelText: 'Google Place ID',
            hintText: 'ChIJ...',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _mapsUrlCtrl,
          decoration: const InputDecoration(
            labelText: 'URL de Google Maps',
            hintText: 'https://g.page/...',
          ),
        ),
      ],
    );
  }
}
