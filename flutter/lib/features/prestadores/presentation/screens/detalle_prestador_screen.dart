/// Pantalla de detalle público de un prestador (cliente).
///
/// Estructura industrial:
/// - Banner (foto_portada_url) + avatar overlap
/// - Nombre + badges (verificado, destacado) + categoría + rating
/// - Stats row: rating, reseñas, años de experiencia
/// - Modalidades: domicilio / local / emergencias
/// - Descripción + especialidades
/// - Catálogo de servicios agrupados por categoría (con precios)
/// - Horario + contacto clickeable + redes sociales
/// - Ubicación + galería de trabajos
/// - FAB de WhatsApp con mensaje pre-armado
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:baqueano_natales/features/prestadores/data/prestador_providers.dart';
import 'package:baqueano_natales/features/prestadores/domain/foto_trabajo.dart';
import 'package:baqueano_natales/features/prestadores/domain/prestador.dart';
import 'package:baqueano_natales/features/prestadores/domain/prestador_servicio.dart';

class DetallePrestadorScreen extends ConsumerWidget {
  const DetallePrestadorScreen({super.key, required this.slug});

  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncPrestador = ref.watch(prestadorDetalleProvider(slug));

    return asyncPrestador.when(
      data: (prestador) => _Contenido(prestador: prestador),
      loading: () => const _LoadingScaffold(),
      error: (e, _) => _ErrorScaffold(
        error: e.toString(),
        onRetry: () => ref.invalidate(prestadorDetalleProvider(slug)),
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

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // --- Banner + avatar ---
          SliverToBoxAdapter(
            child: _BannerHeader(prestador: prestador),
          ),

          // --- Contenido ---
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- Modalidades ---
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (prestador.atiendeDomicilio)
                        _chip(theme, Icons.home_outlined, 'A domicilio'),
                      if (prestador.atiendeLocal)
                        _chip(theme, Icons.store_outlined, 'En local'),
                      if (prestador.atiendeEmergencias)
                        _chip(
                          theme,
                          Icons.emergency_outlined,
                          'Emergencias 24/7',
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
                      style: theme.textTheme.bodyLarge?.copyWith(
                        height: 1.4,
                      ),
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
                                label: Text(_humanizar(e)),
                                visualDensity: VisualDensity.compact,
                              ))
                          .toList(),
                    ),
                  ],

                  // --- Catálogo de servicios ---
                  if (prestador.servicios.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _seccionTitulo(theme, 'Servicios'),
                    _CatalogoServicios(
                      serviciosPorCategoria: prestador.serviciosPorCategoria,
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
                    _ContactRow(
                      icon: Icons.phone_outlined,
                      label: 'Teléfono',
                      value: prestador.telefono!,
                      onTap: () => _launch('tel:${prestador.telefono}'),
                    ),
                  if (prestador.whatsapp != null)
                    _ContactRow(
                      icon: Icons.chat_outlined,
                      label: 'WhatsApp',
                      value: prestador.whatsapp!,
                      onTap: () => _launchWhatsApp(prestador),
                    ),
                  if (prestador.email != null)
                    _ContactRow(
                      icon: Icons.email_outlined,
                      label: 'Email',
                      value: prestador.email!,
                      onTap: () => _launch('mailto:${prestador.email}'),
                    ),
                  if (prestador.sitioWeb != null)
                    _ContactRow(
                      icon: Icons.language_outlined,
                      label: 'Sitio web',
                      value: prestador.sitioWeb!,
                      onTap: () => _launch(prestador.sitioWeb!),
                    ),

                  // --- Redes sociales ---
                  if (prestador.redesSociales != null &&
                      prestador.redesSociales!.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _seccionTitulo(theme, 'Redes sociales'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (prestador.instagram != null)
                          _RedSocialChip(
                            label: 'Instagram',
                            icon: Icons.camera_alt_outlined,
                            color: const Color(0xFFE1306C),
                            onTap: () => _launch(prestador.instagram!),
                          ),
                        if (prestador.facebook != null)
                          _RedSocialChip(
                            label: 'Facebook',
                            icon: Icons.facebook,
                            color: const Color(0xFF1877F2),
                            onTap: () => _launch(prestador.facebook!),
                          ),
                        if (prestador.tiktok != null)
                          _RedSocialChip(
                            label: 'TikTok',
                            icon: Icons.music_note,
                            color: const Color(0xFF000000),
                            onTap: () => _launch(prestador.tiktok!),
                          ),
                        if (prestador.youtube != null)
                          _RedSocialChip(
                            label: 'YouTube',
                            icon: Icons.play_circle_outline,
                            color: const Color(0xFFFF0000),
                            onTap: () => _launch(prestador.youtube!),
                          ),
                      ],
                    ),
                  ],

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
                    _seccionTitulo(theme, 'Trabajos recientes'),
                    _Galeria(fotos: prestador.fotosTrabajos),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),

      // --- FAB de WhatsApp ---
      floatingActionButton: prestador.whatsapp != null
          ? FloatingActionButton.extended(
              onPressed: () => _launchWhatsApp(prestador),
              icon: const Icon(Icons.chat),
              label: const Text('Contactar'),
              backgroundColor: const Color(0xFF25D366),
              foregroundColor: Colors.white,
            )
          : null,
    );
  }

  /// Convierte "mantenimiento_preventivo" → "Mantenimiento preventivo"
  static String _humanizar(String slug) {
    if (slug.isEmpty) return slug;
    final conEspacios = slug.replaceAll('_', ' ');
    return conReposicionamiento(conEspacios);
  }

  static String conReposicionamiento(String texto) {
    return texto[0].toUpperCase() + texto.substring(1);
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
// Banner + avatar
// =========================================================
class _BannerHeader extends StatelessWidget {
  const _BannerHeader({required this.prestador});

  final Prestador prestador;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final topPadding = MediaQuery.of(context).padding.top;
    const bannerHeight = 180.0;
    const avatarSize = 96.0;

    return SizedBox(
      height: bannerHeight + avatarSize / 2 + 90,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Banner
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: bannerHeight,
            child: prestador.fotoPortadaUrl != null
                ? Image.network(
                    prestador.fotoPortadaUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _bannerPlaceholder(theme),
                  )
                : _bannerPlaceholder(theme),
          ),

          // Gradiente sobre el banner
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: bannerHeight,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.35),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.35),
                  ],
                ),
              ),
            ),
          ),

          // Botón back
          Positioned(
            top: topPadding + 8,
            left: 8,
            child: Material(
              color: Colors.black.withValues(alpha: 0.4),
              shape: const CircleBorder(),
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
          ),

          // Avatar
          Positioned(
            top: bannerHeight - avatarSize / 2,
            left: 16,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.colorScheme.surface, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: _avatar(theme, avatarSize),
            ),
          ),

          // Info (nombre, categoría, rating)
          Positioned(
            top: bannerHeight + avatarSize / 2 + 8,
            left: 16,
            right: 16,
            child: _infoHeader(theme),
          ),
        ],
      ),
    );
  }

  Widget _avatar(ThemeData theme, double size) {
    if (prestador.fotoUrl != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: Image.network(
          prestador.fotoUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _avatarPlaceholder(theme, size),
        ),
      );
    }
    return _avatarPlaceholder(theme, size);
  }

  Widget _avatarPlaceholder(ThemeData theme, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(13),
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

  Widget _bannerPlaceholder(ThemeData theme) {
    return Container(
      color: theme.colorScheme.primaryContainer,
      child: Center(
        child: Icon(
          Icons.handyman,
          size: 72,
          color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.4),
        ),
      ),
    );
  }

  Widget _infoHeader(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                prestador.nombre,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (prestador.verificado)
              Padding(
                padding: const EdgeInsets.only(left: 8, top: 4),
                child: Icon(
                  Icons.verified,
                  size: 24,
                  color: theme.colorScheme.primary,
                ),
              ),
            if (prestador.destacado)
              Padding(
                padding: const EdgeInsets.only(left: 4, top: 4),
                child: Icon(
                  Icons.star,
                  size: 24,
                  color: Colors.amber.shade700,
                ),
              ),
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
        const SizedBox(height: 10),
        // Stats row
        Row(
          children: [
            if (prestador.totalResenas > 0) ...[
              Icon(Icons.star, size: 18, color: Colors.amber.shade700),
              const SizedBox(width: 4),
              Text(
                '${prestador.ratingLegible} (${prestador.totalResenas})',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              _separador(theme),
            ],
            if (prestador.aniosExperienciaLegible != null) ...[
              Icon(
                Icons.workspace_premium_outlined,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text(
                prestador.aniosExperienciaLegible!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _separador(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Container(
        width: 3,
        height: 3,
        decoration: BoxDecoration(
          color: theme.colorScheme.onSurfaceVariant,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

// =========================================================
// Catálogo de servicios agrupado
// =========================================================
class _CatalogoServicios extends StatelessWidget {
  const _CatalogoServicios({required this.serviciosPorCategoria});

  final Map<String, List<PrestadorServicio>> serviciosPorCategoria;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categorias = serviciosPorCategoria.keys.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: categorias.map((cat) {
        final servicios = serviciosPorCategoria[cat]!;
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Título de categoría
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  cat.toUpperCase(),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              // Servicios
              ...servicios.map(
                (srv) => _ServicioCard(servicio: srv),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _ServicioCard extends StatelessWidget {
  const _ServicioCard({required this.servicio});

  final PrestadorServicio servicio;

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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          servicio.nombre,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (servicio.destacado) ...[
                        const SizedBox(width: 6),
                        Icon(
                          Icons.local_fire_department,
                          size: 16,
                          color: Colors.orange.shade700,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  servicio.precioLegible,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            if (servicio.descripcion != null &&
                servicio.descripcion!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                servicio.descripcion!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            // Chips de duración y garantía
            if (servicio.duracionLegible != null ||
                servicio.garantiaLegible != null) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  if (servicio.duracionLegible != null)
                    _miniChip(
                      theme,
                      Icons.schedule,
                      servicio.duracionLegible!,
                    ),
                  if (servicio.garantiaLegible != null)
                    _miniChip(
                      theme,
                      Icons.verified_user_outlined,
                      'Garantía ${servicio.garantiaLegible}',
                      color: Colors.green.shade700,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _miniChip(
    ThemeData theme,
    IconData icon,
    String label, {
    Color? color,
  }) {
    final fg = color ?? theme.colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: fg),
        const SizedBox(width: 3),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(color: fg),
        ),
      ],
    );
  }
}

// =========================================================
// Fila de contacto clickeable
// =========================================================
class _ContactRow extends StatelessWidget {
  const _ContactRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 18, color: theme.colorScheme.primary),
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
                  Text(
                    value,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.open_in_new,
              size: 16,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

// =========================================================
// Chip de red social
// =========================================================
class _RedSocialChip extends StatelessWidget {
  const _RedSocialChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =========================================================
// Galería
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
// Launchers (deep links)
// =========================================================
Future<void> _launch(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  try {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    // Silencioso: si no se puede abrir (ej: sin app de teléfono en emulador)
  }
}

Future<void> _launchWhatsApp(Prestador prestador) async {
  final phone = (prestador.whatsapp ?? '').replaceAll(RegExp(r'[^\d]'), '');
  final mensaje = prestador.whatsappMensaje ?? 'Hola, te contacto desde Baqueano Natales.';
  final url = 'https://wa.me/$phone?text=${Uri.encodeComponent(mensaje)}';
  await _launch(url);
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