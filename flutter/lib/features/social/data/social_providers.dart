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
import 'package:baqueano_natales/features/social/domain/publicacion_social.dart';

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
// Cola de publicaciones (filtro por estado)
// =========================================================

/// Parametros de filtro para el listado de publicaciones.
class PublicacionesFiltro {
  const PublicacionesFiltro({this.estado, this.red});

  final EstadoPublicacion? estado;
  final RedSocial? red;

  @override
  bool operator ==(Object other) =>
      other is PublicacionesFiltro &&
      other.estado == estado &&
      other.red == red;

  @override
  int get hashCode => Object.hash(estado, red);
}

/// Listado de publicaciones con filtros.
final publicacionesSocialesProvider =
    FutureProvider.family<PublicacionesPaginadas, PublicacionesFiltro>(
  (ref, filtro) async {
    final repo = ref.watch(socialRepositoryProvider);
    return repo.listarPublicaciones(estado: filtro.estado, red: filtro.red);
  },
);

// =========================================================
// Publicaciones de un prestador (family)
// =========================================================

final publicacionesDePrestadorProvider =
    FutureProvider.family<List<PublicacionSocial>, String>((ref, id) async {
  final repo = ref.watch(socialRepositoryProvider);
  return repo.listarPublicacionesDePrestador(id);
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

/// Devuelve una funcion que reencola una publicacion y refresca la lista.
final reencolarPublicacionProvider =
    Provider<Future<PublicacionSocial> Function(String)>((ref) {
  return (String publicacionId) async {
    final repo = ref.read(socialRepositoryProvider);
    final result = await repo.reencolarPublicacion(publicacionId);
    // Refrescar todos los listados de publicaciones
    ref.invalidate(publicacionesSocialesProvider);
    return result;
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
