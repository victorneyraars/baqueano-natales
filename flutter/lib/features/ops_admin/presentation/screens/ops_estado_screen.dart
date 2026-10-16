/// Pantalla de Ops Dashboard (panel admin, Fase 1 read-only).
///
/// Secciones:
/// - Header con estado consolidado (backend + GitHub + CI/CD)
/// - Componentes del sistema
/// - Ultimo release exitoso
/// - Ultimos 10 workflow runs
/// - Links de descarga (opt-in + Play Store)
///
/// Auto-refresh cada 30s (pausado si la app esta en background).
/// Pull-to-refresh manual.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:baqueano_natales/core/widgets/responsive_layout.dart';
import 'package:baqueano_natales/features/ops_admin/data/ops_providers.dart';
import 'package:baqueano_natales/features/ops_admin/domain/ops_models.dart';

class OpsEstadoScreen extends ConsumerStatefulWidget {
  const OpsEstadoScreen({super.key});

  @override
  ConsumerState<OpsEstadoScreen> createState() => _OpsEstadoScreenState();
}

class _OpsEstadoScreenState extends ConsumerState<OpsEstadoScreen>
    with WidgetsBindingObserver {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _iniciarTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Pausa el auto-refresh si la app no esta visible (ahorra red/bateria).
    if (state == AppLifecycleState.resumed) {
      _iniciarTimer();
    } else {
      _timer?.cancel();
    }
  }

  void _iniciarTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      ref.invalidate(opsHealthProvider);
      ref.invalidate(opsRunsProvider);
      ref.invalidate(opsTracksProvider);
    });
  }

  Future<void> _refrescarTodo() async {
    ref.invalidate(opsHealthProvider);
    ref.invalidate(opsRunsProvider);
    ref.invalidate(opsTracksProvider);
    ref.invalidate(opsLinksProvider);
    // Esperar al health (es el mas lento) para que el RefreshIndicator
    // se vea hasta que la data nueva este lista.
    await ref.read(opsHealthProvider.future);
  }
  @override
  Widget build(BuildContext context) {
    final healthAsync = ref.watch(opsHealthProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ops Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refrescar todo',
            onPressed: _refrescarTodo,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refrescarTodo,
        child: healthAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _VistaError(mensaje: e.toString(), onRetry: _refrescarTodo),
          data: (health) => ResponsiveLayout(
            phone: _VistaPhone(health: health),
            tablet: _VistaTablet(health: health),
          ),
        ),
      ),
    );
  }
}
// ============================================================
// Vistas: phone (1 columna) y tablet (2 columnas)
// ============================================================

class _VistaPhone extends ConsumerWidget {
  const _VistaPhone({required this.health});

  final SystemHealth health;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _Header(health: health),
        const SizedBox(height: 16),
        _ComponentesCard(health: health),
        const SizedBox(height: 16),
        _UltimoReleaseCard(health: health),
        const SizedBox(height: 16),
        const _RunsCard(),
        const SizedBox(height: 16),
        _LinksCard(health: health),
        const SizedBox(height: 16),
        const _QuickLinksCard(),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _VistaTablet extends ConsumerWidget {
  const _VistaTablet({required this.health});

  final SystemHealth health;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _Header(health: health),
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                children: [
                  _ComponentesCard(health: health),
                  const SizedBox(height: 16),
                  _UltimoReleaseCard(health: health),
                ],
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                children: [
                  const _RunsCard(),
                  const SizedBox(height: 16),
                  _LinksCard(health: health),
                  const SizedBox(height: 16),
                  const _QuickLinksCard(),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
// ============================================================
// Header: environment + version + stats 24h
// ============================================================

class _Header extends StatelessWidget {
  const _Header({required this.health});

  final SystemHealth health;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ok = health.allOk;
    final color = ok ? Colors.green : Colors.orange;

    return Card(
      color: color.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  ok ? Icons.check_circle : Icons.warning_amber_rounded,
                  color: color,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ok ? 'Sistema operativo' : 'Atencion requerida',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                      Text(
                        'Environment: ${health.environment} · v${health.version}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _StatBox(
                    label: 'Runs 24h',
                    value: '${health.totalRunsLast24h}',
                    icon: Icons.play_circle_outline,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatBox(
                    label: 'Fallidos 24h',
                    value: '${health.failedRunsLast24h}',
                    icon: Icons.error_outline,
                    color: health.failedRunsLast24h > 0 ? Colors.red : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({
    required this.label,
    required this.value,
    required this.icon,
    this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color ?? theme.colorScheme.primary),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              )),
              Text(label, style: theme.textTheme.bodySmall),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Componentes del sistema
// ============================================================

class _ComponentesCard extends StatelessWidget {
  const _ComponentesCard({required this.health});

  final SystemHealth health;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Componentes',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            if (health.components.isEmpty)
              Text('Sin datos', style: theme.textTheme.bodySmall)
            else
              ...health.components.map((c) => _ComponenteRow(componente: c)),
          ],
        ),
      ),
    );
  }
}

class _ComponenteRow extends StatelessWidget {
  const _ComponenteRow({required this.componente});

