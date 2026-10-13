/// Detalle de un prestador propio (dueño).
///
/// Muestra:
/// - Estado actual + motivo de rechazo (si aplica).
/// - Todos los datos del prestador (v1 + v2).
/// - Catálogo de servicios (con precios).
/// - Acciones: editar, gestionar servicios, enviar a revisión, eliminar.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:baqueano_natales/core/network/api_exceptions.dart';
import 'package:baqueano_natales/features/prestadores/data/prestador_providers.dart';
import 'package:baqueano_natales/features/prestadores/domain/prestador.dart';
import 'package:baqueano_natales/features/prestadores/domain/prestador_servicio.dart';

class DetalleMiPrestadorScreen extends ConsumerWidget {
  const DetalleMiPrestadorScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncPrestador = ref.watch(miPrestadorDetalleProvider(id));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi oficio'),
        actions: [
          IconButton(
            icon: const Icon(Icons.rate_review_outlined),
            tooltip: 'Resenas',
            onPressed: () =>
                context.push('/mis-prestadores/$id/reviews'),
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart_outlined),
            tooltip: 'Reportes',
            onPressed: () => context.push('/mis-prestadores/$id/reportes'),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Editar',
            onPressed: () => context.push('/mis-prestadores/$id/editar'),
          ),
        ],
      ),
      body: asyncPrestador.when(
        data: (prestador) => _Contenido(prestador: prestador, ref: ref),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorState(
          error: e.toString(),
          onRetry: () => ref.invalidate(miPrestadorDetalleProvider(id)),
        ),
      ),
    );
  }
}

class _Contenido extends StatelessWidget {
  const _Contenido({required this.prestador, required this.ref});

  final Prestador prestador;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // --- Card de estado ---
        _EstadoCard(prestador: prestador),

        const SizedBox(height: 16),

        // --- Datos principales ---
        _Seccion(titulo: 'Información', theme: theme),
        _fila(theme, 'Nombre', prestador.nombre),
        _fila(theme, 'Slug', prestador.slug),
        if (prestador.categoria.nombre.isNotEmpty)
          _fila(theme, 'Categoría', prestador.categoria.nombre),
        if (prestador.descripcion != null)
          _fila(theme, 'Descripción', prestador.descripcion!),
        if (prestador.aniosExperiencia != null)
          _fila(theme, 'Años de experiencia',
              '${prestador.aniosExperiencia}'),

        const SizedBox(height: 16),

        // --- Contacto ---
        _Seccion(titulo: 'Contacto', theme: theme),
        _fila(theme, 'Teléfono', prestador.telefono),
        _fila(theme, 'WhatsApp', prestador.whatsapp),
        _fila(theme, 'Mensaje pre-armado', prestador.whatsappMensaje),
        _fila(theme, 'Email', prestador.email),
        _fila(theme, 'Sitio web', prestador.sitioWeb),

        const SizedBox(height: 16),

        // --- Ubicación ---
        _Seccion(titulo: 'Ubicación', theme: theme),
        _fila(theme, 'Comuna', prestador.comuna),
        _fila(theme, 'Región', prestador.region),
        _fila(theme, 'Dirección', prestador.direccion),
        if (prestador.radioCoberturaKm != null)
          _fila(theme, 'Radio cobertura',
              '${prestador.radioCoberturaKm} km'),

        const SizedBox(height: 16),

        // --- Modalidad ---
        _Seccion(titulo: 'Modalidad', theme: theme),
        _fila(theme, 'Atiende a domicilio',
            prestador.atiendeDomicilio ? 'Sí' : 'No'),
        _fila(theme, 'Atiende en local',
            prestador.atiendeLocal ? 'Sí' : 'No'),
        _fila(theme, 'Atención emergencias',
            prestador.atiendeEmergencias ? 'Sí' : 'No'),
        _fila(theme, 'Horario', prestador.horarioDescripcion),

        const SizedBox(height: 16),

