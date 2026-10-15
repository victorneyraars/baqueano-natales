/// Pantalla admin: cola de publicaciones en redes sociales.
///
/// Lista las publicaciones con filtros por estado y red. Muestra:
/// - Red (Facebook / Instagram)
/// - Estado (pendiente / publicado / fallado / agotado)
/// - Preview del mensaje
/// - Intentos + proximo intento + error
///
/// Endpoints: GET /api/v1/admin/social/publicaciones
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:baqueano_natales/core/network/api_exceptions.dart';
import 'package:baqueano_natales/features/social/data/social_providers.dart';
import 'package:baqueano_natales/features/social/domain/cuenta_social.dart';
import 'package:baqueano_natales/features/social/domain/publicacion_social.dart';

class AdminSocialPublicacionesScreen extends ConsumerStatefulWidget {
  const AdminSocialPublicacionesScreen({super.key});

  @override
  ConsumerState<AdminSocialPublicacionesScreen> createState() =>
      _AdminSocialPublicacionesScreenState();
}

class _AdminSocialPublicacionesScreenState
    extends ConsumerState<AdminSocialPublicacionesScreen> {
  EstadoPublicacion? _estadoFiltro;
  RedSocial? _redFiltro;

  @override
  Widget build(BuildContext context) {
    final filtro = PublicacionesFiltro(
      estado: _estadoFiltro,
      red: _redFiltro,
    );
    final async = ref.watch(publicacionesSocialesProvider(filtro));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cola de publicaciones'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refrescar',
            onPressed: () =>
                ref.invalidate(publicacionesSocialesProvider(filtro)),
          ),
        ],
      ),
      body: Column(
        children: [
          _FiltersBar(
            estado: _estadoFiltro,
            red: _redFiltro,
            onEstado: (v) => setState(() => _estadoFiltro = v),
            onRed: (v) => setState(() => _redFiltro = v),
          ),
          Expanded(
            child: async.when(
              loading: () => const Center(
                child: CircularProgressIndicator(),
              ),
              error: (e, _) => _ErrorView(
                error: e,
                onRetry: () => ref.invalidate(
                  publicacionesSocialesProvider(filtro),
                ),
              ),
              data: (data) {
                if (data.items.isEmpty) {
                  return const _EmptyView();
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(publicacionesSocialesProvider(filtro));
                    await ref
                        .read(publicacionesSocialesProvider(filtro).future);
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: data.items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (ctx, i) =>
                        _PublicacionCard(pub: data.items[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------
// Filtros (chips horizontales)
// ---------------------------------------------------------
class _FiltersBar extends StatelessWidget {
  const _FiltersBar({
    required this.estado,
    required this.red,
    required this.onEstado,
    required this.onRed,
  });

  final EstadoPublicacion? estado;
  final RedSocial? red;
  final ValueChanged<EstadoPublicacion?> onEstado;
  final ValueChanged<RedSocial?> onRed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                const _FilterLabel('Estado:'),
                _Chip(
                  label: 'Todos',
                  selected: estado == null,
                  onTap: () => onEstado(null),
                ),
                ...EstadoPublicacion.values.map(
                  (e) => _Chip(
                    label: e.label,
                    selected: estado == e,
                    color: Color(e.colorValue),
                    onTap: () => onEstado(e),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                const _FilterLabel('Red:'),
                _Chip(
                  label: 'Todas',
                  selected: red == null,
                  onTap: () => onRed(null),
                ),
                _Chip(
                  label: 'Facebook',
                  selected: red == RedSocial.facebook,
                  onTap: () => onRed(RedSocial.facebook),
                ),
                _Chip(
                  label: 'Instagram',
                  selected: red == RedSocial.instagram,
                  onTap: () => onRed(RedSocial.instagram),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterLabel extends StatelessWidget {
  const _FilterLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: selected ? Colors.white : null,
          ),
        ),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: c,
        showCheckmark: false,
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

// ---------------------------------------------------------
// Empty / Error states
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
              'No hay publicaciones',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Cambia los filtros o espera a que se encolen nuevas.',
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
// Card de publicacion
// ---------------------------------------------------------
class _PublicacionCard extends ConsumerStatefulWidget {
  const _PublicacionCard({required this.pub});

  final PublicacionSocial pub;

  @override
  ConsumerState<_PublicacionCard> createState() => _PublicacionCardState();
}

class _PublicacionCardState extends ConsumerState<_PublicacionCard> {
  bool _reencolando = false;

  Future<void> _reencolar() async {
    setState(() => _reencolando = true);
    try {
      final fn = ref.read(reencolarPublicacionProvider);
      await fn(widget.pub.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Publicacion reencolada. El worker la procesara pronto.'),
          ),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.message}')),
        );
      }
    } finally {
      if (mounted) setState(() => _reencolando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pub = widget.pub;
    final theme = Theme.of(context);
    final estadoColor = Color(pub.estado.colorValue);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: red + estado + intentos
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

            // Preview
            Text(
              pub.mensajePreview,
              style: theme.textTheme.bodyMedium,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),

            // Metadata
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                if (pub.tieneImagen)
                  const _Meta(icon: Icons.image, text: 'Con imagen'),
                if (pub.intentos > 0)
                  _Meta(
                    icon: Icons.refresh,
                    text: '${pub.intentos} intento(s)',
                  ),
                _Meta(
                  icon: Icons.schedule,
                  text: _fmt(pub.createdAt),
                ),
              ],
            ),

            // Error (si aplica)
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

            // Proximo intento + external id
            if (pub.proximoIntentoEn != null) ...[
              const SizedBox(height: 6),
              _Meta(
                icon: Icons.update,
                text: 'Reintenta: ${_fmt(pub.proximoIntentoEn!)}',
              ),
            ],
            if (pub.externalPostId != null) ...[
              const SizedBox(height: 6),
              _Meta(
                icon: Icons.link,
                text: 'ID: ${pub.externalPostId}',
              ),
            ],

            // Boton Reencolar (solo para estados que pueden reintentar)
            if (pub.estado == EstadoPublicacion.fallado ||
                pub.estado == EstadoPublicacion.agotado) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _reencolando ? null : _reencolar,
                  icon: _reencolando
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh, size: 16),
                  label: const Text('Reencolar'),
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
