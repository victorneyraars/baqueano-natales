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
  bool _subscribingWebhook = false;
  List _posts = const [];
  List _conversaciones = const [];
  List _insights = const [];
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _cargarTodo();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _cargarTodo() async {
    await Future.wait([
      _cargarPosts(),
      _cargarConversaciones(),
      _cargarInsights(),
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
      _errorMsg = null;
    });
    try {
      final items = await ref
          .read(socialRepositoryProvider)
          .listarConversacionesFacebook(widget.cuenta.id);
      if (mounted) {
        setState(() => _conversaciones = items);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMsg = e.toString());
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
      _errorMsg = null;
    });
    try {
      final items = await ref
          .read(socialRepositoryProvider)
          .obtenerInsightsFacebook(widget.cuenta.id);
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

  Future<void> _suscribirWebhook() async {
    setState(() => _subscribingWebhook = true);
    try {
      await ref
          .read(socialRepositoryProvider)
          .suscribirWebhookFacebook(widget.cuenta.id);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Webhook de pagina suscrito')),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error webhook: $e')));
    } finally {
      if (mounted) {
        setState(() => _subscribingWebhook = false);
      }
    }
  }

  Future<void> _editarPost(Map post) async {
    final postId = post['id']?.toString() ?? '';
    if (postId.isEmpty) {
      return;
    }
    final ctrl = TextEditingController(text: post['message']?.toString() ?? '');
    final nuevo = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Editar publicacion'),
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
    if (nuevo == null || nuevo.isEmpty) {
      return;
    }
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
    if (postId.isEmpty) {
      return;
    }
    await ref
        .read(socialRepositoryProvider)
        .eliminarPostFacebook(cuentaId: widget.cuenta.id, postId: postId);
    await _cargarPosts();
  }

  void _abrirComentarios(Map post) {
    final objectId = post['id']?.toString() ?? '';
    if (objectId.isEmpty) {
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) =>
          _ComentariosSheet(cuentaId: widget.cuenta.id, objectId: objectId),
    );
  }

  void _abrirConversacion(Map conv) {
    final convId = conv['id']?.toString() ?? '';
    if (convId.isEmpty) {
      return;
    }
    final parts = conv['participants'];
    final list = (parts is Map ? parts['data'] : null) as List? ?? const [];
    String? recipientId;
    String titulo = 'Conversacion';
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
            Tab(text: 'Metricas'),
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
              children: [_buildPosts(), _buildInbox(), _buildMetricas()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPosts() {
    if (_loadingPosts) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_posts.isEmpty) {
      return const Center(child: Text('Sin publicaciones'));
    }
    return ListView.builder(
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
                if (v == 'comments') {
                  _abrirComentarios(p);
                }
                if (v == 'edit') {
                  _editarPost(p);
                }
                if (v == 'delete') {
                  _eliminarPost(p);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'comments', child: Text('Comentarios')),
                PopupMenuItem(value: 'edit', child: Text('Editar')),
                PopupMenuItem(value: 'delete', child: Text('Eliminar')),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInbox() {
    if (_loadingConvs) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_conversaciones.isEmpty) {
      return const Center(child: Text('Sin conversaciones'));
    }
    return ListView.builder(
      itemCount: _conversaciones.length,
      itemBuilder: (_, i) {
        final c = _conversaciones[i] as Map;
        return ListTile(
          title: Text(c['snippet']?.toString() ?? 'Conversacion', maxLines: 2),
          subtitle: Text(c['updated_time']?.toString() ?? ''),
          onTap: () => _abrirConversacion(c),
        );
      },
    );
  }

  Widget _buildMetricas() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        FilledButton.icon(
          onPressed: _subscribingWebhook ? null : _suscribirWebhook,
          icon: const Icon(Icons.sync),
          label: const Text('Suscribir pagina a Webhooks'),
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
                title: Text(
                  m['title']?.toString() ?? m['name']?.toString() ?? 'Metrica',
                ),
                trailing: Text(last),
              ),
            );
          }),
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
    if (txt.isEmpty) {
      return;
    }
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
    if (txt.isEmpty || dest == null || dest.isEmpty) {
      return;
    }
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
