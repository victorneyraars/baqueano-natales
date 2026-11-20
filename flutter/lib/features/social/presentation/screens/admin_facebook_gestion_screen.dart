import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:baqueano_natales/features/social/data/social_providers.dart';
import 'package:baqueano_natales/features/social/domain/cuenta_social.dart';

class AdminFacebookGestionScreen extends ConsumerStatefulWidget {
  const AdminFacebookGestionScreen({super.key, required this.cuenta});
  final CuentaSocial cuenta;

  @override
  ConsumerState<AdminFacebookGestionScreen> createState() =>
      _AdminFacebookGestionScreenState();
}

class _AdminFacebookGestionScreenState
    extends ConsumerState<AdminFacebookGestionScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  bool _loadingPosts = false;
  bool _loadingConvs = false;
  bool _loadingInsights = false;
  bool _loadingConfig = false;
  bool _subscribingWebhook = false;
  bool _savingConfig = false;
  bool _publishingPost = false;

  List _posts = const [];
  List _conversaciones = const [];
  List _insights = const [];
  Map<String, dynamic> _configData = const {};
  bool _messagingMissing = false;
  String? _errorMsg;
  String _inboxPlatform = 'messenger';
  String _insightsPeriod = 'day';

  final _aboutCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _websiteCtrl = TextEditingController();
  bool _autoPublish = false;

  static const Map<String, dynamic> _categoriasEs = {
    'product/service': 'Producto / servicio',
    'real estate': 'Bienes raíces',
    'local business': 'Negocio local',
    'home improvement': 'Mejoras del hogar',
    'automotive': 'Automotor',
    'professional services': 'Servicios profesionales',
    'contractor': 'Contratista',
    'consultant': 'Consultoría',
  };

  static const Map<String, dynamic> _metricasEs = {
    'daily post engagements': 'Interacciones con publicaciones',
    'weekly post engagements': 'Interacciones con publicaciones (7 días)',
    '28 days post engagements': 'Interacciones con publicaciones (28 días)',
    'page_post_engagements': 'Interacciones con publicaciones',
    'daily total views count per page': 'Visitas de la página',
    'weekly total views count per page': 'Visitas de la página (7 días)',
    '28 days total views count per page': 'Visitas de la página (28 días)',
    'page_views_total': 'Visitas de la página',
    'lifetime total follows': 'Seguidores totales',
    'page_follows': 'Seguidores totales',
  };

  String _traducirCategoria(dynamic raw) {
    final val = raw?.toString().trim() ?? '';
    if (val.isEmpty) return '-';
    return _categoriasEs[val.toLowerCase()] ?? val;
  }

  String _traducirMetrica(Map m) {
    final title = m['title']?.toString().trim() ?? '';
    final name = m['name']?.toString().trim() ?? '';
    if (title.isNotEmpty) {
      final hit = _metricasEs[title.toLowerCase()];
      if (hit != null) return hit;
    }
    if (name.isNotEmpty) {
      final hit = _metricasEs[name.toLowerCase()];
      if (hit != null) return hit;
    }
    return title.isNotEmpty ? title : (name.isNotEmpty ? name : 'Métrica');
  }

  @override
  void initState() {
    super.initState();
    _autoPublish = widget.cuenta.autoPublish;
    _tabs = TabController(length: 4, vsync: this);
    _cargarTodo();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _aboutCtrl.dispose();
    _phoneCtrl.dispose();
    _websiteCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarTodo() async {
    await Future.wait([
      _cargarPosts(),
      _cargarConversaciones(),
      _cargarInsights(),
      _cargarConfiguracion(),
    ]);
  }

  Future<void> _cargarPosts() async {
    setState(() {
      _loadingPosts = true;
      _errorMsg = null;
    });
    try {
      final items = await ref
          .read(socialRepositoryProvider)
          .listarPostsFacebook(widget.cuenta.id);
      if (mounted) {
        setState(() => _posts = items);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMsg = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _loadingPosts = false);
      }
    }
  }

  Future<void> _cargarConversaciones() async {
    setState(() {
      _loadingConvs = true;
      _messagingMissing = false;
    });
    try {
      final items = await ref
          .read(socialRepositoryProvider)
          .listarConversacionesFacebook(
            widget.cuenta.id,
            platform: _inboxPlatform,
          );
      if (mounted) {
        setState(() => _conversaciones = items);
      }
    } catch (e) {
      final msg = e.toString();
      if (mounted) {
        final faltaMessaging =
            msg.contains('pages_messaging') ||
            msg.contains('No tenés permisos');
        setState(() {
          _messagingMissing = faltaMessaging;
          _conversaciones = const [];
          if (!faltaMessaging) {
            _errorMsg = msg;
          }
        });
      }
    } finally {
      if (mounted) {
        setState(() => _loadingConvs = false);
      }
    }
  }

  Future<void> _cargarInsights() async {
    setState(() {
      _loadingInsights = true;
    });
    try {
      final items = await ref
          .read(socialRepositoryProvider)
          .obtenerInsightsFacebook(widget.cuenta.id, period: _insightsPeriod);
      if (mounted) {
        setState(() => _insights = items);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMsg = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _loadingInsights = false);
      }
    }
  }

  Future<void> _cargarConfiguracion() async {
    setState(() => _loadingConfig = true);
    try {
      final cfg = await ref
          .read(socialRepositoryProvider)
          .obtenerConfiguracionFacebook(widget.cuenta.id);
      if (!mounted) return;
      final page = (cfg['page'] as Map?) ?? const {};
      _aboutCtrl.text = page['about']?.toString() ?? '';
      _phoneCtrl.text = page['phone']?.toString() ?? '';
      _websiteCtrl.text = page['website']?.toString() ?? '';
      setState(() {
        _configData = cfg;
        _autoPublish = (cfg['auto_publish'] as bool?) ?? _autoPublish;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _errorMsg = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _loadingConfig = false);
      }
    }
  }

  Future<void> _guardarConfiguracion() async {
    setState(() => _savingConfig = true);
    try {
      await ref
          .read(socialRepositoryProvider)
          .actualizarConfiguracionFacebook(
            cuentaId: widget.cuenta.id,
            about: _aboutCtrl.text.trim(),
            phone: _phoneCtrl.text.trim(),
            website: _websiteCtrl.text.trim(),
            autoPublish: _autoPublish,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Configuración de página guardada')),
      );
      await _cargarConfiguracion();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar la configuración: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _savingConfig = false);
      }
    }
  }

  Future<void> _suscribirWebhook() async {
    setState(() => _subscribingWebhook = true);
    try {
      final res = await ref
          .read(socialRepositoryProvider)
          .suscribirWebhookFacebook(widget.cuenta.id);
      if (!mounted) return;
      final partial = (res['partial_messaging'] as bool?) ?? false;
      final fields = (res['subscribed_fields'] as List?)?.join(', ') ?? 'feed';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            partial
                ? 'Webhook suscrito en ($fields). Mensajería requiere pages_messaging en Meta.'
                : 'Webhook de página suscrito ($fields)',
          ),
        ),
      );
      await _cargarConfiguracion();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error de webhook: $e')));
    } finally {
      if (mounted) {
        setState(() => _subscribingWebhook = false);
      }
    }
  }

  Future<void> _desuscribirWebhook() async {
    setState(() => _subscribingWebhook = true);
    try {
      await ref
          .read(socialRepositoryProvider)
          .desuscribirWebhookFacebook(widget.cuenta.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Webhooks de página desuscritos')),
      );
      await _cargarConfiguracion();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error al desuscribir: $e')));
    } finally {
      if (mounted) {
        setState(() => _subscribingWebhook = false);
      }
    }
  }

  Future<void> _crearNuevoPost() async {
    final msgCtrl = TextEditingController();
    final linkCtrl = TextEditingController();
    final imgCtrl = TextEditingController();
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nueva publicación en Facebook'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: msgCtrl,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Texto de la publicación',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: linkCtrl,
                decoration: const InputDecoration(
                  labelText: 'Enlace (opcional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: imgCtrl,
                decoration: const InputDecoration(
                  labelText: 'URL de imagen pública (opcional)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Publicar'),
          ),
        ],
      ),
    );
    final mensaje = msgCtrl.text.trim();
    final link = linkCtrl.text.trim();
    final img = imgCtrl.text.trim();
    msgCtrl.dispose();
    linkCtrl.dispose();
    imgCtrl.dispose();

    if (confirmar != true || (mensaje.isEmpty && img.isEmpty)) return;
    setState(() => _publishingPost = true);
    try {
      await ref
          .read(socialRepositoryProvider)
          .crearPostFacebook(
            cuentaId: widget.cuenta.id,
            mensaje: mensaje,
            link: link.isEmpty ? null : link,
            imageUrl: img.isEmpty ? null : img,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Publicación enviada a Facebook')),
      );
      await _cargarPosts();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error al publicar: $e')));
    } finally {
      if (mounted) {
        setState(() => _publishingPost = false);
      }
    }
  }

  Future<void> _editarPost(Map post) async {
    final postId = post['id']?.toString() ?? '';
    if (postId.isEmpty) return;
    final ctrl = TextEditingController(text: post['message']?.toString() ?? '');
    final nuevo = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Editar publicación'),
        content: TextField(controller: ctrl, maxLines: 4),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (nuevo == null || nuevo.isEmpty) return;
    await ref
        .read(socialRepositoryProvider)
        .editarPostFacebook(
          cuentaId: widget.cuenta.id,
          postId: postId,
          mensaje: nuevo,
        );
    await _cargarPosts();
  }

  Future<void> _eliminarPost(Map post) async {
    final postId = post['id']?.toString() ?? '';
    if (postId.isEmpty) return;
    await ref
        .read(socialRepositoryProvider)
        .eliminarPostFacebook(cuentaId: widget.cuenta.id, postId: postId);
    await _cargarPosts();
  }

  void _abrirComentarios(Map post) {
    final objectId = post['id']?.toString() ?? '';
    if (objectId.isEmpty) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) =>
          _ComentariosSheet(cuentaId: widget.cuenta.id, objectId: objectId),
    );
  }

  void _abrirConversacion(Map conv) {
    final convId = conv['id']?.toString() ?? '';
    if (convId.isEmpty) return;
    final parts = conv['participants'];
    final list = (parts is Map ? parts['data'] : null) as List? ?? const [];
    String? recipientId;
    String titulo = 'Conversación';
    for (final p in list) {
      if (p is Map) {
        final pid = p['id']?.toString();
        if (pid != null && pid != widget.cuenta.externalId) {
          recipientId = pid;
          titulo = p['name']?.toString() ?? titulo;
          break;
        }
      }
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ConversacionSheet(
        cuentaId: widget.cuenta.id,
        conversationId: convId,
        recipientId: recipientId,
        titulo: titulo,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.cuenta.nombreVisible),
        actions: [
          IconButton(onPressed: _cargarTodo, icon: const Icon(Icons.refresh)),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Posts'),
            Tab(text: 'Inbox'),
            Tab(text: 'Métricas'),
            Tab(text: 'Config'),
          ],
        ),
      ),
      body: Column(
        children: [
          if (_errorMsg != null)
            MaterialBanner(
              content: Text(_errorMsg!, maxLines: 2),
              actions: [
                TextButton(
                  onPressed: () => setState(() => _errorMsg = null),
                  child: const Text('OK'),
                ),
              ],
            ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _buildPosts(),
                _buildInbox(),
                _buildMetricas(),
                _buildConfig(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPosts() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _publishingPost ? null : _crearNuevoPost,
              icon: const Icon(Icons.add),
              label: Text(
                _publishingPost ? 'Publicando...' : 'Nueva publicación',
              ),
            ),
          ),
        ),
        Expanded(
          child: _loadingPosts
              ? const Center(child: CircularProgressIndicator())
              : _posts.isEmpty
              ? const Center(child: Text('Sin publicaciones'))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _posts.length,
                  itemBuilder: (_, i) {
                    final p = _posts[i] as Map;
                    return Card(
                      child: ListTile(
                        title: Text(
                          p['message']?.toString() ?? '(Sin texto)',
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(p['created_time']?.toString() ?? ''),
                        trailing: PopupMenuButton<String>(
                          onSelected: (v) {
                            if (v == 'comments') _abrirComentarios(p);
                            if (v == 'edit') _editarPost(p);
                            if (v == 'delete') _eliminarPost(p);
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'comments',
                              child: Text('Comentarios'),
                            ),
                            PopupMenuItem(value: 'edit', child: Text('Editar')),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text('Eliminar'),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildInbox() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'messenger', label: Text('Messenger')),
              ButtonSegment(value: 'instagram', label: Text('Instagram')),
            ],
            selected: {_inboxPlatform},
            onSelectionChanged: (sel) {
              setState(() => _inboxPlatform = sel.first);
              _cargarConversaciones();
            },
          ),
        ),
        Expanded(
          child: _loadingConvs
              ? const Center(child: CircularProgressIndicator())
              : _messagingMissing
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.info_outline),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _inboxPlatform == 'instagram'
                                      ? 'Instagram no vinculado o sin mensajes activos'
                                      : 'Inbox pendiente de permiso de mensajería',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _inboxPlatform == 'instagram'
                                ? 'Esta página aún no tiene una cuenta de Instagram vinculada o habilitada para mensajes. '
                                      'Los permisos de publicación, métricas y administración de página ya están activos.'
                                : 'Meta requiere el permiso pages_messaging y el rol adecuado en la página para listar y responder conversaciones. '
                                      'Los permisos de publicación, métricas y administración de página ya están activos.',
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: _cargarConversaciones,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Reintentar Inbox'),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : _conversaciones.isEmpty
              ? const Center(child: Text('Sin conversaciones'))
              : ListView.builder(
                  itemCount: _conversaciones.length,
                  itemBuilder: (_, i) {
                    final c = _conversaciones[i] as Map;
                    return ListTile(
                      title: Text(
                        c['snippet']?.toString() ?? 'Conversación',
                        maxLines: 2,
                      ),
                      subtitle: Text(c['updated_time']?.toString() ?? ''),
                      onTap: () => _abrirConversacion(c),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildMetricas() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'day', label: Text('Hoy')),
            ButtonSegment(value: 'week', label: Text('7 días')),
            ButtonSegment(value: 'days_28', label: Text('28 días')),
          ],
          selected: {_insightsPeriod},
          onSelectionChanged: (sel) {
            setState(() => _insightsPeriod = sel.first);
            _cargarInsights();
          },
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _subscribingWebhook ? null : _suscribirWebhook,
          icon: const Icon(Icons.sync),
          label: const Text('Suscribir página a Webhooks'),
        ),
        const SizedBox(height: 12),
        if (_loadingInsights)
          const Center(child: CircularProgressIndicator())
        else
          ..._insights.map((raw) {
            final m = raw as Map;
            final vals = (m['values'] as List?) ?? const [];
            final last = vals.isNotEmpty && vals.last is Map
                ? ((vals.last as Map)['value']?.toString() ?? '-')
                : '-';
            return Card(
              child: ListTile(
                title: Text(_traducirMetrica(m)),
                trailing: Text(last),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildConfig() {
    if (_loadingConfig && _configData.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    final page = (_configData['page'] as Map?) ?? const {};
    final subs = (_configData['subscribed_apps'] as List?) ?? const [];
    final granted = ((_configData['granted_permissions'] as List?) ?? const [])
        .map((e) => e.toString())
        .toList();
    final hasMessaging = (_configData['has_pages_messaging'] as bool?) ?? false;

    final camposSuscritos = subs
        .whereType<Map>()
        .expand((app) => (app['subscribed_fields'] as List?) ?? const [])
        .map((e) => e.toString())
        .toSet()
        .toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Datos de la página',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text('ID Meta: ${page['id'] ?? widget.cuenta.externalId}'),
                Text('Nombre: ${page['name'] ?? widget.cuenta.nombreVisible}'),
                Text('Categoría: ${_traducirCategoria(page['category'])}'),
                Text(
                  'Seguidores: ${page['followers_count'] ?? 0} | Fans: ${page['fan_count'] ?? 0}',
                ),
                Text(
                  'Estado: ${(page['is_published'] as bool? ?? true) ? 'Publicada' : 'No publicada'}',
                ),
                if (page['link'] != null) Text('Enlace: ${page['link']}'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Información y publicación',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Publicación automática'),
                  subtitle: const Text(
                    'Enviar publicaciones automáticas desde Baqueano',
                  ),
                  value: _autoPublish,
                  onChanged: (v) => setState(() => _autoPublish = v),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _aboutCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Descripción / Acerca de',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _phoneCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Teléfono',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _websiteCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Sitio web',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _savingConfig ? null : _guardarConfiguracion,
                  icon: const Icon(Icons.save),
                  label: Text(
                    _savingConfig ? 'Guardando...' : 'Guardar configuración',
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Webhooks y permisos Meta',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  subs.isEmpty
                      ? 'Webhooks: Sin suscripciones activas en la página'
                      : 'Webhooks suscritos: ${subs.length} app(s) (${camposSuscritos.isEmpty ? 'feed' : camposSuscritos.join(', ')})',
                ),
                const SizedBox(height: 6),
                Text(
                  hasMessaging ? 'Messenger (pages_messaging): Activo' : 'Messenger (pages_messaging): Pendiente de habilitar en Meta Developers',
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: granted.map((p) => Chip(label: Text(p))).toList(),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _subscribingWebhook ? null : _suscribirWebhook,
                      icon: const Icon(Icons.sync),
                      label: const Text('Suscribir / actualizar webhooks'),
                    ),
                    if (subs.isNotEmpty)
                      TextButton.icon(
                        onPressed: _subscribingWebhook
                            ? null
                            : _desuscribirWebhook,
                        icon: const Icon(Icons.link_off),
                        label: const Text('Desuscribir webhooks'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ComentariosSheet extends ConsumerStatefulWidget {
  const _ComentariosSheet({required this.cuentaId, required this.objectId});
  final String cuentaId;
  final String objectId;

  @override
  ConsumerState<_ComentariosSheet> createState() => _ComentariosSheetState();
}

class _ComentariosSheetState extends ConsumerState<_ComentariosSheet> {
  bool _loading = true;
  List _items = const [];
  final _ctrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() => _loading = true);
    try {
      final list = await ref
          .read(socialRepositoryProvider)
          .listarComentariosFacebook(
            cuentaId: widget.cuentaId,
            objectId: widget.objectId,
          );
      if (mounted) {
        setState(() => _items = list);
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _enviar() async {
    final txt = _ctrl.text.trim();
    if (txt.isEmpty) return;
    await ref
        .read(socialRepositoryProvider)
        .responderComentarioFacebook(
          cuentaId: widget.cuentaId,
          objectId: widget.objectId,
          mensaje: txt,
        );
    _ctrl.clear();
    await _cargar();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SizedBox(
        height: 420,
        child: Column(
          children: [
            const Text(
              'Comentarios',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      itemCount: _items.length,
                      itemBuilder: (_, i) {
                        final c = _items[i] as Map;
                        final id = c['id']?.toString() ?? '';
                        final hidden = (c['is_hidden'] as bool?) ?? false;
                        return ListTile(
                          title: Text(c['message']?.toString() ?? ''),
                          subtitle: Text(hidden ? 'Oculto' : 'Visible'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(
                                  hidden
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                ),
                                onPressed: id.isEmpty
                                    ? null
                                    : () async {
                                        await ref
                                            .read(socialRepositoryProvider)
                                            .ocultarComentarioFacebook(
                                              cuentaId: widget.cuentaId,
                                              commentId: id,
                                              ocultar: !hidden,
                                            );
                                        await _cargar();
                                      },
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: id.isEmpty
                                    ? null
                                    : () async {
                                        await ref
                                            .read(socialRepositoryProvider)
                                            .eliminarComentarioFacebook(
                                              cuentaId: widget.cuentaId,
                                              commentId: id,
                                            );
                                        await _cargar();
                                      },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    decoration: const InputDecoration(hintText: 'Responder...'),
                  ),
                ),
                IconButton(onPressed: _enviar, icon: const Icon(Icons.send)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ConversacionSheet extends ConsumerStatefulWidget {
  const _ConversacionSheet({
    required this.cuentaId,
    required this.conversationId,
    required this.recipientId,
    required this.titulo,
  });
  final String cuentaId;
  final String conversationId;
  final String? recipientId;
  final String titulo;

  @override
  ConsumerState<_ConversacionSheet> createState() => _ConversacionSheetState();
}

class _ConversacionSheetState extends ConsumerState<_ConversacionSheet> {
  bool _loading = true;
  List _mensajes = const [];
  final _ctrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() => _loading = true);
    try {
      final list = await ref
          .read(socialRepositoryProvider)
          .listarMensajesConversacionFacebook(
            cuentaId: widget.cuentaId,
            conversationId: widget.conversationId,
          );
      if (mounted) {
        setState(() => _mensajes = list);
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _enviar() async {
    final txt = _ctrl.text.trim();
    final dest = widget.recipientId;
    if (txt.isEmpty || dest == null || dest.isEmpty) return;
    await ref
        .read(socialRepositoryProvider)
        .enviarMensajeFacebook(
          cuentaId: widget.cuentaId,
          recipientId: dest,
          texto: txt,
        );
    _ctrl.clear();
    await _cargar();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SizedBox(
        height: 420,
        child: Column(
          children: [
            Text(
              widget.titulo,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      reverse: true,
                      itemCount: _mensajes.length,
                      itemBuilder: (_, i) => ListTile(
                        title: Text(
                          (_mensajes[i] as Map)['message']?.toString() ??
                              '(Adjunto)',
                        ),
                      ),
                    ),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    decoration: const InputDecoration(
                      hintText: 'Escribir mensaje...',
                    ),
                  ),
                ),
                IconButton(
                  onPressed: widget.recipientId == null ? null : _enviar,
                  icon: const Icon(Icons.send),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
