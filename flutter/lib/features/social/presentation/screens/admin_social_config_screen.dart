/// Pantalla admin: configuracion global o por prestador de publicacion en redes.
///
/// Permite:
/// - Alternar entre configuracion global y configuracion individual por prestador
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
import 'package:baqueano_natales/features/prestadores/data/prestador_providers.dart';
import 'package:baqueano_natales/features/prestadores/domain/prestador.dart';
import 'package:baqueano_natales/features/social/data/social_providers.dart';
import 'package:baqueano_natales/features/social/domain/cuenta_social.dart';
import 'package:baqueano_natales/features/social/data/social_repository.dart';

const String _kSeAlquilaMaridoId = 'aaaaaaaa-1111-4111-8111-aaaaaaaaaaaa';

class AdminSocialConfigScreen extends ConsumerStatefulWidget {
  const AdminSocialConfigScreen({super.key});

  @override
  ConsumerState<AdminSocialConfigScreen> createState() =>
      _AdminSocialConfigScreenState();
}

class _AdminSocialConfigScreenState
    extends ConsumerState<AdminSocialConfigScreen> {
  String _alcance = 'global';
  final _idCtrl = TextEditingController();
  String? _idActivo;

  @override
  void dispose() {
    _idCtrl.dispose();
    super.dispose();
  }

  ConfigPropietarioFiltro get _filtroActual {
    final esPrest = _alcance == 'prestador';
    return ConfigPropietarioFiltro(
      propietarioTipo: esPrest ? 'prestador' : null,
      propietarioId: esPrest ? _idActivo : null,
    );
  }

  void _aplicarIdPrestador(String rawId) {
    final limpio = rawId.trim();
    if (limpio.isEmpty) {
      setState(() => _idActivo = null);
      return;
    }
    _idCtrl.text = limpio;
    setState(() => _idActivo = limpio);
  }

  void _recargar() {
    ref.invalidate(configSocialProvider);
    final esPrest = _alcance != 'prestador' || _idActivo != null;
    if (esPrest) {
      ref.invalidate(configPorPropietarioProvider(_filtroActual));
    }
  }

  @override
  Widget build(BuildContext context) {
    final esPrest = _alcance == 'prestador';
    final prestadoresAsync = ref.watch(
      adminPrestadoresProvider(
        const AdminPrestadoresParams(incluirInactivos: true),
      ),
    );
    final cuentasAsync = ref.watch(cuentasSocialesProvider);
    final prestadores =
        prestadoresAsync.asData?.value.items ?? const <Prestador>[];
    final cuentas = cuentasAsync.asData?.value.items ?? const <CuentaSocial>[];
    final cuentasSel = _idActivo == null
        ? const <CuentaSocial>[]
        : cuentas
              .where(
                (c) =>
                    c.propietarioTipo.name == 'prestador' &&
                    c.propietarioId == _idActivo,
              )
              .toList();
    Prestador? selPrest;
    for (final pr in prestadores) {
      if (pr.id == _idActivo) {
        selPrest = pr;
        break;
      }
    }
    final puedeConsultar =
        !esPrest || (_idActivo != null && _idActivo!.isNotEmpty);
    final providerAsync = puedeConsultar
        ? ref.watch(configPorPropietarioProvider(_filtroActual))
        : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuracion'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Recargar',
            onPressed: _recargar,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment<String>(
                          value: 'global',
                          label: Text('Global (Baqueano)'),
                          icon: Icon(Icons.public),
                        ),
                        ButtonSegment<String>(
                          value: 'prestador',
                          label: Text('Por prestador'),
                          icon: Icon(Icons.storefront),
                        ),
                      ],
                      selected: {_alcance},
                      onSelectionChanged: (seleccion) {
                        final nuevo = seleccion.first;
                        setState(() {
                          _alcance = nuevo;
                          if (nuevo == 'prestador' &&
                              (_idActivo == null || _idActivo!.isEmpty)) {
                            _idCtrl.text = _kSeAlquilaMaridoId;
                            _idActivo = _kSeAlquilaMaridoId;
                          }
                        });
                      },
                    ),
                    if (esPrest) ...[
                      const SizedBox(height: 12),
                      if (prestadores.isNotEmpty) ...[
                        DropdownButtonFormField<String>(
                          initialValue:
                              prestadores.any((pr) => pr.id == _idActivo)
                              ? _idActivo
                              : null,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Prestador',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: prestadores.map((pr) {
                            final tieneRed = cuentas.any(
                              (c) =>
                                  c.propietarioTipo.name == 'prestador' &&
                                  c.propietarioId == pr.id,
                            );
                            return DropdownMenuItem<String>(
                              value: pr.id,
                              child: Text(
                                '${pr.nombre} (${tieneRed ? 'con red' : 'sin red'})',
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (v) {
                            if (v != null) _aplicarIdPrestador(v);
                          },
                        ),
                        const SizedBox(height: 8),
                      ],
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _idCtrl,
                              decoration: const InputDecoration(
                                labelText: 'UUID del prestador',
                                hintText: _kSeAlquilaMaridoId,
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              onSubmitted: _aplicarIdPrestador,
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed: () => _aplicarIdPrestador(_idCtrl.text),
                            child: const Text('Cargar'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          ActionChip(
                            label: const Text('Se Alquila Marido'),
                            onPressed: () =>
                                _aplicarIdPrestador(_kSeAlquilaMaridoId),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          if (esPrest && _idActivo != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Card(
                child: ListTile(
                  leading: Icon(
                    cuentasSel.isNotEmpty
                        ? Icons.check_circle
                        : Icons.info_outline,
                  ),
                  title: Text(
                    selPrest?.nombre ??
                        (_idActivo == _kSeAlquilaMaridoId
                            ? 'Se Alquila Marido'
                            : 'Prestador'),
                  ),
                  subtitle: Text(
                    cuentasSel.isEmpty
                        ? 'Sin cuenta social propia conectada'
                        : 'Cuenta propia: ${cuentasSel.map((c) => c.nombreVisible).join(', ')}',
                  ),
                ),
              ),
            ),
          Expanded(
            child: !puedeConsultar
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Ingresa el UUID del prestador y presiona Cargar para editar su configuracion.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : providerAsync!.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => _ErrorView(error: e, onRetry: _recargar),
                    data: (cfg) => _ConfigForm(
                      key: ValueKey(
                        '${_alcance}_${_idActivo ?? 'global'}_${cfg.autoPublish}_${cfg.destino}_${cfg.publicarEnFacebook}_${cfg.publicarEnInstagram}',
                      ),
                      initial: cfg,
                      propietarioTipo: esPrest ? 'prestador' : null,
                      propietarioId: esPrest ? _idActivo : null,
                      tituloAlcance: esPrest
                          ? 'Prestador: $_idActivo'
                          : 'Configuracion global',
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------
// Form con estado local (para trackear cambios sin guardar)
// ---------------------------------------------------------
class _ConfigForm extends ConsumerStatefulWidget {
  const _ConfigForm({
    super.key,
    required this.initial,
    required this.propietarioTipo,
    required this.propietarioId,
    required this.tituloAlcance,
  });

  final ConfigSocial initial;
  final String? propietarioTipo;
  final String? propietarioId;
  final String tituloAlcance;

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
        propietarioTipo: widget.propietarioTipo,
        propietarioId: widget.propietarioId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Configuracion guardada (${widget.tituloAlcance})'),
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
        Text(
          widget.tituloAlcance,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),

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
