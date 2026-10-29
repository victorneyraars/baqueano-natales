import 'package:flutter/material.dart';

/// Sección: datos de Google Business Profile.
class SeccionGbp extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Google Business Profile', style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          'Vinculá el negocio para sincronización automática de NAP.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        TextFormField(
          initialValue: initialPlaceId,
          decoration: const InputDecoration(
            labelText: 'Google Place ID',
            hintText: 'ChIJ...',
          ),
          onChanged: (v) =>
              onPlaceIdChanged(v.trim().isEmpty ? null : v.trim()),
        ),
        const SizedBox(height: 12),
        TextFormField(
          initialValue: initialMapsUrl,
          decoration: const InputDecoration(
            labelText: 'URL de Google Maps',
            hintText: 'https://g.page/...',
          ),
          onChanged: (v) =>
              onMapsUrlChanged(v.trim().isEmpty ? null : v.trim()),
        ),
      ],
    );
  }
}
