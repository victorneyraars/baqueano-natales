import 'dart:io';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';

class AppUpdateService {
  static const String versionUrl =
      'https://api-dev.baqueanonatales.com/apks/version.json';

  static Future<void> checkForUpdates(GoRouter router, GlobalKey<ScaffoldMessengerState> messengerKey, {bool forceShow = false}) async {
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

      if (_isNewerVersion(latestVersion, currentVersion)) {
        final ctx = router.routerDelegate.navigatorKey.currentContext;
        if (ctx != null && ctx.mounted) {
          _showUpdateDialog(ctx, latestVersion, changelog);
        }
      } else if (forceShow) {
        messengerKey.currentState?.showSnackBar(
          const SnackBar(content: Text('Ya estás en la última versión disponible.')),
        );
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
    // Capturar messenger, navigator y context ANTES de los awaits
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final navContext = Navigator.of(context).context;

    // Auto-permiso: si no está habilitado, abrir ajustes
    if (await Permission.requestInstallPackages.isDenied) {
      await Permission.requestInstallPackages.request();
      if (await Permission.requestInstallPackages.isPermanentlyDenied) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Habilita "Instalar apps desconocidas" en Ajustes para actualizar.'),
            duration: Duration(seconds: 5),
          ),
        );
        return;
      }
    }

    // Mostrar diálogo de progreso (con guard de mounted)
    if (!navContext.mounted) return;
    showDialog(
      context: navContext,
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
      
      // Descargar el APK
      await Dio().download(
        'https://api-dev.baqueanonatales.com/apks/app-clientdev.apk',
        savePath,
      );
      
      // Calcular SHA-256 local del archivo descargado
      final file = File(savePath);
      final bytes = await file.readAsBytes();
      final hash = sha256.convert(bytes).toString();
      
      // Obtener el hash esperado del version.json
      final versionData = (await Dio().get(
        'https://api-dev.baqueanonatales.com/apks/version.json?t=${DateTime.now().millisecondsSinceEpoch}',
      )).data;
      final expectedHash = versionData['sha256'] as String? ?? '';
      
      // Comparar
      if (expectedHash.isNotEmpty && hash != expectedHash) {
        navigator.pop();
        await file.delete(); // Borrar el APK corrupto
        messenger.showSnackBar(
          const SnackBar(
            content: Text('❌ Error de integridad: el APK descargado está corrupto o fue manipulado.'),
            duration: Duration(seconds: 5),
          ),
        );
        return;
      }
      
      navigator.pop(); // Cerrar el diálogo de progreso
      await OpenFilex.open(savePath);
    } catch (e) {
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(content: Text('Error al descargar: $e')),
      );
    }
  }
}
