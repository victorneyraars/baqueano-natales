/// Lista de reviews de un prestador (M6).
///
/// Widget reusable que consume `reviewsPrestadorProvider(slug)`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:baqueano_natales/features/prestadores/data/prestador_providers.dart';
import 'package:baqueano_natales/features/prestadores/domain/review.dart';

class ReviewList extends ConsumerWidget {
  const ReviewList({super.key, required this.slug});

  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final async = ref.watch(reviewsPrestadorProvider(slug));

    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => const SizedBox.shrink(),
      data: (data) {
        if (data.total == 0) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.star_border, color: theme.colorScheme.outline),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Aun no hay resenas. Se el primero en calificar.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.star, color: Colors.amber.shade600),
                const SizedBox(width: 6),
                Text(
                  data.promedio.toStringAsFixed(1),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '(${data.total} ${data.total == 1 ? "resena" : "resenas"})',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final r in data.items) _ReviewItemCard(item: r),
          ],
        );
      },
    );
  }
}

class _ReviewItemCard extends StatelessWidget {
  const _ReviewItemCard({required this.item});

  final ReviewItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.clienteNombre ?? 'Cliente',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  _fechaCorta(item.createdAt),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            _EstrellasMini(rating: item.rating),
            if (item.comentario != null && item.comentario!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(item.comentario!),
            ],
            if (item.tieneRespuesta) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Respuesta del taller',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(item.respuestaPrestador!),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _fechaCorta(DateTime d) => '${d.day}/${d.month}/${d.year}';
}

class _EstrellasMini extends StatelessWidget {
  const _EstrellasMini({required this.rating});

  final int rating;

  @override
  Widget build(BuildContext context) {
    final outline = Theme.of(context).colorScheme.outline;
    return Row(
      children: List.generate(5, (i) {
        final estrella = i + 1;
        return Padding(
          padding: const EdgeInsets.only(right: 2),
          child: Icon(
            estrella <= rating ? Icons.star : Icons.star_border,
            color: estrella <= rating ? Colors.amber.shade600 : outline,
            size: 16,
          ),
        );
      }),
    );
  }
}
