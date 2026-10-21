/// Thumbnail de una foto de orden (o cualquier imagen autenticada).
///
/// Usa `AuthedImage` para bajar los bytes con JWT. La variante a
/// mostrar se elige con `variante` (default `thumb`, 256px).
///
/// Nota: si no se pasa `width`/`height`, el widget se estira para
/// llenar el espacio del padre (util dentro de celdas de GridView).
library;

import 'package:flutter/material.dart';

import 'package:baqueano_natales/core/network/authed_image_provider.dart';
import 'package:baqueano_natales/features/oficios/domain/orden_foto.dart';

class FotoThumb extends StatelessWidget {
  const FotoThumb({
    super.key,
    required this.foto,
    this.variante = 'thumb',
    this.width,
    this.height,
    this.borderRadius = 8,
    this.fit = BoxFit.cover,
    this.onTap,
    this.onLongPress,
  });

  final OrdenFoto foto;

  /// Variante a mostrar: `thumb`, `medium` u `original`.
  final String variante;

  /// Si es null, el widget se estira para llenar el padre.
  final double? width;
  final double? height;

  final double borderRadius;
  final BoxFit fit;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final url =
        foto.urlVariante(variante) ?? foto.urlMedium ?? foto.urlOriginal;
    final radius = BorderRadius.circular(borderRadius);

    return ClipRRect(
      borderRadius: radius,
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          width: width ?? double.infinity,
          height: height ?? double.infinity,
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: url == null
              ? _placeholder(context)
              : Image(
                  image: AuthedImage(url: url),
                  fit: fit,
                  gaplessPlayback: true,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return _placeholder(context);
                  },
                  errorBuilder: (context, error, _) =>
                      _placeholder(context, error: true),
                ),
        ),
      ),
    );
  }

  Widget _placeholder(BuildContext context, {bool error = false}) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Icon(
        error ? Icons.broken_image_outlined : Icons.image_outlined,
        color: scheme.outline,
        size: 28,
      ),
    );
  }
}