  final ComponentHealth componente;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (icon, color) = switch (componente.status) {
      ComponentStatus.ok => (Icons.check_circle, Colors.green),
      ComponentStatus.degraded => (Icons.warning_amber_rounded, Colors.orange),
      ComponentStatus.down => (Icons.cancel, Colors.red),
      ComponentStatus.unknown => (Icons.help_outline, Colors.grey),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  componente.name,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (componente.detail != null && componente.detail!.isNotEmpty)
                  Text(
                    componente.detail!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            componente.status.label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Ultimo release exitoso
// ============================================================

class _UltimoReleaseCard extends StatelessWidget {
  const _UltimoReleaseCard({required this.health});

  final SystemHealth health;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final release = health.lastSuccessfulRelease;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ultimo release exitoso',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            if (release == null)
              Text('Sin releases registrados', style: theme.textTheme.bodySmall)
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.local_offer, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          release.name,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '#${release.runNumber} · ${release.headBranch ?? "—"}',
                    style: theme.textTheme.bodySmall,
                  ),
                  if (release.duracionHumana != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Duracion: ${release.duracionHumana}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }
}
// ============================================================
// Ultimos workflow runs
// ============================================================

class _RunsCard extends ConsumerWidget {
  const _RunsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final runsAsync = ref.watch(opsRunsProvider(const RunsParams()));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ultimos runs',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            runsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Text(
                'Error: $e',
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.red),
              ),
              data: (resp) {
                if (resp.runs.isEmpty) {
                  return Text('Sin runs', style: theme.textTheme.bodySmall);
                }
                return Column(
                  children: resp.runs
                      .take(10)
                      .map((r) => _RunRow(run: r))
                      .toList(growable: false),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _RunRow extends StatelessWidget {
  const _RunRow({required this.run});

  final RunInfo run;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (icon, color) = _iconForRun(run);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  run.name,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '#${run.runNumber} · ${run.headBranch ?? "—"}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (run.duracionHumana != null)
            Text(
              run.duracionHumana!,
              style: theme.textTheme.bodySmall,
            ),
        ],
      ),
    );
  }

  static (IconData, Color) _iconForRun(RunInfo run) {
    if (run.status == WorkflowRunStatus.inProgress ||
        run.status == WorkflowRunStatus.queued) {
      return (Icons.sync, Colors.blue);
    }
    switch (run.conclusion) {
      case WorkflowRunConclusion.success:
        return (Icons.check_circle, Colors.green);
      case WorkflowRunConclusion.failure:
        return (Icons.cancel, Colors.red);
      case WorkflowRunConclusion.cancelled:
        return (Icons.block, Colors.grey);
      default:
        return (Icons.help_outline, Colors.grey);
    }
  }
}

// ============================================================
// Links de descarga
// ============================================================

