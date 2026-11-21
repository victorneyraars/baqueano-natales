import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class SelectorNombreServicioScreen extends StatefulWidget {
  const SelectorNombreServicioScreen({super.key, this.nombreInicial});

  final String? nombreInicial;

  @override
  State<SelectorNombreServicioScreen> createState() =>
      _SelectorNombreServicioScreenState();
}

class _SelectorNombreServicioScreenState
    extends State<SelectorNombreServicioScreen> {
  static const List<String> _nombresBase = <String>[
    // Aceite, filtros y fluidos
    'Cambio de aceite y filtro a domicilio',
    'Cambio de aceite de motor',
    'Cambio de filtro de aire / habitáculo / combustible',
    'Revisión y relleno de niveles y fluidos',
    'Purga y cambio de líquido de frenos',
    'Revisión y cambio de refrigerante',
    // Frenos
    'Revisión y cambio de frenos',
    'Cambio de pastillas de freno delanteras',
    'Cambio de pastillas o balatas traseras',
    'Rectificación o cambio de discos / tambores de freno',
    'Regulación de freno de mano / estacionamiento',
    // Eléctrico, carga y diagnóstico
    'Diagnóstico eléctrico / batería',
    'Escáner automotriz y diagnóstico de fallas',
    'Prueba de alternador y sistema de carga',
    'Cambio de batería a domicilio',
    'Revisión y reparación de motor de partida',
    'Revisión de luces, fusibles y relays',
    // Suspensión, dirección y neumáticos
    'Revisión de suspensión y tren delantero',
    'Cambio de amortiguadores y cazoletas',
    'Cambio de terminales, rótulas o bandejas',
    'Rotación e inspección de neumáticos',
    // Motor y mantención general
    'Mantención preventiva',
    'Mantención por kilometraje',
    'Revisión y cambio de correas / tensores',
    'Cambio de bujías y cables / bobinas',
    'Revisión precompra de vehículo',
    'Asistencia y diagnóstico a domicilio',
    // Hogar, instalaciones y reparaciones generales
    'Instalaciones y reparaciones menores',
    'Reparación de cerraduras, bisagras y herrajes',
    'Instalación de luminarias, enchufes o soportes',
    'Gasfitería básica y reparación de fugas',
  ];

  final TextEditingController _busquedaCtrl = TextEditingController();
  final List<String> _nombresPersonalizados = <String>[];
  String _terminoBusqueda = '';
  bool _cargando = true;
  String? _seleccionado;

  @override
  void initState() {
    super.initState();
    final inicial = widget.nombreInicial?.trim();
    _seleccionado = (inicial != null && inicial.isNotEmpty) ? inicial : null;
    _busquedaCtrl.addListener(() {
      setState(() => _terminoBusqueda = _busquedaCtrl.text.trim());
    });
    _cargarPersonalizados();
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

  Future<File> _archivoPersonalizados() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/nombres_servicio_custom.json');
  }

  Future<void> _cargarPersonalizados() async {
    try {
      final file = await _archivoPersonalizados();
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
              _nombresPersonalizados
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

  Future<void> _guardarPersonalizados() async {
    try {
      final file = await _archivoPersonalizados();
      await file.writeAsString(jsonEncode(_nombresPersonalizados));
    } catch (_) {
      // Ignora error de escritura local sin romper el flujo.
    }
  }

  List<String> get _todosLosNombres {
    final vistos = <String>{};
    final resultado = <String>[];
    for (final item in [..._nombresPersonalizados, ..._nombresBase]) {
      final key = _normalizarTexto(item);
      if (vistos.add(key)) {
        resultado.add(item);
      }
    }
    return resultado;
  }

  List<String> get _nombresFiltrados {
    final todos = _todosLosNombres;
    if (_terminoBusqueda.isEmpty) return todos;
    final query = _normalizarTexto(_terminoBusqueda);
    return todos
        .where((item) => _normalizarTexto(item).contains(query))
        .toList();
  }

  bool _esPersonalizado(String nombre) {
    final target = _normalizarTexto(nombre);
    return _nombresPersonalizados.any((p) => _normalizarTexto(p) == target);
  }

  Future<void> _eliminarPersonalizado(String nombre) async {
    final target = _normalizarTexto(nombre);
    setState(() {
      _nombresPersonalizados.removeWhere((p) => _normalizarTexto(p) == target);
      if (_seleccionado != null && _normalizarTexto(_seleccionado!) == target) {
        _seleccionado = null;
      }
    });
    await _guardarPersonalizados();
  }

  Future<void> _mostrarDialogoNombre({String? nombreEditar}) async {
    final esEdicion = nombreEditar != null;
    final ctrl = TextEditingController(
      text: esEdicion
          ? nombreEditar
          : (_terminoBusqueda.length >= 3 ? _terminoBusqueda : ''),
    );
    final formKey = GlobalKey<FormState>();

    final resultado = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          esEdicion
              ? 'Editar nombre de servicio'
              : 'Agregar nombre de servicio',
        ),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: ctrl,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Nombre del servicio',
              hintText: 'Ej: Cambio de pastillas delanteras',
              border: OutlineInputBorder(),
            ),
            validator: (v) {
              final t = v?.trim() ?? '';
              if (t.isEmpty) return 'Ingresa un nombre';
              if (t.length < 3) return 'Mínimo 3 caracteres';
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
      final oldKey = _normalizarTexto(nombreEditar);
      final newKey = _normalizarTexto(resultado);
      final duplicado = _todosLosNombres.any(
        (n) => _normalizarTexto(n) == newKey && _normalizarTexto(n) != oldKey,
      );
      if (duplicado) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ese nombre ya existe en la lista')),
          );
        }
        return;
      }

      setState(() {
        final idx = _nombresPersonalizados.indexWhere(
          (p) => _normalizarTexto(p) == oldKey,
        );
        if (idx != -1) {
          _nombresPersonalizados[idx] = resultado;
        }
        if (_seleccionado != null &&
            _normalizarTexto(_seleccionado!) == oldKey) {
          _seleccionado = resultado;
        }
      });
      await _guardarPersonalizados();
      return;
    }

    final existe = _todosLosNombres.any(
      (n) => _normalizarTexto(n) == _normalizarTexto(resultado),
    );

    if (!existe) {
      setState(() {
        _nombresPersonalizados.insert(0, resultado);
        _seleccionado = resultado;
      });
      await _guardarPersonalizados();
    } else {
      setState(() => _seleccionado = resultado);
    }
  }

  void _confirmarSeleccion() {
    final elegido = _seleccionado?.trim();
    if (elegido == null || elegido.isEmpty) return;
    Navigator.of(context).pop(elegido);
  }

  @override
  Widget build(BuildContext context) {
    final opciones = _nombresFiltrados;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nombres de servicio'),
        actions: [
          TextButton.icon(
            onPressed: _mostrarDialogoNombre,
            icon: const Icon(Icons.add),
            label: const Text('Nuevo'),
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
                hintText: 'Buscar servicio (ej: aceite, frenos, batería)...',
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
                            onPressed: _mostrarDialogoNombre,
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
                      final nombre = opciones[index];
                      final esPersonalizado = _esPersonalizado(nombre);
                      final estaSeleccionado =
                          _seleccionado != null &&
                          _normalizarTexto(_seleccionado!) ==
                              _normalizarTexto(nombre);

                      return GestureDetector(
                        onDoubleTap: () {
                          setState(() => _seleccionado = nombre);
                          _confirmarSeleccion();
                        },
                        child: ListTile(
                          leading: Icon(
                            estaSeleccionado
                                ? Icons.check_circle
                                : (esPersonalizado
                                      ? Icons.bookmark_added_outlined
                                      : Icons.handyman_outlined),
                            color: estaSeleccionado
                                ? theme.colorScheme.primary
                                : null,
                          ),
                          title: Text(
                            nombre,
                            style: estaSeleccionado
                                ? const TextStyle(fontWeight: FontWeight.w600)
                                : null,
                          ),
                          subtitle: Text(
                            esPersonalizado ? 'Agregado por ti' : 'Sugerido',
                          ),
                          selected: estaSeleccionado,
                          trailing: esPersonalizado
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      tooltip: 'Editar nombre',
                                      icon: const Icon(
                                        Icons.edit_outlined,
                                        size: 20,
                                      ),
                                      onPressed: () => _mostrarDialogoNombre(
                                        nombreEditar: nombre,
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Eliminar nombre',
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        size: 20,
                                      ),
                                      onPressed: () =>
                                          _eliminarPersonalizado(nombre),
                                    ),
                                  ],
                                )
                              : null,
                          onTap: () => setState(() => _seleccionado = nombre),
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
                      onPressed: _seleccionado != null
                          ? _confirmarSeleccion
                          : null,
                      icon: const Icon(Icons.check),
                      label: Text(
                        _seleccionado != null
                            ? 'Usar "${_seleccionado!}"'
                            : 'Selecciona un nombre',
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
