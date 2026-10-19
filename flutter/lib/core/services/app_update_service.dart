import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

class AppUpdateService {
  static const String versionUrl =
      'https://api-dev.baqueanonatales.com/apks/version.json';

  static Future<void> checkForUpdates(GoRouter router, GlobalKey<ScaffoldMessengerState> messengerKey) async {
    try {
      final response = await Dio().get('$versionUrl?t=${DateTime.now().millisecondsSinceEpoch}');
      if (response.statusCode != 200) return;

      final data = response.data as Map<String, dynamic>;
      final latestVersion = data['latest_version'] as String?;
      final changelog =
          data['changelog'] as String? ?? 'Mejoras y correcciones.';

      if (latestVersion == null) return;

      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      // DEBUG Obligatorio: mostrar versiones en SnackBar
      messengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text('DEBUG -> Instalada: $currentVersion | Servidor: $latestVersion'),
          duration: const Duration(seconds: 15),
        ),
      );

      if (_isNewerVersion(latestVersion, currentVersion)) {
        final ctx = router.routerDelegate.navigatorKey.currentContext;
        if (ctx != null && ctx.mounted) {
          _showUpdateDialog(ctx, latestVersion, changelog);
        }
      }
    } catch (e) {
      debugPrint('Error checking for updates: $e');
      final ctx = router.routerDelegate.navigatorKey.currentContext;
      if (ctx != null && ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(content: Text('Error update: $e')),
        );
      }
    }
  }

  static bool _isNewerVersion(String latest, String current) {
    final l = latest.split('.').map(int.tryParse).toList();
    final c = current.split('.').map(int.tryParse).toList();
    if (l.length != 3 || c.length != 3) return false;
    if (l[0] != c[0]) return (l[0] ?? 0) > (c[0] ?? 0);
    if (l[1] != c[1]) return (l[1] ?? 0) > (c[1] ?? 0);
    return (l[2] ?? 0) > (c[2] ?? 0);
  }

  static void _showUpdateDialog(
    BuildContext context,
    String version,
    String changelog,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.system_update, color: Colors.blue),
            SizedBox(width: 8),
            Text('Actualizacion disponible'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Nueva version: v$version'),
            const SizedBox(height: 12),
            const Text(
              'Novedades:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(changelog),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Mas tarde'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _downloadAndInstall(context);
            },
            child: const Text('Actualizar ahora'),
          ),
        ],
      ),
    );
  }

  static Future<void> _downloadAndInstall(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text('Descargando actualizacion...'),
          ],
        ),
      ),
    );

    try {
      final dir = await getTemporaryDirectory();
      final savePath = '${dir.path}/update.apk';
      await Dio().download(
        'https://api-dev.baqueanonatales.com/apks/app-clientdev.apk',
        savePath,
      );
      if (context.mounted) Navigator.pop(context);
      await OpenFilex.open(savePath);
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al descargar: $e')),
        );
      }
    }
  }
}
