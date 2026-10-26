import 'package:flutter/material.dart';

/// Diálogo de alerta responsivo con defaults seguros.
///
/// Uso:
/// ```dart
/// ResponsiveAlertDialog(
///   title: const Text('Confirmar'),
///   content: const Text('¿Estás seguro?'),
///   actions: [
///     TextButton(onPressed: ..., child: const Text('Cancelar')),
///     FilledButton(onPressed: ..., child: const Text('Confirmar')),
///   ],
/// )
/// ```
///
/// Ventajas vs `AlertDialog` directo:
/// - `insetPadding` seguro para pantallas angostas (Fold4, tablets, split-screen).
/// - `actionsOverflowDirection: down` por default (botones apilan verticalmente si no entran).
/// - `actionsOverflowAlignment: end` por default (alineación consistente).
class ResponsiveAlertDialog extends StatelessWidget {
  const ResponsiveAlertDialog({
    super.key,
    required this.title,
    required this.content,
    this.actions,
    this.actionsOverflowDirection = VerticalDirection.down,
    this.actionsOverflowAlignment = OverflowBarAlignment.end,
    this.insetPadding,
    this.scrollable = true,
  });

  final Widget title;
  final Widget content;
  final List<Widget>? actions;
  final VerticalDirection actionsOverflowDirection;
  final OverflowBarAlignment actionsOverflowAlignment;
  final EdgeInsets? insetPadding;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: title,
      content: content,
      actions: actions,
      actionsOverflowDirection: actionsOverflowDirection,
      actionsOverflowAlignment: actionsOverflowAlignment,
      scrollable: scrollable,
      insetPadding:
          insetPadding ??
          const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
    );
  }
}
