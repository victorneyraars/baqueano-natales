import 'package:flutter/material.dart';

/// Breakpoints y helpers responsive de Baqueano Natales.
///
/// Mobile-first: usa `isMobile`, `isTablet`, `isDesktop` desde BuildContext.
abstract final class Breakpoints {
  /// Mobile: < 600 (típico teléfono en portrait y landscape chico).
  static const double mobile = 600.0;

  /// Tablet: 600 – 900 (tablet portrait, foldables).
  static const double tablet = 900.0;

  /// Desktop: >= 900 (tablet landscape, desktop, TV).
  static const double desktop = 900.0;
}

/// Extension sobre `BuildContext` para clasificar el ancho actual.
extension ResponsiveContext on BuildContext {
  /// Ancho actual de la pantalla.
  double get screenWidth => MediaQuery.sizeOf(this).width;

  /// `true` si el ancho < 600.
  bool get isMobile => screenWidth < Breakpoints.mobile;

  /// `true` si 600 <= ancho < 900.
  bool get isTablet =>
      screenWidth >= Breakpoints.mobile && screenWidth < Breakpoints.desktop;

  /// `true` si ancho >= 900.
  bool get isDesktop => screenWidth >= Breakpoints.desktop;

  /// Devuelve el valor apropiado según el breakpoint actual.
  T valueFor<T>({required T mobile, T? tablet, T? desktop}) {
    if (isDesktop) return desktop ?? tablet ?? mobile;
    if (isTablet) return tablet ?? mobile;
    return mobile;
  }
}
