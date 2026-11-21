import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class SelectorCategoriaServicioScreen extends StatefulWidget {
  const SelectorCategoriaServicioScreen({super.key, this.categoriaInicial});

  final String? categoriaInicial;

  @override
  State<SelectorCategoriaServicioScreen> createState() =>
      _SelectorCategoriaServicioScreenState();
}

class _SelectorCategoriaServicioScreenState
    extends State<SelectorCategoriaServicioScreen> {
  static const List<String> _categoriasBase = <String>[
    'Mantenimiento',
    'Frenos',
    'Motor',
    'Suspensión',
    'Eléctrico',
    'Emergencias',
    'Instalaciones',
    'Reparaciones',
    'Mecánica a domicilio',
    'Aceites y fluidos',
    'Diagnóstico y escáner',
    'Tren delantero y dirección',
    'Mantención preventiva',
    'Hogar y oficios',
  ];

  final TextEditingController _busquedaCtrl = TextEditingController();
  final List<String> _categoriasPersonalizadas = <String>[];
  String _terminoBusqueda = '';
  bool _cargando = true;
  String? _seleccionada;

  @override
  void initState() {
    super.initState();
    final inicial = widget.categoriaInicial?.trim();
    _seleccionada = (inicial != null && inicial.isNotEmpty) ? inicial : null;
    _busquedaCtrl.addListener(() {
      setState(() => _terminoBusqueda = _busquedaCtrl.text.trim());
    });
    _cargarPersonalizadas();
  }

  @override
  void dispose() {
    _busquedaCtrl.dispose();
    super.dispose();
  }

  String _normalizarTexto(String texto) {
    const reemplazos = {
      'á': 'a',
      'é': 'e',
      'í': 'i',
      'ó': 'o',
      'ú': 'u',
      'ü': 'u',
      'ñ': 'n',
    };
    final lower = texto.toLowerCase().trim();
    final buf = StringBuffer();
    for (final rune in lower.runes) {
      final ch = String.fromCharCode(rune);
      buf.write(reemplazos[ch] ?? ch);
    }
    return buf.toString();
  }

  Future<File> _archivoPersonalizadas() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/categorias_servicio_custom.json');
  }

  Future<void> _cargarPersonalizadas() async {
    try {
      final file = await _archivoPersonalizadas();
      if (file.existsSync()) {
        final raw = await file.readAsString();
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          final items = decoded
              .whereType<String>()
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList();
          if (mounted) {
            setState(() {
              _categoriasPersonalizadas
                ..clear()
                ..addAll(items);
            });
          }
        }
      }
    } catch (_) {
      // Si no existe o hay error de lectura, se mantiene la lista base.
    } finally {
      if (mounted) {
        setState(() => _cargando = false);
      }
    }
  }

  Future<void> _guardarPersonalizadas() async {
    try {
      final file = await _archivoPersonalizadas();
      await file.writeAsString(jsonEncode(_categoriasPersonalizadas));
    } catch (_) {
      // Ignora error de escritura local sin romper el flujo.
    }
  }

  List<String> get _todasLasCategorias {
    final vistos = <String>{};
    final resultado = <String>[];
    for (final item in [..._categoriasPersonalizadas, ..._categoriasBase]) {
      final key = _normalizarTexto(item);
      if (vistos.add(key)) {
        resultado.add(item);
      }
    }
    return resultado;
  }

  List<String> get _categoriasFiltradas {
    final todas = _todasLasCategorias;
    if (_terminoBusqueda.isEmpty) return todas;
    final query = _normalizarTexto(_terminoBusqueda);
    return todas
        .where((item) => _normalizarTexto(item).contains(query))
        .toList();
  }

  bool _esPersonalizada(String categoria) {
    final target = _normalizarTexto(categoria);
    return _categoriasPersonalizadas.any((p) => _normalizarTexto(p) == target);
  }

  Future<void> _eliminarPersonalizada(String categoria) async {
    final target = _normalizarTexto(categoria);
    setState(() {
      _categoriasPersonalizadas.removeWhere(
        (p) => _normalizarTexto(p) == target,
      );
      if (_seleccionada != null && _normalizarTexto(_seleccionada!) == target) {
        _seleccionada = null;
      }
    });
    await _guardarPersonalizadas();
  }

  Future<void> _mostrarDialogoCategoria({String? categoriaEditar}) async {
    final esEdicion = categoriaEditar != null;
    final ctrl = TextEditingController(
      text: esEdicion
          ? categoriaEditar
          : (_terminoBusqueda.length >= 2 ? _terminoBusqueda : ''),
    );
    final formKey = GlobalKey<FormState>();

    final resultado = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          esEdicion
              ? 'Editar categoría de servicio'
              : 'Agregar categoría de servicio',
        ),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: ctrl,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Categoría de servicio',
              hintText: 'Ej: Mecánica a domicilio',
              border: OutlineInputBorder(),
            ),
            validator: (v) {
              final t = v?.trim() ?? '';
              if (t.isEmpty) return 'Ingresa una categoría';
              if (t.length < 2) return 'Mínimo 2 caracteres';
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.of(ctx).pop(ctrl.text.trim());
              }
            },
            child: Text(esEdicion ? 'Guardar cambios' : 'Guardar en lista'),
          ),
        ],
      ),
    );

    ctrl.dispose();

    if (resultado == null || resultado.isEmpty) return;

    if (esEdicion) {
      final oldKey = _normalizarTexto(categoriaEditar);
      final newKey = _normalizarTexto(resultado);
      final duplicado = _todasLasCategorias.any(
        (c) => _normalizarTexto(c) == newKey && _normalizarTexto(c) != oldKey,
      );
      if (duplicado) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Esa categoría ya existe en la lista'),
            ),
          );
        }
        return;
      }

      setState(() {
        final idx = _categoriasPersonalizadas.indexWhere(
          (p) => _normalizarTexto(p) == oldKey,
        );
        if (idx != -1) {
          _categoriasPersonalizadas[idx] = resultado;
        }
        if (_seleccionada != null &&
            _normalizarTexto(_seleccionada!) == oldKey) {
          _seleccionada = resultado;
        }
      });
      await _guardarPersonalizadas();
      return;
    }

    final existe = _todasLasCategorias.any(
      (c) => _normalizarTexto(c) == _normalizarTexto(resultado),
    );

    if (!existe) {
      setState(() {
        _categoriasPersonalizadas.insert(0, resultado);
        _seleccionada = resultado;
      });
      await _guardarPersonalizadas();
    } else {
      setState(() => _seleccionada = resultado);
    }
  }

  void _confirmarSeleccion() {
    final elegida = _seleccionada?.trim();
    if (elegida == null || elegida.isEmpty) return;
    Navigator.of(context).pop(elegida);
  }

  @override
  Widget build(BuildContext context) {
    final opciones = _categoriasFiltradas;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Categorías de servicio'),
        actions: [
          TextButton.icon(
            onPressed: _mostrarDialogoCategoria,
            icon: const Icon(Icons.add),
            label: const Text('Nueva'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
            child: TextField(
              controller: _busquedaCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Buscar categoría (ej: frenos, mantenimiento, domicilio)...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _terminoBusqueda.isNotEmpty
                    ? IconButton(
                        tooltip: 'Limpiar búsqueda',
                        icon: const Icon(Icons.clear),
                        onPressed: _busquedaCtrl.clear,
                      )
                    : null,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 14,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Toca para marcar o doble toque para elegir al instante.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _cargando
                ? const Center(child: CircularProgressIndicator())
                : opciones.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.search_off,
                            size: 40,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'No encontramos coincidencias para "$_terminoBusqueda"',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: _mostrarDialogoCategoria,
                            icon: const Icon(Icons.add),
                            label: const Text('Agregar a la lista'),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                    itemCount: opciones.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final categoria = opciones[index];
                      final esPersonalizada = _esPersonalizada(categoria);
                      final estaSeleccionada =
                          _seleccionada != null &&
                          _normalizarTexto(_seleccionada!) ==
                              _normalizarTexto(categoria);

                      return GestureDetector(
                        onDoubleTap: () {
                          setState(() => _seleccionada = categoria);
                          _confirmarSeleccion();
                        },
                        child: ListTile(
                          leading: Icon(
                            estaSeleccionada
                                ? Icons.check_circle
                                : (esPersonalizada
                                      ? Icons.bookmark_added_outlined
                                      : Icons.category_outlined),
                            color: estaSeleccionada
                                ? theme.colorScheme.primary
                                : null,
                          ),
                          title: Text(
                            categoria,
                            style: estaSeleccionada
                                ? const TextStyle(fontWeight: FontWeight.w600)
                                : null,
                          ),
                          subtitle: Text(
                            esPersonalizada ? 'Agregada por ti' : 'Sugerida',
                          ),
                          selected: estaSeleccionada,
                          trailing: esPersonalizada
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      tooltip: 'Editar categoría',
                                      icon: const Icon(
                                        Icons.edit_outlined,
                                        size: 20,
                                      ),
                                      onPressed: () => _mostrarDialogoCategoria(
                                        categoriaEditar: categoria,
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Eliminar categoría',
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        size: 20,
                                      ),
                                      onPressed: () =>
                                          _eliminarPersonalizada(categoria),
                                    ),
                                  ],
                                )
                              : null,
                          onTap: () =>
                              setState(() => _seleccionada = categoria),
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: Border(top: BorderSide(color: theme.dividerColor)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _seleccionada != null
                          ? _confirmarSeleccion
                          : null,
                      icon: const Icon(Icons.check),
                      label: Text(
                        _seleccionada != null
                            ? 'Usar "${_seleccionada!}"'
                            : 'Selecciona una categoría',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
