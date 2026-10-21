/// Pantalla para calificar una orden entregada (M6).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:baqueano_natales/core/network/api_exceptions.dart';
import 'package:baqueano_natales/features/oficios/data/oficios_providers.dart';

class CrearReviewScreen extends ConsumerStatefulWidget {
  const CrearReviewScreen({super.key, required this.ordenId, this.numeroOrden});

  final String ordenId;
  final String? numeroOrden;

  @override
  ConsumerState<CrearReviewScreen> createState() => _CrearReviewScreenState();
}

class _CrearReviewScreenState extends ConsumerState<CrearReviewScreen> {
  int _rating = 5;
  final _comentarioCtrl = TextEditingController();
  bool _enviando = false;

  @override
  void dispose() {
    _comentarioCtrl.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    setState(() => _enviando = true);
    try {
      final repo = ref.read(oficiosRepositoryProvider);
      await repo.crearReview(
        widget.ordenId,
        rating: _rating,
        comentario: _comentarioCtrl.text.trim().isEmpty
            ? null
            : _comentarioCtrl.text.trim(),
      );
      ref.invalidate(miReviewProvider(widget.ordenId));
      ref.invalidate(miOrdenDetalleProvider(widget.ordenId));
      messenger.showSnackBar(
        const SnackBar(content: Text('Gracias por tu calificacion!')),
      );
      navigator.pop(true);
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

    return Scaffold(
      appBar: AppBar(title: const Text('Calificar servicio')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (widget.numeroOrden != null)
            Text(
              'Orden ${widget.numeroOrden}',
              style: theme.textTheme.titleMedium,
            ),
          const SizedBox(height: 8),
          Text('Como fue tu experiencia?', style: theme.textTheme.bodyLarge),
          const SizedBox(height: 20),
          _SelectorEstrellas(
            rating: _rating,
            onChanged: (v) => setState(() => _rating = v),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              _etiquetaRating(_rating),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _comentarioCtrl,
            maxLines: 5,
            maxLength: 2000,
            decoration: const InputDecoration(
              labelText: 'Comentario (opcional)',
              hintText: 'Conta como fue tu experiencia...',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _enviando ? null : _enviar,
            icon: _enviando
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_outlined),
            label: Text(_enviando ? 'Enviando...' : 'Enviar calificacion'),
          ),
        ],
      ),
    );
  }

  String _etiquetaRating(int rating) {
    switch (rating) {
      case 1:
        return 'Muy malo';
      case 2:
        return 'Malo';
      case 3:
        return 'Regular';
      case 4:
        return 'Bueno';
      case 5:
        return 'Excelente';
      default:
        return '';
    }
  }
}

// =========================================================
// Selector de estrellas
// =========================================================
class _SelectorEstrellas extends StatelessWidget {
  const _SelectorEstrellas({required this.rating, required this.onChanged});

  final int rating;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (i) {
        final estrella = i + 1;
        return IconButton(
          iconSize: 44,
          onPressed: () => onChanged(estrella),
          icon: Icon(
            estrella <= rating ? Icons.star : Icons.star_border,
            color: estrella <= rating ? Colors.amber.shade600 : scheme.outline,
          ),
        );
      }),
    );
  }
}
