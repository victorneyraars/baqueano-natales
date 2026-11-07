/// Providers del home: modo activo y detección de dual-role.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:baqueano_natales/core/config/app_config.dart';
import 'package:baqueano_natales/core/storage/secure_storage.dart';
import 'package:baqueano_natales/features/auth/data/auth_notifier.dart';
import 'package:baqueano_natales/features/prestadores/data/prestador_providers.dart';

/// Modo activo del usuario: 'cliente' o 'prestador'.
/// Persiste en SecureStorage. Default: el rol de la DB.
class ActiveModeNotifier extends Notifier<String> {
  @override
  String build() {
    Future.microtask(_loadSaved);
    final user = ref.read(authNotifierProvider).user;
    return user?.role == 'prestador' ? 'prestador' : 'cliente';
  }

  Future<void> _loadSaved() async {
    final user = ref.read(authNotifierProvider).user;
    // Si NO es prestador, solo puede estar en 'cliente'. Ignorar saved.
    if (user?.role != 'prestador') {
      if (state != 'cliente') {
        state = 'cliente';
      }
      await SecureStorageService.saveActiveMode('cliente');
      return;
    }

    final saved = await SecureStorageService.getActiveMode();
    if (saved != null && saved != state) {
      state = saved;
    }
  }

  Future<void> setMode(String mode) async {
    if (state == mode) return;
    if (mode != 'cliente' && mode != 'prestador') return;
    state = mode;
    await SecureStorageService.saveActiveMode(mode);
  }
}

final activeModeProvider = NotifierProvider<ActiveModeNotifier, String>(
  ActiveModeNotifier.new,
);

/// ¿El usuario puede cambiar de modo?
/// Regla: appType=client + rol=prestador + tiene un perfil de prestador activo.
///
/// Nota de diseño: Anteriormente se exigía que el usuario tuviera un vehículo
/// registrado en la tabla de clientes (misVehiculos) para habilitar el switch.
/// Eso se eliminó porque bloqueaba a los prestadores de Rent a Car (que tienen
/// su flota en rentacar_vehiculos, no en la tabla de clientes) y a mecánicos
/// que no son dueños de un auto registrado en la app.
///
/// Dado que el registro público de prestadores está deshabilitado, cualquier
/// usuario con rol 'prestador' ha sido validado y habilitado por el Admin.
final hasDualRoleProvider = FutureProvider<bool>((ref) async {
  if (AppConfig.appType != AppType.client) return false;

  final auth = ref.watch(authNotifierProvider);
  if (!auth.isAuthenticated) return false;
  final user = auth.user;
  if (user == null) return false;
  if (user.role != 'prestador') return false;

  final misPrestadores = await ref.watch(misPrestadoresProvider.future);
  return misPrestadores.isNotEmpty;
});
