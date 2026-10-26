import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:baqueano_natales/features/admin/data/media_admin_service.dart';
import 'package:baqueano_natales/features/admin/domain/media_asset.dart';

final mediaAdminServiceProvider = Provider<MediaAdminService>((ref) {
  return MediaAdminService();
});

final mediaPendientesProvider = FutureProvider<List<MediaAsset>>((ref) async {
  final service = ref.watch(mediaAdminServiceProvider);
  return service.listarPendientes();
});
