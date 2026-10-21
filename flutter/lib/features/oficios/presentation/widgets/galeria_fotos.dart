/// Grid de fotos de una orden (reusable).
///
/// Uso tipico: en el detalle de la orden, mostrar el grid con las
/// ultimas N fotos + un boton "ver todas" que abre la pantalla
/// completa (`GaleriaFotosScreen`).
library;

import 'package:flutter/material.dart';

import 'package:baqueano_natales/features/oficios/domain/orden_foto.dart';
import 'package:baqueano_natales/features/oficios/presentation/widgets/foto_thumb.dart';

class GaleriaFotos extends StatelessWidget {
  const GaleriaFotos({
    super.key,
    required this.fotos,
    this.maxFotos,
    this.onVerTodas,
    this.onFotoTap,
  });

  final List<OrdenFoto> fotos;

  /// Si se especifica, muestra solo las primeras N fotos.
  final int? maxFotos;

  /// Callback opcional para "ver todas".
  final VoidCallback? onVerTodas;

  /// Callback al tocar una foto (ej. abrir el visor).
  final void Function(OrdenFoto foto)? onFotoTap;

  @override
  Widget build(BuildContext context) {
    if (fotos.isEmpty) {
      return const SizedBox.shrink();
    }

    final visibles = maxFotos != null && fotos.length > maxFotos!
        ? fotos.take(maxFotos!).toList()
        : fotos;
    final restantes = fotos.length - visibles.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            children: [
              Text(
                'Fotos (${fotos.length})',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              if (restantes > 0 && onVerTodas != null)
                TextButton.icon(
                  onPressed: onVerTodas,
                  icon: const Icon(Icons.photo_library_outlined, size: 18),
                  label: Text('Ver todas (+$restantes)'),
                ),
            ],
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 6,
            mainAxisSpacing: 6,
            childAspectRatio: 1,
          ),
          itemCount: visibles.length,
          itemBuilder: (context, i) {
            final f = visibles[i];
            return FotoThumb(
              foto: f,
              onTap: onFotoTap != null ? () => onFotoTap!(f) : null,
            );
          },
        ),
      ],
    );
  }
}
