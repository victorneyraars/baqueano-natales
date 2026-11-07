import 'package:flutter/material.dart';
import 'package:baqueano_natales/core/network/authed_image_provider.dart';

/// Visor de fotos fullscreen (Lightbox) reutilizable en todo el ecosistema.
///
/// Uso:
/// ```dart
/// PhotoViewer.show(context, urls, initialIndex: 0);
/// ```
///
/// Soporta swipe (PageView) y zoom (InteractiveViewer).
/// Las imagenes se cargan con AuthedImage (requiere JWT).
class PhotoViewer extends StatefulWidget {
  const PhotoViewer({
    super.key,
    required this.urls,
    this.initialIndex = 0,
    this.onEliminar,
  });

  final List<String> urls;
  final int initialIndex;
  final Future<void> Function(int index)? onEliminar;

  static void show(
    BuildContext context,
    List<String> urls, {
    int initialIndex = 0,
    Future<void> Function(int index)? onEliminar,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PhotoViewer(
          urls: urls,
          initialIndex: initialIndex,
          onEliminar: onEliminar,
        ),
      ),
    );
  }

  @override
  State<PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<PhotoViewer> {
  late final PageController _ctrl;
  late int _idx;

  @override
  void initState() {
    super.initState();
    _idx = widget.initialIndex;
    _ctrl = PageController(initialPage: _idx);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.urls.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text('Sin fotos', style: TextStyle(color: Colors.white)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${_idx + 1} / ${widget.urls.length}'),
        actions: [
          if (widget.onEliminar != null)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Eliminar',
              onPressed: () async {
                await widget.onEliminar!(_idx);
                if (context.mounted) Navigator.pop(context);
              },
            ),
        ],
      ),
      body: PageView.builder(
        controller: _ctrl,
        itemCount: widget.urls.length,
        onPageChanged: (i) => setState(() => _idx = i),
        itemBuilder: (context, i) {
          final url = widget.urls[i];
          return InteractiveViewer(
            minScale: 1,
            maxScale: 5,
            child: Center(
              child: Image(
                image: AuthedImage(url: url),
                fit: BoxFit.contain,
                gaplessPlayback: true,
                errorBuilder: (context, error, _) => const Center(
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: Colors.white54,
                    size: 64,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
