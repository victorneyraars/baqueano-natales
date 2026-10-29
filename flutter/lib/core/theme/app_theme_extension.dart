import 'package:flutter/material.dart';

/// Tokens semánticos que Material 3 no incluye en `ColorScheme`.
///
/// Incluye:
///   - Semánticos genéricos: success, warning, info
///   - Accent por vertical: rentacarAccent
///   - Estados de reserva: pendiente, confirmada, enCurso,
///     completada, cancelada
///
/// Uso:
///   final ext = Theme.of(context).extension`<AppThemeExtension>`()!;

@immutable
class AppThemeExtension extends ThemeExtension<AppThemeExtension> {
  const AppThemeExtension({
    required this.success,
    required this.onSuccess,
    required this.successContainer,
    required this.warning,
    required this.onWarning,
    required this.warningContainer,
    required this.info,
    required this.onInfo,
    required this.infoContainer,
    required this.rentacarAccent,
    required this.onRentacarAccent,
    required this.rentacarAccentContainer,
    required this.reservaPendiente,
    required this.reservaConfirmada,
    required this.reservaEnCurso,
    required this.reservaCompletada,
    required this.reservaCancelada,
  });

  // ── Semánticos ──────────────────────────────────────────
  final Color success;
  final Color onSuccess;
  final Color successContainer;

  final Color warning;
  final Color onWarning;
  final Color warningContainer;

  final Color info;
  final Color onInfo;
  final Color infoContainer;

  // ── Vertical Rent a Car ─────────────────────────────────
  final Color rentacarAccent;
  final Color onRentacarAccent;
  final Color rentacarAccentContainer;

  // ── Estados de reserva ──────────────────────────────────
  final Color reservaPendiente;
  final Color reservaConfirmada;
  final Color reservaEnCurso;
  final Color reservaCompletada;
  final Color reservaCancelada;

  @override
  AppThemeExtension copyWith({
    Color? success,
    Color? onSuccess,
    Color? successContainer,
    Color? warning,
    Color? onWarning,
    Color? warningContainer,
    Color? info,
    Color? onInfo,
    Color? infoContainer,
    Color? rentacarAccent,
    Color? onRentacarAccent,
    Color? rentacarAccentContainer,
    Color? reservaPendiente,
    Color? reservaConfirmada,
    Color? reservaEnCurso,
    Color? reservaCompletada,
    Color? reservaCancelada,
  }) {
    return AppThemeExtension(
      success: success ?? this.success,
      onSuccess: onSuccess ?? this.onSuccess,
      successContainer: successContainer ?? this.successContainer,
      warning: warning ?? this.warning,
      onWarning: onWarning ?? this.onWarning,
      warningContainer: warningContainer ?? this.warningContainer,
      info: info ?? this.info,
      onInfo: onInfo ?? this.onInfo,
      infoContainer: infoContainer ?? this.infoContainer,
      rentacarAccent: rentacarAccent ?? this.rentacarAccent,
      onRentacarAccent: onRentacarAccent ?? this.onRentacarAccent,
      rentacarAccentContainer:
          rentacarAccentContainer ?? this.rentacarAccentContainer,
      reservaPendiente: reservaPendiente ?? this.reservaPendiente,
      reservaConfirmada: reservaConfirmada ?? this.reservaConfirmada,
      reservaEnCurso: reservaEnCurso ?? this.reservaEnCurso,
      reservaCompletada: reservaCompletada ?? this.reservaCompletada,
      reservaCancelada: reservaCancelada ?? this.reservaCancelada,
    );
  }

  @override
  AppThemeExtension lerp(AppThemeExtension? other, double t) {
    if (other == null) return this;
    return AppThemeExtension(
      success: Color.lerp(success, other.success, t)!,
      onSuccess: Color.lerp(onSuccess, other.onSuccess, t)!,
      successContainer: Color.lerp(
        successContainer,
        other.successContainer,
        t,
      )!,
      warning: Color.lerp(warning, other.warning, t)!,
      onWarning: Color.lerp(onWarning, other.onWarning, t)!,
      warningContainer: Color.lerp(
        warningContainer,
        other.warningContainer,
        t,
      )!,
      info: Color.lerp(info, other.info, t)!,
      onInfo: Color.lerp(onInfo, other.onInfo, t)!,
      infoContainer: Color.lerp(infoContainer, other.infoContainer, t)!,
      rentacarAccent: Color.lerp(rentacarAccent, other.rentacarAccent, t)!,
      onRentacarAccent: Color.lerp(
        onRentacarAccent,
        other.onRentacarAccent,
        t,
      )!,
      rentacarAccentContainer: Color.lerp(
        rentacarAccentContainer,
        other.rentacarAccentContainer,
        t,
      )!,
      reservaPendiente: Color.lerp(
        reservaPendiente,
        other.reservaPendiente,
        t,
      )!,
      reservaConfirmada: Color.lerp(
        reservaConfirmada,
        other.reservaConfirmada,
        t,
      )!,
      reservaEnCurso: Color.lerp(reservaEnCurso, other.reservaEnCurso, t)!,
      reservaCompletada: Color.lerp(
        reservaCompletada,
        other.reservaCompletada,
        t,
      )!,
      reservaCancelada: Color.lerp(
        reservaCancelada,
        other.reservaCancelada,
        t,
      )!,
    );
  }

  /// Versión para tema claro.
  static AppThemeExtension light() => const AppThemeExtension(
    success: Color(0xFF16A34A),
    onSuccess: Colors.white,
    successContainer: Color(0xFFDCFCE7),
    warning: Color(0xFFD97706),
    onWarning: Colors.white,
    warningContainer: Color(0xFFFEF3C7),
    info: Color(0xFF2563EB),
    onInfo: Colors.white,
    infoContainer: Color(0xFFDBEAFE),
    rentacarAccent: Color(0xFFB45309),
    onRentacarAccent: Colors.white,
    rentacarAccentContainer: Color(0xFFFEF3C7),
    reservaPendiente: Color(0xFFD97706),
    reservaConfirmada: Color(0xFF2563EB),
    reservaEnCurso: Color(0xFF9333EA),
    reservaCompletada: Color(0xFF16A34A),
    reservaCancelada: Color(0xFFDC2626),
  );

  /// Versión para tema oscuro.
  static AppThemeExtension dark() => const AppThemeExtension(
    success: Color(0xFF4ADE80),
    onSuccess: Color(0xFF052E16),
    successContainer: Color(0xFF14532D),
    warning: Color(0xFFFBBF24),
    onWarning: Color(0xFF451A03),
    warningContainer: Color(0xFF78350F),
    info: Color(0xFF60A5FA),
    onInfo: Color(0xFF172554),
    infoContainer: Color(0xFF1E3A8A),
    rentacarAccent: Color(0xFFFBBF24),
    onRentacarAccent: Color(0xFF451A03),
    rentacarAccentContainer: Color(0xFF78350F),
    reservaPendiente: Color(0xFFFBBF24),
    reservaConfirmada: Color(0xFF60A5FA),
    reservaEnCurso: Color(0xFFC084FC),
    reservaCompletada: Color(0xFF4ADE80),
    reservaCancelada: Color(0xFFF87171),
  );
}
