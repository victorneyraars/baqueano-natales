/// Gestión de categorías de comercio (admin).
///
/// Permite:
/// - Listar todas (activas + inactivas)
/// - Crear nueva (FAB)
/// - Editar (tocar card)
/// - Activar/desactivar (switch)
///
/// NOTA: no se permite borrar, solo desactivar (soft-delete).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:baqueano_natales/core/network/api_exceptions.dart';
import 'package:baqueano_natales/features/comercios/data/comercio_providers.dart';
import 'package:baqueano_natales/features/comercios/domain/categoria.dart';

class AdminCategoriasComercioScreen extends ConsumerWidget {
  const AdminCategoriasComercioScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncCats = ref.watch(adminCategoriasProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Categorías de comercio')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirFormulario(context, ref, null),
        icon: const Icon(Icons.add),
        label: const Text('Nueva'),
      ),
      body: asyncCats.when(
        data: (cats) {
          if (cats.isEmpty) return const _EmptyState();
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(adminCategoriasProvider);
              ref.invalidate(categoriasProvider);
            },
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: cats.length,
              itemBuilder: (context, index) {
                final cat = cats[index];
                return _CategoriaCard(
                  categoria: cat,
                  onTap: () => _abrirFormulario(context, ref, cat),
                  onToggleActiva: (activa) =>
                      _toggleActiva(context, ref, cat, activa),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorState(
          error: e.toString(),
          onRetry: () => ref.invalidate(adminCategoriasProvider),
        ),
      ),
    );
  }
}

class _CategoriaCard extends StatelessWidget {
  const _CategoriaCard({
    required this.categoria,
    required this.onTap,
    required this.onToggleActiva,
  });

  final Categoria categoria;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggleActiva;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activa = categoria.activo;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Ícono con color
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color:
                      _hexColor(categoria.colorHex) ??
                      theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _iconoFromName(categoria.icono ?? ''),
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            categoria.nombre,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: activa
                                  ? null
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        if (!activa)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Inactiva',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'slug: ${categoria.slug} · orden: ${categoria.orden}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(value: activa, onChanged: onToggleActiva),
            ],
          ),
        ),
      ),
    );
  }

  static IconData _iconoFromName(String name) {
    switch (name) {
      case 'restaurant':
        return Icons.restaurant;
      case 'local_cafe':
        return Icons.local_cafe;
      case 'bakery_dining':
        return Icons.bakery_dining;
      case 'storefront':
        return Icons.storefront;
      case 'local_pharmacy':
        return Icons.local_pharmacy;
      case 'hardware':
        return Icons.hardware;
      case 'handyman':
        return Icons.handyman;
      case 'spa':
        return Icons.spa;
      case 'category':
      default:
        return Icons.category;
    }
  }

  static Color? _hexColor(String? hex) {
    if (hex == null || !hex.startsWith('#') || hex.length != 7) return null;
    final value = int.tryParse(hex.substring(1), radix: 16);
    if (value == null) return null;
    return Color(0xFF000000 | value);
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

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
              Icons.category_outlined,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text('Sin categorías', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Creá la primera categoría con el botón +',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
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
// Modal bottom sheet — crear/editar
// =========================================================
Future<void> _abrirFormulario(
  BuildContext context,
  WidgetRef ref,
  Categoria? categoriaExistente,
) async {
  final esEdicion = categoriaExistente != null;
  final guardado = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) =>
        _FormularioCategoriaSheet(categoria: categoriaExistente, ref: ref),
  );

  if (guardado == true && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(esEdicion ? 'Categoría actualizada' : 'Categoría creada'),
      ),
    );
  }
}

