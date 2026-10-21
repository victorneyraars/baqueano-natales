/// Pantalla del prestador: mis resenas + responder (M6).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:baqueano_natales/core/network/api_exceptions.dart';
import 'package:baqueano_natales/features/prestadores/data/prestador_providers.dart';
import 'package:baqueano_natales/features/prestadores/domain/review.dart';

class ReviewsPrestadorScreen extends ConsumerWidget {
  const ReviewsPrestadorScreen({super.key, required this.prestadorId});

  final String prestadorId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncPrestador = ref.watch(miPrestadorDetalleProvider(prestadorId));

    return Scaffold(
      appBar: AppBar(title: const Text('Resenas')),
      body: asyncPrestador.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Error: $e'),
          ),
        ),
        data: (prestador) =>
            _ContenidoReviews(prestadorId: prestadorId, slug: prestador.slug),
      ),
    );
  }
}

class _ContenidoReviews extends ConsumerStatefulWidget {
  const _ContenidoReviews({required this.prestadorId, required this.slug});

  final String prestadorId;
  final String slug;

  @override
  ConsumerState<_ContenidoReviews> createState() => _ContenidoReviewsState();
}

class _ContenidoReviewsState extends ConsumerState<_ContenidoReviews> {
  @override
  Widget build(BuildContext context) {
    final async = ref.watch(reviewsPrestadorProvider(widget.slug));

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Error: $e'),
        ),
      ),
      data: (data) {
        if (data.total == 0) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                'Aun no tienes resenas. Cuando tus clientes califiquen '
                'tus trabajos, apareceran aqui.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(reviewsPrestadorProvider(widget.slug));
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _ResumenResenas(data: data),
              const SizedBox(height: 16),
              for (final item in data.items)
                _ReviewCardConResponder(
                  item: item,
                  prestadorId: widget.prestadorId,
                  onRefrescar: () =>
                      ref.invalidate(reviewsPrestadorProvider(widget.slug)),
                ),
            ],
          ),
        );
      },
    );
  }
}

// =========================================================
// Resumen (promedio + total)
// =========================================================
class _ResumenResenas extends StatelessWidget {
  const _ResumenResenas({required this.data});

  final ReviewListResponse data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Text(
              data.promedio.toStringAsFixed(1),
              style: theme.textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: List.generate(5, (i) {
                      final e = i + 1;
                      return Icon(
                        e <= data.promedio.round()
                            ? Icons.star
                            : Icons.star_border,
                        color: Colors.amber.shade700,
                        size: 20,
                      );
                    }),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${data.total} ${data.total == 1 ? "resena" : "resenas"}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =========================================================
// Card con boton "Responder"
// =========================================================
class _ReviewCardConResponder extends ConsumerStatefulWidget {
  const _ReviewCardConResponder({
    required this.item,
    required this.prestadorId,
    required this.onRefrescar,
  });

  final ReviewItem item;
  final String prestadorId;
  final VoidCallback onRefrescar;

  @override
  ConsumerState<_ReviewCardConResponder> createState() =>
      _ReviewCardConResponderState();
}

class _ReviewCardConResponderState
    extends ConsumerState<_ReviewCardConResponder> {
  bool _enviando = false;

  Future<void> _responder() async {
    final messenger = ScaffoldMessenger.of(context);
    final texto = await showDialog<String>(
      context: context,
      builder: (ctx) => _DialogResponder(
        nombreCliente: widget.item.clienteNombre ?? 'Cliente',
      ),
    );
    if (texto == null || texto.trim().isEmpty) return;

    setState(() => _enviando = true);
    try {
      final repo = ref.read(prestadorRepositoryProvider);
      await repo.responderReview(
        widget.prestadorId,
        widget.item.id,
        texto.trim(),
      );
      widget.onRefrescar();
      messenger.showSnackBar(
        const SnackBar(content: Text('Respuesta enviada')),
      );
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final item = widget.item;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
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
                  '${item.createdAt.day}/${item.createdAt.month}/'
                  '${item.createdAt.year}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: List.generate(5, (i) {
                final e = i + 1;
                return Padding(
                  padding: const EdgeInsets.only(right: 2),
                  child: Icon(
                    e <= item.rating ? Icons.star : Icons.star_border,
                    color: e <= item.rating
                        ? Colors.amber.shade600
                        : theme.colorScheme.outline,
                    size: 16,
                  ),
                );
              }),
            ),
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
                      'Tu respuesta',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(item.respuestaPrestador!),
                  ],
                ),
              ),
            ] else ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _enviando ? null : _responder,
                icon: _enviando
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.reply_outlined, size: 18),
                label: Text(_enviando ? 'Enviando...' : 'Responder'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// =========================================================
// Dialogo responder
// =========================================================
class _DialogResponder extends StatefulWidget {
  const _DialogResponder({required this.nombreCliente});

  final String nombreCliente;

  @override
  State<_DialogResponder> createState() => _DialogResponderState();
}

class _DialogResponderState extends State<_DialogResponder> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Responder a ${widget.nombreCliente}'),
      content: TextField(
        controller: _ctrl,
        maxLines: 4,
        maxLength: 2000,
        decoration: const InputDecoration(
          hintText: 'Gracias por tu comentario...',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _ctrl.text),
          child: const Text('Enviar'),
        ),
      ],
    );
  }
}
