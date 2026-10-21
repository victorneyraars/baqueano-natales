/// Pantalla: galeria de fotos de una orden (cliente o prestador).
///
/// Carga las fotos via provider correspondiente segun `prestadorId`:
/// - null  -> cliente (`fotosDeMiOrdenProvider`)
/// - !null -> prestador (`fotosDeOrdenPrestadorProvider`)
///
/// Acciones:
/// - FAB "Subir foto": bottom sheet con camara/galeria + momento.
/// - Tap en foto: visor fullscreen con swipe + pinch zoom.
/// - Long-press en foto: eliminar (soft).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'package:baqueano_natales/core/network/api_exceptions.dart';
import 'package:baqueano_natales/core/network/authed_image_provider.dart';
import 'package:baqueano_natales/features/oficios/data/oficios_providers.dart';
import 'package:baqueano_natales/features/oficios/domain/orden_foto.dart';
import 'package:baqueano_natales/features/oficios/presentation/widgets/foto_thumb.dart';

class GaleriaFotosScreen extends ConsumerStatefulWidget {
  const GaleriaFotosScreen({
    super.key,
    required this.ordenId,
    this.prestadorId,
  });

  final String ordenId;

  /// Si es null, se asume rol cliente.
  final String? prestadorId;

  @override
  ConsumerState<GaleriaFotosScreen> createState() => _GaleriaFotosScreenState();
}

class _GaleriaFotosScreenState extends ConsumerState<GaleriaFotosScreen> {
  MomentoFoto? _filtroMomento;
  bool _subiendo = false;

  bool get _esPrestador => widget.prestadorId != null;
  bool get _tieneFiltro => _filtroMomento != null;

  AsyncValue<List<OrdenFoto>> _watchFotos() {
    if (_esPrestador) {
      return ref.watch(
        fotosDeOrdenPrestadorProvider(
          FotosDeOrdenPrestadorParams(
            prestadorId: widget.prestadorId!,
            ordenId: widget.ordenId,
            momento: _filtroMomento,
          ),
        ),
      );
    }
    return ref.watch(
      fotosDeMiOrdenProvider(
        FotosDeMiOrdenParams(ordenId: widget.ordenId, momento: _filtroMomento),
      ),
    );
  }

  Future<void> _refrescar() async {
    if (_esPrestador) {
      ref.invalidate(
        fotosDeOrdenPrestadorProvider(
          FotosDeOrdenPrestadorParams(
            prestadorId: widget.prestadorId!,
            ordenId: widget.ordenId,
            momento: _filtroMomento,
          ),
        ),
      );
    } else {
      ref.invalidate(
        fotosDeMiOrdenProvider(
          FotosDeMiOrdenParams(
            ordenId: widget.ordenId,
            momento: _filtroMomento,
          ),
        ),
      );
    }
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }

  Future<void> _abrirSubirFoto() async {
    final messenger = ScaffoldMessenger.of(context);
    final fuente = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Tomar foto'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Elegir de galeria'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (fuente == null) return;

    final momento = await _pedirMomento();
    if (momento == null) return;

    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(
      source: fuente,
      maxWidth: 2048,
      maxHeight: 2048,
      imageQuality: 85,
    );
    if (picked == null) return;
    if (!mounted) return;

    setState(() => _subiendo = true);
    try {
      final bytes = await picked.readAsBytes();
      final repo = ref.read(oficiosRepositoryProvider);
      if (_esPrestador) {
        await repo.subirFotoPrestador(
          prestadorId: widget.prestadorId!,
          ordenId: widget.ordenId,
          bytes: bytes,
          nombreArchivo: picked.name,
          momento: momento,
        );
      } else {
        await repo.subirFoto(
          ordenId: widget.ordenId,
          bytes: bytes,
          nombreArchivo: picked.name,
          momento: momento,
        );
      }
      await _refrescar();
      messenger.showSnackBar(const SnackBar(content: Text('Foto subida')));
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _subiendo = false);
    }
  }

  Future<MomentoFoto?> _pedirMomento() {
    return showModalBottomSheet<MomentoFoto>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'Momento de la foto',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            for (final m in MomentoFoto.values)
              ListTile(
                title: Text(m.label),
                onTap: () => Navigator.pop(ctx, m),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _eliminarFoto(OrdenFoto foto) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar foto'),
        content: const Text('Esta accion no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      final repo = ref.read(oficiosRepositoryProvider);
      if (_esPrestador) {
        await repo.eliminarFotoDeOrdenPrestador(
          widget.prestadorId!,
          widget.ordenId,
          foto.id,
        );
      } else {
        await repo.eliminarFotoDeMiOrden(widget.ordenId, foto.id);
      }
      await _refrescar();
      messenger.showSnackBar(const SnackBar(content: Text('Foto eliminada')));
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _abrirVisor(List<OrdenFoto> fotos, int initialIndex) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _VisorFotos(
          fotos: fotos,
          initialIndex: initialIndex,
          onEliminar: _eliminarFoto,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final async = _watchFotos();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _tieneFiltro
              ? 'Fotos - ${_filtroMomento!.label}'
              : 'Fotos de la orden',
        ),
        actions: [
          IconButton(
            icon: Badge(
              isLabelVisible: _tieneFiltro,
              child: const Icon(Icons.tune),
            ),
            tooltip: 'Filtrar por momento',
            onPressed: _abrirFiltro,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refrescar',
            onPressed: _refrescar,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _subiendo ? null : _abrirSubirFoto,
        icon: _subiendo
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.add_a_photo_outlined),
        label: Text(_subiendo ? 'Subiendo...' : 'Subir foto'),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorView(error: e, onRetry: _refrescar),
        data: (fotos) {
          if (fotos.isEmpty) {
            return _EmptyView(
              filtro: _filtroMomento,
              onSubir: _subiendo ? null : _abrirSubirFoto,
            );
          }
          return RefreshIndicator(
            onRefresh: _refrescar,
            child: GridView.builder(
              // Padding bottom extra para que el FAB no tape la ultima fila.
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 6,
                mainAxisSpacing: 6,
                childAspectRatio: 1,
              ),
              itemCount: fotos.length,
              itemBuilder: (context, i) {
                final f = fotos[i];
                return FotoThumb(
                  foto: f,
                  onTap: () => _abrirVisor(fotos, i),
                  onLongPress: () => _eliminarFoto(f),
                );
              },
            ),
          );
        },
      ),
    );
  }

  void _abrirFiltro() {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'Filtrar por momento',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.clear_all),
              title: const Text('Todos'),
              selected: _filtroMomento == null,
              onTap: () {
                Navigator.pop(ctx);
                setState(() => _filtroMomento = null);
              },
            ),
            for (final m in MomentoFoto.values)
              ListTile(
                title: Text(m.label),
                selected: _filtroMomento == m,
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => _filtroMomento = m);
                },
              ),
          ],
        ),
      ),
    );
  }
}

// =========================================================
// Visor fullscreen
// =========================================================
class _VisorFotos extends StatefulWidget {
  const _VisorFotos({
    required this.fotos,
    required this.initialIndex,
    required this.onEliminar,
  });

  final List<OrdenFoto> fotos;
  final int initialIndex;
  final Future<void> Function(OrdenFoto) onEliminar;

  @override
  State<_VisorFotos> createState() => _VisorFotosState();
}

class _VisorFotosState extends State<_VisorFotos> {
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
    if (widget.fotos.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text('Sin fotos', style: TextStyle(color: Colors.white)),
        ),
      );
    }
    final foto = widget.fotos[_idx];
    final url = foto.urlOriginal ?? foto.urlMedium ?? foto.urlThumb;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          '${_idx + 1} / ${widget.fotos.length}  -  ${foto.momento.label}',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Eliminar',
            onPressed: () async {
              await widget.onEliminar(foto);
              if (context.mounted) Navigator.pop(context);
            },
          ),
        ],
      ),
      body: url == null
          ? const Center(
              child: Text('Sin imagen', style: TextStyle(color: Colors.white)),
            )
          : PageView.builder(
              controller: _ctrl,
              itemCount: widget.fotos.length,
              onPageChanged: (i) => setState(() => _idx = i),
              itemBuilder: (context, i) {
                final f = widget.fotos[i];
                final u = f.urlOriginal ?? f.urlMedium ?? f.urlThumb;
                if (u == null) return const SizedBox.shrink();
                return InteractiveViewer(
                  minScale: 1,
                  maxScale: 5,
                  child: Center(
                    child: Image(
                      image: AuthedImage(url: u),
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

// =========================================================
// Vistas auxiliares
// =========================================================
class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.filtro, required this.onSubir});

  final MomentoFoto? filtro;
  final VoidCallback? onSubir;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.photo_camera_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(
              filtro == null
                  ? 'Aun no hay fotos en esta orden'
                  : 'No hay fotos en el momento "${filtro!.label}"',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Subi la primera foto para documentar el trabajo.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onSubir,
              icon: const Icon(Icons.add_a_photo_outlined),
              label: const Text('Subir foto'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final msg = error is ApiException
        ? (error as ApiException).message
        : 'No se pudieron cargar las fotos.';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 12),
            Text(msg, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
