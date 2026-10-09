/// Editor del catálogo de servicios de un prestador (dueño).
///
/// Permite:
/// - Ver el listado de servicios (con precios, duración, garantía).
/// - Agregar un servicio nuevo (modal bottom sheet).
/// - Editar un servicio existente.
/// - Eliminar un servicio.
///
/// Categorías de servicio: strings libres (Mantenimiento, Frenos, Motor...)
/// que se agrupan visualmente en el detalle público.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:baqueano_natales/core/network/api_exceptions.dart';
import 'package:baqueano_natales/features/prestadores/data/prestador_providers.dart';
import 'package:baqueano_natales/features/prestadores/domain/prestador.dart';
import 'package:baqueano_natales/features/prestadores/domain/prestador_servicio.dart';

class EditorServiciosScreen extends ConsumerWidget {
  const EditorServiciosScreen({super.key, required this.prestadorId});

  final String prestadorId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncPrestador = ref.watch(miPrestadorDetalleProvider(prestadorId));

    return Scaffold(
      appBar: AppBar(title: const Text('Servicios')),
      floatingActionButton: asyncPrestador.maybeWhen(
        data: (p) => FloatingActionButton.extended(
          onPressed: () => _abrirFormulario(context, ref, p, null),
          icon: const Icon(Icons.add),
          label: const Text('Agregar'),
        ),
        orElse: () => null,
      ),
      body: asyncPrestador.when(
        data: (prestador) => _Contenido(
          prestador: prestador,
          ref: ref,
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorState(
          error: e.toString(),
          onRetry: () => ref.invalidate(miPrestadorDetalleProvider(prestadorId)),
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

    if (prestador.servicios.isEmpty) {
      return _EmptyState(
        onAgregar: () => _abrirFormulario(context, ref, prestador, null),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(miPrestadorDetalleProvider(prestador.id));
      },
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        itemCount: prestador.servicios.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                '${prestador.servicios.length} servicio(s) en tu catálogo',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            );
          }
          final srv = prestador.servicios[index - 1];
          return _ServicioCard(
            servicio: srv,
            onEditar: () =>
                _abrirFormulario(context, ref, prestador, srv),
            onEliminar: () => _confirmarEliminar(context, ref, prestador, srv),
          );
        },
      ),
    );
  }
}

class _ServicioCard extends StatelessWidget {
  const _ServicioCard({
    required this.servicio,
    required this.onEditar,
    required this.onEliminar,
  });

  final PrestadorServicio servicio;
  final VoidCallback onEditar;
  final VoidCallback onEliminar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          servicio.nombre,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (servicio.destacado) ...[
                        const SizedBox(width: 6),
                        Icon(
                          Icons.local_fire_department,
                          size: 18,
                          color: Colors.orange.shade700,
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  onPressed: onEditar,
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Editar',
                ),
                IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    size: 20,
                    color: Colors.red.shade700,
                  ),
                  onPressed: onEliminar,
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Eliminar',
                ),
              ],
            ),
            if (servicio.categoriaServicio != null) ...[
              const SizedBox(height: 4),
              Chip(
                label: Text(servicio.categoriaServicio!),
                visualDensity: VisualDensity.compact,
                labelStyle: theme.textTheme.labelSmall,
                padding: EdgeInsets.zero,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ],
            if (servicio.descripcion != null &&
                servicio.descripcion!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                servicio.descripcion!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                _metaChip(
                  theme,
                  Icons.attach_money,
                  servicio.precioLegible,
                  bold: true,
                ),
                if (servicio.duracionLegible != null)
                  _metaChip(
                    theme,
                    Icons.schedule,
                    servicio.duracionLegible!,
                  ),
                if (servicio.garantiaLegible != null)
                  _metaChip(
                    theme,
                    Icons.verified_user_outlined,
                    'Garantía ${servicio.garantiaLegible}',
                    color: Colors.green.shade700,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _metaChip(
    ThemeData theme,
    IconData icon,
    String label, {
    bool bold = false,
    Color? color,
  }) {
    final fg = color ?? theme.colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: fg),
        const SizedBox(width: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: fg,
            fontWeight: bold ? FontWeight.bold : null,
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAgregar});

  final VoidCallback onAgregar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.list_alt_outlined,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'Sin servicios en tu catálogo',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Agregá los servicios que ofrecés con precios orientativos '
              'para que los clientes te encuentren.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onAgregar,
              icon: const Icon(Icons.add),
              label: const Text('Agregar primer servicio'),
            ),
          ],
        ),
      ),
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

