import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:baqueano_natales/features/brand_kit/data/brand_kit_providers.dart';
import 'package:baqueano_natales/features/brand_kit/domain/brand_asset.dart';

/// Pantalla del brand kit: listado por categoría con preview,
/// descarga individual y ZIP completo.
class BrandKitScreen extends ConsumerWidget {
  const BrandKitScreen({super.key, required this.slug});

  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncKit = ref.watch(brandKitProvider(slug));
    return Scaffold(
      appBar: AppBar(title: const Text('Kit de marca')),
      floatingActionButton: asyncKit.maybeWhen(
        data: (kit) => FloatingActionButton.extended(
          icon: const Icon(Icons.download),
          label: Text('Descargar ZIP (${kit.total})'),
          onPressed: () => _downloadZip(context, ref, kit),
        ),
        orElse: () => null,
      ),
      body: asyncKit.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _buildError(context, ref, e),
        data: (kit) => _buildBody(context, ref, kit),
      ),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, BrandKit kit) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
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
                  '${kit.total} archivos optimizados para web, Android, iOS y print.',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        for (final cat in ['web', 'android', 'ios', 'print']) ...[
          _categorySection(context, ref, cat, kit.categories[cat] ?? []),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _categorySection(
    BuildContext context,
    WidgetRef ref,
    String category,
    List<BrandAsset> assets,
  ) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        key: PageStorageKey('cat_$category'),
        title: Row(
          children: [
            Text(_categoryLabel(category), style: theme.textTheme.titleMedium),
            const SizedBox(width: 8),
            Chip(
              label: Text('${assets.length}'),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
        children: [for (final a in assets) _AssetTile(slug: slug, asset: a)],
      ),
    );
  }

  String _categoryLabel(String cat) {
    switch (cat) {
      case 'web':
        return 'Web';
      case 'android':
        return 'Android';
      case 'ios':
        return 'iOS';
      case 'print':
        return 'Print';
      default:
        return cat;
    }
  }

  Widget _buildError(BuildContext context, WidgetRef ref, Object e) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 12),
            Text('Error: $e', textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => ref.invalidate(brandKitProvider(slug)),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _downloadZip(
    BuildContext context,
    WidgetRef ref,
    BrandKit kit,
  ) async {
    try {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Descargando ZIP...')));
      final repo = ref.read(brandKitRepositoryProvider);
      final dir = await getTemporaryDirectory();
      final savePath = '${dir.path}/${kit.slug}-brand-kit.zip';
      await repo.downloadZipToPath(kit.slug, savePath, null);
      await SharePlus.instance.share(
        ShareParams(files: [XFile(savePath)], subject: 'Brand kit ${kit.slug}'),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}

/// Tile individual para un asset con preview y acciones.
class _AssetTile extends ConsumerWidget {
  const _AssetTile({required this.slug, required this.asset});

  final String slug;
  final BrandAsset asset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: SizedBox(
        width: 40,
        height: 40,
        child: asset.hasPreview
            ? _AssetPreview(slug: slug, asset: asset)
            : Icon(_iconFor(asset.contentType)),
      ),
      title: Text(asset.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(asset.subtitle),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.download_outlined),
            tooltip: 'Descargar',
            onPressed: () => _download(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Compartir',
            onPressed: () => _share(context, ref),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(String ct) {
    if (ct == 'image/svg+xml') return Icons.code;
    if (ct == 'image/x-icon') return Icons.image;
    return Icons.insert_drive_file;
  }

  Future<Uint8List> _getBytes(WidgetRef ref) async {
    final repo = ref.read(brandKitRepositoryProvider);
    return repo.downloadAssetBytes(slug, asset.path);
  }

  Future<void> _download(BuildContext context, WidgetRef ref) async {
    try {
      final bytes = await _getBytes(ref);
      final dir = await getTemporaryDirectory();
      final savePath = '${dir.path}/${asset.name}';
      final file = File(savePath);
      await file.writeAsBytes(bytes);
      final result = await OpenFilex.open(savePath);
      if (result.type != ResultType.done && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al abrir: ${result.message}')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _share(BuildContext context, WidgetRef ref) async {
    try {
      final bytes = await _getBytes(ref);
      final dir = await getTemporaryDirectory();
      final savePath = '${dir.path}/${asset.name}';
      final file = File(savePath);
      await file.writeAsBytes(bytes);
      await SharePlus.instance.share(ShareParams(files: [XFile(savePath)]));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}

/// Preview de imagen con cache via FutureProvider.
class _AssetPreview extends ConsumerWidget {
  const _AssetPreview({required this.slug, required this.asset});

  final String slug;
  final BrandAsset asset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncBytes = ref.watch(
      brandAssetBytesProvider((slug: slug, path: asset.path)),
    );
    return asyncBytes.when(
      loading: () => const Center(
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (_, _) => const Icon(Icons.broken_image_outlined),
      data: (bytes) => Image.memory(bytes, fit: BoxFit.contain),
    );
  }
}
