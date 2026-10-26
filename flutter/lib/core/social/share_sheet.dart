import 'package:flutter/material.dart';
import 'package:baqueano_natales/core/social/shareable_entity.dart';
import 'package:baqueano_natales/core/social/share_service.dart';

/// Muestra el bottom sheet con las opciones de compartir.
Future<void> showShareSheet(
  BuildContext context,
  ShareableEntity entity,
) async {
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => _ShareSheetContent(entity: entity),
  );
}

class _ShareSheetContent extends StatelessWidget {
  const _ShareSheetContent({required this.entity});
  final ShareableEntity entity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Compartir',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              entity.title,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            _ShareOption(
              icon: Icons.chat,
              label: 'WhatsApp',
              color: const Color(0xFF25D366),
              onTap: () {
                Navigator.pop(context);
                ShareService.instance.shareToWhatsApp(entity);
              },
            ),
            _ShareOption(
              icon: Icons.telegram,
              label: 'Telegram',
              color: const Color(0xFF0088CC),
              onTap: () {
                Navigator.pop(context);
                ShareService.instance.shareToTelegram(entity);
              },
            ),
            _ShareOption(
              icon: Icons.email,
              label: 'Email',
              color: theme.colorScheme.primary,
              onTap: () {
                Navigator.pop(context);
                ShareService.instance.shareToEmail(entity);
              },
            ),
            _ShareOption(
              icon: Icons.share,
              label: 'Más opciones',
              color: theme.colorScheme.primary,
              onTap: () {
                Navigator.pop(context);
                ShareService.instance.shareGeneric(entity);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ShareOption extends StatelessWidget {
  const _ShareOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color),
      ),
      title: Text(label),
      onTap: onTap,
    );
  }
}
