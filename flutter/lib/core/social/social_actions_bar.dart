import 'package:flutter/material.dart';
import 'package:baqueano_natales/core/social/share_sheet.dart';
import 'package:baqueano_natales/core/social/shareable_entity.dart';

/// Barra de acciones sociales reutilizable.
///
/// Sirve para CUALQUIER entidad: turnos, prestadores, comercios, productos, etc.
class SocialActionsBar extends StatelessWidget {
  const SocialActionsBar({
    super.key,
    required this.entity,
    this.onReview,
    this.onFavorite,
    this.isFavorite = false,
    this.showShare = true,
    this.showReview = true,
    this.title = '¿Te gustó?',
    this.subtitle = 'Compartilo con tus amigos y sumá tu experiencia.',
  });

  final ShareableEntity entity;
  final VoidCallback? onReview;
  final VoidCallback? onFavorite;
  final bool isFavorite;
  final bool showShare;
  final bool showReview;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasShare = showShare;
    final hasReview = showReview && onReview != null;
    final hasFavorite = onFavorite != null;

    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.thumb_up_alt_outlined,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            if (hasShare && hasReview)
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => showShareSheet(context, entity),
                      icon: const Icon(Icons.share, size: 18),
                      label: const Text('Compartir'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onReview,
                      icon: const Icon(Icons.star_outline, size: 18),
                      label: const Text('Reseñar'),
                    ),
                  ),
                ],
              )
            else if (hasShare)
              FilledButton.icon(
                onPressed: () => showShareSheet(context, entity),
                icon: const Icon(Icons.share, size: 18),
                label: const Text('Compartir'),
              )
            else if (hasReview)
              OutlinedButton.icon(
                onPressed: onReview,
                icon: const Icon(Icons.star_outline, size: 18),
                label: const Text('Reseñar'),
              ),
            if (hasFavorite) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: onFavorite,
                icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border),
                label: Text(isFavorite ? 'Guardado' : 'Guardar'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
