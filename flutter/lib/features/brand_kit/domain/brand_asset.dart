/// Asset individual del brand kit.
///
/// Mapea el JSON del endpoint GET /mis-brand/{slug}/assets/list.
class BrandAsset {
  const BrandAsset({
    required this.path,
    required this.name,
    required this.category,
    required this.sizeBytes,
    required this.contentType,
    this.dimensions,
  });

  final String path;
  final String name;
  final String category;
  final int sizeBytes;
  final String contentType;
  final String? dimensions;

  factory BrandAsset.fromJson(Map<String, dynamic> json) {
    return BrandAsset(
      path: json['path'] as String,
      name: json['name'] as String,
      category: json['category'] as String,
      sizeBytes: (json['size_bytes'] as num).toInt(),
      contentType: json['content_type'] as String,
      dimensions: json['dimensions'] as String?,
    );
  }

  bool get isPng => contentType == 'image/png';
  bool get isSvg => contentType == 'image/svg+xml';
  bool get isIco => contentType == 'image/x-icon';
  bool get hasPreview => isPng;

  String get sizeLabel {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String get subtitle {
    final parts = <String>[sizeLabel];
    if (dimensions != null) parts.add(dimensions!);
    return parts.join(' · ');
  }
}

/// Brand kit completo agrupado por categoría.
class BrandKit {
  const BrandKit({
    required this.slug,
    required this.total,
    required this.categories,
  });

  final String slug;
  final int total;
  final Map<String, List<BrandAsset>> categories;

  factory BrandKit.fromJson(Map<String, dynamic> json) {
    final raw = json['categories'] as Map<String, dynamic>? ?? {};
    final cats = <String, List<BrandAsset>>{};
    for (final entry in raw.entries) {
      final list = entry.value as List<dynamic>? ?? [];
      cats[entry.key] = list
          .whereType<Map<String, dynamic>>()
          .map(BrandAsset.fromJson)
          .toList();
    }
    return BrandKit(
      slug: json['slug'] as String,
      total: (json['total'] as num).toInt(),
      categories: cats,
    );
  }

  List<BrandAsset> get all => categories.values.expand((l) => l).toList();
}
