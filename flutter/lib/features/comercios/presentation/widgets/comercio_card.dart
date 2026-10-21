/// Card reutilizable para mostrar un comercio en listados.
library;

import 'package:flutter/material.dart';

import 'package:baqueano_natales/features/comercios/domain/comercio.dart';

class ComercioCard extends StatelessWidget {
  const ComercioCard({super.key, required this.comercio, this.onTap});

  final Comercio comercio;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- Portada o placeholder ---
            if (comercio.portadaUrl != null)
              Image.network(
                comercio.portadaUrl!,
                height: 110,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _placeholderPortada(theme),
              )
            else
              _placeholderPortada(theme),

            // --- Info ---
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Logo + nombre + categoría
                  Row(
                    children: [
                      _logo(theme),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    comercio.nombre,
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (comercio.destacado) ...[
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.star,
                                    size: 18,
                                    color: Colors.amber.shade700,
                                  ),
                                ],
                              ],
                            ),
                            if (comercio.categoria != null)
                              Text(
                                comercio.categoria!.nombre,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  if (comercio.descripcionCorta != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      comercio.descripcionCorta!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],

                  const SizedBox(height: 8),

                  // Dirección
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 14,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          comercio.direccion,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Badges delivery/retiro + rating
                  Row(
                    children: [
                      if (comercio.aceptaDelivery)
                        _badge(theme, Icons.delivery_dining, 'Delivery'),
                      if (comercio.aceptaDelivery && comercio.aceptaRetiro)
                        const SizedBox(width: 6),
                      if (comercio.aceptaRetiro)
                        _badge(theme, Icons.shopping_bag_outlined, 'Retiro'),
                      const Spacer(),
                      if (comercio.totalResenas > 0)
                        Row(
                          children: [
                            Icon(
                              Icons.star,
                              size: 14,
                              color: Colors.amber.shade700,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '${comercio.ratingLegible} (${comercio.totalResenas})',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholderPortada(ThemeData theme) {
    return Container(
      height: 90,
      color: theme.colorScheme.primaryContainer,
      child: Center(
        child: Icon(
          Icons.storefront,
          size: 42,
          color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.6),
        ),
      ),
    );
  }

  Widget _logo(ThemeData theme) {
    if (comercio.logoUrl != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          comercio.logoUrl!,
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _logoPlaceholder(theme),
        ),
      );
    }
    return _logoPlaceholder(theme);
  }

  Widget _logoPlaceholder(ThemeData theme) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.storefront,
        color: theme.colorScheme.onPrimaryContainer,
      ),
    );
  }

  Widget _badge(ThemeData theme, IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: theme.colorScheme.onSecondaryContainer),
          const SizedBox(width: 3),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSecondaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}
