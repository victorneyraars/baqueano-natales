/// Detalle de un comercio propio (dueño).
///
/// Muestra:
/// - Estado actual del comercio + motivo de rechazo (si aplica).
/// - Todos los datos del comercio.
/// - Horarios.
/// - Acciones: editar, gestionar horarios, enviar a revisión, eliminar.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:baqueano_natales/core/network/api_exceptions.dart';
import 'package:baqueano_natales/features/comercios/data/comercio_providers.dart';
import 'package:baqueano_natales/features/comercios/domain/comercio.dart';
import 'package:baqueano_natales/features/comercios/domain/horario.dart';

class DetalleMiComercioScreen extends ConsumerWidget {
  const DetalleMiComercioScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncComercio = ref.watch(miComercioDetalleProvider(id));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi comercio'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Editar',
            onPressed: () => context.push('/mis-comercios/$id/editar'),
          ),
        ],
      ),
      body: asyncComercio.when(
        data: (comercio) => _Contenido(comercio: comercio, ref: ref),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorState(
          error: e.toString(),
          onRetry: () => ref.invalidate(miComercioDetalleProvider(id)),
        ),
      ),
    );
  }
}

class _Contenido extends StatelessWidget {
  const _Contenido({required this.comercio, required this.ref});

  final Comercio comercio;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // --- Card de estado ---
        _EstadoCard(comercio: comercio),

        const SizedBox(height: 16),

        // --- Datos principales ---
        _Seccion(titulo: 'Información', theme: theme),
        _fila(theme, 'Nombre', comercio.nombre),
        _fila(theme, 'Slug', comercio.slug),
        if (comercio.categoria != null)
          _fila(theme, 'Categoría', comercio.categoria!.nombre),
        if (comercio.descripcionCorta != null)
          _fila(theme, 'Descripción corta', comercio.descripcionCorta!),
        if (comercio.descripcionLarga != null)
          _fila(theme, 'Descripción larga', comercio.descripcionLarga!),

        const SizedBox(height: 16),

        // --- Contacto ---
        _Seccion(titulo: 'Contacto', theme: theme),
        _fila(theme, 'Teléfono', comercio.telefono),
        _fila(theme, 'WhatsApp', comercio.whatsapp),
        _fila(theme, 'Email', comercio.email),
        _fila(theme, 'Sitio web', comercio.sitioWeb),

        const SizedBox(height: 16),

        // --- Ubicación ---
        _Seccion(titulo: 'Ubicación', theme: theme),
        _fila(theme, 'Dirección', comercio.direccion),
        _fila(theme, 'Ciudad', comercio.ciudad),
        _fila(theme, 'Región', comercio.region),
        _fila(theme, 'Referencia', comercio.referencia),
        if (comercio.latitud != null && comercio.longitud != null)
          _fila(
            theme,
            'Coordenadas',
            '${comercio.latitud!.toStringAsFixed(4)}, '
                '${comercio.longitud!.toStringAsFixed(4)}',
          ),

        const SizedBox(height: 16),

        // --- Delivery ---
        _Seccion(titulo: 'Delivery', theme: theme),
        _fila(theme, 'Acepta delivery', comercio.aceptaDelivery ? 'Sí' : 'No'),
        _fila(theme, 'Acepta retiro', comercio.aceptaRetiro ? 'Sí' : 'No'),
        if (comercio.aceptaDelivery) ...[
          _fila(theme, 'Costo de envío', '\$${comercio.costoEnvioClp}'),
          _fila(theme, 'Pedido mínimo', '\$${comercio.pedidoMinimoClp}'),
          if (comercio.radioEntregaKm != null)
            _fila(theme, 'Radio de entrega', '${comercio.radioEntregaKm} km'),
          if (comercio.tiempoPreparacionMin != null)
            _fila(theme, 'Preparación', '${comercio.tiempoPreparacionMin} min'),
        ],

        const SizedBox(height: 16),

