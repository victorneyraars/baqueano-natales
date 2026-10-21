/// Pantalla admin: editor de afiches con preview en vivo.
///
/// Layout:
///   - Preview grande (reactivo a los cambios con debounce de 400ms)
///   - Chips de tamano (IG feed, Story, etc)
///   - Formulario con TextField por parametro (de la plantilla)
///   - Boton "Generar ahora" (para forzar sin esperar debounce)
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'dart:io';

import 'package:baqueano_natales/core/network/api_exceptions.dart';
import 'package:baqueano_natales/features/promocion/data/promocion_providers.dart';
import 'package:baqueano_natales/features/promocion/domain/afiche.dart';

class AdminPromocionEditorScreen extends ConsumerStatefulWidget {
  const AdminPromocionEditorScreen({super.key, required this.plantillaId});

  final String plantillaId;

  @override
  ConsumerState<AdminPromocionEditorScreen> createState() =>
      _AdminPromocionEditorScreenState();
}

class _AdminPromocionEditorScreenState
    extends ConsumerState<AdminPromocionEditorScreen> {
  final Map<String, TextEditingController> _controllers = {};
  TamanoAfiche _tamano = TamanoAfiche.igFeed;
  AficheGenerado? _afiche;
  String? _error;
  bool _generando = false;
  bool _descargando = false;
  bool _publicando = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    // Arrancar con preview generado en blanco tras el primer frame.
    WidgetsBinding.instance.addPostFrameCallback((_) => _generar());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// Devuelve (o crea) el controller para un param.
  TextEditingController _controller(String key) {
    return _controllers.putIfAbsent(
      key,
      () => TextEditingController(text: kParamPlaceholders[key] ?? ''),
    );
  }

  /// Recoge los params actuales del form.
  Map<String, dynamic> _paramsActuales(List<String> params) {
    final result = <String, dynamic>{};
    for (final p in params) {
      final txt = _controller(p).text.trim();
      if (txt.isEmpty) continue;
      // Conversion a int si parece numero
      final asInt = int.tryParse(txt);
      if (asInt != null) {
        result[p] = asInt;
      } else if (p == 'especialidades') {
        // comma-separated list
        result[p] = txt
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
      } else {
        result[p] = txt;
      }
    }
    return result;
  }

  /// Debounce para no golpear el backend en cada keystroke.
  void _onParamChange(List<String> params) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _generar);
  }

  Future<void> _generar() async {
    setState(() {
      _generando = true;
      _error = null;
    });
    try {
      // Cargar plantilla para saber sus params
      final plantillas = await ref.read(plantillasPromocionProvider.future);
      final plantilla = plantillas.firstWhere(
        (p) => p.id == widget.plantillaId,
        orElse: () => plantillas.first,
      );
      final params = _paramsActuales(plantilla.todosLosParams);

      final repo = ref.read(promocionRepositoryProvider);
      final afiche = await repo.generarAfiche(
        plantilla: widget.plantillaId,
        tamano: _tamano,
        params: params,
      );
      if (!mounted) return;
      setState(() {
        _afiche = afiche;
        _generando = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _generando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Error: $e';
        _generando = false;
      });
    }
  }

  /// Descarga el PNG y lo guarda en un archivo temporal.
  Future<File?> _guardarPngTemporal() async {
    final plantillas = await ref.read(plantillasPromocionProvider.future);
    final plantilla = plantillas.firstWhere(
      (p) => p.id == widget.plantillaId,
      orElse: () => plantillas.first,
    );
    final params = _paramsActuales(plantilla.todosLosParams);
    final repo = ref.read(promocionRepositoryProvider);
    final bytes = await repo.generarAfichePng(
      plantilla: widget.plantillaId,
      tamano: _tamano,
      params: params,
    );
    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/afiche-${widget.plantillaId}-${DateTime.now().millisecondsSinceEpoch}.png',
    );
    await file.writeAsBytes(bytes);
    return file;
  }

  /// Descarga el PNG al dispositivo (via share sheet con opcion "Guardar").
  Future<void> _descargarPng() async {
    setState(() => _descargando = true);
    try {
      final file = await _guardarPngTemporal();
      if (file == null || !mounted) return;
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'image/png')],
          subject: 'Afiche Baqueano Natales',
        ),
      );
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: ${e.message}')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error inesperado: $e')));
      }
    } finally {
      if (mounted) setState(() => _descargando = false);
    }
  }

  /// Comparte el PNG via share sheet nativo.
  Future<void> _compartirPng() async {
    setState(() => _descargando = true);
    try {
      final file = await _guardarPngTemporal();
      if (file == null || !mounted) return;
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'image/png')],
          text: 'Mira este afiche de Baqueano Natales',
        ),
      );
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: ${e.message}')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error inesperado: $e')));
      }
    } finally {
      if (mounted) setState(() => _descargando = false);
    }
  }

  /// Abre modal para elegir redes + caption y publica.
  Future<void> _publicarEnRedes() async {
    final plantillas = await ref.read(plantillasPromocionProvider.future);
    final plantilla = plantillas.firstWhere(
      (p) => p.id == widget.plantillaId,
      orElse: () => plantillas.first,
    );
    final params = _paramsActuales(plantilla.todosLosParams);
    if (!mounted) return;

    final result = await showModalBottomSheet<_PublicarConfig>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PublicarModal(plantilla: plantilla),
    );
    if (result == null || !mounted) return;

    setState(() => _publicando = true);
    try {
      final repo = ref.read(promocionRepositoryProvider);
      final res = await repo.publicarAfiche(
        plantilla: widget.plantillaId,
        tamano: _tamano,
        params: params,
        redes: result.redes,
        caption: result.caption,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Encolado en: ${res.redes.join(", ")}. '
              'El worker lo publicara en segundos.',
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error inesperado: $e')));
      }
    } finally {
      if (mounted) setState(() => _publicando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final plantillasAsync = ref.watch(plantillasPromocionProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Editor: ${widget.plantillaId}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Regenerar',
            onPressed: _generando ? null : _generar,
          ),
        ],
      ),
      body: plantillasAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (plantillas) {
          final plantilla = plantillas.firstWhere(
            (p) => p.id == widget.plantillaId,
            orElse: () => plantillas.first,
          );
          return _Editor(
            plantilla: plantilla,
            tamano: _tamano,
            afiche: _afiche,
            error: _error,
            generando: _generando,
            descargando: _descargando,
            publicando: _publicando,
            controllerFor: _controller,
            onTamanoChange: (t) {
              setState(() => _tamano = t);
              _generar();
            },
            onParamChange: () => _onParamChange(plantilla.todosLosParams),
            onGenerar: _generar,
            onDescargar: _descargarPng,
            onCompartir: _compartirPng,
            onPublicar: _publicarEnRedes,
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------
// Layout principal del editor
// ---------------------------------------------------------
class _Editor extends StatelessWidget {
  const _Editor({
    required this.plantilla,
    required this.tamano,
    required this.afiche,
    required this.error,
    required this.generando,
    required this.descargando,
    required this.publicando,
    required this.controllerFor,
    required this.onTamanoChange,
    required this.onParamChange,
    required this.onGenerar,
    required this.onDescargar,
    required this.onCompartir,
    required this.onPublicar,
  });

  final PlantillaInfo plantilla;
  final TamanoAfiche tamano;
  final AficheGenerado? afiche;
  final String? error;
  final bool generando;
  final bool descargando;
  final bool publicando;
  final TextEditingController Function(String) controllerFor;
  final ValueChanged<TamanoAfiche> onTamanoChange;
  final VoidCallback onParamChange;
  final Future<void> Function() onGenerar;
  final Future<void> Function() onDescargar;
  final Future<void> Function() onCompartir;
  final Future<void> Function() onPublicar;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Preview
        _PreviewCard(afiche: afiche, error: error, generando: generando),
        const SizedBox(height: 16),

        // Chips de tamano
        const _SectionTitle('Tamano'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: TamanoAfiche.values.map((t) {
            return ChoiceChip(
              label: Text('${t.label} ? ${t.aspecto}'),
              selected: tamano == t,
              onSelected: (_) => onTamanoChange(t),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),

        // Formulario
        const _SectionTitle('Contenido'),
        const SizedBox(height: 8),
        ...plantilla.todosLosParams.map((p) {
          final esRequerido = plantilla.paramsRequeridos.contains(p);
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TextField(
              controller: controllerFor(p),
              decoration: InputDecoration(
                labelText: (kParamLabels[p] ?? p) + (esRequerido ? ' *' : ''),
                hintText: kParamPlaceholders[p],
                border: const OutlineInputBorder(),
              ),
              maxLines: _maxLines(p),
              onChanged: (_) => onParamChange(),
            ),
          );
        }),

        const SizedBox(height: 16),

        // Regenerar
        FilledButton.icon(
          onPressed: generando ? null : onGenerar,
          icon: generando
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh),
          label: const Text('Regenerar afiche'),
        ),
        const SizedBox(height: 12),

        // Descargar + Compartir (side by side)
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: descargando ? null : onDescargar,
                icon: descargando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download),
                label: const Text('Descargar'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: descargando ? null : onCompartir,
                icon: const Icon(Icons.share),
                label: const Text('Compartir'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Publicar en redes (full width, primario)
        FilledButton.icon(
          onPressed: publicando ? null : onPublicar,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF16a34a),
            minimumSize: const Size.fromHeight(48),
          ),
          icon: publicando
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.send),
          label: const Text('Publicar en redes'),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  int _maxLines(String p) {
    if (p == 'descripcion' || p == 'frase') return 3;
    return 1;
  }
}

// ---------------------------------------------------------
// Preview card (con SVG renderizado)
// ---------------------------------------------------------
class _PreviewCard extends StatelessWidget {
  const _PreviewCard({
    required this.afiche,
    required this.error,
    required this.generando,
  });

  final AficheGenerado? afiche;
  final String? error;
  final bool generando;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Container(
        constraints: const BoxConstraints(minHeight: 320),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Center(child: _buildContenido(theme)),
            ),
            if (generando)
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildContenido(ThemeData theme) {
    if (error != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 12),
          Text(
            error!,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
        ],
      );
    }
    if (afiche == null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.image_outlined,
            size: 64,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(height: 12),
          Text('Generando preview...', style: theme.textTheme.bodyMedium),
        ],
      );
    }

    // Preview con aspect ratio respetado
    return AspectRatio(
      aspectRatio: afiche!.aspecto,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: theme.dividerColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: SvgPicture.string(
          afiche!.svg,
          fit: BoxFit.contain,
          placeholderBuilder: (_) =>
              const Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}

// ---------------------------------------------------------
// Modal de publicacion
// ---------------------------------------------------------

class _PublicarConfig {
  const _PublicarConfig({required this.redes, this.caption});

  final List<String> redes;
  final String? caption;
}

class _PublicarModal extends StatefulWidget {
  const _PublicarModal({required this.plantilla});

  final PlantillaInfo plantilla;

  @override
  State<_PublicarModal> createState() => _PublicarModalState();
}

class _PublicarModalState extends State<_PublicarModal> {
  bool _facebook = true;
  bool _instagram = true;
  bool _google = false;
  late final TextEditingController _caption;

  @override
  void initState() {
    super.initState();
    final placeholder =
        kParamPlaceholders[widget.plantilla.paramsRequeridos.first] ?? '';
    _caption = TextEditingController(text: placeholder);
  }

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  List<String> get _redesSeleccionadas {
    final r = <String>[];
    if (_facebook) r.add('facebook');
    if (_instagram) r.add('instagram');
    if (_google) r.add('google_business');
    return r;
  }

  void _publicar() {
    if (_redesSeleccionadas.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Eleg? al menos una red')));
      return;
    }
    Navigator.of(context).pop(
      _PublicarConfig(
        redes: _redesSeleccionadas,
        caption: _caption.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final padding = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + padding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: theme.dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            'Publicar afiche',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Eleg? las redes y edit? el texto del post.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),

          // Redes
          Text(
            'Redes',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          CheckboxListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            value: _facebook,
            onChanged: (v) => setState(() => _facebook = v ?? false),
            title: const Text('Facebook'),
            secondary: const Icon(Icons.facebook),
          ),
          CheckboxListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            value: _instagram,
            onChanged: (v) => setState(() => _instagram = v ?? false),
            title: const Text('Instagram'),
            subtitle: const Text('Requiere imagen (el afiche ya la tiene)'),
            secondary: const Icon(Icons.camera_alt),
          ),
          CheckboxListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            value: _google,
            onChanged: (v) => setState(() => _google = v ?? false),
            title: const Text('Google Business'),
            subtitle: const Text('Requiere API aprobada (flag)'),
            secondary: const Icon(Icons.storefront),
          ),
          const SizedBox(height: 16),

          // Caption
          Text(
            'Texto del post',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _caption,
            maxLines: 4,
            maxLength: 2200,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Ej: Nuevo servicio en Baqueano Natales...',
            ),
          ),
          const SizedBox(height: 16),

          // Botones
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: _publicar,
                  icon: const Icon(Icons.send),
                  label: const Text('Publicar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
