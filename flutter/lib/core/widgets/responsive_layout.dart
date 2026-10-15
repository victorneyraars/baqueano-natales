/// Layout responsive canonico del proyecto.
///
/// Regla 11 de OPERATIVA_DEV.md:
///   < 600 dp -> phone
///   600-1199 dp -> tablet
///   >= 1200 dp -> desktop (opcional)
///
/// Uso:
///   ResponsiveLayout(
///     phone: _VistaPhone(),
///     tablet: _VistaTablet(),
///     desktop: _VistaDesktop(),  // opcional
///   )
library;

import 'package:flutter/widgets.dart';

class ResponsiveLayout extends StatelessWidget {
  const ResponsiveLayout({
    super.key,
    required this.phone,
    required this.tablet,
    this.desktop,
  });

  final Widget phone;
  final Widget tablet;
  final Widget? desktop;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (w >= 1200 && desktop != null) return desktop!;
    if (w >= 600) return tablet;
    return phone;
  }
}

/// Helper: true si el ancho actual corresponde a tablet (>= 600 dp).
bool esTablet(BuildContext context) => MediaQuery.sizeOf(context).width >= 600;