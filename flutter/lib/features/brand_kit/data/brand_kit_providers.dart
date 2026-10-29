import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:baqueano_natales/features/brand_kit/data/brand_kit_repository.dart';
import 'package:baqueano_natales/features/brand_kit/domain/brand_asset.dart';

/// Provider del repositorio (inyectable para tests).
final brandKitRepositoryProvider = Provider<BrandKitRepository>((ref) {
  return BrandKitRepository();
});

/// Lista de assets del brand kit por slug del prestador.
///
/// Uso: ref.watch(brandKitProvider('vasquez'))
final brandKitProvider = FutureProvider.family<BrandKit, String>((
  ref,
  slug,
) async {
  final repo = ref.watch(brandKitRepositoryProvider);
  return repo.listAssets(slug);
});

/// Bytes de un asset individual para preview o guardado.
///
/// Uso: ref.watch(brandAssetBytesProvider((slug: 'vasquez', path: 'web/favicon-32x32.png')))
final brandAssetBytesProvider =
    FutureProvider.family<Uint8List, ({String slug, String path})>((
      ref,
      args,
    ) async {
      final repo = ref.watch(brandKitRepositoryProvider);
      return repo.downloadAssetBytes(args.slug, args.path);
    });
