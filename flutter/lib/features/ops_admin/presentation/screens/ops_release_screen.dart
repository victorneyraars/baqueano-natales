/// Pantalla de release trigger (Fase 2d del modulo ops).
///
/// Flujo:
///   1. Usuario ingresa version_name (ej. "0.3.5")
///   2. Boton "Generar preview" -> POST /release/preview
///   3. Muestra versiones calculadas + validaciones
///   4. Si can_proceed, boton "Publicar release"
///   5. Modal de confirmacion con input "CONFIRMAR"
///   6. POST /release/trigger -> tag creado en GitHub
///   7. Muestra resultado (tag, run_url, duracion estimada)
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';

import '../widgets/apk_download_button.dart';

import 'package:baqueano_natales/core/network/api_exceptions.dart';
import 'package:baqueano_natales/features/ops_admin/data/ops_providers.dart';
import 'package:baqueano_natales/features/ops_admin/domain/ops_models.dart';

class OpsReleaseScreen extends ConsumerStatefulWidget {
  const OpsReleaseScreen({super.key});

  @override
  ConsumerState<OpsReleaseScreen> createState() => _OpsReleaseScreenState();
}

class _OpsReleaseScreenState extends ConsumerState<OpsReleaseScreen> {
  final _versionController = TextEditingController();
  final _versionFormKey = GlobalKey<FormState>();

  // Estado del preview actual
  ReleasePreview? _preview;
  bool _loadingPreview = false;
  String? _previewError;

  // Estado del trigger
  bool _triggering = false;
  ReleaseTrigger? _triggerResult;
  String? _triggerError;
  String? _suggestedVersion;
  String? _commitType;
  String? _commitMsg;
  String? _currentVersion;
  int? _nextVersionCode;

  @override
  void initState() {
    super.initState();
    _autocompletarVersion();
  }

  /// Hace un preview "probe" para leer currentVersion y sugerir la siguiente.
  /// Usa 99.99.99 para garantizar que el backend siempre responda.
  Future<void> _autocompletarVersion() async {
    if (_versionController.text.isNotEmpty) return;
    try {
      final result = await ref.read(
        opsReleasePreviewProvider(
          const ReleasePreviewParams(versionName: '99.99.99'),
        ).future,
      );
      final current = result.currentVersion; // ej. "0.3.4+7"
      if (current.isEmpty) return;
      final base = current.split('+').first; // "0.3.4"
      final parts = base.split('.');
      if (parts.length != 3) return;
      final major = int.tryParse(parts[0]);
      final minor = int.tryParse(parts[1]);
      if (major == null || minor == null) return;
      final patch = int.tryParse(parts[2]) ?? 0;
      final msg = result.headCommitMessage.toLowerCase();

      String type = 'patch (fix)';
      String suggested = '$major.$minor.${patch + 1}';

      if (msg.contains('breaking change') || msg.contains('!:')) {
        type = 'major (breaking)';
        suggested = '${major + 1}.0.0';
      } else if (msg.startsWith('feat') ||
          msg.contains('feat:') ||
          msg.contains('feat(')) {
        type = 'minor (feature)';
        suggested = '$major.${minor + 1}.0';
      } else if (msg.startsWith('fix') ||
          msg.contains('fix:') ||
          msg.contains('fix(')) {
        type = 'patch (fix)';
        suggested = '$major.$minor.${patch + 1}';
      } else {
        type = 'patch (default)';
        suggested = '$major.$minor.${patch + 1}';
      }

      if (!mounted) return;
      setState(() {
        _suggestedVersion = suggested;
        _commitType = type;
        _commitMsg = result.headCommitMessage;
        _currentVersion = result.currentVersion;
        _nextVersionCode = result.nextVersionCode;
        if (_versionController.text.isEmpty) {
          _versionController.text = suggested;
        }
      });
    } catch (_) {
      // silencioso: si falla, el usuario escribe a mano
    }
  }

  @override
  void dispose() {
    _versionController.dispose();
    super.dispose();
  }

