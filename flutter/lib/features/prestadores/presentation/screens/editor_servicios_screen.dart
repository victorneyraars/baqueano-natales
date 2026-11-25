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
import 'package:baqueano_natales/features/prestadores/presentation/screens/selector_categoria_servicio_screen.dart';
import 'package:baqueano_natales/features/prestadores/presentation/screens/selector_nombre_servicio_screen.dart';

class EditorServiciosScreen extends ConsumerWidget {
  const EditorServiciosScreen({super.key, required this.prestadorId});

  final String prestadorId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncPrestador = ref.watch(miPrestadorDetalleProvider(prestadorId));

    return Scaffold(
      appBar: AppBar(title: const Text('Servicios y precios')),
      floatingActionButton: asyncPrestador.maybeWhen(
        data: (p) => FloatingActionButton.extended(
          onPressed: () => _abrirFormulario(context, ref, p, null),
          icon: const Icon(Icons.add),
          label: const Text('Agregar'),
        ),
        orElse: () => null,
      ),
      body: asyncPrestador.when(
        data: (prestador) => _Contenido(prestador: prestador, ref: ref),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorState(
          error: e.toString(),
          onRetry: () =>
              ref.invalidate(miPrestadorDetalleProvider(prestadorId)),
        ),
      ),
    );
  }
}

class _Contenido extends StatefulWidget {
  const _Contenido({required this.prestador, required this.ref});

  final Prestador prestador;
  final WidgetRef ref;

  @override
  State<_Contenido> createState() => _ContenidoState();
}

class _ContenidoState extends State<_Contenido> {
  final TextEditingController _filtroCtrl = TextEditingController();
  String _consulta = '';
  String _filtroSeleccionado = 'Todos';

