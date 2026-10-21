// lib/features/ops_admin/domain/ops_models.dart
//
// Modelos del Ops Dashboard (Fase 1, read-only).
// Replican 1:1 los schemas Pydantic del backend:
//   backend/app/modules/ops/schemas.py
//
// Parsing defensivo: tolerante a nulls y campos faltantes. Los enums
// incluyen un valor `unknown` para no romper si el backend agrega valores
// nuevos. Los DateTime son tolerantes a formatos inesperados (nullable).
// ============================================================
// Helpers internos de parseo defensivo
// ============================================================
int? _asInt(Object? v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}

String? _asString(Object? v) {
  if (v == null) return null;
  if (v is String) return v;
  return v.toString();
}

DateTime? _asDateTime(Object? v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  if (v is String) return DateTime.tryParse(v);
  return null;
}

List<Map<String, dynamic>> _asListOfMap(Object? v) {
  if (v is! List) return const [];
  final out = <Map<String, dynamic>>[];
  for (final item in v) {
    if (item is Map<String, dynamic>) {
      out.add(item);
    } else if (item is Map) {
      out.add(item.cast<String, dynamic>());
    }
  }
  return List.unmodifiable(out);
}

Map<String, dynamic>? _asMap(Object? v) {
  if (v is Map<String, dynamic>) return v;
  if (v is Map) return v.cast<String, dynamic>();
  return null;
}

// ============================================================
// Enums
// ============================================================
/// Estado de un workflow run de GitHub Actions.
enum WorkflowRunStatus {
  queued,
  inProgress,
  completed,
  requested,
  waiting,
  pending,
  unknown;

  static WorkflowRunStatus fromRaw(String? raw) {
    switch (raw) {
      case 'queued':
        return WorkflowRunStatus.queued;
      case 'in_progress':
        return WorkflowRunStatus.inProgress;
      case 'completed':
        return WorkflowRunStatus.completed;
      case 'requested':
        return WorkflowRunStatus.requested;
      case 'waiting':
        return WorkflowRunStatus.waiting;
      case 'pending':
        return WorkflowRunStatus.pending;
      default:
        return WorkflowRunStatus.unknown;
    }
  }

  String get label {
    switch (this) {
      case WorkflowRunStatus.queued:
        return 'En cola';
      case WorkflowRunStatus.inProgress:
        return 'En progreso';
      case WorkflowRunStatus.completed:
        return 'Completado';
      case WorkflowRunStatus.requested:
        return 'Solicitado';
      case WorkflowRunStatus.waiting:
        return 'Esperando';
      case WorkflowRunStatus.pending:
        return 'Pendiente';
      case WorkflowRunStatus.unknown:
        return 'Desconocido';
    }
  }
}

/// Resultado final de un workflow run (o null si aun no termino).
enum WorkflowRunConclusion {
  success,
  failure,
  neutral,
  cancelled,
  skipped,
  timedOut,
  actionRequired,
  stale;

  static WorkflowRunConclusion? fromRaw(String? raw) {
    switch (raw) {
      case 'success':
        return WorkflowRunConclusion.success;
      case 'failure':
        return WorkflowRunConclusion.failure;
      case 'neutral':
        return WorkflowRunConclusion.neutral;
      case 'cancelled':
        return WorkflowRunConclusion.cancelled;
      case 'skipped':
        return WorkflowRunConclusion.skipped;
      case 'timed_out':
        return WorkflowRunConclusion.timedOut;
      case 'action_required':
        return WorkflowRunConclusion.actionRequired;
      case 'stale':
        return WorkflowRunConclusion.stale;
      default:
        return null;
    }
  }

  String get label {
    switch (this) {
      case WorkflowRunConclusion.success:
        return 'Exitoso';
      case WorkflowRunConclusion.failure:
        return 'Fallido';
      case WorkflowRunConclusion.neutral:
        return 'Neutral';
      case WorkflowRunConclusion.cancelled:
        return 'Cancelado';
      case WorkflowRunConclusion.skipped:
        return 'Omitido';
      case WorkflowRunConclusion.timedOut:
        return 'Timeout';
      case WorkflowRunConclusion.actionRequired:
        return 'Requiere accion';
      case WorkflowRunConclusion.stale:
        return 'Obsoleto';
    }
  }
}

/// Estado de un componente del sistema.
enum ComponentStatus {
  ok,
  degraded,
  down,
  unknown;