        // --- Especialidades ---
        if (prestador.especialidades != null &&
            prestador.especialidades!.isNotEmpty) ...[
          _Seccion(titulo: 'Especialidades', theme: theme),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: prestador.especialidades!
                .map((e) => Chip(
                      label: Text(_humanizar(e)),
                      visualDensity: VisualDensity.compact,
                    ))
                .toList(),
          ),
          const SizedBox(height: 16),
        ],

        // --- Servicios (resumen + acción) ---
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _Seccion(titulo: 'Servicios', theme: theme),
            TextButton.icon(
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: const Text('Gestionar'),
              onPressed: () =>
                  context.push('/mis-prestadores/${prestador.id}/servicios'),
            ),
          ],
        ),
        if (prestador.servicios.isEmpty)
          Text(
            'Sin servicios cargados. Agregá al menos uno para que los clientes te encuentren.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          )
        else
          ...prestador.servicios
              .take(5)
              .map((s) => _ServicioItem(servicio: s)),
        if (prestador.servicios.length > 5)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '+ ${prestador.servicios.length - 5} servicio(s) más',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),

        const SizedBox(height: 24),

        // --- Acciones ---
        if (prestador.estado == EstadoPrestador.borrador ||
            prestador.estado == EstadoPrestador.rechazado) ...[
          FilledButton.icon(
            icon: const Icon(Icons.send_outlined),
            label: const Text('Enviar a revisión'),
            onPressed: () => _enviarARevision(context, ref, prestador.id),
          ),
          const SizedBox(height: 8),
        ],

        OutlinedButton.icon(
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Editar datos'),
          onPressed: () =>
              context.push('/mis-prestadores/${prestador.id}/editar'),
        ),

        const SizedBox(height: 8),

        OutlinedButton.icon(
          icon: const Icon(Icons.list_alt_outlined),
          label: const Text('Gestionar servicios'),
          onPressed: () =>
              context.push('/mis-prestadores/${prestador.id}/servicios'),
        ),

        const SizedBox(height: 8),

        OutlinedButton.icon(
          icon: const Icon(Icons.receipt_long_outlined),
          label: const Text('Ordenes del taller'),
          onPressed: () => context.push(
            '/mis-prestadores/${prestador.id}/ordenes',
          ),
        ),
        const SizedBox(height: 8),

        OutlinedButton.icon(
          icon: const Icon(Icons.calendar_month_outlined),
          label: const Text('Agenda del taller'),
          onPressed: () => context.push(
            '/mis-prestadores/${prestador.id}/turnos',
          ),
        ),

        const SizedBox(height: 8),
        OutlinedButton.icon(
          icon: const Icon(Icons.share_outlined),
          label: const Text('Publicaciones en redes'),
          onPressed: () => context.push(
            '/mis-prestadores/${prestador.id}/publicaciones',
          ),
        ),

        const SizedBox(height: 8),

        OutlinedButton.icon(
          icon: const Icon(Icons.delete_outline),
          label: const Text('Eliminar prestador'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.red.shade700,
          ),
          onPressed: () => _confirmarEliminar(context, ref, prestador),
        ),

        const SizedBox(height: 32),
      ],
    );
  }

  Widget _fila(ThemeData theme, String label, String? valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              valor ?? '—',
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  static String _humanizar(String slug) {
    if (slug.isEmpty) return slug;
    final s = slug.replaceAll('_', ' ');
    return s[0].toUpperCase() + s.substring(1);
  }

  Future<void> _enviarARevision(
    BuildContext context,
    WidgetRef ref,
    String prestadorId,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enviar a revisión'),
        content: const Text(
          'Tu perfil será revisado por un administrador. '
          '¿Confirmás el envío?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Enviar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!context.mounted) return;

    try {
      final repo = ref.read(prestadorRepositoryProvider);
      await repo.enviarARevision(prestadorId);
      ref.invalidate(miPrestadorDetalleProvider(prestadorId));
      ref.invalidate(misPrestadoresProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Prestador enviado a revisión')),
      );
    } on ApiException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  Future<void> _confirmarEliminar(
    BuildContext context,
    WidgetRef ref,
    Prestador prestador,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar prestador'),
        content: Text(
          '¿Estás seguro de que querés eliminar "${prestador.nombre}"?\n\n'
          'Esta acción se puede revertir contactando a soporte.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade700,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!context.mounted) return;

    try {
      final repo = ref.read(prestadorRepositoryProvider);
      await repo.eliminarPrestador(prestador.id);
      ref.invalidate(misPrestadoresProvider);
      if (!context.mounted) return;
      context.pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Prestador eliminado')),
      );
    } on ApiException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }
}

// =========================================================
// Sub-widgets
// =========================================================
class _Seccion extends StatelessWidget {
  const _Seccion({required this.titulo, required this.theme});

  final String titulo;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        titulo,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _ServicioItem extends StatelessWidget {
  const _ServicioItem({required this.servicio});

  final PrestadorServicio servicio;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              servicio.nombre,
              style: theme.textTheme.bodyMedium,
            ),
          ),
          Text(
            servicio.precioLegible,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _EstadoCard extends StatelessWidget {
  const _EstadoCard({required this.prestador});

  final Prestador prestador;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final estado = prestador.estado ?? EstadoPrestador.borrador;
    final (color, bg, icon) = _estilo(estado);

    return Card(
      color: bg,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 8),
                Text(
                  estado.label,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (prestador.destacado)
                  Icon(Icons.star, color: Colors.amber.shade700),
                if (prestador.verificado) ...[
                  const SizedBox(width: 8),
                  Icon(
                    Icons.verified,
                    color: theme.colorScheme.primary,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _descripcionEstado(estado),
              style: theme.textTheme.bodySmall?.copyWith(color: color),
            ),
            if (prestador.estado == EstadoPrestador.rechazado &&
                prestador.motivoRechazo != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: Colors.red.shade700,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Motivo del rechazo',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.red.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            prestador.motivoRechazo!,
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  (Color, Color, IconData) _estilo(EstadoPrestador estado) {
    switch (estado) {
      case EstadoPrestador.verificado:
        return (
          Colors.green.shade800,
          Colors.green.shade50,
          Icons.verified_outlined,
        );
      case EstadoPrestador.pendiente:
        return (
          Colors.orange.shade800,
          Colors.orange.shade50,
          Icons.schedule_outlined,
        );
      case EstadoPrestador.rechazado:
        return (
          Colors.red.shade800,
          Colors.red.shade50,
          Icons.cancel_outlined,
        );
      case EstadoPrestador.suspendido:
        return (
          Colors.grey.shade800,
          Colors.grey.shade100,
          Icons.block_outlined,
        );
      case EstadoPrestador.borrador:
        return (
          Colors.blueGrey.shade800,
          Colors.blueGrey.shade50,
          Icons.edit_note_outlined,
        );
    }
  }

  String _descripcionEstado(EstadoPrestador estado) {
    switch (estado) {
      case EstadoPrestador.verificado:
        return 'Tu oficio está visible públicamente en la app.';
      case EstadoPrestador.pendiente:
        return 'Estamos revisando tu perfil. Te avisaremos pronto.';
      case EstadoPrestador.rechazado:
        return 'Tu perfil fue rechazado. Revisá el motivo y corregí.';
      case EstadoPrestador.suspendido:
        return 'Tu oficio está suspendido temporalmente.';
      case EstadoPrestador.borrador:
        return 'Completá la información y enviá a revisión.';
    }
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error al cargar', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(error, textAlign: TextAlign.center),
            const SizedBox(height: 24),
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