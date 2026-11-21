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
    'Cambio de aceite y filtro a domicilio',
    'Revisión y cambio de frenos',
    'Diagnóstico eléctrico / batería',
    'Mantención preventiva',
    'Revisión de suspensión y tren delantero',
  ];

  final List<String> _nombresPersonalizados = <String>[];
  bool _cargando = true;
  late String? _seleccionado;

  @override
  void initState() {
    super.initState();
    final inicial = widget.nombreInicial?.trim();
    _seleccionado = (inicial != null && inicial.isNotEmpty) ? inicial : null;
    _cargarPersonalizados();
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
      final key = item.toLowerCase();
      if (vistos.add(key)) {
        resultado.add(item);
      }
    }
    return resultado;
  }

  Future<void> _mostrarDialogoAgregarNombre() async {
    final ctrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final nuevoNombre = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Agregar nombre de servicio'),
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
            child: const Text('Guardar en lista'),
          ),
        ],
      ),
    );

    ctrl.dispose();

    if (nuevoNombre == null || nuevoNombre.isEmpty) return;

    final existe = _todosLosNombres.any(
      (n) => n.toLowerCase() == nuevoNombre.toLowerCase(),
    );

    if (!existe) {
      setState(() {
        _nombresPersonalizados.insert(0, nuevoNombre);
        _seleccionado = nuevoNombre;
      });
      await _guardarPersonalizados();
    } else {
      setState(() => _seleccionado = nuevoNombre);
    }

    if (mounted) {
      Navigator.of(context).pop(nuevoNombre);
    }
  }

  @override
  Widget build(BuildContext context) {
    final opciones = _todosLosNombres;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nombres de servicio'),
        actions: [
          TextButton.icon(
            onPressed: _mostrarDialogoAgregarNombre,
            icon: const Icon(Icons.add),
            label: const Text('Agregar'),
          ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: opciones.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final nombre = opciones[index];
                final esPersonalizado = _nombresPersonalizados.any(
                  (p) => p.toLowerCase() == nombre.toLowerCase(),
                );
                final estaSeleccionado =
                    _seleccionado?.toLowerCase() == nombre.toLowerCase();

                return ListTile(
                  leading: Icon(
                    estaSeleccionado
                        ? Icons.check_circle
                        : (esPersonalizado
                              ? Icons.bookmark_added_outlined
                              : Icons.handyman_outlined),
                  ),
                  title: Text(nombre),
                  subtitle: esPersonalizado
                      ? const Text('Agregado por ti')
                      : const Text('Sugerido'),
                  selected: estaSeleccionado,
                  onTap: () => Navigator.of(context).pop(nombre),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _mostrarDialogoAgregarNombre,
        icon: const Icon(Icons.add),
        label: const Text('Agregar nombre'),
      ),
    );
  }
}
