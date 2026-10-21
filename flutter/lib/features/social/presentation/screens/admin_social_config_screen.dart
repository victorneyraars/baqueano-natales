/// Pantalla admin: configuracion global de publicacion en redes.
///
/// Permite:
/// - Activar/desactivar la publicacion automatica
/// - Elegir destino (central / propio / ambos)
/// - Activar/desactivar publicacion en Facebook / Instagram
/// - Forzar un ciclo del worker ("Procesar cola ahora")
///
/// Endpoints:
///   GET   /api/v1/admin/social/config
///   PATCH /api/v1/admin/social/config
///   POST  /api/v1/admin/social/publicaciones/procesar-ahora
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:baqueano_natales/core/network/api_exceptions.dart';
import 'package:baqueano_natales/features/social/data/social_providers.dart';
import 'package:baqueano_natales/features/social/data/social_repository.dart';

class AdminSocialConfigScreen extends ConsumerWidget {
  const AdminSocialConfigScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(configSocialProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuracion'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Recargar',
            onPressed: () => ref.invalidate(configSocialProvider),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorView(
          error: e,
          onRetry: () => ref.invalidate(configSocialProvider),
        ),
        data: (cfg) => _ConfigForm(initial: cfg),
      ),
    );
  }
}

// ---------------------------------------------------------
// Form con estado local (para trackear cambios sin guardar)
// ---------------------------------------------------------
class _ConfigForm extends ConsumerStatefulWidget {
  const _ConfigForm({required this.initial});

  final ConfigSocial initial;

  @override
  ConsumerState<_ConfigForm> createState() => _ConfigFormState();
}

class _ConfigFormState extends ConsumerState<_ConfigForm> {
  late bool _autoPublish;
  late String _destino;
  late bool _enFacebook;
  late bool _enInstagram;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _autoPublish = widget.initial.autoPublish;
    _destino = widget.initial.destino;
    _enFacebook = widget.initial.publicarEnFacebook;
    _enInstagram = widget.initial.publicarEnInstagram;
  }

  bool get _hayCambios {
    return _autoPublish != widget.initial.autoPublish ||
        _destino != widget.initial.destino ||
        _enFacebook != widget.initial.publicarEnFacebook ||
        _enInstagram != widget.initial.publicarEnInstagram;
  }

  Future<void> _guardar() async {
    setState(() => _saving = true);
    try {
      final fn = ref.read(actualizarConfigProvider);
      await fn(
        autoPublish: _autoPublish,
        destino: _destino,
        publicarEnFacebook: _enFacebook,
        publicarEnInstagram: _enInstagram,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Configuracion guardada')));
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: ${e.message}')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _procesarColaAhora() async {
    setState(() => _saving = true);
    try {
      final fn = ref.read(procesarColaAhoraProvider);
      final stats = await fn();
      if (mounted) {
        final procesadas = stats['procesadas'] ?? 0;
        final publicadas = stats['publicadas'] ?? 0;
        final falladas = stats['falladas'] ?? 0;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Worker: $procesadas procesadas, '
              '$publicadas publicadas, $falladas falladas',
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: ${e.message}')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // --- Seccion: Publicacion automatica ---
        const _SectionTitle(title: 'Publicacion automatica'),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('Activar publicacion automatica'),
                subtitle: const Text(
                  'Cuando se aprueba un prestador o se agrega un servicio, '
                  'se publica automaticamente en las redes configuradas.',
                ),
                value: _autoPublish,
                onChanged: (v) => setState(() => _autoPublish = v),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // --- Seccion: Redes ---
        const _SectionTitle(title: 'Redes'),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.facebook),
                title: const Text('Facebook'),
                value: _enFacebook,
                onChanged: _autoPublish
                    ? (v) => setState(() => _enFacebook = v)
                    : null,
              ),
              const Divider(height: 1),
              SwitchListTile(
                secondary: const Icon(Icons.camera_alt),
                title: const Text('Instagram'),
                subtitle: const Text(
                  'Requiere imagen. Si la publicacion no tiene foto, '
                  'se salta Instagram.',
                ),
                value: _enInstagram,
                onChanged: _autoPublish
                    ? (v) => setState(() => _enInstagram = v)
                    : null,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // --- Seccion: Destino ---
        const _SectionTitle(title: 'Destino'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Donde publicar los eventos de los prestadores:',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                AbsorbPointer(
                  absorbing: !_autoPublish,
                  child: Opacity(
                    opacity: _autoPublish ? 1.0 : 0.5,
                    child: RadioGroup<String>(
                      groupValue: _destino,
                      onChanged: (v) =>
                          setState(() => _destino = v ?? 'central'),
                      child: const Column(
                        children: [
                          RadioListTile<String>(
                            value: 'central',
                            title: Text('Solo cuenta central'),
                            subtitle: Text('Baqueano Natales'),
                          ),
                          RadioListTile<String>(
                            value: 'propio',
                            title: Text('Solo cuenta del prestador'),
                            subtitle: Text(
                              'Requiere que el prestador tenga una',
                            ),
                          ),
                          RadioListTile<String>(
                            value: 'ambos',
                            title: Text('Ambas'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // --- Seccion: Acciones ---
        const _SectionTitle(title: 'Acciones'),
        FilledButton.icon(
          onPressed: (_hayCambios && !_saving) ? _guardar : null,
          icon: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save),
          label: const Text('Guardar cambios'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _saving ? null : _procesarColaAhora,
          icon: const Icon(Icons.play_arrow),
          label: const Text('Procesar cola ahora'),
        ),
        const SizedBox(height: 8),
        Text(
          'Fuerza un ciclo del worker sin esperar los 30 segundos. '
          'Util para publicar inmediatamente tras guardar cambios.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------
// Widgets auxiliares
// ---------------------------------------------------------
class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

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
