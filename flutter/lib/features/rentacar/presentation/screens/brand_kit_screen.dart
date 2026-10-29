import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:baqueano_natales/core/network/dio_client.dart';

class BrandKitScreen extends ConsumerStatefulWidget {
  const BrandKitScreen({super.key, required this.slug});
  final String slug;
  @override
  ConsumerState<BrandKitScreen> createState() => _BrandKitScreenState();
}

class _BrandKitScreenState extends ConsumerState<BrandKitScreen> {
  bool _downloading = false;
  double _progress = 0.0;

  Future<void> _descargar() async {
    setState(() {
      _downloading = true;
      _progress = 0.0;
    });
    try {
      final url = '/api/v1/mis-brand/${widget.slug}/assets';
      final dir = await getTemporaryDirectory();
      final savePath = '${dir.path}/${widget.slug}-brand-kit.zip';
      await DioClient.instance.download(
        url,
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1 && mounted) {
            setState(() => _progress = received / total);
          }
        },
      );
      if (mounted) setState(() => _downloading = false);
      final result = await OpenFilex.open(savePath);
      if (result.type != ResultType.done && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al abrir: ${result.message}')),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _downloading = false);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Kit de marca')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Kit de marca completo',
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '35 archivos optimizados para web, Android, iOS y print.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  const _Fila(
                    'Web',
                    'favicon.ico, 192/512px, og-image, manifest',
                  ),
                  const _Fila(
                    'Android',
                    '5 mipmaps + adaptive foreground/monochrome',
                  ),
                  const _Fila('iOS', '11 AppIcon sizes (20 a 1024)'),
                  const _Fila('Print', 'SVG vectorial + PNG 2048'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              icon: _downloading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download_outlined),
              label: Text(
                _downloading
                    ? 'Descargando ${(_progress * 100).toStringAsFixed(0)}%'
                    : 'Descargar kit de marca',
              ),
              onPressed: _downloading ? null : _descargar,
            ),
          ),
        ],
      ),
    );
  }
}

class _Fila extends StatelessWidget {
  const _Fila(this.plataforma, this.detalle);
  final String plataforma;
  final String detalle;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(
              plataforma,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(child: Text(detalle, style: theme.textTheme.bodySmall)),
        ],
      ),
    );
  }
}
