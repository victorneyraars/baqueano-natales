import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:baqueano_natales/core/network/api_exceptions.dart';
import 'package:baqueano_natales/features/prestadores/data/prestador_providers.dart';

/// Pantalla de gestion de correos y canales de contacto del prestador.
///
/// Muestra:
/// - Email principal (recibe todo por defecto via Cloudflare catch-all)
/// - 8 correos del dominio con descripcion + toggles visible/activo
/// - WhatsApp, redes, google (read-only)
///
/// Persiste en perfil_negocio.canales_contacto (JSONB del backend).
class CorreosContactoScreen extends ConsumerWidget {
  const CorreosContactoScreen({super.key, required this.prestadorId});
  final String prestadorId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(canalesContactoProvider(prestadorId));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Correos y contacto'),
        actions: [
          IconButton(
            tooltip: 'Recargar',
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                ref.invalidate(canalesContactoProvider(prestadorId)),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorView(
          error: e,
          onRetry: () => ref.invalidate(canalesContactoProvider(prestadorId)),
        ),
        data: (canales) => _Body(prestadorId: prestadorId, canales: canales),
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text('$error', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }
}

class _Body extends ConsumerStatefulWidget {
  const _Body({required this.prestadorId, required this.canales});
  final String prestadorId;
  final Map<String, dynamic> canales;

  @override
  ConsumerState<_Body> createState() => _BodyState();
}

class _BodyState extends ConsumerState<_Body> {
  bool _cambiandoEmail = false;
  bool _verificando = false;
  final Set<String> _procesando = <String>{};

  Map<String, dynamic> get _canales => widget.canales;

  String get _emailReenvio =>
      (_canales['email_reenvio_personal'] as String?) ?? '';

  bool get _emailVerificado =>
      (_canales['email_reenvio_verificado'] as bool?) ?? false;

  List<Map<String, dynamic>> get _emails =>
      ((_canales['email'] as List?) ?? const [])
          .cast<Map<String, dynamic>>()
          .toList();

  Future<void> _cambiarEmail() async {
    final ctrl = TextEditingController(text: _emailReenvio);
    final nuevo = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cambiar email principal'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Todos los correos de tu dominio llegaran a esta direccion.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                hintText: 'tu@email.com',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final v = ctrl.text.trim();
              if (!RegExp(r'^[\w\.\-]+@[\w\.\-]+\.\w+$').hasMatch(v)) {
                ScaffoldMessenger.of(
                  ctx,
                ).showSnackBar(const SnackBar(content: Text('Email invalido')));
                return;
              }
              Navigator.pop(ctx, v);
            },
            child: const Text('Guardar y verificar'),
          ),
        ],
      ),
    );
    if (nuevo == null || nuevo.isEmpty || nuevo == _emailReenvio) return;

    setState(() => _cambiandoEmail = true);
    try {
      final repo = ref.read(prestadorRepositoryProvider);
      final res = await repo.cambiarEmailReenvio(
        prestadorId: widget.prestadorId,
        email: nuevo,
      );
      ref.invalidate(canalesContactoProvider(widget.prestadorId));
      if (!mounted) return;
      _snack(res['mensaje']?.toString() ?? 'Guardado');
    } on ApiException catch (e) {
      if (!mounted) return;
      _snack(e.message, isError: true);
    } finally {
      if (mounted) setState(() => _cambiandoEmail = false);
    }
  }

  Future<void> _confirmarVerificacion() async {
    setState(() => _verificando = true);
    try {
      final repo = ref.read(prestadorRepositoryProvider);
      final res = await repo.confirmarEmailReenvio(widget.prestadorId);
      ref.invalidate(canalesContactoProvider(widget.prestadorId));
      if (!mounted) return;
      _snack(res['mensaje']?.toString() ?? 'Verificado');
    } on ApiException catch (e) {
      if (!mounted) return;
      _snack(e.message, isError: true);
    } finally {
      if (mounted) setState(() => _verificando = false);
    }
  }

  Future<void> _toggleCanal(String tipo, {bool? visible, bool? activo}) async {
    setState(() => _procesando.add(tipo));
    try {
      final repo = ref.read(prestadorRepositoryProvider);
      await repo.actualizarCanalEmail(
        prestadorId: widget.prestadorId,
        tipo: tipo,
        visiblePublico: visible,
        activo: activo,
      );
      ref.invalidate(canalesContactoProvider(widget.prestadorId));
    } on ApiException catch (e) {
      if (!mounted) return;
      _snack(e.message, isError: true);
    } finally {
      if (mounted) setState(() => _procesando.remove(tipo));
    }
  }

  @override
  Widget build(BuildContext context) {
    final emails = _emails;
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(canalesContactoProvider(widget.prestadorId));
        await ref.read(canalesContactoProvider(widget.prestadorId).future);
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildEmailPrincipal(),
          const SizedBox(height: 24),
          Text(
            'Correos de tu dominio (${emails.length})',
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Todos llegan al email principal de arriba. Podes desactivarlos '
            'o marcarlos como no visibles en la web.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          for (final e in emails) _buildCorreoCard(e),
          const SizedBox(height: 24),
          _buildInfoAdicional(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildEmailPrincipal() {
    final theme = Theme.of(context);
    final verificado = _emailVerificado;
    final color = verificado ? Colors.green : Colors.orange;

    return Card(
      elevation: 2,
      color: verificado ? Colors.green.shade50 : Colors.orange.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.star, color: color, size: 22),
                const SizedBox(width: 8),
                Text(
                  'EMAIL PRINCIPAL',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    color: color.shade800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.mail, color: color, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _emailReenvio.isEmpty ? '(sin configurar)' : _emailReenvio,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  verificado ? Icons.check_circle : Icons.schedule,
                  color: color,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  verificado ? 'Verificado' : 'Pendiente de verificacion',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: color.shade800,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            if (!verificado && _emailReenvio.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Revisa $_emailReenvio y hace click en el link de Cloudflare.',
                style: theme.textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _cambiandoEmail ? null : _cambiarEmail,
                    icon: _cambiandoEmail
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.edit, size: 18),
                    label: const Text('Cambiar email'),
                  ),
                ),
                if (!verificado && _emailReenvio.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _verificando ? null : _confirmarVerificacion,
                      icon: _verificando
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check, size: 18),
                      label: const Text('Ya verifique'),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCorreoCard(Map<String, dynamic> e) {
    final tipo = (e['tipo'] as String?) ?? '';
    final direccion = (e['direccion'] as String?) ?? '';
    final descripcion = (e['descripcion'] as String?) ?? '';
    final visible = (e['visible_publico'] as bool?) ?? false;
    final activo = (e['activo'] as bool?) ?? true;
    final override = e['override_destino'] as String?;
    final procesando = _procesando.contains(tipo);
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.mail_outline, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    direccion,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (procesando)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(descripcion, style: theme.textTheme.bodySmall),
            if (override != null && override.isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.arrow_forward,
                      size: 12,
                      color: Colors.blue.shade800,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      override,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.blue.shade800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                _miniSwitch(
                  label: 'Visible web',
                  value: visible,
                  onChanged: procesando
                      ? null
                      : (v) => _toggleCanal(tipo, visible: v),
                ),
                const SizedBox(width: 16),
                _miniSwitch(
                  label: 'Activo',
                  value: activo,
                  onChanged: procesando
                      ? null
                      : (v) => _toggleCanal(tipo, activo: v),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoAdicional() {
    final whatsapps = ((_canales['whatsapp'] as List?) ?? const [])
        .cast<Map<String, dynamic>>();
    final redes = ((_canales['redes_sociales'] as List?) ?? const [])
        .cast<Map<String, dynamic>>();
    final google = (_canales['google'] as Map?) ?? const {};

    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: const Text('Otros canales (informativo)'),
      subtitle: const Text('WhatsApp, redes y Google'),
      children: [
        for (final w in whatsapps)
          ListTile(
            dense: true,
            leading: const Icon(Icons.phone),
            title: Text((w['numero'] as String?) ?? ''),
            subtitle: Text((w['descripcion'] as String?) ?? ''),
          ),
        for (final r in redes)
          ListTile(
            dense: true,
            leading: const Icon(Icons.link),
            title: Text((r['plataforma'] as String?) ?? ''),
            subtitle: Text((r['url'] as String?) ?? '(sin URL)'),
          ),
        ListTile(
          dense: true,
          leading: const Icon(Icons.cloud),
          title: const Text('Google Cloud'),
          subtitle: Text((google['service_account_email'] as String?) ?? ''),
        ),
      ],
    );
  }

  Widget _miniSwitch({
    required String label,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 24,
          child: Transform.scale(
            scale: 0.7,
            child: Switch(
              value: value,
              onChanged: onChanged,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : null,
      ),
    );
  }
}
