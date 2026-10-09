/// Card reutilizable para mostrar un prestador en listados.
library;

import 'package:flutter/material.dart';

import 'package:baqueano_natales/features/prestadores/domain/prestador.dart';

class PrestadorCard extends StatelessWidget {
  const PrestadorCard({
    super.key,
    required this.prestador,
    this.onTap,
  });

  final Prestador prestador;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _avatar(theme),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Nombre + estrella destacado + badge verificado
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            prestador.nombre,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (prestador.verificado) ...[
                          const SizedBox(width: 4),
                          Icon(
                            Icons.verified,
                            size: 16,
                            color: theme.colorScheme.primary,
                          ),
                        ],
                        if (prestador.destacado) ...[
                          const SizedBox(width: 4),
                          Icon(
                            Icons.star,
                            size: 18,
                            color: Colors.amber.shade700,
                          ),
                        ],
                      ],
                    ),

                    const SizedBox(height: 2),

                    // Categoría
                    Row(
                      children: [
                        Icon(
                          Icons.handyman,
                          size: 12,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          prestador.categoria.nombre,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),

                    // Descripción corta
                    if (prestador.descripcion != null &&
                        prestador.descripcion!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        prestador.descripcion!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],

                    const SizedBox(height: 8),

                    // Comuna
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            prestador.comuna,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Badges modalidades + rating
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (prestador.atiendeDomicilio)
                          _badge(
                            theme,
                            Icons.home_outlined,
                            'A domicilio',
                          ),
                        if (prestador.atiendeLocal)
                          _badge(
                            theme,
                            Icons.store_outlined,
                            'En local',
                          ),
                        if (prestador.atiendeEmergencias)
                          _badge(
                            theme,
                            Icons.emergency_outlined,
                            '24/7',
                            highlight: true,
                          ),
                        if (prestador.totalResenas > 0)
                          _badge(
                            theme,
                            Icons.star,
                            '${prestador.ratingLegible} (${prestador.totalResenas})',
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _avatar(ThemeData theme) {
    if (prestador.fotoUrl != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          prestador.fotoUrl!,
          width: 64,
          height: 64,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _avatarPlaceholder(theme),
        ),
      );
    }
    return _avatarPlaceholder(theme);
  }

  Widget _avatarPlaceholder(ThemeData theme) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          prestador.iniciales,
          style: theme.textTheme.titleLarge?.copyWith(
            color: theme.colorScheme.onPrimaryContainer,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _badge(
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 3),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(color: fg),
          ),
        ],
      ),
    );
  }
}