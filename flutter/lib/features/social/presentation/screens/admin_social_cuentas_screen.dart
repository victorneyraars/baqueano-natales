/// Pantalla admin: cuentas sociales conectadas.
///
/// Lista las cuentas de Facebook, Instagram, etc. conectadas al sistema.
/// Muestra red, nombre, propietario, si esta activa y si publica automatico.
///
/// Endpoints: GET /api/v1/admin/social/cuentas
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:baqueano_natales/core/network/api_exceptions.dart';
import 'package:baqueano_natales/features/social/data/social_providers.dart';
import 'package:baqueano_natales/features/social/domain/cuenta_social.dart';

class AdminSocialCuentasScreen extends ConsumerWidget {
  const AdminSocialCuentasScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(cuentasSocialesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Redes sociales'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refrescar',
            onPressed: () => ref.invalidate(cuentasSocialesProvider),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorView(
          error: e,
          onRetry: () => ref.invalidate(cuentasSocialesProvider),
        ),
        data: (data) {
          if (data.items.isEmpty) {
            return const _EmptyView();
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(cuentasSocialesProvider);
              await ref.read(cuentasSocialesProvider.future);
            },
            child: ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: data.items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (ctx, i) => _CuentaCard(cuenta: data.items[i]),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------
// Empty state
// ---------------------------------------------------------
class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off, size: 64, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              'No hay redes conectadas',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Conecta una pagina de Facebook para empezar a publicar '
              'automaticamente.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------
// Error state
// ---------------------------------------------------------
class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final msg = error is ApiException
        ? (error as ApiException).message
        : 'Error inesperado';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
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

// ---------------------------------------------------------
// Card de cuenta
// ---------------------------------------------------------
class _CuentaCard extends ConsumerWidget {
  const _CuentaCard({required this.cuenta});

  final CuentaSocial cuenta;

  IconData get _icon {
    switch (cuenta.red) {
      case RedSocial.facebook:
        return Icons.facebook;
      case RedSocial.instagram:
        return Icons.camera_alt;
      case RedSocial.googleBusiness:
        return Icons.storefront;
    }
  }

  Color get _color {
    switch (cuenta.red) {
      case RedSocial.facebook:
        return const Color(0xFF1877F2);
      case RedSocial.instagram:
        return const Color(0xFFE1306C);
      case RedSocial.googleBusiness:
        return const Color(0xFF34A853);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_icon, color: _color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          cuenta.nombreVisible,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      _Badge(label: cuenta.red.label, color: _color),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    cuenta.propietarioTipo.label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (cuenta.instagramUsername != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      '@${cuenta.instagramUsername}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _Pill(
                        label: cuenta.activo ? 'Activa' : 'Inactiva',
                        icon: cuenta.activo ? Icons.check_circle : Icons.cancel,
                        color: cuenta.activo ? Colors.green : Colors.grey,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _AutoPublishSwitch(cuenta: cuenta),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------
// Small widgets
// ---------------------------------------------------------
class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.icon, required this.color});

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Switch para activar/desactivar publicacion automatica de una cuenta.
class _AutoPublishSwitch extends ConsumerStatefulWidget {
  const _AutoPublishSwitch({required this.cuenta});
  final CuentaSocial cuenta;

  @override
  ConsumerState<_AutoPublishSwitch> createState() => _AutoPublishSwitchState();
}

class _AutoPublishSwitchState extends ConsumerState<_AutoPublishSwitch> {
  bool _loading = false;

  Future<void> _toggle(bool value) async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final repo = ref.read(socialRepositoryProvider);
      await repo.toggleAutoPublishCuenta(
        cuentaId: widget.cuenta.id,
        activo: value,
      );
      ref.invalidate(cuentasSocialesProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              value
                  ? '✅ Auto-publicacion activada'
                  : '⏸️ Auto-publicacion desactivada',
            ),
            backgroundColor: value ? Colors.green : Colors.grey.shade700,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: widget.cuenta.autoPublish
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: SwitchListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
        secondary: Icon(
          widget.cuenta.autoPublish ? Icons.bolt : Icons.pan_tool_alt,
          color: widget.cuenta.autoPublish
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurfaceVariant,
          size: 20,
        ),
        title: Text(
          'Publicar automaticamente',
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          widget.cuenta.autoPublish
              ? 'Esta cuenta recibe publicaciones automaticas'
              : 'Esta cuenta no recibe publicaciones automaticas',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        value: widget.cuenta.autoPublish,
        onChanged: _loading ? null : _toggle,
      ),
    );
  }
}