  static ComponentStatus fromRaw(String? raw) {
    switch (raw) {
      case 'ok':
        return ComponentStatus.ok;
      case 'degraded':
        return ComponentStatus.degraded;
      case 'down':
        return ComponentStatus.down;
      default:
        return ComponentStatus.unknown;
    }
  }

  String get label {
    switch (this) {
      case ComponentStatus.ok:
        return 'OK';
      case ComponentStatus.degraded:
        return 'Degradado';
      case ComponentStatus.down:
        return 'Caido';
      case ComponentStatus.unknown:
        return 'Desconocido';
    }
  }
} // ============================================================

// GitHub Actions
// ============================================================
/// Resumen de un workflow run de GitHub Actions.
class RunInfo {
  final int id;
  final String name;
  final int workflowId;
  final String event;
  final WorkflowRunStatus status;
  final WorkflowRunConclusion? conclusion;
  final String? headBranch;
  final String headSha;
  final int runNumber;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String htmlUrl;
  final int? durationSeconds;
  const RunInfo({
    required this.id,
    required this.name,
    required this.workflowId,
    required this.event,
    required this.status,
    this.conclusion,
    this.headBranch,
    this.headSha = '',
    this.runNumber = 0,
    this.createdAt,
    this.updatedAt,
    this.htmlUrl = '',
    this.durationSeconds,
  });
  factory RunInfo.fromJson(Map<String, dynamic> json) {
    return RunInfo(
      id: _asInt(json['id']) ?? 0,
      name: _asString(json['name']) ?? '',
      workflowId: _asInt(json['workflow_id']) ?? 0,
      event: _asString(json['event']) ?? '',
      status: WorkflowRunStatus.fromRaw(_asString(json['status'])),
      conclusion: WorkflowRunConclusion.fromRaw(_asString(json['conclusion'])),
      headBranch: _asString(json['head_branch']),
      headSha: _asString(json['head_sha']) ?? '',
      runNumber: _asInt(json['run_number']) ?? 0,
      createdAt: _asDateTime(json['created_at']),
      updatedAt: _asDateTime(json['updated_at']),
      htmlUrl: _asString(json['html_url']) ?? '',
      durationSeconds: _asInt(json['duration_seconds']),
    );
  }

  /// Duracion en formato humano (ej. "1m 15s"). Null si no hay datos.
  String? get duracionHumana {
    final s = durationSeconds;
    if (s == null) return null;
    if (s < 60) return '${s}s';
    final m = s ~/ 60;
    final rest = s % 60;
    if (m < 60) return rest == 0 ? '${m}m' : '${m}m ${rest}s';
    final h = m ~/ 60;
    final restM = m % 60;
    return restM == 0 ? '${h}h' : '${h}h ${restM}m';
  }
}

/// Un paso (step) dentro de un job.
class StepInfo {
  final String name;
  final String status;
  final String? conclusion;
  final int number;
  final DateTime? startedAt;
  final DateTime? completedAt;
  const StepInfo({
    required this.name,
    this.status = '',
    this.conclusion,
    this.number = 0,
    this.startedAt,
    this.completedAt,
  });
  factory StepInfo.fromJson(Map<String, dynamic> json) {
    return StepInfo(
      name: _asString(json['name']) ?? '',
      status: _asString(json['status']) ?? '',
      conclusion: _asString(json['conclusion']),
      number: _asInt(json['number']) ?? 0,
      startedAt: _asDateTime(json['started_at']),
      completedAt: _asDateTime(json['completed_at']),
    );
  }
}

/// Un job dentro de un workflow run.
class JobInfo {
  final int id;
  final String name;
  final String status;
  final String? conclusion;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final List<StepInfo> steps;
  const JobInfo({
    required this.id,
    required this.name,
    this.status = '',
    this.conclusion,
    this.startedAt,
    this.completedAt,
    this.steps = const [],
  });
  factory JobInfo.fromJson(Map<String, dynamic> json) {
    return JobInfo(
      id: _asInt(json['id']) ?? 0,
      name: _asString(json['name']) ?? '',
      status: _asString(json['status']) ?? '',
      conclusion: _asString(json['conclusion']),
      startedAt: _asDateTime(json['started_at']),
      completedAt: _asDateTime(json['completed_at']),
      steps: _asListOfMap(json['steps'])
          .map(StepInfo.fromJson)
          .toList(growable: false),
    );
  }
}