class _LinksCard extends StatelessWidget {
  const _LinksCard({required this.health});

  final SystemHealth health;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final links = health.links;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Links de descarga',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            if (links == null)
              Text('Sin links configurados', style: theme.textTheme.bodySmall)
            else ...[
              _LinkRow(app: links.client),
              const SizedBox(height: 12),
              _LinkRow(app: links.admin),
            ],
          ],
        ),
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({required this.app});

  final AppLinks app;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          app.appLabel,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            if (app.optInUrl.isNotEmpty)
              ActionChip(
                avatar: const Icon(Icons.group_add, size: 16),
                label: const Text('Opt-in testers'),
                onPressed: () => _abrirUrl(context, app.optInUrl),
              ),
            if (app.playStoreUrl.isNotEmpty)
              ActionChip(
                avatar: const Icon(Icons.shop, size: 16),
                label: const Text('Play Store'),
                onPressed: () => _abrirUrl(context, app.playStoreUrl),
              ),
          ],
        ),
      ],
    );
  }

  static Future<void> _abrirUrl(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo abrir: $url')),
      );
    }
  }
}

// ============================================================
// Vista de error (con boton de retry)
// ============================================================

class _VistaError extends StatelessWidget {
  const _VistaError({required this.mensaje, required this.onRetry});

  final String mensaje;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // ListView para que el RefreshIndicator siga funcionando.
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 60),
        Icon(Icons.cloud_off, size: 64, color: theme.colorScheme.error),
        const SizedBox(height: 16),
        Text(
          'No se pudo cargar el Ops Dashboard',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          mensaje,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 24),
        Center(
          child: FilledButton.icon(
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
            onPressed: onRetry,
          ),
        ),
      ],
    );
  }
}
// ============================================================
// Quick links (accesos a dashboards externos)
// ============================================================

class _QuickLinksCard extends ConsumerWidget {
  const _QuickLinksCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final linksAsync = ref.watch(opsQuickLinksProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Accesos directos',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Dashboards externos sin salir de la app',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            linksAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Text(
                'Error: $e',
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.red),
              ),
              data: (resp) {
                if (resp.categories.isEmpty) {
                  return Text('Sin accesos', style: theme.textTheme.bodySmall);
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final cat in resp.categories) ...[
                      _QuickLinkCategorySection(categoria: cat),
                      const SizedBox(height: 8),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickLinkCategorySection extends StatelessWidget {
  const _QuickLinkCategorySection({required this.categoria});

  final QuickLinkCategory categoria;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Row(
            children: [
              Icon(_iconForQuickLink(categoria.icon), size: 16,
                  color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Text(
                categoria.label,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
        for (final link in categoria.links) _QuickLinkTile(link: link),
      ],
    );
  }
}

class _QuickLinkTile extends StatelessWidget {
  const _QuickLinkTile({required this.link});

  final QuickLink link;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => _abrirLink(context, link.url),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            Icon(_iconForQuickLink(link.icon), size: 20,
                color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    link.label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (link.description != null && link.description!.isNotEmpty)
                    Text(
                      link.description!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            Icon(
              Icons.open_in_new,
              size: 16,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> _abrirLink(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || url.isEmpty) return;
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo abrir: $url')),
      );
    }
  }
}

IconData _iconForQuickLink(String nombre) {
  switch (nombre) {
    case 'people':
      return Icons.people_outline;
    case 'rocket':
      return Icons.rocket_launch_outlined;
    case 'shop':
      return Icons.shop_outlined;
    case 'git':
      return Icons.code;
    case 'play':
      return Icons.play_circle_outline;
    case 'tag':
      return Icons.local_offer_outlined;
    case 'bug':
      return Icons.bug_report_outlined;
    case 'cloud':
      return Icons.cloud_outlined;
    case 'server':
      return Icons.dns_outlined;
    case 'health':
      return Icons.monitor_heart_outlined;
    case 'dashboard':
      return Icons.dashboard_outlined;
    default:
      return Icons.link;
  }
}