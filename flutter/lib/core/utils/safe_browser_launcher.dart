import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Utilidad centralizada para abrir URLs. Evade bloqueos de Motorola/Android 11+.
class SafeBrowserLauncher {
  // IMPORTANTE: El nombre del canal debe coincidir exactamente con MainActivity.kt
  static const MethodChannel _channel = MethodChannel(
    'com.baqueano/url_launcher',
  );

  static Future<bool> open(String url, {BuildContext? context}) async {
    bool success = false;
    String errorMessage = 'No se pudo abrir el enlace automáticamente.';

    if (Platform.isAndroid) {
      try {
        final bool? result = await _channel.invokeMethod('launchUrl', {
          'url': url,
        });
        if (result == true) success = true;
      } on MissingPluginException {
        debugPrint(
          '[SafeBrowserLauncher] Canal nativo no encontrado. Fallback...',
        );
      } on PlatformException catch (e) {
        errorMessage = e.message ?? errorMessage;
      }
    }

    if (!success) {
      try {
        final uri = Uri.parse(url);
        success = await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (e) {
        debugPrint('[SafeBrowserLauncher] Error fallback: $e');
      }
    }

    if (!success && context != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Theme.of(context).colorScheme.error,
          duration: const Duration(seconds: 10),
          action: SnackBarAction(
            label: 'Copiar URL',
            textColor: Theme.of(context).colorScheme.onError,
            onPressed: () => Clipboard.setData(ClipboardData(text: url)),
          ),
        ),
      );
    }
    return success;
  }
}
