/// Detalle de prestador para admin.
///
/// Acciones disponibles según estado:
/// - `pendiente`    → Verificar / Rechazar
/// - `verificado`   → Suspender / Destacar / Re-verificar (no-op)
/// - `suspendido`   → Re-verificar
/// - `rechazado`    → Re-verificar (si el dueño corrigió)
///
/// Muestra:
/// - Datos completos del prestador (incluyendo contacto interno)
/// - Catálogo de servicios
/// - Galería
/// - Motivo de rechazo/suspensión si aplica
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:baqueano_natales/core/network/api_exceptions.dart';
import 'package:baqueano_natales/features/prestadores/data/prestador_providers.dart';
import 'package:baqueano_natales/features/prestadores/domain/prestador.dart';
import 'package:baqueano_natales/features/prestadores/domain/prestador_servicio.dart';

class AdminDetallePrestadorScreen extends ConsumerWidget {
  const AdminDetallePrestadorScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncPrestador = ref.watch(adminPrestadorDetalleProvider(id));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle prestador'),
      ),
      body: asyncPrestador.when(
        data: (prestador) => _Contenido(prestador: prestador, ref: ref),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorState(
          error: e.toString(),
          onRetry: () => ref.invalidate(adminPrestadorDetalleProvider(id)),
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

        // --- Acciones ---
        _AccionesAdmin(prestador: prestador, ref: ref),

        const SizedBox(height: 24),

        // --- Datos principales ---
        _Seccion(titulo: 'Información', theme: theme),
        _fila(theme, 'Nombre', prestador.nombre),
        _fila(theme, 'Slug', prestador.slug),
        if (prestador.categoria.nombre.isNotEmpty)
          _fila(theme, 'Categoría', prestador.categoria.nombre),
        if (prestador.descripcion != null)
          _fila(theme, 'Descripción', prestador.descripcion!),
        if (prestador.aniosExperiencia != null)
          _fila(
            theme,
            'Años de experiencia',
            '${prestador.aniosExperiencia}',
          ),

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
          _fila(
            theme,
            'Radio cobertura',
            '${prestador.radioCoberturaKm} km',
          ),

        const SizedBox(height: 16),

        // --- Modalidad ---
        _Seccion(titulo: 'Modalidad', theme: theme),
        _fila(
          theme,
          'Atiende a domicilio',
          prestador.atiendeDomicilio ? 'Sí' : 'No',
        ),
        _fila(
          theme,
          'Atiende en local',
          prestador.atiendeLocal ? 'Sí' : 'No',
        ),
        _fila(
          theme,
          'Emergencias',
          prestador.atiendeEmergencias ? 'Sí' : 'No',
        ),
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
                .map(
                  (e) => Chip(
                    label: Text(_humanizar(e)),
                    visualDensity: VisualDensity.compact,
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 16),
        ],

        // --- Redes ---
        if (prestador.redesSociales != null &&
            prestador.redesSociales!.isNotEmpty) ...[
          _Seccion(titulo: 'Redes sociales', theme: theme),
          ...prestador.redesSociales!.entries.map(
            (e) => _fila(
              theme,
              e.key[0].toUpperCase() + e.key.substring(1),
              e.value.toString(),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // --- Servicios ---
        _Seccion(
          titulo: 'Servicios (${prestador.servicios.length})',
          theme: theme,
        ),
        if (prestador.servicios.isEmpty)
          Text(
            'Sin servicios cargados',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          )
        else
          ...prestador.servicios.map((s) => _ServicioItem(servicio: s)),

        const SizedBox(height: 24),

        // --- Metadata ---
        _Seccion(titulo: 'Metadata', theme: theme),
        _fila(theme, 'ID', prestador.id),
        _fila(theme, 'Usuario ID', prestador.usuarioId),
        if (prestador.verificadoEn != null)
          _fila(
            theme,
            'Verificado en',
            prestador.verificadoEn!.toLocal().toString().split('.').first,
          ),
        if (prestador.createdAt != null)
          _fila(
            theme,
            'Creado',
            prestador.createdAt!.toLocal().toString().split('.').first,
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  servicio.nombre,
                  style: theme.textTheme.bodyMedium,
                ),
                if (servicio.categoriaServicio != null)
                  Text(
                    servicio.categoriaServicio!,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
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

// =========================================================
// Card de estado
// =========================================================
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
            if (prestador.motivoRechazo != null &&
                (estado == EstadoPrestador.rechazado ||
                    estado == EstadoPrestador.suspendido)) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      estado == EstadoPrestador.rechazado
                          ? 'Motivo del rechazo'
                          : 'Motivo de la suspensión',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: color,
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
}

// =========================================================
// Acciones admin
// =========================================================
class _AccionesAdmin extends StatelessWidget {
  const _AccionesAdmin({required this.prestador, required this.ref});

  final Prestador prestador;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final estado = prestador.estado ?? EstadoPrestador.borrador;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Verificar (pendiente/suspendido)
        if (estado == EstadoPrestador.pendiente ||
            estado == EstadoPrestador.suspendido)
          FilledButton.icon(
            icon: const Icon(Icons.verified_outlined),
            label: Text(
              estado == EstadoPrestador.pendiente
                  ? 'Verificar prestador'
                  : 'Re-verificar (reactivar)',
            ),
            onPressed: () => _confirmarVerificar(context, ref, prestador),
          ),

        // Rechazar (pendiente)
        if (estado == EstadoPrestador.pendiente) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.cancel_outlined),
            label: const Text('Rechazar'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red.shade700,
            ),
            onPressed: () => _abrirDialogoRechazar(context, ref, prestador),
          ),
        ],

        // Suspender (verificado)
        if (estado == EstadoPrestador.verificado) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.block_outlined),
            label: const Text('Suspender'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.grey.shade800,
            ),
            onPressed: () => _abrirDialogoSuspender(context, ref, prestador),
          ),
        ],

        // Destacar (verificado)
        if (estado == EstadoPrestador.verificado) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: Icon(
              prestador.destacado ? Icons.star : Icons.star_border,
            ),
            label: Text(
              prestador.destacado
                  ? 'Quitar destacado'
                  : 'Marcar como destacado',
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.amber.shade800,
            ),
            onPressed: () => _toggleDestacado(context, ref, prestador),
          ),
        ],
      ],
    );
  }

  Future<void> _confirmarVerificar(
    BuildContext context,
    WidgetRef ref,
    Prestador prestador,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Verificar prestador'),
        content: Text(
          '¿Verificar "${prestador.nombre}"?\n\n'
          'Será visible públicamente en la app.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Verificar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!context.mounted) return;

    try {
      final repo = ref.read(prestadorRepositoryProvider);
      await repo.adminVerificar(id: prestador.id);
      ref.invalidate(adminPrestadorDetalleProvider(prestador.id));
      ref.invalidate(adminPrestadoresProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Prestador verificado')),
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

  Future<void> _abrirDialogoRechazar(
    BuildContext context,
    WidgetRef ref,
    Prestador prestador,
  ) async {
    final motivo = await _pedirMotivo(
      context,
      titulo: 'Rechazar prestador',
      hint: 'Explicá por qué se rechaza (mínimo 5 caracteres)',
    );

    if (motivo == null || motivo.trim().length < 5) return;
    if (!context.mounted) return;

    try {
      final repo = ref.read(prestadorRepositoryProvider);
      await repo.adminRechazar(id: prestador.id, motivo: motivo.trim());
      ref.invalidate(adminPrestadorDetalleProvider(prestador.id));
      ref.invalidate(adminPrestadoresProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Prestador rechazado')),
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

  Future<void> _abrirDialogoSuspender(
    BuildContext context,
    WidgetRef ref,
    Prestador prestador,
  ) async {
    final motivo = await _pedirMotivo(
      context,
      titulo: 'Suspender prestador',
      hint: 'Explicá por qué se suspende (mínimo 5 caracteres)',
    );

    if (motivo == null || motivo.trim().length < 5) return;
    if (!context.mounted) return;

    try {
      final repo = ref.read(prestadorRepositoryProvider);
      await repo.adminSuspender(id: prestador.id, motivo: motivo.trim());
      ref.invalidate(adminPrestadorDetalleProvider(prestador.id));
      ref.invalidate(adminPrestadoresProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Prestador suspendido')),
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

  Future<void> _toggleDestacado(
    BuildContext context,
    WidgetRef ref,
    Prestador prestador,
  ) async {
    try {
      final repo = ref.read(prestadorRepositoryProvider);
      await repo.adminDestacar(
        id: prestador.id,
        destacado: !prestador.destacado,
      );
      ref.invalidate(adminPrestadorDetalleProvider(prestador.id));
      ref.invalidate(adminPrestadoresProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            prestador.destacado
                ? 'Ya no está destacado'
                : 'Ahora está destacado',
          ),
        ),
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

  Future<String?> _pedirMotivo(
    BuildContext context, {
    required String titulo,
    required String hint,
  }) {
    return showDialog<String>(
      context: context,
      builder: (_) => _MotivoDialog(titulo: titulo, hint: hint),
    );
  }
}

// =========================================================
// Diálogo para pedir motivo (rechazar/suspender)
// =========================================================
class _MotivoDialog extends StatefulWidget {
  const _MotivoDialog({required this.titulo, required this.hint});

  final String titulo;
  final String hint;

  @override
  State<_MotivoDialog> createState() => _MotivoDialogState();
}

class _MotivoDialogState extends State<_MotivoDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _confirmar() {
    final texto = _controller.text.trim();
    if (texto.length < 5) return;
    Navigator.of(context).pop(texto);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.titulo),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLines: 4,
        maxLength: 1000,
        decoration: InputDecoration(
          hintText: widget.hint,
          border: const OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _confirmar,
          child: const Text('Confirmar'),
        ),
      ],
    );
  }
}

// =========================================================
// Error
// =========================================================
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