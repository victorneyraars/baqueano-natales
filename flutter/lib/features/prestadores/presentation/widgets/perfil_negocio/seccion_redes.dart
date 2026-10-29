import 'package:flutter/material.dart';
import 'package:baqueano_natales/features/prestadores/domain/perfil_negocio.dart';

/// Sección: redes sociales y directorios.
class SeccionRedes extends StatefulWidget {
  const SeccionRedes({
    super.key,
    required this.initialValue,
    required this.onChanged,
  });

  final RedesSocialesPerfil? initialValue;
  final ValueChanged<RedesSocialesPerfil> onChanged;

  @override
  State<SeccionRedes> createState() => _SeccionRedesState();
}

class _SeccionRedesState extends State<SeccionRedes> {
  late final Map<String, TextEditingController> _ctrls;

  @override
  void initState() {
    super.initState();
    final r = widget.initialValue;
    _ctrls = {
      'instagram': TextEditingController(text: r?.instagram ?? ''),
      'facebook': TextEditingController(text: r?.facebook ?? ''),
      'tiktok': TextEditingController(text: r?.tiktok ?? ''),
      'youtube': TextEditingController(text: r?.youtube ?? ''),
      'google_business': TextEditingController(text: r?.googleBusiness ?? ''),
      'tripadvisor': TextEditingController(text: r?.tripadvisor ?? ''),
    };
    for (final c in _ctrls.values) {
      c.addListener(_emitir);
    }
  }

  void _emitir() {
    String? v(String k) {
      final t = _ctrls[k]!.text.trim();
      return t.isEmpty ? null : t;
    }

    widget.onChanged(
      RedesSocialesPerfil(
        instagram: v('instagram'),
        facebook: v('facebook'),
        tiktok: v('tiktok'),
        youtube: v('youtube'),
        googleBusiness: v('google_business'),
        tripadvisor: v('tripadvisor'),
      ),
    );
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labels = {
      'instagram': 'Instagram',
      'facebook': 'Facebook',
      'tiktok': 'TikTok',
      'youtube': 'YouTube',
      'google_business': 'Google Business',
      'tripadvisor': 'TripAdvisor',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Redes sociales y directorios',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(
          'Consumidas por Schema.org sameAs y Open Graph.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        for (final k in labels.keys) ...[
          TextField(
            controller: _ctrls[k],
            decoration: InputDecoration(labelText: labels[k]),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}
