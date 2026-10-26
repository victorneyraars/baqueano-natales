/// Pantalla Home (dual-role: cliente / prestador).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:baqueano_natales/features/auth/data/auth_notifier.dart';
import 'package:baqueano_natales/core/services/app_update_service.dart';
import 'package:baqueano_natales/core/widgets/version_badge.dart';
import 'package:baqueano_natales/features/home/data/home_providers.dart';
import 'package:baqueano_natales/features/home/presentation/widgets/home_cliente_body.dart';
import 'package:baqueano_natales/features/home/presentation/widgets/home_prestador_body.dart';
import 'package:baqueano_natales/features/home/presentation/widgets/mode_switcher.dart';
import 'package:baqueano_natales/features/settings/presentation/about_screen.dart';
import 'package:baqueano_natales/main_client.dart' show scaffoldMessengerKey;

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _handleLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Estás seguro de que querés cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(authNotifierProvider.notifier).logout();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    final user = authState.user;
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final mode = ref.watch(activeModeProvider);
    final dual = ref.watch(hasDualRoleProvider).value ?? false;
    // Safeguard: si el usuario no es prestador, forzar modo cliente.
    final effectiveMode = (user.role != 'prestador') ? 'cliente' : mode;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        centerTitle: false,
        title: dual
            ? const ModeSwitcher()
            : Text(effectiveMode == 'prestador' ? 'Mi taller' : 'Inicio'),
        actions: appBarActionsWithBadge(
          extra: [
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                if (value == 'about') {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AboutScreen()),
                  );
                } else if (value == 'update') {
                  AppUpdateService.checkForUpdates(
                    GoRouter.of(context),
                    scaffoldMessengerKey,
                    forceShow: true,
                  );
                } else if (value == 'logout') {
                  _handleLogout(context, ref);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'about', child: Text('Acerca de')),
                const PopupMenuItem(
                  value: 'update',
                  child: Text('Buscar actualización'),
                ),
                const PopupMenuItem(
                  value: 'logout',
                  child: Text('Cerrar sesión'),
                ),
              ],
            ),
          ],
        ),
      ),
      body: effectiveMode == 'prestador'
          ? const HomePrestadorBody()
          : const HomeClienteBody(),
    );
  }
}