        // --- Horarios (con botón Gestionar al lado) ---
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _Seccion(titulo: 'Horarios', theme: theme),
            TextButton.icon(
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: const Text('Gestionar'),
              onPressed: () =>
                  context.push('/mis-comercios/${comercio.id}/horarios'),
            ),
          ],
        ),
        if (comercio.horarios.isEmpty)
          Text(
            'Sin horarios cargados',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          )
        else
          _HorariosTabla(horarios: comercio.horarios),

        const SizedBox(height: 24),

        // --- Acciones ---
        if (comercio.estado == EstadoComercio.borrador ||
            comercio.estado == EstadoComercio.rechazado) ...[
          FilledButton.icon(
            icon: const Icon(Icons.send_outlined),
            label: const Text('Enviar a revisión'),
            onPressed: () => _enviarARevision(context, ref, comercio.id),
          ),
          const SizedBox(height: 8),
        ],

        OutlinedButton.icon(
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Editar comercio'),
          onPressed: () => context.push('/mis-comercios/${comercio.id}/editar'),
        ),

        const SizedBox(height: 8),

        OutlinedButton.icon(
          icon: const Icon(Icons.schedule_outlined),
          label: const Text('Gestionar horarios'),
          onPressed: () =>
              context.push('/mis-comercios/${comercio.id}/horarios'),
        ),

        const SizedBox(height: 8),

        OutlinedButton.icon(
          icon: const Icon(Icons.delete_outline),
          label: const Text('Eliminar comercio'),
          style: OutlinedButton.styleFrom(foregroundColor: Colors.red.shade700),
          onPressed: () => _confirmarEliminar(context, ref, comercio),
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
            width: 130,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(valor ?? '—', style: theme.textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }

  Future<void> _enviarARevision(
    BuildContext context,
    WidgetRef ref,
    String comercioId,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enviar a revisión'),
        content: const Text(
          'Tu comercio será revisado por un administrador. '
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
      final repo = ref.read(comercioRepositoryProvider);
      await repo.enviarARevision(comercioId);
      ref.invalidate(miComercioDetalleProvider(comercioId));
      ref.invalidate(misComerciosProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Comercio enviado a revisión')),
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
    Comercio comercio,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar comercio'),
        content: Text(
          '¿Estás seguro de que querés eliminar "${comercio.nombre}"?\n\n'
          'Esta acción se puede revertir contactando a soporte.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!context.mounted) return;

    try {
      final repo = ref.read(comercioRepositoryProvider);
      await repo.eliminarComercio(comercio.id);
      ref.invalidate(misComerciosProvider);
      if (!context.mounted) return;
      context.pop();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Comercio eliminado')));
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

class _EstadoCard extends StatelessWidget {
  const _EstadoCard({required this.comercio});

  final Comercio comercio;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final estado = comercio.estado ?? EstadoComercio.borrador;
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
                if (comercio.destacado)
                  Icon(Icons.star, color: Colors.amber.shade700),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _descripcionEstado(estado),
              style: theme.textTheme.bodySmall?.copyWith(color: color),
            ),
            if (comercio.estado == EstadoComercio.rechazado &&
                comercio.motivoRechazo != null) ...[
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
                            comercio.motivoRechazo!,
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

  (Color, Color, IconData) _estilo(EstadoComercio estado) {
    switch (estado) {
      case EstadoComercio.verificado:
        return (
          Colors.green.shade800,
          Colors.green.shade50,
          Icons.verified_outlined,
        );
      case EstadoComercio.pendiente:
        return (
          Colors.orange.shade800,
          Colors.orange.shade50,
          Icons.schedule_outlined,
        );
      case EstadoComercio.rechazado:
        return (Colors.red.shade800, Colors.red.shade50, Icons.cancel_outlined);
      case EstadoComercio.suspendido:
        return (
          Colors.grey.shade800,
          Colors.grey.shade100,
          Icons.block_outlined,
        );
      case EstadoComercio.borrador:
        return (
          Colors.blueGrey.shade800,
          Colors.blueGrey.shade50,
          Icons.edit_note_outlined,
        );
    }
  }

  String _descripcionEstado(EstadoComercio estado) {
    switch (estado) {
      case EstadoComercio.verificado:
        return 'Tu comercio está visible públicamente en la app.';
      case EstadoComercio.pendiente:
        return 'Estamos revisando tu comercio. Te avisaremos pronto.';
      case EstadoComercio.rechazado:
        return 'Tu comercio fue rechazado. Revisá el motivo y corregí.';
      case EstadoComercio.suspendido:
        return 'Tu comercio está suspendido temporalmente.';
      case EstadoComercio.borrador:
        return 'Completá la información y enviá a revisión.';
    }
  }
}

class _HorariosTabla extends StatelessWidget {
  const _HorariosTabla({required this.horarios});

  final List<Horario> horarios;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final porDia = <int, List<Horario>>{};
    for (final h in horarios) {
      porDia.putIfAbsent(h.diaSemana, () => []).add(h);
    }
    final dias = porDia.keys.toList()..sort();

    return Column(
      children: dias.map((dia) {
        final lista = porDia[dia]!;
        final todosCerrados = lista.every((h) => h.cerrado);
        final texto = todosCerrados
            ? 'Cerrado'
            : lista
                  .where((h) => !h.cerrado)
                  .map((h) => h.rangoLegible)
                  .join(' / ');

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 100,
                child: Text(
                  lista.first.nombreDia,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  texto,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: todosCerrados
                        ? theme.colorScheme.onSurfaceVariant
                        : null,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
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
