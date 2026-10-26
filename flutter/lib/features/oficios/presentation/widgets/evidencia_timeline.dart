import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:baqueano_natales/features/oficios/data/oficios_providers.dart';
import 'package:baqueano_natales/features/oficios/domain/media_asset_turno.dart';

/// Timeline horizontal de evidencia (fotos/videos) de un turno.
///
/// Muestra una fila por fase (ingreso, diagnostico, en_proceso, entrega,
/// reclamo, otro) con los assets correspondientes.
class EvidenciaTimeline extends ConsumerWidget {
  const EvidenciaTimeline({super.key, required this.turnoId});

  final String turnoId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncMedia = ref.watch(mediaDeTurnoProvider(turnoId));
    final theme = Theme.of(context);

    return asyncMedia.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(16),
        child: Text('Error al cargar evidencia: $e'),
      ),
      data: (assets) {
        if (assets.isEmpty) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    Icons.camera_alt_outlined,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'El prestador aun no ha subido evidencia de este trabajo.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // Agrupar por fase
        final porFase = <String, List<MediaAssetTurno>>{};
        for (final a in assets) {
          porFase.putIfAbsent(a.fase, () => []).add(a);
        }

        // Orden de fases
        const ordenFases = [
          'ingreso',
          'diagnostico',
          'en_proceso',
          'entrega',
          'reclamo',
          'otro',
        ];

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.camera_alt,
                      color: theme.colorScheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Evidencia del trabajo',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${assets.length} archivo(s) subido(s) por el prestador',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                for (final fase in ordenFases)
                  if (porFase.containsKey(fase))
                    _FaseSection(
                      faseLabel: porFase[fase]!.first.faseLabel,
                      assets: porFase[fase]!,
                    ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _FaseSection extends StatelessWidget {
  const _FaseSection({required this.faseLabel, required this.assets});

  final String faseLabel;
  final List<MediaAssetTurno> assets;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 6),
          child: Text(
            faseLabel.toUpperCase(),
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ),
        SizedBox(
          height: 120,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: assets.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (ctx, i) => _ThumbCard(asset: assets[i]),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _ThumbCard extends StatelessWidget {
  const _ThumbCard({required this.asset});

  final MediaAssetTurno asset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () => _abrirPreview(context),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 120,
          height: 120,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (asset.esVideo)
                Container(
                  color: Colors.black87,
                  child: const Center(
                    child: Icon(
                      Icons.play_circle_fill,
                      color: Colors.white,
                      size: 48,
                    ),
                  ),
                )
              else
                Image.network(
                  asset.urlPublica,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: Icon(
                      Icons.broken_image,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              Positioned(
                bottom: 4,
                left: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    asset.createdAt != null
                        ? _formatoHora(asset.createdAt!)
                        : asset.faseLabel,
                    style: const TextStyle(color: Colors.white, fontSize: 10),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatoHora(DateTime dt) {
    final local = dt.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  void _abrirPreview(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (asset.esVideo)
              Container(
                height: 300,
                color: Colors.black,
                child: const Center(
                  child: Text(
                    'Reproductor de video (proximamente)',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              )
            else
              Image.network(asset.urlPublica, fit: BoxFit.contain),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    asset.faseLabel,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  if (asset.descripcion != null &&
                      asset.descripcion!.isNotEmpty)
                    Text(asset.descripcion!),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('Cerrar'),
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
}
