import 'package:flutter/material.dart';

import 'package:baqueano_natales/core/network/dio_client.dart';
import 'package:baqueano_natales/features/prestadores/domain/perfil_negocio.dart';

/// Sección: fotos y logo del negocio.
///
/// Permite cargar el logo de 3 formas:
/// 1. Botón "Usar logo del kit" (auto-rellena con el endpoint público).
/// 2. Pegar una URL propia manualmente.
/// 3. Dejar vacío (la web usa fallback a /logo.png local).
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
  FotosNegocio _fotos = const FotosNegocio();

  @override
  void initState() {
    super.initState();
    _fotos = widget.initialValue ?? const FotosNegocio();
    _logoCtrl = TextEditingController(text: _fotos.logo512 ?? '');
    _logoCtrl.addListener(_emit);
  }

  void _emit() {
    _fotos = FotosNegocio(
      logo512: _logoCtrl.text.trim().isEmpty ? null : _logoCtrl.text.trim(),
      portada: _fotos.portada,
      galeria: _fotos.galeria,
    );
    widget.onChanged(_fotos);
  }

  String get _logoKitUrl {
    final baseUrl = DioClient.instance.options.baseUrl;
    final slug = widget.slug ?? '';
    return '$baseUrl/api/v1/public/brand/$slug/logo.png?size=512';
  }

  void _usarLogoDelKit() {
    setState(() {
      _logoCtrl.text = _logoKitUrl;
    });
  }

  void _limpiarLogo() {
    setState(() {
      _logoCtrl.clear();
    });
  }

  @override
  void dispose() {
    _logoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final logoActual = _logoCtrl.text.trim();
    final hasSlug = widget.slug != null && widget.slug!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Fotos y logo', style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          'Usá el logo del kit de marca o pegá una URL propia.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        if (logoActual.isNotEmpty) ...[
          Center(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Image.network(
                logoActual,
                height: 80,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stack) =>
                    const Icon(Icons.broken_image, size: 40),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: hasSlug ? _usarLogoDelKit : null,
                icon: const Icon(Icons.palette),
                label: const Text('Usar logo del kit'),
              ),
            ),
            if (logoActual.isNotEmpty) ...[
              const SizedBox(width: 8),
              IconButton.outlined(
                onPressed: _limpiarLogo,
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Quitar logo',
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _logoCtrl,
          decoration: const InputDecoration(
            labelText: 'URL del logo (opcional)',
            hintText: 'https://...',
            helperText: 'Pegá la URL o usá el botón de arriba',
          ),
        ),
        const SizedBox(height: 24),
        _fila(theme, 'Portada', _fotos.portada),
        const SizedBox(height: 8),
        _fila(
          theme,
          'Galería',
          _fotos.galeria.isNotEmpty ? _fotos.galeria.first.url : null,
        ),
      ],
    );
  }

  Widget _fila(ThemeData theme, String label, String? url) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        child: Icon(
          url == null ? Icons.image_not_supported : Icons.image,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      title: Text(label),
      subtitle: Text(
        url ?? 'Sin cargar',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
