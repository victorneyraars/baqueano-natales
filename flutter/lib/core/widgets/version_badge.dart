/// Badge de versión + flavor + commit SHA, visible en dev/staging.
library;

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:baqueano_natales/core/config/app_config.dart';

/// Hash corto del commit (inyectado por --dart-define=GIT_SHA=...).
const _gitSha = String.fromEnvironment('GIT_SHA', defaultValue: 'local');

/// Widget compacto que muestra:
///   v0.8.8 (61) - clientDev - a1b2c3d
///
/// Visible solo en dev/staging. En prod devuelve SizedBox.shrink()
/// (la info completa está en AboutScreen).
class VersionBadge extends StatelessWidget {
  const VersionBadge({super.key, this.compact = false});
  final bool compact;

  String get _flavorName {
    final env = switch (AppConfig.environment) {
      Environment.dev => 'Dev',
      Environment.staging => 'Staging',
      Environment.prod => 'Prod',
    };
    final type = switch (AppConfig.appType) {
      AppType.client => 'client',
      AppType.admin => 'admin',
    };
    return '$type$env';
  }

  Color get _badgeColor => switch (AppConfig.environment) {
    Environment.dev => const Color(0xFFFF6D00),
    Environment.staging => const Color(0xFFFFA000),
    Environment.prod => Colors.grey,
  };

  @override
  Widget build(BuildContext context) {
    if (AppConfig.environment == Environment.prod) {
      return const SizedBox.shrink();
    }
    // Responsive: pantallas angostas (< 400dp) fuerzan formato compacto
    // porque el AppBar tiene espacio limitado.
    final screenWidth = MediaQuery.sizeOf(context).width;
    final esAngosto = compact || screenWidth < 400;
    final sha = _gitSha.length > 7 ? _gitSha.substring(0, 7) : _gitSha;
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        final info = snapshot.data;
        final version = info?.version ?? '...';
        final build = info?.buildNumber ?? '...';
        final texto = esAngosto
            ? 'v$version ($build)'
            : 'v$version ($build) - $_flavorName - $sha';
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _badgeColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: _badgeColor.withValues(alpha: 0.5)),
          ),
          child: Text(
            texto,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: _badgeColor,
              fontFamily: 'monospace',
            ),
          ),
        );
      },
    );
  }
}

/// Helper para agregar el badge a `AppBar.actions`.
/// El badge va primero (izquierda) y los extras después (derecha).
List<Widget> appBarActionsWithBadge({List<Widget>? extra}) => [
  const Center(
    child: Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.0),
      child: FittedBox(fit: BoxFit.scaleDown, child: VersionBadge()),
    ),
  ),
  ...?extra,
];
