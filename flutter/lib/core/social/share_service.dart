import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:baqueano_natales/core/social/shareable_entity.dart';

/// Servicio centralizado para compartir cualquier entidad de la app.
///
/// Usa `share_plus` (share sheet nativo) + `url_launcher` (WhatsApp, Telegram, Email).
class ShareService {
  ShareService._();
  static final ShareService instance = ShareService._();

  /// Share sheet nativo de Android/iOS.
  Future<void> shareGeneric(ShareableEntity entity) async {
    final text = entity.buildFullText();
    await SharePlus.instance.share(
      ShareParams(text: text, subject: entity.title),
    );
  }

  /// Comparte directamente por WhatsApp.
  Future<bool> shareToWhatsApp(ShareableEntity entity) async {
    final text = Uri.encodeComponent(entity.buildShortText());
    final url = Uri.parse('https://wa.me/?text=$text');
    return launchUrl(url, mode: LaunchMode.externalApplication);
  }

  /// Comparte por Telegram.
  Future<bool> shareToTelegram(ShareableEntity entity) async {
    final text = Uri.encodeComponent(entity.buildShortText());
    final url = Uri.parse('https://t.me/share/url?url=$text');
    return launchUrl(url, mode: LaunchMode.externalApplication);
  }

  /// Comparte por Email.
  Future<bool> shareToEmail(ShareableEntity entity) async {
    final subject = Uri.encodeComponent(entity.title);
    final body = Uri.encodeComponent(entity.buildFullText());
    final url = Uri.parse('mailto:?subject=$subject&body=$body');
    return launchUrl(url);
  }

  /// Copia el link público al portapapeles (si está disponible).
  Future<void> copyLink(ShareableEntity entity, {BuildContext? context}) async {
    if (entity.publicUrl == null || entity.publicUrl!.isEmpty) return;
    // Nota: para usar Clipboard necesitamos flutter/services.
    // Este método es un placeholder; implementar con Clipboard si se necesita.
  }

  /// Abre una URL externa (ej: WhatsApp del prestador, Instagram).
  Future<bool> openExternal(String url) async {
    final uri = Uri.parse(url);
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
