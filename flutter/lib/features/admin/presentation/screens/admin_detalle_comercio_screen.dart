/// Detalle de comercio para admin.
///
/// Acciones según estado:
/// - `pendiente`    → Verificar / Rechazar
/// - `verificado`   → Suspender / Destacar
/// - `suspendido`   → Re-verificar
/// - `rechazado`    → Re-verificar (si el dueño corrigió)
///
/// Muestra:
/// - Datos completos del comercio (incluye contacto interno)
/// - Horarios
/// - Galería (si aplica)
/// - Motivo de rechazo/suspensión si aplica
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:baqueano_natales/core/network/api_exceptions.dart';
import 'package:baqueano_natales/features/comercios/data/comercio_providers.dart';
import 'package:baqueano_natales/features/comercios/domain/comercio.dart';
import 'package:baqueano_natales/features/comercios/domain/horario.dart';

class AdminDetalleComercioScreen extends ConsumerWidget {
  const AdminDetalleComercioScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncComercio = ref.watch(adminComercioDetalleProvider(id));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle comercio'),
      ),
      body: asyncComercio.when(
        data: (comercio) => _Contenido(comercio: comercio, ref: ref),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorState(
          error: e.toString(),
          onRetry: () => ref.invalidate(adminComercioDetalleProvider(id)),
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

        // --- Acciones ---
        _AccionesAdmin(comercio: comercio, ref: ref),

        const SizedBox(height: 24),

        // --- Información ---
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
        _fila(
          theme,
          'Acepta delivery',
          comercio.aceptaDelivery ? 'Sí' : 'No',
        ),
        _fila(
          theme,
          'Acepta retiro',
          comercio.aceptaRetiro ? 'Sí' : 'No',
        ),
        if (comercio.aceptaDelivery) ...[
          _fila(theme, 'Costo de envío', '\$${comercio.costoEnvioClp}'),
          _fila(theme, 'Pedido mínimo', '\$${comercio.pedidoMinimoClp}'),
          if (comercio.radioEntregaKm != null)
            _fila(
              theme,
              'Radio de entrega',
              '${comercio.radioEntregaKm} km',
            ),
          if (comercio.tiempoPreparacionMin != null)
            _fila(
              theme,
              'Tiempo de preparación',
              '${comercio.tiempoPreparacionMin} min',
            ),
        ],

        const SizedBox(height: 16),

        // --- Horarios ---
        _Seccion(
          titulo: 'Horarios (${comercio.horarios.length})',
          theme: theme,
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

        // --- Metadata ---
        _Seccion(titulo: 'Metadata', theme: theme),
        _fila(theme, 'ID', comercio.id),
        _fila(theme, 'Propietario ID', comercio.propietarioId),
        if (comercio.verificadoEn != null)
          _fila(
            theme,
            'Verificado en',
            comercio.verificadoEn!.toLocal().toString().split('.').first,
          ),
        if (comercio.createdAt != null)
          _fila(
            theme,
            'Creado',
            comercio.createdAt!.toLocal().toString().split('.').first,
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

// =========================================================
// Card de estado
// =========================================================
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
            if (comercio.motivoRechazo != null &&
                (estado == EstadoComercio.rechazado ||
                    estado == EstadoComercio.suspendido)) ...[
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
                      estado == EstadoComercio.rechazado
                          ? 'Motivo del rechazo'
                          : 'Motivo de la suspensión',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: color,
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
        return (
          Colors.red.shade800,
          Colors.red.shade50,
          Icons.cancel_outlined,
        );
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
}

// =========================================================
// Acciones admin
// =========================================================
class _AccionesAdmin extends StatelessWidget {
  const _AccionesAdmin({required this.comercio, required this.ref});

  final Comercio comercio;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final estado = comercio.estado ?? EstadoComercio.borrador;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Verificar
        if (estado == EstadoComercio.pendiente ||
            estado == EstadoComercio.suspendido)
          FilledButton.icon(
            icon: const Icon(Icons.verified_outlined),
            label: Text(
              estado == EstadoComercio.pendiente
                  ? 'Verificar comercio'
                  : 'Re-verificar (reactivar)',
            ),
            onPressed: () => _confirmarVerificar(context, ref, comercio),
          ),

        // Rechazar (pendiente)
        if (estado == EstadoComercio.pendiente) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.cancel_outlined),
            label: const Text('Rechazar'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red.shade700,
            ),
            onPressed: () => _abrirDialogoRechazar(context, ref, comercio),
          ),
        ],

        // Suspender (verificado)
        if (estado == EstadoComercio.verificado) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.block_outlined),
            label: const Text('Suspender'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.grey.shade800,
            ),
            onPressed: () => _abrirDialogoSuspender(context, ref, comercio),
          ),
        ],

        // Destacar (verificado)
        if (estado == EstadoComercio.verificado) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: Icon(
              comercio.destacado ? Icons.star : Icons.star_border,
            ),
            label: Text(
              comercio.destacado
                  ? 'Quitar destacado'
                  : 'Marcar como destacado',
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.amber.shade800,
            ),
            onPressed: () => _toggleDestacado(context, ref, comercio),
          ),
        ],
      ],
    );
  }

  Future<void> _confirmarVerificar(
    BuildContext context,
    WidgetRef ref,
    Comercio comercio,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Verificar comercio'),
        content: Text(
          '¿Verificar "${comercio.nombre}"?\n\n'
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
      final repo = ref.read(comercioRepositoryProvider);
      await repo.adminVerificar(id: comercio.id);
      ref.invalidate(adminComercioDetalleProvider(comercio.id));
      ref.invalidate(adminComerciosProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Comercio verificado')),
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
    Comercio comercio,
  ) async {
    final motivo = await _pedirMotivo(
      context,
      titulo: 'Rechazar comercio',
      hint: 'Explicá por qué se rechaza (mínimo 5 caracteres)',
    );

    if (motivo == null || motivo.trim().length < 5) return;
    if (!context.mounted) return;

    try {
      final repo = ref.read(comercioRepositoryProvider);
      await repo.adminRechazar(id: comercio.id, motivo: motivo.trim());
      ref.invalidate(adminComercioDetalleProvider(comercio.id));
      ref.invalidate(adminComerciosProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Comercio rechazado')),
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
    Comercio comercio,
  ) async {
    final motivo = await _pedirMotivo(
      context,
      titulo: 'Suspender comercio',
      hint: 'Explicá por qué se suspende (mínimo 5 caracteres)',
    );

    if (motivo == null || motivo.trim().length < 5) return;
    if (!context.mounted) return;

    try {
      final repo = ref.read(comercioRepositoryProvider);
      await repo.adminSuspender(id: comercio.id, motivo: motivo.trim());
      ref.invalidate(adminComercioDetalleProvider(comercio.id));
      ref.invalidate(adminComerciosProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Comercio suspendido')),
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
    Comercio comercio,
  ) async {
    try {
      final repo = ref.read(comercioRepositoryProvider);
      await repo.adminDestacar(
        id: comercio.id,
        destacado: !comercio.destacado,
      );
      ref.invalidate(adminComercioDetalleProvider(comercio.id));
      ref.invalidate(adminComerciosProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            comercio.destacado
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