Future<void> _toggleActiva(
  BuildContext context,
  WidgetRef ref,
  Categoria categoria,
  bool activa,
) async {
  try {
    final repo = ref.read(comercioRepositoryProvider);
    await repo.adminEditarCategoria(
      id: categoria.id,
      cambios: {'activo': activa},
    );
    ref.invalidate(adminCategoriasProvider);
    ref.invalidate(categoriasProvider);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(activa ? 'Categoría activada' : 'Categoría desactivada'),
      ),
    );
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
class _FormularioCategoriaSheet extends StatefulWidget {
  const _FormularioCategoriaSheet({required this.categoria, required this.ref});

  final Categoria? categoria;
  final WidgetRef ref;

  @override
  State<_FormularioCategoriaSheet> createState() =>
      _FormularioCategoriaSheetState();
}

class _FormularioCategoriaSheetState extends State<_FormularioCategoriaSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _slugCtrl = TextEditingController();
  final _descripcionCtrl = TextEditingController();
  final _iconoCtrl = TextEditingController();
  final _colorCtrl = TextEditingController();
  final _ordenCtrl = TextEditingController();

  bool _guardando = false;

  bool get _esEdicion => widget.categoria != null;

  // Íconos predefinidos para elegir
  static const _iconosDisponibles = <String, IconData>{
    'restaurant': Icons.restaurant,
    'local_cafe': Icons.local_cafe,
    'bakery_dining': Icons.bakery_dining,
    'storefront': Icons.storefront,
    'local_pharmacy': Icons.local_pharmacy,
    'hardware': Icons.hardware,
    'handyman': Icons.handyman,
    'spa': Icons.spa,
    'category': Icons.category,
  };

  // Colores predefinidos
  static const _coloresDisponibles = <String>[
    '#E53935',
    '#6D4C41',
    '#FB8C00',
    '#43A047',
    '#00ACC1',
    '#546E7A',
    '#3949AB',
    '#D81B60',
    '#757575',
    '#1976D2',
  ];

  @override
  void initState() {
    super.initState();
    final c = widget.categoria;
    if (c != null) {
      _nombreCtrl.text = c.nombre;
      _slugCtrl.text = c.slug;
      _descripcionCtrl.text = c.descripcion ?? '';
      _iconoCtrl.text = c.icono ?? '';
      _colorCtrl.text = c.colorHex ?? '';
      _ordenCtrl.text = c.orden.toString();
    } else {
      _iconoCtrl.text = 'storefront';
      _colorCtrl.text = '#1976D2';
      _ordenCtrl.text = '0';
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _slugCtrl.dispose();
    _descripcionCtrl.dispose();
    _iconoCtrl.dispose();
    _colorCtrl.dispose();
    _ordenCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();
    setState(() => _guardando = true);

    try {
      final repo = widget.ref.read(comercioRepositoryProvider);

      if (_esEdicion) {
        await repo.adminEditarCategoria(
          id: widget.categoria!.id,
          cambios: {
            'nombre': _nombreCtrl.text.trim(),
            'slug': _slugCtrl.text.trim(),
            'descripcion': _nullable(_descripcionCtrl.text),
            'icono': _nullable(_iconoCtrl.text),
            'color_hex': _nullable(_colorCtrl.text),
            'orden': _parseIntOrNull(_ordenCtrl.text) ?? 0,
          },
        );
      } else {
        await repo.adminCrearCategoria(
          nombre: _nombreCtrl.text.trim(),
          slug: _slugCtrl.text.trim(),
          descripcion: _nullable(_descripcionCtrl.text),
          icono: _nullable(_iconoCtrl.text),
          colorHex: _nullable(_colorCtrl.text),
          orden: _parseIntOrNull(_ordenCtrl.text) ?? 0,
        );
      }

      widget.ref.invalidate(adminCategoriasProvider);
      widget.ref.invalidate(categoriasProvider);
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

  String _slugify(String texto) {
    return texto
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
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
                    _esEdicion ? 'Editar categoría' : 'Nueva categoría',
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
                        labelText: 'Nombre *',
                        hintText: 'Ej: Restaurante',
                        border: OutlineInputBorder(),
                      ),
                      textInputAction: TextInputAction.next,
                      onChanged: (v) {
                        if (!_esEdicion && _slugCtrl.text.isEmpty) {
                          _slugCtrl.text = _slugify(v);
                        }
                      },
                      validator: (v) {
                        final t = v?.trim() ?? '';
                        if (t.isEmpty) return 'Ingresá el nombre';
                        if (t.length < 2) return 'Mínimo 2 caracteres';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _slugCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Slug *',
                        hintText: 'restaurante',
                        border: OutlineInputBorder(),
                        helperText: 'URL-safe, minúsculas y guiones',
                      ),
                      textInputAction: TextInputAction.next,
                      validator: (v) {
                        final t = v?.trim() ?? '';
                        if (t.isEmpty) return 'Ingresá el slug';
                        if (!RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$')
                            .hasMatch(t)) {
                          return 'Solo minúsculas, números y guiones';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _descripcionCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Descripción',
                        hintText: 'Breve descripción de la categoría',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                      maxLines: 2,
                      maxLength: 500,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 8),

                    TextFormField(
                      controller: _ordenCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Orden',
                        hintText: '10',
                        border: OutlineInputBorder(),
                        helperText: 'Menor número = aparece primero',
                      ),
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),

                    // Ícono
                    Text('Ícono', style: theme.textTheme.labelLarge),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _iconosDisponibles.entries
                          .map(
                            (e) => _IconoSelector(
                              nombre: e.key,
                              icono: e.value,
                              seleccionado: _iconoCtrl.text == e.key,
                              onTap: () {
                                setState(() => _iconoCtrl.text = e.key);
                              },
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 16),

                    // Color
                    Text('Color', style: theme.textTheme.labelLarge),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _coloresDisponibles
                          .map(
                            (c) => _ColorSelector(
                              hex: c,
                              seleccionado: _colorCtrl.text == c,
                              onTap: () {
                                setState(() => _colorCtrl.text = c);
                              },
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 16),

                    // Preview
                    Text('Vista previa', style: theme.textTheme.labelLarge),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color:
                                _hexColor(_colorCtrl.text) ??
                                theme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            _iconosDisponibles[_iconoCtrl.text] ??
                                Icons.category,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _nombreCtrl.text.isEmpty
                                ? 'Nombre de categoría'
                                : _nombreCtrl.text,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
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
                      : (_esEdicion ? 'Guardar cambios' : 'Crear categoría'),
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

  static Color? _hexColor(String? hex) {
    if (hex == null || !hex.startsWith('#') || hex.length != 7) return null;
    final value = int.tryParse(hex.substring(1), radix: 16);
    if (value == null) return null;
    return Color(0xFF000000 | value);
  }
}

class _IconoSelector extends StatelessWidget {
  const _IconoSelector({
    required this.nombre,
    required this.icono,
    required this.seleccionado,
    required this.onTap,
  });

  final String nombre;
  final IconData icono;
  final bool seleccionado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: seleccionado
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: seleccionado
                ? theme.colorScheme.primary
                : Colors.transparent,
            width: 2,
          ),
        ),
        child: Icon(
          icono,
          color: seleccionado
              ? theme.colorScheme.onPrimaryContainer
              : theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _ColorSelector extends StatelessWidget {
  const _ColorSelector({
    required this.hex,
    required this.seleccionado,
    required this.onTap,
  });

  final String hex;
  final bool seleccionado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _hexColor(hex) ?? Colors.grey;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: seleccionado
                ? theme.colorScheme.primary
                : Colors.transparent,
            width: 3,
          ),
        ),
        child: seleccionado
            ? const Icon(Icons.check, color: Colors.white)
            : null,
      ),
    );
  }

  static Color? _hexColor(String hex) {
    if (!hex.startsWith('#') || hex.length != 7) return null;
    final value = int.tryParse(hex.substring(1), radix: 16);
    if (value == null) return null;
    return Color(0xFF000000 | value);
  }
}
