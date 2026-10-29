import 'package:flutter/material.dart';

/// Paleta de Baqueano Natales.
///
/// Fuente de verdad de color. No usar estas constantes directamente en
/// widgets: consumir `Theme.of(context).colorScheme` o `AppThemeExtension`.
abstract final class AppColors {
  // ── Seeds por flavor ─────────────────────────────────────
  /// Baqueano Natales (client) — verde Patagonia.
  static const Color seedClient = Color(0xFF2E7D32);

  /// Baqueano Admin — morado interno.
  static const Color seedAdmin = Color(0xFF6A1B9A);

  // ── Accent específico por vertical ───────────────────────
  /// Rent a Car Vásquez — Amber-700 (atardecer patagónico).
  static const Color rentacarAccent = Color(0xFFB45309);

  // ── Anclas culturales ────────────────────────────────────
  static const Color secondary = Color(0xFF1E3A5F);
  static const Color tertiary = Color(0xFF4A7C59);

  // ── Superficies ──────────────────────────────────────────
  static const Color surfaceLight = Color(0xFFF8F7F5);
  static const Color surfaceDark = Color(0xFF121212);

  // ── Texto ────────────────────────────────────────────────
  static const Color onSurfaceLight = Color(0xFF1A1A1A);

  // ── Semánticos base ─────────────────────────────────────
  static const Color success = Color(0xFF16A34A);
  static const Color warning = Color(0xFFD97706);
  static const Color info = Color(0xFF2563EB);
  static const Color error = Color(0xFFDC2626);
}
