/// Pantalla de detalle público de un prestador (cliente).
///
/// Muestra:
/// - Foto de perfil + nombre + badge verificado
/// - Categoría, descripción
/// - Modalidades (domicilio / local / emergencias)
/// - Contacto (teléfono, WhatsApp, email, web)
/// - Ubicación (comuna, dirección)
/// - Especialidades
/// - Galería de fotos de trabajos
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:baqueano_natales/features/prestadores/data/prestador_providers.dart';
import 'package:baqueano_natales/features/prestadores/domain/foto_trabajo.dart';
import 'package:baqueano_natales/features/prestadores/domain/prestador.dart';

class DetallePrestadorScreen extends ConsumerWidget {
  const DetallePrestadorScreen({super.key, required this.slug});

  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncPrestador = ref.watch(prestadorDetalleProvider(slug));

    return Scaffold(
      body: asyncPrestador.when(
        data: (prestador) => _Contenido(prestador: prestador),
        loading: () => const _LoadingScaffold(),
        error: (e, _) => _ErrorScaffold(
          error: e.toString(),
          onRetry: () => ref.invalidate(prestadorDetalleProvider(slug)),
        ),
      ),
    );
  }
}

class _Contenido extends StatelessWidget {
  const _Contenido({required this.prestador});

  final Prestador prestador;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return CustomScrollView(
      slivers: [
        // --- AppBar simple ---
        SliverAppBar(
          pinned: true,
          expandedHeight: 140,
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              color: theme.colorScheme.primaryContainer,
            ),
          ),
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- Avatar + nombre + categoría ---
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _avatar(theme),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  prestador.nombre,
                                  style: theme.textTheme.headlineSmall
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                              ),
                              if (prestador.verificado)
                                Icon(
                                  Icons.verified,
                                  size: 24,
                                  color: theme.colorScheme.primary,
                                ),
                              if (prestador.destacado) ...[
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.star,
                                  size: 24,
                                  color: Colors.amber.shade700,
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.handyman,
                                size: 16,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                prestador.categoria.nombre,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                          if (prestador.totalResenas > 0) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.star,
                                  size: 16,
                                  color: Colors.amber.shade700,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  '${prestador.ratingLegible} '
                                  '(${prestador.totalResenas} reseñas)',
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // --- Modalidades ---
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (prestador.atiendeDomicilio)
                      _chip(
                        theme,
                        Icons.home_outlined,
                        'A domicilio',
                      ),
                    if (prestador.atiendeLocal)
                      _chip(
                        theme,
                        Icons.store_outlined,
                        'En local',
                      ),
                    if (prestador.atiendeEmergencias)
                      _chip(
                        theme,
                        Icons.emergency_outlined,
                        '24/7',
                        highlight: true,
                      ),
                  ],
                ),

                // --- Descripción ---
                if (prestador.descripcion != null &&
                    prestador.descripcion!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    prestador.descripcion!,
                    style: theme.textTheme.bodyLarge,
                  ),
                ],

                // --- Especialidades ---
                if (prestador.especialidades != null &&
                    prestador.especialidades!.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _seccionTitulo(theme, 'Especialidades'),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: prestador.especialidades!
                        .map((e) => Chip(
                              label: Text(e),
                              visualDensity: VisualDensity.compact,
                            ))
                        .toList(),
                  ),
                ],

                const SizedBox(height: 24),

                // --- Horario ---
                if (prestador.horarioDescripcion != null) ...[
                  _seccionTitulo(theme, 'Horario'),
                  _infoRow(
                    theme,
                    Icons.schedule_outlined,
                    'Atención',
                    prestador.horarioDescripcion!,
                  ),
                  const SizedBox(height: 16),
                ],

                // --- Contacto ---
                _seccionTitulo(theme, 'Contacto'),
                if (prestador.telefono != null)
                  _infoRow(
                    theme,
                    Icons.phone_outlined,
                    'Teléfono',
                    prestador.telefono!,
                  ),
                if (prestador.whatsapp != null)
                  _infoRow(
                    theme,
                    Icons.chat_outlined,
                    'WhatsApp',
                    prestador.whatsapp!,
                  ),
                if (prestador.email != null)
                  _infoRow(
                    theme,
                    Icons.email_outlined,
                    'Email',
                    prestador.email!,
                  ),
                if (prestador.sitioWeb != null)
                  _infoRow(
                    theme,
                    Icons.language_outlined,
                    'Sitio web',
                    prestador.sitioWeb!,
                  ),
                if (prestador.telefono == null &&
                    prestador.whatsapp == null &&
                    prestador.email == null &&
                    prestador.sitioWeb == null)
                  Text(
                    'Sin información de contacto',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),

                const SizedBox(height: 24),

                // --- Ubicación ---
                _seccionTitulo(theme, 'Ubicación'),
                _infoRow(
                  theme,
                  Icons.location_on_outlined,
                  'Comuna',
                  prestador.comuna,
                ),
                if (prestador.direccion != null)
                  _infoRow(
                    theme,
                    Icons.map_outlined,
                    'Dirección',
                    prestador.direccion!,
                  ),
                if (prestador.radioCoberturaKm != null)
                  _infoRow(
                    theme,
                    Icons.radar_outlined,
                    'Radio de cobertura',
                    '${prestador.radioCoberturaKm} km',
                  ),

                // --- Galería ---
                if (prestador.fotosTrabajos.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _seccionTitulo(theme, 'Trabajos'),
                  _Galeria(fotos: prestador.fotosTrabajos),
                ],

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _avatar(ThemeData theme) {
    if (prestador.fotoUrl != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          prestador.fotoUrl!,
          width: 88,
          height: 88,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _avatarPlaceholder(theme),
        ),
      );
    }
    return _avatarPlaceholder(theme);
  }

  Widget _avatarPlaceholder(ThemeData theme) {
    return Container(
      width: 88,
      height: 88,
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          prestador.iniciales,
          style: theme.textTheme.headlineMedium?.copyWith(
            color: theme.colorScheme.onPrimaryContainer,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _chip(
    ThemeData theme,
    IconData icon,
    String label, {
    bool highlight = false,
  }) {
    final bg = highlight
        ? Colors.red.shade50
        : theme.colorScheme.secondaryContainer;
    final fg = highlight
        ? Colors.red.shade800
        : theme.colorScheme.onSecondaryContainer;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(color: fg),
          ),
        ],
      ),
    );
  }

  Widget _seccionTitulo(ThemeData theme, String titulo) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        titulo,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _infoRow(
    ThemeData theme,
    IconData icon,
    String label,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(value, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =========================================================
// Galería de fotos de trabajos
// =========================================================
class _Galeria extends StatelessWidget {
  const _Galeria({required this.fotos});

  final List<FotoTrabajo> fotos;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
      ),
      itemCount: fotos.length,
      itemBuilder: (context, index) {
        final foto = fotos[index];
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            foto.url,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              color: Colors.grey.shade200,
              child: const Center(
                child: Icon(Icons.broken_image, color: Colors.grey),
              ),
            ),
          ),
        );
      },
    );
  }
}

// =========================================================
// Estados de carga / error
// =========================================================
class _LoadingScaffold extends StatelessWidget {
  const _LoadingScaffold();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: const Center(child: CircularProgressIndicator()),
    );
  }
}

class _ErrorScaffold extends StatelessWidget {
  const _ErrorScaffold({required this.error, required this.onRetry});

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error al cargar', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(error, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}