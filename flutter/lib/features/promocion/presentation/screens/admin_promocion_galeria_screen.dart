/// Pantalla admin: galeria de plantillas de afiches.
///
/// Muestra las 5 plantillas disponibles con preview visual (colores +
/// icono). Al tocar una, navega al editor con esa plantilla precargada.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:baqueano_natales/core/network/api_exceptions.dart';
import 'package:baqueano_natales/features/promocion/data/promocion_providers.dart';
import 'package:baqueano_natales/features/promocion/domain/afiche.dart';

class AdminPromocionGaleriaScreen extends ConsumerWidget {
  const AdminPromocionGaleriaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(plantillasPromocionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Afiches'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refrescar',
            onPressed: () => ref.invalidate(plantillasPromocionProvider),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorView(
          error: e,
          onRetry: () => ref.invalidate(plantillasPromocionProvider),
        ),
        data: (plantillas) {
          if (plantillas.isEmpty) {
            return const _EmptyView();
          }
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.75,
            ),
            itemCount: plantillas.length,
            itemBuilder: (ctx, i) => _PlantillaCard(
              plantilla: plantillas[i],
              onTap: () => context.push(
                '/admin/promocion/editor/${plantillas[i].id}',
              ),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------
// Card de plantilla (con preview visual)
// ---------------------------------------------------------
class _PlantillaCard extends StatelessWidget {
  const _PlantillaCard({required this.plantilla, required this.onTap});

  final PlantillaInfo plantilla;
  final VoidCallback onTap;

  /// Visual por plantilla (icono + gradiente).
  _Visual _visual() {
    switch (plantilla.id) {
      case 'nuevo_servicio':
        return const _Visual(
          icon: Icons.new_releases,
          bg: Color(0xFF16a34a),
          fg: Colors.white,
        );
      case 'oferta':
        return const _Visual(
          icon: Icons.local_fire_department,
          bg: Color(0xFFf97316),
          fg: Colors.white,
        );
      case 'destacado':
        return const _Visual(
          icon: Icons.workspace_premium,
          bg: Color(0xFF16a34a),
          fg: Color(0xFFfbbf24),
        );
      case 'evento':
        return const _Visual(
          icon: Icons.event,
          bg: Color(0xFF7c3aed),
          fg: Colors.white,
        );
      case 'profesional':
        return const _Visual(
          icon: Icons.format_quote,
          bg: Color(0xFFf1f5f9),
          fg: Color(0xFF16a34a),
        );
      case 'lanzamiento':
        return const _Visual(
          icon: Icons.rocket_launch,
          bg: Color(0xFF7c3aed),
          fg: Color(0xFFdcfce7),
        );
      default:
        return _Visual(
          icon: Icons.image,
          bg: Colors.grey.shade300,
          fg: Colors.grey.shade700,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final v = _visual();

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Preview (placeholder visual)
            Expanded(
              flex: 5,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      v.bg,
                      Color.lerp(v.bg, Colors.black, 0.15)!,
                    ],
                  ),
                ),
                child: Stack(
                  children: [
                    // Blobs decorativos
                    Positioned(
                      top: -30,
                      right: -30,
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.15),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -40,
                      left: -20,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.10),
                        ),
                      ),
                    ),
                    Center(
                      child: Icon(v.icon, size: 56, color: v.fg),
                    ),
                  ],
                ),
              ),
            ),
            // Info
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plantilla.nombre,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Expanded(
                      child: Text(
                        plantilla.descripcion,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Visual {
  const _Visual({required this.icon, required this.bg, required this.fg});
  final IconData icon;
  final Color bg;
  final Color fg;
}

// ---------------------------------------------------------
// Empty / Error
// ---------------------------------------------------------
class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('No hay plantillas disponibles'),
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
