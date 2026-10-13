/// Seccion de review en el detalle de una orden (M6).
///
/// Estados:
/// - Orden no entregada -> no muestra nada.
/// - Orden entregada sin review -> CTA "Calificar servicio".
/// - Orden entregada con review -> estrellas + comentario + (respuesta).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:baqueano_natales/features/oficios/data/oficios_providers.dart';
import 'package:baqueano_natales/features/oficios/domain/orden_trabajo.dart';
import 'package:baqueano_natales/features/prestadores/domain/review.dart';

class ReviewSeccion extends ConsumerWidget {
  const ReviewSeccion({super.key, required this.orden});

  final OrdenTrabajo orden;

  bool get _puedeCalificar =>
      orden.estado == EstadoOrden.entregado ||
      orden.estado == EstadoOrden.garantia;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!_puedeCalificar) return const SizedBox.shrink();

    final async = ref.watch(miReviewProvider(orden.id));

    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (review) {
        if (review == null) {
          return _CardCalificar(
            ordenId: orden.id,
            numeroOrden: orden.numero,
          );
        }
        return _CardReview(review: review);
      },
    );
  }
}

// =========================================================
// Card: invitar a calificar
// =========================================================
class _CardCalificar extends StatelessWidget {
  const _CardCalificar({required this.ordenId, required this.numeroOrden});

  final String ordenId;
  final String numeroOrden;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.star_outline,
                    color: theme.colorScheme.onPrimaryContainer),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Califica este servicio',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Tu opinion ayuda a otros clientes y al taller a mejorar.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () =>
                  context.push('/mis-ordenes/$ordenId/review'),
              icon: const Icon(Icons.rate_review_outlined),
              label: const Text('Calificar'),
            ),
          ],
        ),
      ),
    );
  }
}

// =========================================================
// Card: review existente
// =========================================================
class _CardReview extends StatelessWidget {
  const _CardReview({required this.review});

  final Review review;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.star, color: Colors.amber.shade600),
                const SizedBox(width: 8),
                Text(
                  'Tu calificacion',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _EstrellasEstaticas(rating: review.rating),
            if (review.comentario != null &&
                review.comentario!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(review.comentario!),
            ],
            if (review.tieneRespuesta) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Respuesta del taller',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(review.respuestaPrestador!),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EstrellasEstaticas extends StatelessWidget {
  const _EstrellasEstaticas({required this.rating});

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
            size: 20,
          ),
        );
      }),
    );
  }
}
