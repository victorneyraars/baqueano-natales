/// Pantalla admin: cola de publicaciones en redes sociales.
///
/// Lista las publicaciones con filtros por estado y red y permite compartir
/// en grupos externos con trazabilidad de share_id + UTM o texto sin enlace.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:baqueano_natales/core/network/api_exceptions.dart';
import 'package:baqueano_natales/features/social/data/social_providers.dart';
import 'package:baqueano_natales/features/social/domain/cuenta_social.dart';
import 'package:baqueano_natales/features/social/domain/publicacion_social.dart';

class _CompartidoPendiente {
  const _CompartidoPendiente({
    required this.shareId,
    required this.grupoNombre,
    required this.urlCompartida,
    required this.filtro,
  });

  final String shareId;
  final String grupoNombre;
  final String urlCompartida;
  final PublicacionesFiltro filtro;
}

class _SeleccionCompartir {
  const _SeleccionCompartir({
    required this.grupoNombre,
    required this.incluirEnlace,
  });

  final String grupoNombre;
  final bool incluirEnlace;
}

class AdminSocialPublicacionesScreen extends ConsumerStatefulWidget {
  const AdminSocialPublicacionesScreen({super.key});

  @override
  ConsumerState<AdminSocialPublicacionesScreen> createState() =>
      _AdminSocialPublicacionesScreenState();
}