/// Detalle completo de un run: incluye jobs + steps.
class RunDetail extends RunInfo {
  final List<JobInfo> jobs;
  const RunDetail({
    required super.id,
    required super.name,
    required super.workflowId,
    required super.event,
    required super.status,
    super.conclusion,
    super.headBranch,
    super.headSha,
    super.runNumber,
    super.createdAt,
    super.updatedAt,
    super.htmlUrl,
    super.durationSeconds,
    this.jobs = const [],
  });
  factory RunDetail.fromJson(Map<String, dynamic> json) {
    return RunDetail(
      id: _asInt(json['id']) ?? 0,
      name: _asString(json['name']) ?? '',
      workflowId: _asInt(json['workflow_id']) ?? 0,
      event: _asString(json['event']) ?? '',
      status: WorkflowRunStatus.fromRaw(_asString(json['status'])),
      conclusion: WorkflowRunConclusion.fromRaw(_asString(json['conclusion'])),
      headBranch: _asString(json['head_branch']),
      headSha: _asString(json['head_sha']) ?? '',
      runNumber: _asInt(json['run_number']) ?? 0,
      createdAt: _asDateTime(json['created_at']),
      updatedAt: _asDateTime(json['updated_at']),
      htmlUrl: _asString(json['html_url']) ?? '',
      durationSeconds: _asInt(json['duration_seconds']),
      jobs: _asListOfMap(json['jobs'])
          .map(JobInfo.fromJson)
          .toList(growable: false),
    );
  }
}

/// Lista paginada de runs.
class RunsResponse {
  final int totalCount;
  final List<RunInfo> runs;
  const RunsResponse({this.totalCount = 0, this.runs = const []});
  factory RunsResponse.fromJson(Map<String, dynamic> json) {
    return RunsResponse(
      totalCount: _asInt(json['total_count']) ?? 0,
      runs: _asListOfMap(json['runs'])
          .map(RunInfo.fromJson)
          .toList(growable: false),
    );
  }
} // ============================================================

// Play Console (tracks + versiones)
// ============================================================
/// Version actual en un track de Play Store.
class TrackVersion {
  final String track;
  final int? versionCode;
  final String? versionName;
  final String? status;
  final String? releaseName;
  final String? releaseNotes;
  const TrackVersion({
    required this.track,
    this.versionCode,
    this.versionName,
    this.status,
    this.releaseName,
    this.releaseNotes,
  });
  factory TrackVersion.fromJson(Map<String, dynamic> json) {
    return TrackVersion(
      track: _asString(json['track']) ?? '',
      versionCode: _asInt(json['version_code']),
      versionName: _asString(json['version_name']),
      status: _asString(json['status']),
      releaseName: _asString(json['release_name']),
      releaseNotes: _asString(json['release_notes']),
    );
  }

  /// Etiqueta legible del track (ej. "internal" -> "Internal").
  String get trackLabel {
    switch (track) {
      case 'internal':
        return 'Internal';
      case 'alpha':
        return 'Alpha';
      case 'beta':
        return 'Beta';
      case 'production':
        return 'Produccion';
      default:
        return track.isEmpty ? 'Desconocido' : track;
    }
  }
}

/// Tracks de una app.
class AppTracks {
  final String packageName;
  final String appLabel;
  final List<TrackVersion> tracks;
  final String? error;
  const AppTracks({
    required this.packageName,
    required this.appLabel,
    this.tracks = const [],
    this.error,
  });
  factory AppTracks.fromJson(Map<String, dynamic> json) {
    return AppTracks(
      packageName: _asString(json['package_name']) ?? '',
      appLabel: _asString(json['app_label']) ?? '',
      tracks: _asListOfMap(json['tracks'])
          .map(TrackVersion.fromJson)
          .toList(growable: false),
      error: _asString(json['error']),
    );
  }
}

/// Tracks de las 2 apps (client + admin).
class TracksResponse {
  final AppTracks client;
  final AppTracks admin;
  const TracksResponse({required this.client, required this.admin});
  factory TracksResponse.fromJson(Map<String, dynamic> json) {
    return TracksResponse(
      client: AppTracks.fromJson(_asMap(json['client']) ?? const {}),
      admin: AppTracks.fromJson(_asMap(json['admin']) ?? const {}),
    );
  }
}

// ============================================================
// Links de descarga
// ============================================================
/// Links de descarga de una app.
class AppLinks {
  final String packageName;
  final String appLabel;
  final String optInUrl;
  final String playStoreUrl;
  const AppLinks({
    required this.packageName,
    required this.appLabel,
    this.optInUrl = '',
    this.playStoreUrl = '',
  });
  factory AppLinks.fromJson(Map<String, dynamic> json) {
    return AppLinks(
      packageName: _asString(json['package_name']) ?? '',
      appLabel: _asString(json['app_label']) ?? '',
      optInUrl: _asString(json['opt_in_url']) ?? '',
      playStoreUrl: _asString(json['play_store_url']) ?? '',
    );
  }
}

