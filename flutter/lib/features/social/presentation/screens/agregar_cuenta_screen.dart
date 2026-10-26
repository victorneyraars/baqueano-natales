import 'dart:async';

import 'package:baqueano_natales/core/social/deep_link_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:baqueano_natales/core/network/api_exceptions.dart';
import 'package:baqueano_natales/features/social/data/social_providers.dart';
import 'package:baqueano_natales/features/social/domain/pagina_facebook.dart';

/// Pantalla para agregar cuentas de Facebook al sistema.
///
/// Flujo:
/// 1. Si NO hay admin token → muestra setup (OAuth + pegar token_ref).
/// 2. Si hay admin token → muestra lista de páginas con checkboxes.
class AgregarCuentaScreen extends ConsumerStatefulWidget {
  const AgregarCuentaScreen({super.key});

  @override
  ConsumerState<AgregarCuentaScreen> createState() =>
      _AgregarCuentaScreenState();
}

class _AgregarCuentaScreenState extends ConsumerState<AgregarCuentaScreen> {
  // Estado de selección
  final Set<String> _seleccionadas = {};
  String _propietarioTipo = 'baqueano';
  String? _prestadorId;

  @override
  Widget build(BuildContext context) {
    final statusAsync = ref.watch(adminTokenStatusProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Agregar cuenta')),
      body: statusAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (status) {
          if (!status.hasToken) {
            return const _SetupAdminTokenView();
          }
          return _ListaPaginasView(
            seleccionadas: _seleccionadas,
            onToggle: (id) {
              setState(() {
                if (_seleccionadas.contains(id)) {
                  _seleccionadas.remove(id);
                } else {
                  _seleccionadas.add(id);
                }
              });
            },
            propietarioTipo: _propietarioTipo,
            prestadorId: _prestadorId,
            onPropietarioChanged: (tipo, id) {
              setState(() {
                _propietarioTipo = tipo;
                _prestadorId = id;
              });
            },
          );
        },
      ),
      bottomNavigationBar: statusAsync.maybeWhen(
        data: (status) {
          if (!status.hasToken || _seleccionadas.isEmpty) return null;
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton.icon(
                onPressed: () => _conectarSeleccionadas(context),
                icon: const Icon(Icons.link),
                label: Text('Conectar ${_seleccionadas.length} página(s)'),
              ),
            ),
          );
        },
        orElse: () => null,
      ),
    );
  }

  Future<void> _conectarSeleccionadas(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final repo = ref.read(socialRepositoryProvider);
    var ok = 0;
    var fail = 0;
    for (final pageId in _seleccionadas) {
      try {
        await repo.conectarPaginaAdmin(
          pageId: pageId,
          propietarioTipo: _propietarioTipo,
          propietarioId: _propietarioTipo == 'prestador' ? _prestadorId : null,
        );
        ok++;
      } catch (_) {
        fail++;
      }
    }
    ref.invalidate(cuentasSocialesProvider);
    ref.invalidate(paginasAdminProvider);
    navigator.pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          '✅ $ok conectada(s)${fail > 0 ? " · ❌ $fail fallaron" : ""}',
        ),
        backgroundColor: fail == 0 ? Colors.green : Colors.orange,
      ),
    );
  }
}

// =========================================================
// Setup inicial (cuando NO hay admin token)
// =========================================================
class _SetupAdminTokenView extends ConsumerStatefulWidget {
  const _SetupAdminTokenView();

  @override
  ConsumerState<_SetupAdminTokenView> createState() =>
      _SetupAdminTokenViewState();
}

class _SetupAdminTokenViewState extends ConsumerState<_SetupAdminTokenView> {
  final _tokenRefCtrl = TextEditingController();
  bool _loading = false;
  String? _oauthUrl;
  StreamSubscription<Uri>? _deepLinkSub;

  @override
  void initState() {
    super.initState();
    _setupDeepLinkListener();
  }

  void _setupDeepLinkListener() {
    // Escuchar links entrantes mientras la app esta en foreground.
    _deepLinkSub = DeepLinkService.instance.stream.listen(_handleDeepLink);
    // Tambien chequear si la app arranco desde un deep link.
    DeepLinkService.instance.getInitial().then((uri) {
      if (uri != null && mounted) _handleDeepLink(uri);
    });
  }