// =========================================================
// Modal Bottom Sheet — Crear / editar servicio
// =========================================================
Future<void> _abrirFormulario(
  BuildContext context,
  WidgetRef ref,
  Prestador prestador,
  PrestadorServicio? servicioExistente,
) async {
  final esEdicion = servicioExistente != null;

  final guardado = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => _FormularioServicioSheet(
      prestadorId: prestador.id,
      servicio: servicioExistente,
      ref: ref,
    ),
  );

  if (guardado == true && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          esEdicion ? 'Servicio actualizado' : 'Servicio agregado',
        ),
      ),
    );
  }
}

Future<void> _confirmarEliminar(
  BuildContext context,
  WidgetRef ref,
  Prestador prestador,
  PrestadorServicio servicio,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Eliminar servicio'),
      content: Text('¿Eliminar "${servicio.nombre}"?'),
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
    await repo.eliminarServicio(
      prestadorId: prestador.id,
      servicioId: servicio.id,
    );
    ref.invalidate(miPrestadorDetalleProvider(prestador.id));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Servicio eliminado')),
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

// =========================================================
// Sheet con el formulario
// =========================================================
class _FormularioServicioSheet extends StatefulWidget {
  const _FormularioServicioSheet({
    required this.prestadorId,
    required this.servicio,
    required this.ref,
  });

  final String prestadorId;
  final PrestadorServicio? servicio;
  final WidgetRef ref;

  @override
  State<_FormularioServicioSheet> createState() =>
      _FormularioServicioSheetState();
}

class _FormularioServicioSheetState extends State<_FormularioServicioSheet> {
  final _formKey = GlobalKey<FormState>();

  final _nombreCtrl = TextEditingController();
  final _descripcionCtrl = TextEditingController();
  final _categoriaCtrl = TextEditingController();
  final _precioDesdeCtrl = TextEditingController();
  final _precioHastaCtrl = TextEditingController();
  final _duracionCtrl = TextEditingController();
  final _garantiaCtrl = TextEditingController();

  bool _destacado = false;
  bool _guardando = false;

  bool get _esEdicion => widget.servicio != null;

  static const _categoriasSugeridas = <String>[
    'Mantenimiento',
    'Frenos',
    'Motor',
    'Suspensión',
    'Eléctrico',
    'Emergencias',
    'Instalaciones',
    'Reparaciones',
  ];

  @override
  void initState() {
    super.initState();
    final s = widget.servicio;
    if (s != null) {
      _nombreCtrl.text = s.nombre;
      _descripcionCtrl.text = s.descripcion ?? '';
      _categoriaCtrl.text = s.categoriaServicio ?? '';
      _precioDesdeCtrl.text = s.precioDesdeClp?.toString() ?? '';
      _precioHastaCtrl.text = s.precioHastaClp?.toString() ?? '';
      _duracionCtrl.text = s.duracionEstimadaMin?.toString() ?? '';
      _garantiaCtrl.text = s.garantiaDias?.toString() ?? '';
      _destacado = s.destacado;
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _descripcionCtrl.dispose();
    _categoriaCtrl.dispose();
    _precioDesdeCtrl.dispose();
    _precioHastaCtrl.dispose();
    _duracionCtrl.dispose();
    _garantiaCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();
    setState(() => _guardando = true);

    try {
      final repo = widget.ref.read(prestadorRepositoryProvider);

      final desde = _parseIntOrNull(_precioDesdeCtrl.text);
      final hasta = _parseIntOrNull(_precioHastaCtrl.text);

      if (_esEdicion) {
        final cambios = <String, dynamic>{
          'nombre': _nombreCtrl.text.trim(),
          'descripcion': _nullable(_descripcionCtrl.text),
          'categoria_servicio': _nullable(_categoriaCtrl.text),
          'precio_desde_clp': desde,
          'precio_hasta_clp': hasta,
          'duracion_estimada_min': _parseIntOrNull(_duracionCtrl.text),
          'garantia_dias': _parseIntOrNull(_garantiaCtrl.text),
          'destacado': _destacado,
        };
        await repo.editarServicio(
          prestadorId: widget.prestadorId,
          servicioId: widget.servicio!.id,
          cambios: cambios,
        );
      } else {
        await repo.agregarServicio(
          prestadorId: widget.prestadorId,
          nombre: _nombreCtrl.text.trim(),
          descripcion: _nullable(_descripcionCtrl.text),
          categoriaServicio: _nullable(_categoriaCtrl.text),
          precioDesdeClp: desde,
          precioHastaClp: hasta,
          duracionEstimadaMin: _parseIntOrNull(_duracionCtrl.text),
          garantiaDias: _parseIntOrNull(_garantiaCtrl.text),
          destacado: _destacado,
        );
      }

      widget.ref
          .invalidate(miPrestadorDetalleProvider(widget.prestadorId));
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  String? _nullable(String s) {
    final t = s.trim();
    return t.isEmpty ? null : t;
  }

  int? _parseIntOrNull(String s) {
    final t = s.trim();
    if (t.isEmpty) return null;
    return int.tryParse(t);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (ctx, scrollController) => Column(
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.4,
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(
                    _esEdicion ? 'Editar servicio' : 'Nuevo servicio',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  children: [
                    TextFormField(
                      controller: _nombreCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nombre del servicio *',
                        hintText: 'Ej: Cambio de aceite y filtro',
                        border: OutlineInputBorder(),
                      ),
                      textInputAction: TextInputAction.next,
                      validator: (v) {
                        final t = v?.trim() ?? '';
                        if (t.isEmpty) return 'Ingresá el nombre';
                        if (t.length < 3) return 'Mínimo 3 caracteres';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _categoriaCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Categoría de servicio',
                        hintText: 'Ej: Mantenimiento, Frenos, Motor',
                        border: OutlineInputBorder(),
                        helperText: 'Ayuda a agrupar servicios similares',
                      ),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 8),

                    // Sugerencias de categoría
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: _categoriasSugeridas
                          .map(
                            (c) => ActionChip(
                              label: Text(c),
                              visualDensity: VisualDensity.compact,
                              onPressed: () {
                                setState(() => _categoriaCtrl.text = c);
                              },
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _descripcionCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Descripción',
                        hintText: 'Qué incluye, detalles',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _precioDesdeCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Precio desde',
                              hintText: '0',
                              border: OutlineInputBorder(),
                              prefixText: '\$ ',
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            textInputAction: TextInputAction.next,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: _precioHastaCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Precio hasta',
                              hintText: '0',
                              border: OutlineInputBorder(),
                              prefixText: '\$ ',
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            textInputAction: TextInputAction.next,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Dejá los precios en blanco si preferís "Consultar"',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _duracionCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Duración',
                              hintText: '30',
                              border: OutlineInputBorder(),
                              suffixText: 'min',
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            textInputAction: TextInputAction.next,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: _garantiaCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Garantía',
                              hintText: '30',
                              border: OutlineInputBorder(),
                              suffixText: 'días',
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    SwitchListTile(
                      title: const Text('Servicio destacado'),
                      subtitle: const Text(
                        'Marcalo como tu servicio estrella (aparece primero)',
                      ),
                      value: _destacado,
                      onChanged: (v) => setState(() => _destacado = v),
                      contentPadding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton.icon(
                icon: _guardando
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(_esEdicion ? Icons.save : Icons.add),
                label: Text(
                  _guardando
                      ? 'Guardando...'
                      : (_esEdicion ? 'Guardar cambios' : 'Agregar servicio'),
                ),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: _guardando ? null : _guardar,
              ),
            ),
          ],
        ),
      ),
    );
  }
}