class _AdminSocialPublicacionesScreenState
    extends ConsumerState<AdminSocialPublicacionesScreen>
    with WidgetsBindingObserver {
  EstadoPublicacion? _estadoFiltro;
  RedSocial? _redFiltro;
  _CompartidoPendiente? _pendiente;
  bool _mostrandoDialogoConfirmacion = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _pendiente != null &&
        !_mostrandoDialogoConfirmacion &&
        mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _pendiente != null && !_mostrandoDialogoConfirmacion) {
          _mostrarDialogoConfirmacion(_pendiente!);
        }
      });
    }
  }

  Future<void> _mostrarDialogoConfirmacion(_CompartidoPendiente info) async {
    _mostrandoDialogoConfirmacion = true;
    try {
      final estadoElegido = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('Confirmar estado del compartir'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Grupo: ${info.grupoNombre}'),
              const SizedBox(height: 4),
              Text(
                'Ref: ${info.shareId}',
                style: Theme.of(ctx).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              const Text(
                '¿En qué estado quedó la publicación al volver de Facebook?',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop('cancelado'),
              child: const Text('Cancelado'),
            ),
            OutlinedButton(
              onPressed: () => Navigator.of(ctx).pop('pendiente_aprobacion'),
              child: const Text('Pendiente de aprobación'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop('publicado'),
              child: const Text('Publicado'),
            ),
          ],
        ),
      );

      if (estadoElegido != null && mounted) {
        try {
          await ref
              .read(socialRepositoryProvider)
              .confirmarCompartido(
                shareId: info.shareId,
                estadoReportado: estadoElegido,
              );
          ref.invalidate(publicacionesSocialesProvider(info.filtro));
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Compartido ${info.shareId} marcado como: $estadoElegido',
                ),
              ),
            );
          }
        } on ApiException catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('No se pudo confirmar: ${e.message}')),
            );
          }
        }
      }
      if (estadoElegido != null) {
        setState(() => _pendiente = null);
      }
    } finally {
      _mostrandoDialogoConfirmacion = false;
    }
  }

  Future<void> _iniciarCompartirConTrazabilidad(
    PublicacionSocial pub,
    String? urlPublicacion,
    PublicacionesFiltro filtro,
  ) async {
    final seleccion = await showModalBottomSheet<_SeleccionCompartir>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _SelectorGrupoSheet(urlDefecto: urlPublicacion),
    );
    if (seleccion == null || seleccion.grupoNombre.trim().isEmpty || !mounted) {
      return;
    }
    try {
      final grupoLimpio = seleccion.grupoNombre.trim();
      final incluirEnlace = seleccion.incluirEnlace;
      final urlBase =
          (pub.contenido['link']?.toString().trim().isNotEmpty == true)
          ? pub.contenido['link'].toString().trim()
          : (urlPublicacion ?? 'https://sealquilamarido.com/mecanica');

      try {
        final res = await ref
            .read(socialRepositoryProvider)
            .registrarCompartido(
              grupoNombre: grupoLimpio,
              publicacionId: pub.id,
              red: pub.red.value,
              urlBase: urlBase,
            );

        final shareId = (res['share_id'] as String?) ?? '';
        final urlConUtm = (res['url_compartida'] as String?) ?? urlBase;
        final cooldownSeg =
            (res['cooldown_segundos_restantes'] as num?)?.toInt() ?? 0;

        if (cooldownSeg > 0 && mounted) {
          final mins = (cooldownSeg / 60).ceil();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Aviso anti-spam: quedan ~$mins min desde el último compartido en grupos.',
              ),
            ),
          );
        }

        final mensajeRaw =
            (pub.contenido['message']?.toString().trim().isNotEmpty == true)
            ? pub.contenido['message'].toString().trim()
            : 'Servicio mecánico en Puerto Natales — atención rápida y transparente.';
        final textoParaPegar = incluirEnlace
            ? '$mensajeRaw\n\n$urlConUtm'
            : '$mensajeRaw\n\nBúscanos en la web como Se Alquila Marido en Puerto Natales.';

        await Clipboard.setData(ClipboardData(text: textoParaPegar));

        if (shareId.isNotEmpty) {
          setState(() {
            _pendiente = _CompartidoPendiente(
              shareId: shareId,
              grupoNombre: grupoLimpio,
              urlCompartida: urlConUtm,
              filtro: filtro,
            );
          });
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Copiado al portapapeles · Ref: $shareId'),
              duration: const Duration(seconds: 2),
            ),
          );
        }

        final uriGrupos = Uri.parse('https://www.facebook.com/groups/');
        final abrioGrupos = await launchUrl(
          uriGrupos,
          mode: LaunchMode.externalApplication,
        );
        if (!abrioGrupos) {
          await SharePlus.instance.share(ShareParams(text: textoParaPegar));
        }
      } on ApiException catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al registrar compartido: ${e.message}'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo completar compartir: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtro = PublicacionesFiltro(estado: _estadoFiltro, red: _redFiltro);
    final async = ref.watch(publicacionesSocialesProvider(filtro));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cola de publicaciones'),
        actions: [
          if (_pendiente != null)
            IconButton(
              icon: const Icon(Icons.fact_check_outlined),
              tooltip: 'Confirmar último compartir',
              onPressed: () => _mostrarDialogoConfirmacion(_pendiente!),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refrescar',
            onPressed: () =>
                ref.invalidate(publicacionesSocialesProvider(filtro)),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_pendiente != null)
            MaterialBanner(
              backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
              content: Text(
                'Compartido pendiente de confirmar en ${_pendiente!.grupoNombre} (${_pendiente!.shareId})',
              ),
              actions: [
                TextButton(
                  onPressed: () => _mostrarDialogoConfirmacion(_pendiente!),
                  child: const Text('Confirmar ahora'),
                ),
              ],
            ),
          _FiltersBar(
            estado: _estadoFiltro,
            red: _redFiltro,
            onEstado: (v) => setState(() => _estadoFiltro = v),
            onRed: (v) => setState(() => _redFiltro = v),
          ),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _ErrorView(
                error: e,
                onRetry: () =>
                    ref.invalidate(publicacionesSocialesProvider(filtro)),
              ),
              data: (data) {
                if (data.items.isEmpty) {
                  return const _EmptyView();
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(publicacionesSocialesProvider(filtro));
                    await ref.read(
                      publicacionesSocialesProvider(filtro).future,
                    );
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: data.items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (ctx, i) => _PublicacionCard(
                      pub: data.items[i],
                      onCompartirConGrupo: (url) =>
                          _iniciarCompartirConTrazabilidad(
                            data.items[i],
                            url,
                            filtro,
                          ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectorGrupoSheet extends ConsumerStatefulWidget {
  const _SelectorGrupoSheet({this.urlDefecto});

  final String? urlDefecto;

  @override
  ConsumerState<_SelectorGrupoSheet> createState() =>
      _SelectorGrupoSheetState();
}

class _SelectorGrupoSheetState extends ConsumerState<_SelectorGrupoSheet> {
  final TextEditingController _destinoCtrl = TextEditingController();
  final List<String> _destinos = <String>[];
  String? _elegido;
  bool _cargando = true;
  bool _incluirEnlace = true;

  @override
  void initState() {
    super.initState();
    _cargarDestinosPersistidos();
  }

  Future<void> _cargarDestinosPersistidos() async {
    try {
      final guardados = await ref
          .read(socialRepositoryProvider)
          .listarDestinosGuardados();
      if (!mounted) return;
      setState(() {
        _destinos
          ..clear()
          ..addAll(guardados);
        if (_elegido == null && _destinos.isNotEmpty) {
          _elegido = _destinos.first;
        }
        _cargando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _cargando = false);
    }
  }

  void _agregarDestinoALista() {
    final texto = _destinoCtrl.text.trim();
    if (texto.isEmpty) return;
    final existente = _destinos.firstWhere(
      (d) => d.toLowerCase() == texto.toLowerCase(),
      orElse: () => '',
    );
    setState(() {
      if (existente.isNotEmpty) {
        _elegido = existente;
      } else {
        _destinos.insert(0, texto);
        _elegido = texto;
      }
      _destinoCtrl.clear();
    });
  }

  @override
  void dispose() {
    _destinoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final filtro = _destinoCtrl.text.trim().toLowerCase();
    final visibles = filtro.isEmpty
        ? _destinos
        : _destinos.where((d) => d.toLowerCase().contains(filtro)).toList();

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Portafolio de grupos y destinos',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            _incluirEnlace
                ? 'Se copiará el texto + enlace con UTM/share_id y se guardará en tu historial.'
                : 'Se copiará el texto sin enlaces indicando buscar en la web y se guardará en tu historial.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _destinoCtrl,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'Agregar o filtrar grupo / destino',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _agregarDestinoALista(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonal(
                onPressed: _destinoCtrl.text.trim().isEmpty
                    ? null
                    : _agregarDestinoALista,
                child: const Text('Agregar'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_cargando)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (visibles.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                filtro.isEmpty
                    ? 'Aún no tienes destinos guardados. Escribe un grupo y pulsa Agregar o comparte para guardarlo en BD.'
                    : 'Sin coincidencias en tu lista. Puedes usar o agregar ese destino.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: visibles.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final destino = visibles[index];
                  final seleccionado = _elegido == destino;
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      seleccionado
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                    ),
                    title: Text(destino),
                    selected: seleccionado,
                    trailing: IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      tooltip: 'Quitar de la vista',
                      onPressed: () {
                        setState(() {
                          _destinos.remove(destino);
                          if (_elegido == destino) {
                            _elegido = _destinos.isNotEmpty
                                ? _destinos.first
                                : null;
                          }
                        });
                      },
                    ),
                    onTap: () => setState(() => _elegido = destino),
                  );
                },
              ),
            ),
          const SizedBox(height: 8),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Incluir enlace web en el texto'),
            subtitle: Text(
              _incluirEnlace
                  ? 'Agrega enlace con UTM y share_id'
                  : 'Sin enlace; indica buscar en la web Se Alquila Marido',
            ),
            value: _incluirEnlace,
            onChanged: (v) => setState(() => _incluirEnlace = v),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancelar'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () {
                  final escrito = _destinoCtrl.text.trim();
                  final grupoObjetivo =
                      (escrito.isNotEmpty ? escrito : (_elegido ?? '')).trim();
                  if (grupoObjetivo.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Selecciona un destino de la lista o escribe uno nuevo.',
                        ),
                      ),
                    );
                    return;
                  }
                  Navigator.of(context).pop(
                    _SeleccionCompartir(
                      grupoNombre: grupoObjetivo,
                      incluirEnlace: _incluirEnlace,
                    ),
                  );
                },
                icon: const Icon(Icons.share, size: 18),
                label: const Text('Copiar y compartir'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FiltersBar extends StatelessWidget {
  const _FiltersBar({
    required this.estado,
    required this.red,
    required this.onEstado,
    required this.onRed,
  });

  final EstadoPublicacion? estado;
  final RedSocial? red;
  final ValueChanged<EstadoPublicacion?> onEstado;
  final ValueChanged<RedSocial?> onRed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                const _FilterLabel('Estado:'),
                _Chip(
                  label: 'Todos',
                  selected: estado == null,
                  onTap: () => onEstado(null),
                ),
                ...EstadoPublicacion.values.map(
                  (e) => _Chip(
                    label: e.label,
                    selected: estado == e,
                    color: Color(e.colorValue),
                    onTap: () => onEstado(e),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                const _FilterLabel('Red:'),
                _Chip(
                  label: 'Todas',
                  selected: red == null,
                  onTap: () => onRed(null),
                ),
                _Chip(
                  label: 'Facebook',
                  selected: red == RedSocial.facebook,
                  onTap: () => onRed(RedSocial.facebook),
                ),
                _Chip(
                  label: 'Instagram',
                  selected: red == RedSocial.instagram,
                  onTap: () => onRed(RedSocial.instagram),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterLabel extends StatelessWidget {
  const _FilterLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall
            ?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(
          label,
          style: TextStyle(fontSize: 12, color: selected ? Colors.white : null),
        ),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: c,
        showCheckmark: false,
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

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
            Icon(
              Icons.inbox_outlined,
              size: 64,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'No hay publicaciones',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Cambia los filtros o espera a que se encolen nuevas.',
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

class _PublicacionCard extends ConsumerStatefulWidget {
  const _PublicacionCard({
    required this.pub,
    required this.onCompartirConGrupo,
  });

  final PublicacionSocial pub;
  final Future<void> Function(String? urlPublicacion) onCompartirConGrupo;

  @override
  ConsumerState<_PublicacionCard> createState() => _PublicacionCardState();
}

class _PublicacionCardState extends ConsumerState<_PublicacionCard> {
  bool _reencolando = false;

  String? _resolverUrlPublicacion(PublicacionSocial pub) {
    final rawPermalink = pub.contenido['permalink_url']?.toString().trim();
    if (rawPermalink != null && rawPermalink.isNotEmpty) {
      return rawPermalink;
    }
    final extId = pub.externalPostId?.trim();
    if (extId == null || extId.isEmpty) return null;
    if (pub.red == RedSocial.facebook) {
      final partes = extId.split('_');
      if (partes.length == 2 && partes[0].isNotEmpty && partes[1].isNotEmpty) {
        return 'https://www.facebook.com/${partes[0]}/posts/${partes[1]}';
      }
      return 'https://www.facebook.com/$extId';
    }
    return null;
  }

  Future<void> _abrirEnFacebook(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo abrir el enlace en Facebook.'),
        ),
      );
    }
  }

  Future<void> _reencolar() async {
    setState(() => _reencolando = true);
    try {
      final fn = ref.read(reencolarPublicacionProvider);
      await fn(widget.pub.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Publicacion reencolada. El worker la procesara pronto.',
            ),
          ),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: ${e.message}')));
      }
    } finally {
      if (mounted) setState(() => _reencolando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pub = widget.pub;
    final theme = Theme.of(context);
    final estadoColor = Color(pub.estado.colorValue);
    final urlPub = _resolverUrlPublicacion(pub);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  pub.red == RedSocial.facebook
                      ? Icons.facebook
                      : Icons.camera_alt,
                  size: 16,
                  color: pub.red == RedSocial.facebook
                      ? const Color(0xFF1877F2)
                      : const Color(0xFFE1306C),
                ),
                const SizedBox(width: 6),
                Text(
                  pub.red.label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: estadoColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    pub.estado.label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: estadoColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              pub.mensajePreview,
              style: theme.textTheme.bodyMedium,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                if (pub.tieneImagen)
                  const _Meta(icon: Icons.image, text: 'Con imagen'),
                if (pub.intentos > 0)
                  _Meta(
                    icon: Icons.refresh,
                    text: '${pub.intentos} intento(s)',
                  ),
                _Meta(icon: Icons.schedule, text: _fmt(pub.createdAt)),
              ],
            ),
            if (pub.errorUltimo != null &&
                pub.errorUltimo!.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 14,
                      color: Colors.red,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        pub.errorUltimo!,
                        style: const TextStyle(fontSize: 11, color: Colors.red),
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (pub.proximoIntentoEn != null) ...[
              const SizedBox(height: 6),
              _Meta(
                icon: Icons.update,
                text: 'Reintenta: ${_fmt(pub.proximoIntentoEn!)}',
              ),
            ],
            if (pub.externalPostId != null) ...[
              const SizedBox(height: 6),
              _Meta(icon: Icons.link, text: 'ID: ${pub.externalPostId}'),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (pub.estado == EstadoPublicacion.publicado && urlPub != null)
                  OutlinedButton.icon(
                    onPressed: () => _abrirEnFacebook(urlPub),
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: const Text('Abrir en Facebook'),
                  ),
                OutlinedButton.icon(
                  onPressed: () => widget.onCompartirConGrupo(urlPub),
                  icon: const Icon(Icons.share, size: 16),
                  label: const Text('Compartir en grupo'),
                ),
              ],
            ),
            if (pub.estado == EstadoPublicacion.fallado ||
                pub.estado == EstadoPublicacion.agotado) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _reencolando ? null : _reencolar,
                  icon: _reencolando
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh, size: 16),
                  label: const Text('Reencolar'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _fmt(DateTime dt) {
    final d = dt.toLocal();
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')} '
        '${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}';
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 3),
        Text(text, style: TextStyle(fontSize: 11, color: color)),
      ],
    );
  }
}