/// Links de descarga de las 2 apps.
class LinksResponse {
  final AppLinks client;
  final AppLinks admin;
  const LinksResponse({required this.client, required this.admin});
  factory LinksResponse.fromJson(Map<String, dynamic> json) {
    return LinksResponse(
      client: AppLinks.fromJson(_asMap(json['client']) ?? const {}),
      admin: AppLinks.fromJson(_asMap(json['admin']) ?? const {}),
    );
  }
}

// ============================================================
// Health consolidado
// ============================================================
/// Estado de un componente del sistema.
class ComponentHealth {
  final String name;
  final ComponentStatus status;
  final String? detail;
  const ComponentHealth({
    required this.name,
    required this.status,
    this.detail,
  });
  factory ComponentHealth.fromJson(Map<String, dynamic> json) {
    return ComponentHealth(
      name: _asString(json['name']) ?? '',
      status: ComponentStatus.fromRaw(_asString(json['status'])),
      detail: _asString(json['detail']),
    );
  }
}

/// Estado consolidado del sistema para el panel admin.
class SystemHealth {
  final String environment;
  final String version;
  final DateTime? timestamp;
  final List<ComponentHealth> components;
  final RunInfo? lastSuccessfulRelease;
  final int totalRunsLast24h;
  final int failedRunsLast24h;
  final LinksResponse? links;
  const SystemHealth({
    this.environment = '',
    this.version = '',
    this.timestamp,
    this.components = const [],
    this.lastSuccessfulRelease,
    this.totalRunsLast24h = 0,
    this.failedRunsLast24h = 0,
    this.links,
  });
  factory SystemHealth.fromJson(Map<String, dynamic> json) {
    final linksRaw = _asMap(json['links']);
    final lastReleaseRaw = _asMap(json['last_successful_release']);
    return SystemHealth(
      environment: _asString(json['environment']) ?? '',
      version: _asString(json['version']) ?? '',
      timestamp: _asDateTime(json['timestamp']),
      components: _asListOfMap(json['components'])
          .map(ComponentHealth.fromJson)
          .toList(growable: false),
      lastSuccessfulRelease: lastReleaseRaw == null
          ? null
          : RunInfo.fromJson(lastReleaseRaw),
      totalRunsLast24h: _asInt(json['total_runs_last_24h']) ?? 0,
      failedRunsLast24h: _asInt(json['failed_runs_last_24h']) ?? 0,
      links: linksRaw == null ? null : LinksResponse.fromJson(linksRaw),
    );
  }

  /// `true` si todos los componentes estan OK.
  bool get allOk =>
      components.isNotEmpty &&
      components.every((c) => c.status == ComponentStatus.ok);
}
// ============================================================
// Quick links (accesos rapidos a dashboards externos)
// ============================================================

/// Un link a un dashboard o herramienta externa.
class QuickLink {
  final String id;
  final String label;
  final String? description;
  final String url;
  final String icon;

  const QuickLink({
    required this.id,
    required this.label,
    this.description,
    this.url = '',
    this.icon = '',
  });

  factory QuickLink.fromJson(Map<String, dynamic> json) {
    return QuickLink(
      id: _asString(json['id']) ?? '',
      label: _asString(json['label']) ?? '',
      description: _asString(json['description']),
      url: _asString(json['url']) ?? '',
      icon: _asString(json['icon']) ?? '',
    );
  }
}

/// Una categoria de links (ej. Play Console, GitHub).
class QuickLinkCategory {
  final String id;
  final String label;
  final String icon;
  final List<QuickLink> links;

  const QuickLinkCategory({
    required this.id,
    required this.label,
    this.icon = '',
    this.links = const [],
  });

  factory QuickLinkCategory.fromJson(Map<String, dynamic> json) {
    return QuickLinkCategory(
      id: _asString(json['id']) ?? '',
      label: _asString(json['label']) ?? '',
      icon: _asString(json['icon']) ?? '',
      links: _asListOfMap(json['links'])
          .map(QuickLink.fromJson)
          .toList(growable: false),
    );
  }
}

/// Respuesta con todas las categorias y links.
class QuickLinksResponse {
  final List<QuickLinkCategory> categories;

  const QuickLinksResponse({this.categories = const []});