  Future<void> _generarPreview() async {
    if (!_versionFormKey.currentState!.validate()) return;

    setState(() {
      _loadingPreview = true;
      _previewError = null;
      _preview = null;
      _triggerResult = null;
      _triggerError = null;
    });

    try {
      final params = ReleasePreviewParams(
        versionName: _versionController.text.trim(),
      );
      final result = await ref.read(opsReleasePreviewProvider(params).future);
      if (mounted) {
        setState(() {
          _preview = result;
          _loadingPreview = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _previewError = e.message;
          _loadingPreview = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _previewError = 'Error inesperado: $e';
          _loadingPreview = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Publicar release')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ----- Intro -----
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.new_releases,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Nueva version',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('El release va a:', style: theme.textTheme.bodySmall),
                  const SizedBox(height: 4),
                  Text(
                    '1. Actualizar pubspec.yaml con la nueva version\n'
                    '2. Crear el tag en GitHub (ej. v0.3.5)\n'
                    '3. Disparar el workflow Release (firma + sube a Play Store)\n'
                    '4. Publicar en Play Store internal testing',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ----- Asistente SemVer -----
          if (_suggestedVersion != null)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(
                  alpha: 0.3,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.auto_awesome,
                        size: 18,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Asistente SemVer',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_commitMsg != null) ...[
                    Text(
                      'Último commit: $_commitMsg',
                      style: theme.textTheme.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                  ],
                  if (_commitType != null)
                    Text(
                      'Detectado: $_commitType',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _currentVersion != null && _nextVersionCode != null
                              ? 'Actual: $_currentVersion  ➔  Nueva: $_suggestedVersion+$_nextVersionCode'
                              : 'Recomendación: $_suggestedVersion',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      FilledButton.tonal(
                        onPressed: () {
                          setState(() {
                            _versionController.text = _suggestedVersion!;
                          });
                        },
                        child: const Text('Usar'),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          // ----- Input version -----
          Form(
            key: _versionFormKey,
            child: TextFormField(
              controller: _versionController,
              decoration: const InputDecoration(
                labelText: 'Version a publicar',
                hintText: '0.3.5',
                helperText: 'Formato: X.Y.Z (sin +N, se agrega automatico)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.local_offer_outlined),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Ingresa una version';
                }
                final regex = RegExp(r'^\d+\.\d+\.\d+$');
                if (!regex.hasMatch(value.trim())) {
                  return 'Formato invalido. Usa X.Y.Z (ej. 0.3.5)';
                }
                return null;
              },
              enabled: !_loadingPreview && !_triggering,
            ),
          ),
          const SizedBox(height: 12),

          // ----- Boton generar preview -----
          FilledButton.icon(
            icon: _loadingPreview
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.preview),
            label: Text(
              _loadingPreview ? 'Generando preview...' : 'Generar preview',
            ),
            onPressed: _loadingPreview || _triggering ? null : _generarPreview,
          ),
          const SizedBox(height: 16),

          // ----- Error del preview -----
          if (_previewError != null) ...[
            Card(
              color: theme.colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: theme.colorScheme.onErrorContainer,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _previewError!,
                        style: TextStyle(
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ----- Preview resultado -----
          if (_preview != null) _buildPreviewCard(theme, _preview!),

          // ----- Trigger resultado -----
          if (_triggerResult != null) ...[
            const SizedBox(height: 16),
            _buildTriggerResultCard(theme, _triggerResult!),
          ],

          // ----- Trigger error -----
          if (_triggerError != null) ...[
            const SizedBox(height: 16),
            Card(
              color: theme.colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      Icons.cancel,
                      color: theme.colorScheme.onErrorContainer,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _triggerError!,
                        style: TextStyle(
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPreviewCard(ThemeData theme, ReleasePreview preview) {
    return SizedBox(
      width: double.infinity,
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    preview.canProceed
                        ? Icons.check_circle
                        : Icons.error_outline,
                    color: preview.canProceed ? Colors.green : Colors.red,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      preview.canProceed
                          ? 'Listo para publicar'
                          : 'Revisar validaciones',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: preview.canProceed
                            ? Colors.green.shade700
                            : Colors.red.shade700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildVersionRow(theme, 'Actual', preview.currentVersion, false),
              const SizedBox(height: 4),
              _buildVersionRow(theme, 'Nueva', preview.targetVersion, true),
              const SizedBox(height: 12),
              _buildDetailRow(theme, 'Tag', preview.targetTag),
              _buildDetailRow(
                theme,
                'VersionCode',
                '${preview.nextVersionCode}',
              ),
              _buildDetailRow(theme, 'Workflow', preview.workflowName),
              _buildDetailRow(
                theme,
                'Duracion',
                '~${preview.estimatedDurationMin} min',
              ),
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              Text('Commit a taggear:', style: theme.textTheme.labelSmall),
              const SizedBox(height: 4),
              Text(
                preview.headSha.length >= 7
                    ? '${preview.headSha.substring(0, 7)}  -  ${preview.headCommitMessage}'
                    : preview.headCommitMessage,
                style: theme.textTheme.bodySmall,
              ),
              if (preview.headCommitAgeMinutes != null)
                Text(
                  'Hace ${preview.headCommitAgeMinutes} min',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                'Validaciones (${preview.validations.length})',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              ...preview.validations.map((v) => _buildValidationRow(theme, v)),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: _triggering
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.rocket_launch),
                  label: Text(
                    _triggering ? 'Publicando...' : 'Publicar release',
                  ),
                  onPressed: !preview.canProceed || _triggering
                      ? null
                      : () => _mostrarModalConfirmacion(preview),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // ----- Build triggers -----
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.build),
                  label: const Text('Generar APK Admin (dev)'),
                  onPressed: () => _triggerBuild(context, 'adminDev'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.build),
                  label: const Text('Generar APK Client (dev)'),
                  onPressed: () => _triggerBuild(context, 'clientDev'),
                ),
              ),
              const SizedBox(height: 16),
              // ----- Descarga e instalación in-app -----
              Row(
                children: [
                  const Expanded(
                    child: ApkDownloadButton(
                      flavor: 'adminDev',
                      label: 'Descargar e Instalar Admin',
                      icon: Icons.admin_panel_settings,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    icon: const Icon(Icons.share),
                    tooltip: 'Compartir link Admin',
                    onPressed: () {
                      SharePlus.instance.share(
                        ShareParams(
                          text: 'Descarga el APK de Admin (dev) aquí: https://api-dev.baqueanonatales.com/apks/app-admindev.apk',
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Expanded(
                    child: ApkDownloadButton(
                      flavor: 'clientDev',
                      label: 'Descargar e Instalar Client',
                      icon: Icons.people,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    icon: const Icon(Icons.share),
                    tooltip: 'Compartir link Client',
                    onPressed: () {
                      SharePlus.instance.share(
                        ShareParams(
                          text: 'Descarga el APK de Client (dev) aquí: https://api-dev.baqueanonatales.com/apks/app-clientdev.apk',
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVersionRow(
    ThemeData theme,
    String label,
    String value,
    bool highlight,
  ) {
    return Row(
      children: [
        SizedBox(
          width: 60,
          child: Text(label, style: theme.textTheme.bodySmall),
        ),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
            color: highlight ? theme.colorScheme.primary : null,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(ThemeData theme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: theme.textTheme.bodySmall),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildValidationRow(ThemeData theme, ValidationCheck v) {
    final (icon, color) = switch (v.status) {
      ValidationStatus.ok => (Icons.check_circle, Colors.green),
      ValidationStatus.warning => (Icons.warning_amber_rounded, Colors.orange),
      ValidationStatus.error => (Icons.cancel, Colors.red),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(v.name, style: theme.textTheme.bodyMedium),
                if (v.detail != null)
                  Text(
                    v.detail!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTriggerResultCard(ThemeData theme, ReleaseTrigger result) {
    return Card(
      color: Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.check_circle,
                  color: Colors.green.shade700,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Release publicado',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(result.message, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 12),
            _buildDetailRow(theme, 'Tag', result.tag),
            _buildDetailRow(
              theme,
              'Commit',
              result.commitSha.length >= 7
                  ? result.commitSha.substring(0, 7)
                  : result.commitSha,
            ),
            _buildDetailRow(
              theme,
              'Duracion',
              '~${result.estimatedDurationMin} min',
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.open_in_new),
                label: const Text('Ver workflow en GitHub'),
                onPressed: () => _abrirUrl(result.githubUrl),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _abrirUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _mostrarModalConfirmacion(ReleasePreview preview) async {
    final controller = TextEditingController();
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final matches = controller.text == 'CONFIRMAR';
          return AlertDialog(
            title: Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.orange.shade700,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Confirmar release',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Vas a crear el tag ${preview.targetTag} en GitHub. '
                  'Esto dispara el workflow Release que firma el AAB '
                  'y lo sube a Play Store internal.',
                ),
                const SizedBox(height: 16),
                Text(
                  'Escribi CONFIRMAR para continuar:',
                  style: Theme.of(ctx).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: controller,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'CONFIRMAR',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setModalState(() {}),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: matches ? () => Navigator.of(ctx).pop(true) : null,
                style: FilledButton.styleFrom(
                  backgroundColor: matches ? Colors.red.shade700 : null,
                ),
                child: const Text('Publicar'),
              ),
            ],
          );
        },
      ),
    );

    if (confirmado == true) {
      await _ejecutarTrigger(preview);
    }
  }

  Future<void> _ejecutarTrigger(ReleasePreview preview) async {
    setState(() {
      _triggering = true;
      _triggerError = null;
      _triggerResult = null;
    });

    try {
      final repo = ref.read(opsRepositoryProvider);
      final result = await repo.releaseTrigger(
        previewToken: preview.previewToken,
      );
      if (mounted) {
        setState(() {
          _triggerResult = result;
          _triggering = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _triggerError = e.message;
          _triggering = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _triggerError = 'Error inesperado: $e';
          _triggering = false;
        });
      }
    }
  }

  Future<void> _triggerBuild(BuildContext context, String flavor) async {
    try {
      final repo = ref.read(opsRepositoryProvider);
      final result = await repo.triggerDevBuild(flavor: flavor);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Build disparado.'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
