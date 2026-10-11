/// Providers del modulo promocion.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:baqueano_natales/features/promocion/data/promocion_repository.dart';
import 'package:baqueano_natales/features/promocion/domain/afiche.dart';

// =========================================================
// Repositorio
// =========================================================
final promocionRepositoryProvider = Provider<PromocionRepository>((ref) {
  return PromocionRepository();
});

// =========================================================
// Plantillas (galeria)
// =========================================================
final plantillasPromocionProvider =
    FutureProvider<List<PlantillaInfo>>((ref) async {
  final repo = ref.watch(promocionRepositoryProvider);
  return repo.listarPlantillas();
});

// =========================================================
// Estado del editor (plantilla + tamano + params)
// =========================================================
class EditorAficheState {
  const EditorAficheState({
    this.plantillaId,
    this.tamano = TamanoAfiche.igFeed,
    this.params = const {},
  });

  final String? plantillaId;
  final TamanoAfiche tamano;
  final Map<String, dynamic> params;

  EditorAficheState copyWith({
    String? plantillaId,
    TamanoAfiche? tamano,
    Map<String, dynamic>? params,
  }) {
    return EditorAficheState(
      plantillaId: plantillaId ?? this.plantillaId,
      tamano: tamano ?? this.tamano,
      params: params ?? this.params,
    );
  }

  /// Listo para generar (plantilla elegida + params requeridos presentes).
  bool get listo {
    if (plantillaId == null) return false;
    return params.values.any((v) {
      if (v == null) return false;
      if (v is String) return v.trim().isNotEmpty;
      return true;
    });
  }
}

class EditorAficheNotifier extends StateNotifier<EditorAficheState> {
  EditorAficheNotifier() : super(const EditorAficheState());

  void seleccionarPlantilla(String id) {
    state = EditorAficheState(
      plantillaId: id,
      tamano: state.tamano,
      params: {}, // reset params al cambiar plantilla
    );
  }

  void setTamano(TamanoAfiche t) {
    state = state.copyWith(tamano: t);
  }

  void setParam(String key, dynamic value) {
    state = state.copyWith(
      params: {...state.params, key: value},
    );
  }

  void limpiar() {
    state = EditorAficheState(
      plantillaId: state.plantillaId,
      tamano: state.tamano,
      params: {},
    );
  }
}

final editorAficheProvider =
    StateNotifierProvider<EditorAficheNotifier, EditorAficheState>((ref) {
  return EditorAficheNotifier();
});

// =========================================================
// Generacion del afiche (reactiva a editorAficheProvider)
// =========================================================
final aficheGeneradoProvider =
    FutureProvider.autoDispose<AficheGenerado?>((ref) async {
  final state = ref.watch(editorAficheProvider);
  if (!state.listo) return null;

  final repo = ref.watch(promocionRepositoryProvider);
  return repo.generarAfiche(
    plantilla: state.plantillaId!,
    tamano: state.tamano,
    params: state.params,
  );
});
