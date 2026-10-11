/// Pantalla del dueño: publicaciones en redes del prestador.
///
/// Lista las publicaciones en redes sociales relacionadas con este
/// prestador (su alta + servicios agregados). Read-only.
///
/// Endpoint: GET /api/v1/mis-prestadores/{id}/publicaciones
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:baqueano_natales/core/network/api_exceptions.dart';
import 'package:baqueano_natales/features/social/data/social_providers.dart';
import 'package:baqueano_natales/features/social/domain/cuenta_social.dart';
import 'package:baqueano_natales/features/social/domain/publicacion_social.dart';

class MisPublicacionesScreen extends ConsumerWidget {
  const MisPublicacionesScreen({super.key, required this.prestadorId});

  final String prestadorId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(publicacionesDePrestadorProvider(prestadorId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis publicaciones'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refrescar',
            onPressed: () => ref.invalidate(
              publicacionesDePrestadorProvider(prestadorId),
            ),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorView(
          error: e,
          onRetry: () => ref.invalidate(
            publicacionesDePrestadorProvider(prestadorId),
          ),
        ),
        data: (pubs) {
          if (pubs.isEmpty) {
            return const _EmptyView();
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(
                publicacionesDePrestadorProvider(prestadorId),
              );
              await ref.read(
                publicacionesDePrestadorProvider(prestadorId).future,
              );
            },
            child: ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: pubs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (ctx, i) => _PublicacionCard(pub: pubs[i]),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------
// Empty / Error
// ---------------------------------------------------------
class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 64,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'Todavia no hay publicaciones',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Cuando se apruebe tu prestador o agregues servicios, '
              'se publicaran automaticamente en las redes sociales '
              'de Baqueano Natales.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final msg = error is ApiException
        ? (error as ApiException).message
        : 'Error inesperado';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(msg, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------
// Card
// ---------------------------------------------------------
class _PublicacionCard extends StatelessWidget {
  const _PublicacionCard({required this.pub});

  final PublicacionSocial pub;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final estadoColor = Color(pub.estado.colorValue);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  pub.red == RedSocial.facebook
                      ? Icons.facebook
                      : Icons.camera_alt,
                  size: 16,
                  color: pub.red == RedSocial.facebook
                      ? const Color(0xFF1877F2)
                      : const Color(0xFFE1306C),
                ),
                const SizedBox(width: 6),
                Text(
                  pub.red.label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: estadoColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    pub.estado.label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: estadoColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              pub.mensajePreview,
              style: theme.textTheme.bodyMedium,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                if (pub.tieneImagen)
                  const _Meta(icon: Icons.image, text: 'Con imagen'),
                _Meta(icon: Icons.schedule, text: _fmt(pub.createdAt)),
              ],
            ),
            if (pub.errorUltimo != null &&
                pub.errorUltimo!.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: Colors.red.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 14,
                      color: Colors.red,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        pub.errorUltimo!,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.red,
                        ),
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _fmt(DateTime dt) {
    final d = dt.toLocal();
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')} '
        '${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}';
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 3),
        Text(
          text,
          style: TextStyle(fontSize: 11, color: color),
        ),
      ],
    );
  }
}