  factory QuickLinksResponse.fromJson(Map<String, dynamic> json) {
    return QuickLinksResponse(
      categories: _asListOfMap(json['categories'])
          .map(QuickLinkCategory.fromJson)
          .toList(growable: false),
    );
  }
}
// ============================================================
// Fase 2 - Release preview + trigger
// ============================================================

/// Estado de una validacion previa al release.
enum ValidationStatus {
  ok,
  warning,
  error;

  static ValidationStatus fromRaw(String? raw) {
    switch (raw) {
      case 'ok':
        return ValidationStatus.ok;
      case 'warning':
        return ValidationStatus.warning;
      case 'error':
        return ValidationStatus.error;
      default:
        return ValidationStatus.error;
    }
  }
}

/// Una validacion previa al release.
class ValidationCheck {
  final String name;
  final ValidationStatus status;
  final String? detail;

  const ValidationCheck({
    required this.name,
    this.status = ValidationStatus.error,
    this.detail,
  });

  factory ValidationCheck.fromJson(Map<String, dynamic> json) {
    return ValidationCheck(
      name: _asString(json['name']) ?? '',
      status: ValidationStatus.fromRaw(_asString(json['status'])),
      detail: _asString(json['detail']),
    );
  }
}

/// Preview de un release (respuesta del endpoint).
class ReleasePreview {
  final String currentVersion;
  final String targetVersion;
  final String targetTag;
  final int nextVersionCode;

  final String headSha;
  final String headCommitMessage;
  final int? headCommitAgeMinutes;

  final List<ValidationCheck> validations;
  final bool canProceed;

  final int estimatedDurationMin;
  final String workflowName;

  final String previewToken;
  final DateTime? expiresAt;

  const ReleasePreview({
    this.currentVersion = '',
    this.targetVersion = '',
    this.targetTag = '',
    this.nextVersionCode = 0,
    this.headSha = '',
    this.headCommitMessage = '',
    this.headCommitAgeMinutes,
    this.validations = const [],
    this.canProceed = false,
    this.estimatedDurationMin = 0,
    this.workflowName = '',
    this.previewToken = '',
    this.expiresAt,
  });

  factory ReleasePreview.fromJson(Map<String, dynamic> json) {
    return ReleasePreview(
      currentVersion: _asString(json['current_version']) ?? '',
      targetVersion: _asString(json['target_version']) ?? '',
      targetTag: _asString(json['target_tag']) ?? '',
      nextVersionCode: _asInt(json['next_version_code']) ?? 0,
      headSha: _asString(json['head_sha']) ?? '',
      headCommitMessage: _asString(json['head_commit_message']) ?? '',
      headCommitAgeMinutes: _asInt(json['head_commit_age_minutes']),
      validations: _asListOfMap(json['validations'])
          .map(ValidationCheck.fromJson)
          .toList(growable: false),
      canProceed: json['can_proceed'] == true,
      estimatedDurationMin: _asInt(json['estimated_duration_min']) ?? 0,
      workflowName: _asString(json['workflow_name']) ?? '',
      previewToken: _asString(json['preview_token']) ?? '',
      expiresAt: _asDateTime(json['expires_at']),
    );
  }

  /// Cantidad de validaciones con error.
  int get errorCount =>
      validations.where((v) => v.status == ValidationStatus.error).length;

  /// Cantidad de validaciones con warning.
  int get warningCount =>
      validations.where((v) => v.status == ValidationStatus.warning).length;
}

/// Respuesta del trigger de release.
class ReleaseTrigger {
  final String tag;
  final String commitSha;
  final String workflowName;
  final int estimatedDurationMin;
  final String githubUrl;
  final String auditLogId;
  final String message;

  const ReleaseTrigger({
    this.tag = '',
    this.commitSha = '',
    this.workflowName = '',
    this.estimatedDurationMin = 0,
    this.githubUrl = '',
    this.auditLogId = '',
    this.message = '',
  });

  factory ReleaseTrigger.fromJson(Map<String, dynamic> json) {
    return ReleaseTrigger(
      tag: _asString(json['tag']) ?? '',
      commitSha: _asString(json['commit_sha']) ?? '',
      workflowName: _asString(json['workflow_name']) ?? '',
      estimatedDurationMin: _asInt(json['estimated_duration_min']) ?? 0,
      githubUrl: _asString(json['github_url']) ?? '',
      auditLogId: _asString(json['audit_log_id']) ?? '',
      message: _asString(json['message']) ?? '',
    );
  }
}
