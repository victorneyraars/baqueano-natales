/// Providers de Riverpod para el modulo social (admin).
///
/// Expone:
/// - Repositorio (inyectable para tests).
/// - Listado de cuentas conectadas.
/// - Config global.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:baqueano_natales/features/social/data/social_repository.dart';
import 'package:baqueano_natales/features/social/domain/cuenta_social.dart';

// =========================================================
// Repositorio (inyectable para tests)
// =========================================================
final socialRepositoryProvider = Provider<SocialRepository>((ref) {
  return SocialRepository();
});

// =========================================================
// Listado de cuentas conectadas
// =========================================================
final cuentasSocialesProvider =
    FutureProvider<CuentasPaginadas>((ref) async {
  final repo = ref.watch(socialRepositoryProvider);
  return repo.listarCuentas();
});

// =========================================================
// Config global
// =========================================================
final configSocialProvider = FutureProvider<ConfigSocial>((ref) async {
  final repo = ref.watch(socialRepositoryProvider);
  return repo.obtenerConfig();
});

// =========================================================
// Cuentas filtradas por red (family)
// =========================================================
final cuentasSocialesPorRedProvider =
    FutureProvider.family<CuentasPaginadas, RedSocial?>((ref, red) async {
  final repo = ref.watch(socialRepositoryProvider);
  return repo.listarCuentas(red: red);
});


// =========================================================
// Acciones (no son providers de estado, son helpers)
// =========================================================

/// Devuelve una funcion que llama al worker y refresca la lista de cuentas.
final procesarColaAhoraProvider = Provider<Future<Map<String, dynamic>>
    Function()>((ref) {
  return () async {
    final repo = ref.read(socialRepositoryProvider);
    final stats = await repo.procesarColaAhora();
    // Refrescar listados tras publicar
    ref.invalidate(cuentasSocialesProvider);
    return stats;
  };
});

/// Actualiza la config global y refresca el provider.
final actualizarConfigProvider =
    Provider<Future<ConfigSocial> Function({
      bool? autoPublish,
      String? destino,
      bool? publicarEnFacebook,
      bool? publicarEnInstagram,
    })>((ref) {
  return ({
    bool? autoPublish,
    String? destino,
    bool? publicarEnFacebook,
    bool? publicarEnInstagram,
  }) async {
    final repo = ref.read(socialRepositoryProvider);
    final result = await repo.actualizarConfig(
      autoPublish: autoPublish,
      destino: destino,
      publicarEnFacebook: publicarEnFacebook,
      publicarEnInstagram: publicarEnInstagram,
    );
    ref.invalidate(configSocialProvider);
    return result;
  };
});