  void _handleDeepLink(Uri uri) {
    final tokenRef = DeepLinkService.extractFacebookTokenRef(uri);
    if (tokenRef == null || tokenRef.isEmpty) return;
    if (!mounted) return;
    // Auto-completar el token y guardar automaticamente
    _tokenRefCtrl.text = tokenRef;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Token recibido automaticamente'),
        duration: Duration(seconds: 1),
      ),
    );
    _guardar();
  }

  @override
  void dispose() {
    _deepLinkSub?.cancel();
    _tokenRefCtrl.dispose();
    super.dispose();
  }

  Future<void> _generarUrl() async {
    setState(() => _loading = true);
    try {
      final repo = ref.read(socialRepositoryProvider);
      final oauth = await repo.getFacebookOAuthUrl(appRedirect: true);
      setState(() {
        _oauthUrl = oauth.url;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _guardar() async {
    final tokenRef = _tokenRefCtrl.text.trim();
    if (tokenRef.isEmpty) return;
    setState(() => _loading = true);
    try {
      final repo = ref.read(socialRepositoryProvider);
      await repo.setupAdminToken(tokenRef);
      ref.invalidate(adminTokenStatusProvider);
      // El widget _AgregarCuentaScreenState escucha este provider
      // y cambia automaticamente a la lista de paginas.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Admin token configurado'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.message}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _abrirNavegador(String url) async {
    try {
      final uri = Uri.parse(url);
      final ok = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'No se pudo abrir el navegador. Copiá la URL y abrila manualmente.',
            ),
            action: SnackBarAction(
              label: 'Copiar',
              onPressed: () => _copiarUrl(url),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al abrir: $e'),
            action: SnackBarAction(
              label: 'Copiar URL',
              onPressed: () => _copiarUrl(url),
            ),
          ),
        );
      }
    }
  }

  Future<void> _copiarUrl(String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ URL copiada al portapapeles'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Setup inicial',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Este es un paso único. Una vez configurado, podrás '
                  'agregar todas las páginas de Facebook sin volver a '
                  'autenticarte.',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Paso 1
        _Paso(
          numero: 1,
          titulo: 'Autorizar Facebook',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_oauthUrl == null)
                FilledButton.icon(
                  onPressed: _loading ? null : _generarUrl,
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Generar URL de autorización'),
                )
              else ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(
                    _oauthUrl!,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _abrirNavegador(_oauthUrl!),
                        icon: const Icon(Icons.open_in_browser),
                        label: const Text('Abrir en navegador'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      onPressed: () => _copiarUrl(_oauthUrl!),
                      icon: const Icon(Icons.copy),
                      tooltip: 'Copiar URL',
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Paso 2
        _Paso(
          numero: 2,
          titulo: 'Pegar token_ref',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Después de autorizar, Facebook te redirige a una página '
                'con un token. Copialo y pegalo acá:',
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _tokenRefCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'token_ref',
                  border: OutlineInputBorder(),
                  hintText: 'eyJ...',
                ),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _loading ? null : _guardar,
                icon: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check),
                label: const Text('Guardar'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// =========================================================
// Lista de páginas (cuando YA hay admin token)
// =========================================================
class _ListaPaginasView extends ConsumerWidget {
  const _ListaPaginasView({
    required this.seleccionadas,
    required this.onToggle,
    required this.propietarioTipo,
    required this.prestadorId,
    required this.onPropietarioChanged,
  });

  final Set<String> seleccionadas;
  final void Function(String id) onToggle;
  final String propietarioTipo;
  final String? prestadorId;
  final void Function(String tipo, String? id) onPropietarioChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paginasAsync = ref.watch(paginasAdminProvider);
    return paginasAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Icon(Icons.error, color: Colors.red, size: 48),
              const SizedBox(height: 8),
              Text('$e', textAlign: TextAlign.center),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () => ref.invalidate(paginasAdminProvider),
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      ),
      data: (paginas) {
        if (paginas.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                'No hay páginas disponibles.\n'
                'Verificá que tu cuenta de Facebook tenga páginas que administres.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Propietario de las páginas',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'baqueano',
                          label: Text('Baqueano'),
                          icon: Icon(Icons.business),
                        ),
                        ButtonSegment(
                          value: 'prestador',
                          label: Text('Prestador'),
                          icon: Icon(Icons.handyman),
                        ),
                      ],
                      selected: {propietarioTipo},
                      onSelectionChanged: (s) {
                        onPropietarioChanged(s.first, prestadorId);
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                'Seleccioná las páginas a conectar:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 8),
            for (final p in paginas)
              _PaginaTile(
                pagina: p,
                selected: seleccionadas.contains(p.id),
                onTap: p.yaConectada ? null : () => onToggle(p.id),
              ),
          ],
        );
      },
    );
  }
}

class _PaginaTile extends StatelessWidget {
  const _PaginaTile({
    required this.pagina,
    required this.selected,
    required this.onTap,
  });

  final PaginaFacebook pagina;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: CheckboxListTile(
        value: selected,
        onChanged: pagina.yaConectada ? null : (_) => onTap?.call(),
        title: Text(pagina.name),
        subtitle: pagina.yaConectada
            ? const Text('Ya conectada')
            : (pagina.category != null ? Text(pagina.category!) : null),
        secondary: const Icon(Icons.facebook, color: Color(0xFF1877F2)),
      ),
    );
  }
}

class _Paso extends StatelessWidget {
  const _Paso({
    required this.numero,
    required this.titulo,
    required this.child,
  });

  final int numero;
  final String titulo;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            shape: BoxShape.circle,
          ),
          child: Text(
            '$numero',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              child,
            ],
          ),
        ),
      ],
    );
  }
}
