import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:baqueano_natales/core/config/app_config.dart';

import 'app_colors.dart';
import 'app_theme_extension.dart';

/// Tema visual de Baqueano Natales.
///
/// Preserva API histórica:
///   - AppTheme.light → ThemeData
///   - AppTheme.dark  → ThemeData
///   - AppTheme._()   → constructor privado
///
/// Seeds por flavor (ver AppColors): verde client, morado admin.
/// Tipografía unificada con la web: Inter.
abstract final class AppTheme {
  AppTheme._();

  static const double spaceXs = 4;
  static const double spaceS = 8;
  static const double spaceM = 12;
  static const double spaceL = 16;
  static const double spaceXl = 24;
  static const double spaceXxl = 32;

  static const double radiusS = 8;
  static const double radiusM = 12;
  static const double radiusL = 16;

  static Color get _seedColor {
    switch (AppConfig.appType) {
      case AppType.client:
        return AppColors.seedClient;
      case AppType.admin:
        return AppColors.seedAdmin;
    }
  }

  static TextTheme _textTheme(Brightness brightness) {
    final base = GoogleFonts.interTextTheme();
    final onSurface = brightness == Brightness.light
        ? AppColors.onSurfaceLight
        : Colors.white;

    return base.copyWith(
      displayLarge: base.displayLarge?.copyWith(
        fontSize: 32,
        height: 40 / 32,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        color: onSurface,
      ),
      displayMedium: base.displayMedium?.copyWith(
        fontSize: 28,
        height: 36 / 28,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
        color: onSurface,
      ),
      displaySmall: base.displaySmall?.copyWith(
        fontSize: 24,
        height: 32 / 24,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        color: onSurface,
      ),
      headlineLarge: base.headlineLarge?.copyWith(
        fontSize: 28,
        height: 36 / 28,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        color: onSurface,
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        fontSize: 22,
        height: 28 / 22,
        fontWeight: FontWeight.w600,
        color: onSurface,
      ),
      headlineSmall: base.headlineSmall?.copyWith(
        fontSize: 20,
        height: 26 / 20,
        fontWeight: FontWeight.w600,
        color: onSurface,
      ),
      titleLarge: base.titleLarge?.copyWith(
        fontSize: 18,
        height: 24 / 18,
        fontWeight: FontWeight.w600,
        color: onSurface,
      ),
      titleMedium: base.titleMedium?.copyWith(
        fontSize: 16,
        height: 22 / 16,
        fontWeight: FontWeight.w600,
        color: onSurface,
      ),
      titleSmall: base.titleSmall?.copyWith(
        fontSize: 14,
        height: 20 / 14,
        fontWeight: FontWeight.w600,
        color: onSurface,
      ),
      bodyLarge: base.bodyLarge?.copyWith(
        fontSize: 16,
        height: 24 / 16,
        fontWeight: FontWeight.w400,
        color: onSurface,
      ),
      bodyMedium: base.bodyMedium?.copyWith(
        fontSize: 14,
        height: 20 / 14,
        fontWeight: FontWeight.w400,
        color: onSurface,
      ),
      bodySmall: base.bodySmall?.copyWith(
        fontSize: 12,
        height: 16 / 12,
        fontWeight: FontWeight.w400,
        color: onSurface,
      ),
      labelSmall: base.labelSmall?.copyWith(
        fontSize: 12,
        height: 16 / 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.2,
        color: onSurface,
      ),
      labelMedium: base.labelMedium?.copyWith(
        fontSize: 14,
        height: 18 / 14,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.3,
        color: onSurface,
      ),
      labelLarge: base.labelLarge?.copyWith(
        fontSize: 16,
        height: 20 / 16,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        color: onSurface,
      ),
    );
  }

  static ThemeData get light {
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: _seedColor,
          brightness: Brightness.light,
        ).copyWith(
          secondary: AppColors.secondary,
          tertiary: AppColors.tertiary,
          surface: AppColors.surfaceLight,
          onSurface: AppColors.onSurfaceLight,
        );
    return _build(colorScheme, AppThemeExtension.light());
  }

  static ThemeData get dark {
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: _seedColor,
          brightness: Brightness.dark,
        ).copyWith(
          secondary: const Color(0xFF7BA7D9),
          tertiary: const Color(0xFF8BC4A3),
          surface: AppColors.surfaceDark,
        );
    return _build(colorScheme, AppThemeExtension.dark());
  }

  static ThemeData _build(ColorScheme scheme, AppThemeExtension ext) {
    final textTheme = _textTheme(scheme.brightness);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      textTheme: textTheme,
      extensions: <ThemeExtension<dynamic>>[ext],

      appBarTheme: AppBarTheme(
        backgroundColor: scheme.inversePrimary,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          padding: const EdgeInsets.symmetric(
            horizontal: spaceXl,
            vertical: spaceL,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusM),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: spaceXl,
            vertical: spaceL,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusM),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.3),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusM),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusM),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: spaceL,
          vertical: spaceL,
        ),
      ),

      dialogTheme: const DialogThemeData(
        insetPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      ),

      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusL),
        ),
      ),

      chipTheme: ChipThemeData(
        padding: const EdgeInsets.symmetric(
          horizontal: spaceS,
          vertical: spaceXs,
        ),
        labelStyle: textTheme.labelSmall,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusS),
        ),
      ),

      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: 0.5),
        thickness: 1,
        space: 1,
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return scheme.onPrimary;
          }
          return scheme.outline;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return scheme.primary;
          }
          return scheme.surfaceContainerHighest;
        }),
      ),

      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: scheme.primaryContainer,
          selectedForegroundColor: scheme.onPrimaryContainer,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusS),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),

      tabBarTheme: TabBarThemeData(
        labelStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        unselectedLabelStyle: textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w500,
        ),
        labelColor: scheme.primary,
        unselectedLabelColor: scheme.onSurfaceVariant,
        indicatorColor: scheme.primary,
        indicatorSize: TabBarIndicatorSize.label,
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primaryContainer,
        foregroundColor: scheme.onPrimaryContainer,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusM),
        ),
      ),

      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: spaceL,
          vertical: spaceXs,
        ),
        iconColor: scheme.onSurfaceVariant,
        titleTextStyle: textTheme.bodyLarge,
        subtitleTextStyle: textTheme.bodySmall?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusS),
        ),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.surfaceContainerHighest,
        circularTrackColor: scheme.surfaceContainerHighest,
      ),

      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: scheme.onSurface,
          highlightColor: scheme.primaryContainer.withValues(alpha: 0.3),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          padding: const EdgeInsets.symmetric(
            horizontal: spaceL,
            vertical: spaceM,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusS),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),

      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: ZoomPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: ZoomPageTransitionsBuilder(),
        },
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusM),
        ),
      ),
    );
  }
}