  @override
  void initState() {
    super.initState();
    _filtroCtrl.addListener(() {
      setState(() => _consulta = _filtroCtrl.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _filtroCtrl.dispose();
    super.dispose();
  }

  int get _totalActivos =>
      widget.prestador.servicios.where((s) => s.activo).length;

  int get _totalPausados =>
      widget.prestador.servicios.where((s) => !s.activo).length;

  String get _etiquetaActivos => 'Activos ($_totalActivos)';
  String get _etiquetaPausados => 'Pausados ($_totalPausados)';

  List<String> get _filtrosDisponibles {
    final categorias = <String>{};
    for (final s in widget.prestador.servicios) {
      final cat = s.categoriaServicio?.trim() ?? '';
      if (cat.isNotEmpty) {
        categorias.add(cat);
      }
    }
    return [
      'Todos',
      _etiquetaActivos,
      _etiquetaPausados,
      'Destacados',
      ...categorias,
    ];
  }

  List<PrestadorServicio> get _serviciosFiltrados {
    return widget.prestador.servicios.where((s) {
      if (_filtroSeleccionado.startsWith('Activos (') && !s.activo) {
        return false;
      }
      if (_filtroSeleccionado.startsWith('Pausados (') && s.activo) {
        return false;
      }
      if (_filtroSeleccionado == 'Destacados' && !s.destacado) {
        return false;
      }
      if (_filtroSeleccionado != 'Todos' &&
          !_filtroSeleccionado.startsWith('Activos (') &&
          !_filtroSeleccionado.startsWith('Pausados (') &&
          _filtroSeleccionado != 'Destacados') {
        final cat = (s.categoriaServicio ?? '').trim().toLowerCase();
        if (cat != _filtroSeleccionado.toLowerCase()) {
          return false;
        }
      }
      if (_consulta.isNotEmpty) {
        final nombre = s.nombre.toLowerCase();
        final desc = (s.descripcion ?? '').toLowerCase();
        final cat = (s.categoriaServicio ?? '').toLowerCase();
        if (!nombre.contains(_consulta) &&
            !desc.contains(_consulta) &&
            !cat.contains(_consulta)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final prestador = widget.prestador;
    final ref = widget.ref;

    if (prestador.servicios.isEmpty) {
      return _EmptyState(
        onAgregar: () => _abrirFormulario(context, ref, prestador, null),
      );
    }

    final filtrados = _serviciosFiltrados;
    final filtros = _filtrosDisponibles;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(miPrestadorDetalleProvider(prestador.id));
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 96),
        children: [
          Text(
            '${filtrados.length} de ${prestador.servicios.length} servicio(s) en tu catálogo',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _filtroCtrl,
            decoration: InputDecoration(
              hintText: 'Buscar por nombre, categoría o detalle...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _consulta.isNotEmpty
                  ? IconButton(
                      tooltip: 'Limpiar búsqueda',
                      icon: const Icon(Icons.clear),
                      onPressed: _filtroCtrl.clear,
                    )
                  : null,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: filtros.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (context, index) {
                final filtro = filtros[index];
                final activo = _filtroSeleccionado == filtro;
                return ChoiceChip(
                  label: Text(filtro),
                  selected: activo,
                  visualDensity: VisualDensity.compact,
                  onSelected: (_) =>
                      setState(() => _filtroSeleccionado = filtro),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          if (filtrados.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Column(
                children: [
                  Icon(
                    Icons.filter_list_off,
                    size: 36,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No hay servicios que coincidan con el filtro.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () {
                      _filtroCtrl.clear();
                      setState(() => _filtroSeleccionado = 'Todos');
                    },
                    child: const Text('Limpiar filtros'),
                  ),
                ],
              ),
            )
          else
            for (final srv in filtrados)
              _ServicioCard(
                servicio: srv,
                onEditar: () => _abrirFormulario(context, ref, prestador, srv),
                onDuplicar: () => _abrirFormulario(
                  context,
                  ref,
                  prestador,
                  null,
                  plantillaCopia: srv,
                ),
                onToggleActivo: () =>
                    _alternarActivo(context, ref, prestador, srv),
                onEliminar: () =>
                    _confirmarEliminar(context, ref, prestador, srv),
                onPublicarRedes: () =>
                    _publicarServicioRedes(context, ref, prestador, srv),
              ),
        ],
      ),
    );
  }
}

class _ServicioCard extends StatelessWidget {
  const _ServicioCard({
    required this.servicio,
    required this.onEditar,
    required this.onDuplicar,
    required this.onToggleActivo,
    required this.onEliminar,
    required this.onPublicarRedes,
  });

  final PrestadorServicio servicio;
  final VoidCallback onEditar;
  final VoidCallback onDuplicar;
  final VoidCallback onToggleActivo;
  final VoidCallback onEliminar;
  final VoidCallback onPublicarRedes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Opacity(
      opacity: servicio.activo ? 1.0 : 0.65,
      child: Card(
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
                    icon: const Icon(Icons.copy_outlined, size: 20),
                    onPressed: onDuplicar,
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Duplicar',
                  ),
                  IconButton(
                    icon: Icon(
                      servicio.activo
                          ? Icons.pause_circle_outline
                          : Icons.play_circle_outline,
                      size: 20,
                      color: servicio.activo
                          ? theme.colorScheme.onSurfaceVariant
                          : Colors.orange.shade800,
                    ),
                    onPressed: onToggleActivo,
                    visualDensity: VisualDensity.compact,
                    tooltip: servicio.activo
                        ? 'Pausar servicio'
                        : 'Activar servicio',
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
              if (servicio.categoriaServicio != null || !servicio.activo) ...[
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (servicio.categoriaServicio != null)
                      Chip(
                        label: Text(servicio.categoriaServicio!),
                        visualDensity: VisualDensity.compact,
                        labelStyle: theme.textTheme.labelSmall,
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    if (!servicio.activo)
                      Chip(
                        label: const Text('Pausado'),
                        visualDensity: VisualDensity.compact,
                        labelStyle: theme.textTheme.labelSmall?.copyWith(
                          color: Colors.orange.shade900,
                          fontWeight: FontWeight.w600,
                        ),
                        side: BorderSide(color: Colors.orange.shade300),
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                  ],
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
                    _metaChip(theme, Icons.schedule, servicio.duracionLegible!),
                  if (servicio.garantiaLegible != null)
                    _metaChip(
                      theme,
                      Icons.verified_user_outlined,
                      'Garantía ${servicio.garantiaLegible}',
                      color: Colors.green.shade700,
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onPublicarRedes,
                  icon: const Icon(Icons.campaign_outlined, size: 18),
                  label: const Text('Publicar en redes'),
                ),
              ),
            ],
          ),
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
  PrestadorServicio? servicioExistente, {
  PrestadorServicio? plantillaCopia,
}) async {
  final esEdicion = servicioExistente != null;

  final guardado = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => _FormularioServicioSheet(
      prestadorId: prestador.id,
      servicio: servicioExistente,
      plantillaCopia: plantillaCopia,
      ref: ref,
    ),
  );

  if (guardado == true && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(esEdicion ? 'Servicio actualizado' : 'Servicio agregado'),
      ),
    );
  }
}

Future<void> _alternarActivo(
  BuildContext context,
  WidgetRef ref,
  Prestador prestador,
  PrestadorServicio servicio,
) async {
  final nuevoEstado = !servicio.activo;
  try {
    final repo = ref.read(prestadorRepositoryProvider);
    await repo.editarServicio(
      prestadorId: prestador.id,
      servicioId: servicio.id,
      cambios: {'activo': nuevoEstado},
    );
    ref.invalidate(miPrestadorDetalleProvider(prestador.id));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(nuevoEstado ? 'Servicio activado' : 'Servicio pausado'),
      ),
    );
  } on ApiException catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(e.message), backgroundColor: Colors.red.shade700),
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
    final repo = ref.read(prestadorRepositoryProvider);
    await repo.eliminarServicio(
      prestadorId: prestador.id,
      servicioId: servicio.id,
    );
    ref.invalidate(miPrestadorDetalleProvider(prestador.id));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Servicio eliminado')));
  } on ApiException catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(e.message), backgroundColor: Colors.red.shade700),
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
    this.plantillaCopia,
  });

  final String prestadorId;
  final PrestadorServicio? servicio;
  final PrestadorServicio? plantillaCopia;
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
  bool _activo = true;
  final List<CampoExtraServicio> _camposExtra = [];
  final List<String> _clausulasCustom = [];
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

  List<(String, String)> _clausulasParaCategoria() {
    final cat = _categoriaCtrl.text.trim().toLowerCase();
    if (cat.contains('freno')) {
      return const [
        ('Valor por eje', 'Tarifa referencial por eje (par de ruedas).'),
        (
          'Solo mano de obra',
          'Solo mano de obra; cliente aporta pastillas o se cotizan aparte.',
        ),
        (
          'Limpieza y guías',
          'Incluye limpieza de caliper, lubricación de pasadores y prueba de frenado.',
        ),
        (
          'Sin discos ni EPB',
          'No incluye rectificado/cambio de discos ni freno eléctrico (EPB).',
        ),
      ];
    }
    if (cat.contains('eléctric') || cat.contains('electric')) {
      return const [
        (
          'Valor por visita',
          'Tarifa base por visita y diagnóstico en terreno.',
        ),
        (
          'Multímetro / carga',
          'Incluye medición de batería, carga de alternador y consumo básico.',
        ),
        (
          'Sin repuestos',
          'No incluye repuestos eléctricos; fallas mayores se cotizan aparte.',
        ),
        (
          'Presupuesto previo',
          'Cualquier intervención adicional se informa antes de ejecutar.',
        ),
      ];
    }
    if (cat.contains('suspensi')) {
      return const [
        (
          'Valor por rueda',
          'Tarifa referencial por rueda; según acceso y estado de pernos.',
        ),
        (
          'Solo mano de obra',
          'Solo mano de obra; cliente aporta repuestos o se cotizan aparte.',
        ),
        (
          'Superficie plana',
          'Requiere vehículo en superficie plana, firme y segura.',
        ),
        (
          'Sin elevador',
          'No incluye alineación ni trabajos que requieran elevador de taller.',
        ),
      ];
    }
    if (cat.contains('emergencia')) {
      return const [
        (
          'Valor por visita',
          'Tarifa base de salida y asistencia en terreno en Puerto Natales.',
        ),
        (
          'Diagnóstico rápido',
          'Evaluación en terreno para partida o solución segura.',
        ),
        (
          'Presupuesto previo',
          'Reparaciones adicionales o repuestos se cotizan antes de intervenir.',
        ),
        (
          'Zona segura',
          'Sujeto a condiciones seguras de estacionamiento y clima.',
        ),
      ];
    }
    if (cat.contains('mantenimiento') || cat.contains('motor')) {
      return const [
        (
          'Solo mano de obra',
          'Solo mano de obra; cliente aporta lubricante y filtros.',
        ),
        (
          'Retiro aceite \$5.000',
          'Retiro y disposición responsable de aceite usado opcional por \$5.000 adicionales.',
        ),
        (
          'Estanqueidad y torque',
          'Bandeja de contención, apriete controlado y control final de nivel.',
        ),
        (
          'Sin cubre cárter complejo',
          'No incluye golilla ni desarme de cubre cárter complejo; fallas previas se informan.',
        ),
      ];
    }
    return const [
      (
        'Solo mano de obra',
        'Solo mano de obra; cliente aporta repuestos o se cotizan aparte.',
      ),
      (
        'Presupuesto previo',
        'Se informa cualquier falla adicional antes de intervenir.',
      ),
      (
        'Superficie plana',
        'Requiere vehículo estacionado en superficie plana, segura y accesible.',
      ),
      (
        'Mecánica ligera',
        'Alcance de mecánica ligera; trabajos de elevador se derivan a taller.',
      ),
    ];
  }

  String _plantillaParaCategoria() {
    final cat = _categoriaCtrl.text.trim().toLowerCase();
    if (cat.contains('freno')) {
      return '• Incluye: cambio de pastillas de frenos por eje a domicilio, limpieza de caliper, lubricación de guías y prueba de frenado.\n'
          '• Insumos: solo mano de obra (cliente aporta pastillas o se cotizan aparte).\n'
          '• Condiciones: requiere superficie plana y segura. No incluye rectificado/cambio de discos, purgado completo ni freno eléctrico (EPB).\n'
          '• Garantía: cubre mano de obra ejecutada (no cubre fallas de repuestos aportados por el cliente).';
    }
    if (cat.contains('eléctric') || cat.contains('electric')) {
      return '• Incluye: revisión eléctrica básica a domicilio, prueba de batería, carga de alternador y diagnóstico en terreno.\n'
          '• Insumos: no incluye repuestos eléctricos ni fusibles especiales (se cotizan aparte).\n'
          '• Condiciones: presupuesto previo antes de intervenir; fallas de electrónica compleja se derivan a taller.\n'
          '• Garantía: cubre la mano de obra de la reparación ejecutada.';
    }
    if (cat.contains('suspensi')) {
      return '• Incluye: desmontaje, recambio de componente liviano en terreno y verificación de apriete.\n'
          '• Insumos: solo mano de obra (cliente aporta repuestos o se cotizan aparte).\n'
          '• Condiciones: requiere superficie plana y segura. No incluye alineación ni trabajos de elevador; pernos trabados o fallas previas se informan antes.\n'
          '• Garantía: cubre mano de obra ejecutada (no cubre fallas de repuestos aportados por el cliente).';
    }
    if (cat.contains('emergencia')) {
      return '• Incluye: asistencia mecánica ligera en terreno en Puerto Natales y diagnóstico inicial.\n'
          '• Insumos: repuestos o insumos requeridos se cotizan aparte.\n'
          '• Condiciones: sujeto a ubicación segura y accesible; presupuesto previo antes de reparar.\n'
          '• Garantía: cubre mano de obra ejecutada en la intervención.';
    }
    if (cat.contains('mantenimiento')) {
      return '• Incluye: mantención preventiva a domicilio con bandeja de contención, apriete controlado y verificación final.\n'
          '• Insumos: solo mano de obra (cliente aporta lubricante, filtros o repuestos).\n'
          '• Condiciones: requiere superficie plana y segura; fallas previas o trabajos complejos se informan antes de intervenir.\n'
          '• Garantía: cubre mano de obra y estanqueidad en el trabajo realizado.';
    }
    return '• Incluye: servicio de mecánica ligera a domicilio con protocolo de limpieza y seguridad.\n'
        '• Insumos: solo mano de obra (cliente aporta repuestos o se cotizan aparte).\n'
        '• Condiciones: requiere superficie plana y segura; trabajos de elevador o mecánica mayor se derivan a taller.\n'
        '• Garantía: cubre mano de obra ejecutada (no cubre fallas de repuestos aportados por el cliente).';
  }

  void _aplicarPlantillaDescripcion() {
    final plantilla = _plantillaParaCategoria();
    final actual = _descripcionCtrl.text.trim();
    if (actual.isEmpty) {
      setState(() => _descripcionCtrl.text = plantilla);
      return;
    }
    if (!actual.contains('• Incluye:')) {
      setState(() {
        _descripcionCtrl.text = '$plantilla\n\n$actual';
      });
    }
  }

  void _insertarClausula(String texto) {
    final actual = _descripcionCtrl.text.trim();
    if (actual.contains(texto)) return;
    setState(() {
      _descripcionCtrl.text = actual.isEmpty ? '• $texto' : '$actual\n• $texto';
    });
  }

  static const List<(String, String)> _presetsCamposIndustria = [
    (
      'Modalidad / Unidad',
      'Por servicio (o especificar por eje / rueda / hora)',
    ),
    (
      'Repuestos e insumos',
      'Solo mano de obra; cliente aporta o se cotizan aparte',
    ),
    (
      'Terreno y seguridad',
      'Superficie plana y firme; sujeto a clima y zona segura',
    ),
    (
      'Cobertura y traslado',
      'Radio urbano incluido; sector rural/ripio con recargo',
    ),
    ('Vehículo / Alcance', 'Auto, SUV, camioneta 4x4 o furgón liviano'),
    (
      'Diagnóstico / Espera',
      'Diagnóstico descontable si repara; espera máx. 15 min',
    ),
  ];

  Future<void> _abrirDialogoCampoExtra({
    int? index,
    String? claveInicial,
    String? valorInicial,
  }) async {
    final claveCtrl = TextEditingController(
      text: index != null ? _camposExtra[index].clave : (claveInicial ?? ''),
    );
    final valorCtrl = TextEditingController(
      text: index != null ? _camposExtra[index].valor : (valorInicial ?? ''),
    );

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(index != null ? 'Editar campo' : 'Agregar campo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: claveCtrl,
              decoration: const InputDecoration(
                labelText: 'Nombre del campo *',
                hintText: 'Ej: Unidad de cobro, Repuestos, Zona',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: valorCtrl,
              decoration: const InputDecoration(
                labelText: 'Detalle / Valor *',
                hintText: 'Ej: Por eje (par de ruedas)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              minLines: 1,
              textCapitalization: TextCapitalization.sentences,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (claveCtrl.text.trim().isEmpty ||
                  valorCtrl.text.trim().isEmpty) {
                return;
              }
              Navigator.of(ctx).pop(true);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (ok == true) {
      final nuevo = CampoExtraServicio(
        clave: claveCtrl.text.trim(),
        valor: valorCtrl.text.trim(),
      );
      setState(() {
        if (index != null) {
          _camposExtra[index] = nuevo;
        } else {
          final existente = _camposExtra.indexWhere(
            (c) => c.clave.toLowerCase() == nuevo.clave.toLowerCase(),
          );
          if (existente >= 0) {
            _camposExtra[existente] = nuevo;
          } else {
            _camposExtra.add(nuevo);
          }
        }
      });
    }
    claveCtrl.dispose();
    valorCtrl.dispose();
  }

  Future<void> _abrirDialogoNuevaClausula() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nueva cláusula rápida'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: 'Texto de la cláusula',
            hintText: 'Ej: Incluye escaneo OBD2 básico sin costo adicional.',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
          minLines: 2,
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (ctrl.text.trim().isEmpty) {
                return;
              }
              Navigator.of(ctx).pop(true);
            },
            child: const Text('Insertar'),
          ),
        ],
      ),
    );

    if (ok == true) {
      final texto = ctrl.text.trim();
      setState(() {
        if (!_clausulasCustom.contains(texto)) {
          _clausulasCustom.add(texto);
        }
      });
      _insertarClausula(texto);
    }
    ctrl.dispose();
  }

  @override
  void initState() {
    super.initState();
    final s = widget.servicio ?? widget.plantillaCopia;
    if (s != null) {
      _nombreCtrl.text = widget.servicio != null
          ? s.nombre
          : '${s.nombre} (copia)';
      _descripcionCtrl.text = s.descripcion ?? '';
      _categoriaCtrl.text = s.categoriaServicio ?? '';
      _precioDesdeCtrl.text = s.precioDesdeClp?.toString() ?? '';
      _precioHastaCtrl.text = s.precioHastaClp?.toString() ?? '';
      _duracionCtrl.text = s.duracionEstimadaMin?.toString() ?? '';
      _garantiaCtrl.text = s.garantiaDias?.toString() ?? '';
      _destacado = widget.servicio != null ? s.destacado : false;
      _activo = widget.servicio != null ? s.activo : true;
      _camposExtra.addAll(s.camposExtra);
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
          'activo': _activo,
          'campos_extra': _camposExtra.map((c) => c.toJson()).toList(),
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
          camposExtra: _camposExtra,
        );
      }

      widget.ref.invalidate(miPrestadorDetalleProvider(widget.prestadorId));
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
                      decoration: InputDecoration(
                        labelText: 'Nombre del servicio *',
                        hintText: 'Ej: Cambio de aceite y filtro',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          tooltip: 'Elegir o agregar nombre de servicio',
                          icon: const Icon(
                            Icons.arrow_drop_down_circle_outlined,
                          ),
                          onPressed: () async {
                            final elegido = await Navigator.of(context)
                                .push<String>(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        SelectorNombreServicioScreen(
                                          nombreInicial: _nombreCtrl.text,
                                        ),
                                  ),
                                );
                            if (elegido != null &&
                                elegido.trim().isNotEmpty &&
                                mounted) {
                              setState(() => _nombreCtrl.text = elegido.trim());
                            }
                          },
                        ),
                      ),
                      textInputAction: TextInputAction.next,
                      validator: (v) {
                        final t = v?.trim() ?? '';
                        if (t.isEmpty) return 'Ingresa el nombre';
                        if (t.length < 3) return 'Mínimo 3 caracteres';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _categoriaCtrl,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        labelText: 'Categoría de servicio',
                        hintText: 'Ej: Mantenimiento, Frenos, Motor',
                        border: const OutlineInputBorder(),
                        helperText: 'Ayuda a agrupar servicios similares',
                        suffixIcon: IconButton(
                          tooltip: 'Elegir o agregar categoría de servicio',
                          icon: const Icon(
                            Icons.arrow_drop_down_circle_outlined,
                          ),
                          onPressed: () async {
                            final elegida = await Navigator.of(context)
                                .push<String>(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        SelectorCategoriaServicioScreen(
                                          categoriaInicial: _categoriaCtrl.text,
                                        ),
                                  ),
                                );
                            if (elegida != null &&
                                elegida.trim().isNotEmpty &&
                                mounted) {
                              setState(
                                () => _categoriaCtrl.text = elegida.trim(),
                              );
                            }
                          },
                        ),
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

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Detalle y condiciones estándar',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _aplicarPlantillaDescripcion,
                          icon: const Icon(Icons.auto_fix_high, size: 16),
                          label: const Text('Plantilla pro'),
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    TextFormField(
                      controller: _descripcionCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Descripción',
                        hintText: 'Qué incluye, protocolo, extras y garantía',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                      maxLines: 4,
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        for (final item in _clausulasParaCategoria())
                          ActionChip(
                            label: Text('+ ${item.$1}'),
                            visualDensity: VisualDensity.compact,
                            onPressed: () => _insertarClausula(item.$2),
                          ),
                        for (final custom in _clausulasCustom)
                          ActionChip(
                            label: Text(
                              '+ ${custom.length > 24 ? '${custom.substring(0, 24)}…' : custom}',
                            ),
                            visualDensity: VisualDensity.compact,
                            onPressed: () => _insertarClausula(custom),
                          ),
                        ActionChip(
                          avatar: const Icon(Icons.add, size: 16),
                          label: const Text('Nueva cláusula'),
                          visualDensity: VisualDensity.compact,
                          onPressed: _abrirDialogoNuevaClausula,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextFormField(
                                controller: _precioDesdeCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Precio desde',
                                  hintText: '20000',
                                  border: OutlineInputBorder(),
                                  prefixText: '\$ ',
                                ),
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                textInputAction: TextInputAction.next,
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 4,
                                runSpacing: 4,
                                children: [
                                  for (final monto in [20000, 25000, 35000])
                                    ChoiceChip(
                                      label: Text(
                                        '\$${monto.toString().replaceAllMapped(RegExp(r"\B(?=(\d{3})+(?!\d))"), (m) => ".")}',
                                      ),
                                      selected:
                                          _precioDesdeCtrl.text.trim() ==
                                          '$monto',
                                      visualDensity: VisualDensity.compact,
                                      onSelected: (_) => setState(
                                        () => _precioDesdeCtrl.text = '$monto',
                                      ),
                                    ),
                                ],
                              ),
                            ],
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
                            validator: (v) {
                              final desde = _parseIntOrNull(
                                _precioDesdeCtrl.text,
                              );
                              final hasta = _parseIntOrNull(v ?? '');
                              if (desde != null &&
                                  hasta != null &&
                                  hasta < desde) {
                                return 'Debe ser >= precio desde';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Deja los precios en blanco si prefieres "Consultar"',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),

                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextFormField(
                                controller: _duracionCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Duración',
                                  hintText: '45',
                                  border: OutlineInputBorder(),
                                  suffixText: 'min',
                                ),
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                textInputAction: TextInputAction.next,
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 4,
                                runSpacing: 4,
                                children: [
                                  for (final min in [30, 45, 60])
                                    ChoiceChip(
                                      label: Text('${min}m'),
                                      selected:
                                          _duracionCtrl.text.trim() == '$min',
                                      visualDensity: VisualDensity.compact,
                                      onSelected: (_) => setState(
                                        () => _duracionCtrl.text = '$min',
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextFormField(
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
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 4,
                                runSpacing: 4,
                                children: [
                                  for (final dias in [7, 15, 30, 90])
                                    ChoiceChip(
                                      label: Text('${dias}d'),
                                      selected:
                                          _garantiaCtrl.text.trim() == '$dias',
                                      visualDensity: VisualDensity.compact,
                                      onSelected: (_) => setState(
                                        () => _garantiaCtrl.text = '$dias',
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Detalles técnicos y condiciones',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _abrirDialogoCampoExtra,
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Agregar campo'),
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                        ),
                      ],
                    ),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        for (final preset in _presetsCamposIndustria)
                          ActionChip(
                            label: Text('+ ${preset.$1}'),
                            visualDensity: VisualDensity.compact,
                            onPressed: () => _abrirDialogoCampoExtra(
                              claveInicial: preset.$1,
                              valorInicial: preset.$2,
                            ),
                          ),
                      ],
                    ),
                    if (_camposExtra.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      for (var i = 0; i < _camposExtra.length; i++)
                        Card(
                          margin: const EdgeInsets.only(bottom: 6),
                          elevation: 0,
                          color: theme.colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.45),
                          child: ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 2,
                            ),
                            title: Text(
                              _camposExtra[i].clave,
                              style: theme.textTheme.labelLarge,
                            ),
                            subtitle: Text(_camposExtra[i].valor),
                            onTap: () => _abrirDialogoCampoExtra(index: i),
                            trailing: IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              tooltip: 'Quitar campo',
                              onPressed: () =>
                                  setState(() => _camposExtra.removeAt(i)),
                            ),
                          ),
                        ),
                    ],
                    const SizedBox(height: 12),

                    SwitchListTile(
                      title: const Text('Servicio destacado'),
                      subtitle: const Text(
                        'Márcalo como tu servicio estrella (aparece primero)',
                      ),
                      value: _destacado,
                      onChanged: (v) => setState(() => _destacado = v),
                      contentPadding: EdgeInsets.zero,
                    ),
                    SwitchListTile(
                      title: const Text('Servicio activo'),
                      subtitle: const Text(
                        'Si lo pausas, se conserva en el catálogo sin eliminarlo',
                      ),
                      value: _activo,
                      onChanged: (v) => setState(() => _activo = v),
                      contentPadding: EdgeInsets.zero,
                    ),
                    if (!_esEdicion) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Al agregar el servicio se encolará automáticamente para las redes configuradas si el envío automático está activo.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
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

Future<void> _publicarServicioRedes(
  BuildContext context,
  WidgetRef ref,
  Prestador prestador,
  PrestadorServicio servicio,
) async {
  final confirmar = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Publicar servicio en redes'),
      content: Text(
        '¿Enviar "${servicio.nombre}" a la cola de publicación de la página? '
        'Luego podrás compartirlo manualmente en grupos locales.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Publicar'),
        ),
      ],
    ),
  );
  if (confirmar != true || !context.mounted) return;

  try {
    final res = await ref
        .read(prestadorRepositoryProvider)
        .publicarServicioEnRedes(
          prestadorId: prestador.id,
          servicioId: servicio.id,
        );
    if (!context.mounted) return;
    final encoladas = (res['encoladas'] as num?)?.toInt() ?? 0;
    final detalle = res['detalle'] as String? ?? 'Listo';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          encoladas > 0
              ? '$detalle ($encoladas en cola). Podrás compartirlo en grupos desde la página.'
              : detalle,
        ),
      ),
    );
  } on ApiException catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(e.message)));
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('No se pudo encolar: $e')));
  }
}
