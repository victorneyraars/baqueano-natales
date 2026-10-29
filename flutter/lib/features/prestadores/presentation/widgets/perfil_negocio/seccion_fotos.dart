import 'package:flutter/material.dart';
import 'package:baqueano_natales/features/prestadores/domain/perfil_negocio.dart';

/// Sección: fotos del negocio (logo, portada, galería).
///
/// MVP: solo muestra las URLs actuales + hint para editar desde web/panel.
/// En próxima fase: upload a R2 con presigned URLs.
class SeccionFotos extends StatelessWidget {
  const SeccionFotos({super.key, required this.initialValue});

  final FotosNegocio? initialValue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final logo = initialValue?.logo512;
    final portada = initialValue?.portada;
    final galeria = initialValue?.galeria ?? const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Fotos y logo', style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          'Subida de fotos disponible desde el panel web.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        _fila(theme, 'Logo 512x512', logo),
        const SizedBox(height: 8),
        _fila(theme, 'Portada', portada),
        const SizedBox(height: 8),
        _fila(
          theme,
          'Galería (${galeria.length} fotos)',
          galeria.isNotEmpty ? galeria.first.url : null,
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
