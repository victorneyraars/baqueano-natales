/// Pantalla de detalle público de un comercio (cliente).
///
/// Muestra:
/// - Portada + logo
/// - Nombre, categoría, descripción
/// - Contacto (teléfono, WhatsApp, web)
/// - Dirección + referencia
/// - Horarios (multi-franja)
/// - Badges delivery/retiro + rating
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:baqueano_natales/features/comercios/data/comercio_providers.dart';
import 'package:baqueano_natales/features/comercios/domain/comercio.dart';
import 'package:baqueano_natales/features/comercios/domain/horario.dart';

class DetalleComercioScreen extends ConsumerWidget {
  const DetalleComercioScreen({super.key, required this.slug});

  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncComercio = ref.watch(comercioDetalleProvider(slug));

    return Scaffold(
      body: asyncComercio.when(
        data: (comercio) => _Contenido(comercio: comercio),
        loading: () => const _LoadingScaffold(),
        error: (e, _) => _ErrorScaffold(
          error: e.toString(),
          onRetry: () => ref.invalidate(comercioDetalleProvider(slug)),
        ),
      ),
    );
  }
}

class _Contenido extends StatelessWidget {
  const _Contenido({required this.comercio});

  final Comercio comercio;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return CustomScrollView(
      slivers: [
        // --- AppBar con portada ---
        SliverAppBar(
          expandedHeight: 180,
          pinned: true,
          flexibleSpace: FlexibleSpaceBar(
            background: comercio.portadaUrl != null
                ? Image.network(
                    comercio.portadaUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _placeholderPortada(theme),
                  )
                : _placeholderPortada(theme),
          ),
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- Logo + nombre + categoría ---
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _logo(theme),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  comercio.nombre,
                                  style: theme.textTheme.headlineSmall
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                              ),
                              if (comercio.destacado)
                                Icon(
                                  Icons.star,
                                  size: 24,
                                  color: Colors.amber.shade700,
                                ),
                            ],
                          ),
                          if (comercio.categoria != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              comercio.categoria!.nombre,
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // --- Badges ---
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (comercio.aceptaDelivery)
                      _chip(theme, Icons.delivery_dining, 'Delivery'),
                    if (comercio.aceptaRetiro)
                      _chip(theme, Icons.shopping_bag_outlined, 'Retiro'),
                    if (comercio.totalResenas > 0)
                      _chip(
                        theme,
                        Icons.star,
                        '${comercio.ratingLegible} (${comercio.totalResenas})',
                      ),
                  ],
                ),

                // --- Descripción corta ---
                if (comercio.descripcionCorta != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    comercio.descripcionCorta!,
                    style: theme.textTheme.bodyLarge,
                  ),
                ],

                // --- Descripción larga ---
                if (comercio.descripcionLarga != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    comercio.descripcionLarga!,
                    style: theme.textTheme.bodyMedium,
                  ),
                ],

                const SizedBox(height: 24),

                // --- Contacto ---
                _seccionTitulo(theme, 'Contacto'),
                if (comercio.telefono != null)
                  _infoRow(
                    theme,
                    Icons.phone_outlined,
                    'Teléfono',
                    comercio.telefono!,
                  ),
                if (comercio.whatsapp != null)
                  _infoRow(
                    theme,
                    Icons.chat_outlined,
                    'WhatsApp',
                    comercio.whatsapp!,
                  ),
                if (comercio.email != null)
                  _infoRow(
                    theme,
                    Icons.email_outlined,
                    'Email',
                    comercio.email!,
                  ),
                if (comercio.sitioWeb != null)
                  _infoRow(
                    theme,
                    Icons.language_outlined,
                    'Sitio web',
                    comercio.sitioWeb!,
                  ),
                if (comercio.telefono == null &&
                    comercio.whatsapp == null &&
                    comercio.email == null &&
                    comercio.sitioWeb == null)
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
                  'Dirección',
                  comercio.direccion,
                ),
                if (comercio.referencia != null)
                  _infoRow(
                    theme,
                    Icons.info_outline,
                    'Referencia',
                    comercio.referencia!,
                  ),

                const SizedBox(height: 24),

                // --- Horarios ---
                _seccionTitulo(theme, 'Horarios'),
                if (comercio.horarios.isEmpty)
                  Text(
                    'Sin horarios publicados',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  )
                else
                  _HorariosTabla(horarios: comercio.horarios),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _placeholderPortada(ThemeData theme) {
    return Container(
      color: theme.colorScheme.primaryContainer,
      child: Center(
        child: Icon(
          Icons.storefront,
          size: 72,
          color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.5),
        ),
      ),
    );
  }

  Widget _logo(ThemeData theme) {
    if (comercio.logoUrl != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          comercio.logoUrl!,
          width: 72,
          height: 72,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _logoPlaceholder(theme),
        ),
      );
    }
    return _logoPlaceholder(theme);
  }

  Widget _logoPlaceholder(ThemeData theme) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        Icons.storefront,
        size: 36,
        color: theme.colorScheme.onPrimaryContainer,
      ),
    );
  }

  Widget _chip(ThemeData theme, IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: theme.colorScheme.onSecondaryContainer,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSecondaryContainer,
            ),
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

class _HorariosTabla extends StatelessWidget {
  const _HorariosTabla({required this.horarios});

  final List<Horario> horarios;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Agrupar por día
    final porDia = <int, List<Horario>>{};
    for (final h in horarios) {
      porDia.putIfAbsent(h.diaSemana, () => []).add(h);
    }

    // Ordenar días 0..6
    final dias = porDia.keys.toList()..sort();

    return Column(
      children: dias.map((dia) {
        final lista = porDia[dia]!;
        // Si todos los horarios del día están cerrados, mostrar "Cerrado"
        final todosCerrados = lista.every((h) => h.cerrado);
        final texto = todosCerrados
            ? 'Cerrado'
            : lista
                .where((h) => !h.cerrado)
                .map((h) => h.rangoLegible)
                .join(' / ');

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 100,
                child: Text(
                  lista.first.nombreDia,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  texto,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: todosCerrados
                        ? theme.colorScheme.onSurfaceVariant
                        : null,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

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