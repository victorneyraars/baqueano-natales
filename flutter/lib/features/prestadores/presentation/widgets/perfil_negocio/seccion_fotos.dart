import 'package:flutter/material.dart';

import 'package:baqueano_natales/core/network/dio_client.dart';
import 'package:baqueano_natales/features/prestadores/domain/perfil_negocio.dart';

/// Sección: fotos y logo del negocio.
///
/// Logo: 3 opciones (kit, URL propia, vacío).
/// Portada: 3 opciones (kit og-image, URL propia, vacío).
/// Galería: read-only por ahora (upload en próxima fase).
class SeccionFotos extends StatefulWidget {
  const SeccionFotos({
    super.key,
    required this.initialValue,
    this.slug,
    required this.onChanged,
  });

  final FotosNegocio? initialValue;
  final String? slug;
  final ValueChanged<FotosNegocio> onChanged;

  @override
  State<SeccionFotos> createState() => _SeccionFotosState();
}

class _SeccionFotosState extends State<SeccionFotos> {
  late final TextEditingController _logoCtrl;
  late final TextEditingController _portadaCtrl;
  FotosNegocio _fotos = const FotosNegocio();

  @override
  void initState() {
    super.initState();
    _fotos = widget.initialValue ?? const FotosNegocio();
    _logoCtrl = TextEditingController(text: _fotos.logo512 ?? '');
    _portadaCtrl = TextEditingController(text: _fotos.portada ?? '');
    _logoCtrl.addListener(_emit);
    _portadaCtrl.addListener(_emit);
  }

  void _emit() {
    _fotos = FotosNegocio(
      logo512: _logoCtrl.text.trim().isEmpty ? null : _logoCtrl.text.trim(),
      portada: _portadaCtrl.text.trim().isEmpty
          ? null
          : _portadaCtrl.text.trim(),
      galeria: _fotos.galeria,
    );
    widget.onChanged(_fotos);
  }

  String get _brandBaseUrl {
    final baseUrl = DioClient.instance.options.baseUrl;
    final slug = widget.slug ?? '';
    return '$baseUrl/api/v1/public/brand/$slug';
  }

  void _usarLogoDelKit() {
    setState(() {
      _logoCtrl.text = '$_brandBaseUrl/logo.png?size=512';
    });
  }

  void _usarPortadaDelKit() {
    setState(() {
      _portadaCtrl.text = '$_brandBaseUrl/cover.png';
    });
  }

  void _limpiarLogo() => setState(() => _logoCtrl.clear());
  void _limpiarPortada() => setState(() => _portadaCtrl.clear());

  @override
  void dispose() {
    _logoCtrl.dispose();
    _portadaCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasSlug = widget.slug != null && widget.slug!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Logo', style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          'Usá el logo del kit de marca o pegá una URL propia.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        _preview(theme, _logoCtrl.text.trim(), 60),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: hasSlug ? _usarLogoDelKit : null,
                icon: const Icon(Icons.palette),
                label: const Text('Usar logo del kit'),
              ),
            ),
            if (_logoCtrl.text.isNotEmpty) ...[
              const SizedBox(width: 8),
              IconButton.outlined(
                onPressed: _limpiarLogo,
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Quitar logo',
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _logoCtrl,
          decoration: const InputDecoration(
            labelText: 'URL del logo (opcional)',
            hintText: 'https://...',
          ),
        ),
        const SizedBox(height: 24),
        Text('Portada', style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          'Banner de 1200x630. Se usa al compartir la web en redes.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        _preview(theme, _portadaCtrl.text.trim(), 80),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: hasSlug ? _usarPortadaDelKit : null,
                icon: const Icon(Icons.image_outlined),
                label: const Text('Usar portada del kit'),
              ),
            ),
            if (_portadaCtrl.text.isNotEmpty) ...[
              const SizedBox(width: 8),
              IconButton.outlined(
                onPressed: _limpiarPortada,
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Quitar portada',
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _portadaCtrl,
          decoration: const InputDecoration(
            labelText: 'URL de la portada (opcional)',
            hintText: 'https://...',
          ),
        ),
        const SizedBox(height: 24),
        Text('Galería', style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          'Fotos del local y la flota. Upload disponible próximamente.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            child: Icon(
              _fotos.galeria.isEmpty ? Icons.image_not_supported : Icons.image,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          title: const Text('Fotos (" + _fotos.galeria.length.toString() + ")'),
          subtitle: const Text('Sin cargar (próxima fase)'),
        ),
      ],
    );
  }

  Widget _preview(ThemeData theme, String url, double height) {
    if (url.isEmpty) return const SizedBox.shrink();
    return Center(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Image.network(
          url,
          height: height,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stack) => Icon(
            Icons.broken_image,
            size: height / 2,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
