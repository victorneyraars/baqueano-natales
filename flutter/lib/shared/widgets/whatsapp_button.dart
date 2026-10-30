import 'package:flutter/material.dart';
import 'package:baqueano_natales/core/domain/whatsapp_info.dart';
import 'package:baqueano_natales/core/services/whatsapp_service.dart';

/// Variantes visuales del boton WhatsApp.
enum WhatsAppButtonVariant { primary, outline, icon }

/// Tamanos disponibles.
enum WhatsAppButtonSize { sm, md, lg }

/// Boton reutilizable de WhatsApp.
///
/// Reglas:
/// - Usa LaunchMode.externalApplication (regla #6)
/// - Fallback silencioso si falta telefono (no rompe layout)
/// - Brand color WhatsApp: 0xFF25D366
class WhatsAppButton extends StatelessWidget {
  static const _brandColor = Color(0xFF25D366);
  static const _brandColorDark = Color(0xFF1DA851);

  final WhatsAppInfo info;
  final String context;
  final Map<String, String> vars;
  final WhatsAppButtonVariant variant;
  final WhatsAppButtonSize size;
  final String? label;
  final VoidCallback? onTap;

  const WhatsAppButton({
    super.key,
    required this.info,
    this.context = 'app',
    this.vars = const {},
    this.variant = WhatsAppButtonVariant.primary,
    this.size = WhatsAppButtonSize.md,
    this.label,
    this.onTap,
  });

  Future<void> _open(BuildContext ctx) async {
    final ok = await WhatsAppService.open(
      phoneDigits: info.phoneDigits,
      message: info.messageFor(context, vars),
    );
    if (!ok && ctx.mounted) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir WhatsApp')),
      );
    }
    onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (!info.isConfigured) return const SizedBox.shrink();
    final defaultLabel = label ?? 'WhatsApp';
    switch (variant) {
      case WhatsAppButtonVariant.primary:
        return _buildFilled(context, defaultLabel);
      case WhatsAppButtonVariant.outline:
        return _buildOutlined(context, defaultLabel);
      case WhatsAppButtonVariant.icon:
        return _buildIcon(context);
    }
  }

  Widget _buildFilled(BuildContext ctx, String txt) {
    return FilledButton.icon(
      onPressed: () => _open(ctx),
      icon: _icon(),
      label: Text(txt),
      style: FilledButton.styleFrom(
        backgroundColor: _brandColor,
        foregroundColor: Colors.white,
        minimumSize: _minSize(),
        padding: _padding(),
      ),
    );
  }

  Widget _buildOutlined(BuildContext ctx, String txt) {
    return OutlinedButton.icon(
      onPressed: () => _open(ctx),
      icon: _icon(),
      label: Text(txt),
      style: OutlinedButton.styleFrom(
        foregroundColor: _brandColorDark,
        minimumSize: _minSize(),
        padding: _padding(),
      ),
    );
  }

  Widget _buildIcon(BuildContext ctx) {
    return IconButton(
      onPressed: () => _open(ctx),
      icon: _icon(),
      color: _brandColor,
      tooltip: 'WhatsApp',
    );
  }

  Widget _icon() {
    final px = switch (size) {
      WhatsAppButtonSize.sm => 16.0,
      WhatsAppButtonSize.md => 20.0,
      WhatsAppButtonSize.lg => 24.0,
    };
    return Icon(Icons.chat, size: px);
  }

  Size _minSize() => switch (size) {
    WhatsAppButtonSize.sm => const Size(0, 36),
    WhatsAppButtonSize.md => const Size(0, 48),
    WhatsAppButtonSize.lg => const Size(0, 56),
  };

  EdgeInsets _padding() => switch (size) {
    WhatsAppButtonSize.sm => const EdgeInsets.symmetric(
      horizontal: 12,
      vertical: 4,
    ),
    WhatsAppButtonSize.md => const EdgeInsets.symmetric(
      horizontal: 16,
      vertical: 8,
    ),
    WhatsAppButtonSize.lg => const EdgeInsets.symmetric(
      horizontal: 20,
      vertical: 12,
    ),
  };
}
