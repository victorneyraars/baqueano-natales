import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../../data/ops_providers.dart';

class ApkDownloadButton extends ConsumerStatefulWidget {
  final String flavor;
  final String label;
  final IconData icon;

  const ApkDownloadButton({
    super.key,
    required this.flavor,
    required this.label,
    required this.icon,
  });

  @override
  ConsumerState<ApkDownloadButton> createState() => _ApkDownloadButtonState();
}

class _ApkDownloadButtonState extends ConsumerState<ApkDownloadButton> {
  bool _isDownloading = false;
  double _progress = 0.0;

  Future<void> _downloadAndInstall() async {
    setState(() {
      _isDownloading = true;
      _progress = 0.0;
    });
    try {
      final repo = ref.read(opsRepositoryProvider);
      final apkInfo = await repo.getLatestApk(widget.flavor);
      final url = apkInfo['url'];
      final version = apkInfo['version'] ?? 'dev';

      final dir = await getTemporaryDirectory();
      final savePath = '${dir.path}/app-${widget.flavor}-$version.apk';

      await Dio().download(
        url,
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            setState(() {
              _progress = received / total;
            });
          }
        },
      );

      setState(() {
        _isDownloading = false;
      });

      final result = await OpenFilex.open(savePath);
      if (result.type != ResultType.done && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al abrir instalador: ${result.message}'),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isDownloading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error al descargar: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        icon: _isDownloading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(widget.icon),
        label: _isDownloading
            ? Text('Descargando... ${(_progress * 100).toStringAsFixed(0)}%')
            : Text(widget.label),
        onPressed: _isDownloading ? null : _downloadAndInstall,
      ),
    );
  }
}
