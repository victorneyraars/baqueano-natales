/// Pantalla cliente: crear o editar un vehiculo.
///
/// Modo crear: si `objetoId` es null.
/// Modo editar: si `objetoId` viene del path (carga el vehiculo existente).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:baqueano_natales/core/network/api_exceptions.dart';
import 'package:baqueano_natales/features/oficios/data/oficios_providers.dart';
import 'package:baqueano_natales/features/oficios/domain/vehiculo.dart';
import 'package:baqueano_natales/features/oficios/presentation/widgets/patente_auto_formatter.dart';

class FormularioVehiculoScreen extends ConsumerStatefulWidget {
  const FormularioVehiculoScreen({super.key, this.objetoId});

  /// Si viene, es edicion. Si no, es creacion.
  final String? objetoId;

  @override
  ConsumerState<FormularioVehiculoScreen> createState() =>
      _FormularioVehiculoScreenState();
}

class _FormularioVehiculoScreenState
    extends ConsumerState<FormularioVehiculoScreen> {
  final _formKey = GlobalKey<FormState>();

  final _patenteCtrl = TextEditingController();
  final _marcaCtrl = TextEditingController();
  final _modeloCtrl = TextEditingController();
  final _anioCtrl = TextEditingController();
  final _colorCtrl = TextEditingController();
  final _kmCtrl = TextEditingController();
  final _aliasCtrl = TextEditingController();
  final _vinCtrl = TextEditingController();
  final _notasCtrl = TextEditingController();

  TipoVehiculo _tipo = TipoVehiculo.otro;
  String? _formatoPatenteDetectado;
  Timer? _debouncePatente;
  bool _buscandoPatente = false;
  bool _patenteNoEncontrada = false;
  bool _guardando = false;
  bool _cargando = false;

  bool get _esEdicion => widget.objetoId != null;

  @override
  void initState() {
    super.initState();
    if (_esEdicion) {
      _cargarVehiculo();
    }
  }

  Future<void> _cargarVehiculo() async {
    setState(() => _cargando = true);
    try {
      final repo = ref.read(oficiosRepositoryProvider);
      final v = await repo.obtenerVehiculo(widget.objetoId!);
      if (!mounted) return;
      _patenteCtrl.text = v.patente;
      _marcaCtrl.text = v.marca;
      _modeloCtrl.text = v.modelo;
      _anioCtrl.text = v.anio.toString();
      _colorCtrl.text = v.color ?? '';
      _kmCtrl.text = v.kilometrajeActual.toString();
      _aliasCtrl.text = v.alias ?? '';
      _vinCtrl.text = v.vin ?? '';
      _notasCtrl.text = v.notas ?? '';
      setState(() => _tipo = v.tipoVehiculo);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error al cargar: $e')));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  void dispose() {
    _debouncePatente?.cancel();
    _patenteCtrl.dispose();
    _marcaCtrl.dispose();
    _modeloCtrl.dispose();
    _anioCtrl.dispose();
    _colorCtrl.dispose();
    _kmCtrl.dispose();
    _aliasCtrl.dispose();
    _vinCtrl.dispose();
    _notasCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _guardando = true);
    final repo = ref.read(oficiosRepositoryProvider);
    final anio = int.parse(_anioCtrl.text.trim());
    final km = int.tryParse(_kmCtrl.text.trim()) ?? 0;

    try {
      if (_esEdicion) {
        final cambios = <String, dynamic>{
          'marca': _marcaCtrl.text.trim(),
          'modelo': _modeloCtrl.text.trim(),
          'anio': anio,
          'tipo_vehiculo': _tipo.value,
          'kilometraje_actual': km,
          'alias': _aliasCtrl.text.trim().isEmpty
              ? null
              : _aliasCtrl.text.trim(),
          'color': _colorCtrl.text.trim().isEmpty
              ? null
              : _colorCtrl.text.trim(),
          'vin': _vinCtrl.text.trim().isEmpty ? null : _vinCtrl.text.trim(),
          'notas': _notasCtrl.text.trim().isEmpty
              ? null
              : _notasCtrl.text.trim(),
        };
        await repo.actualizarVehiculo(widget.objetoId!, cambios);
      } else {
        final nuevo = Vehiculo(
          objetoId: '',
          patente: _patenteCtrl.text.trim().toUpperCase(),
          marca: _marcaCtrl.text.trim(),
          modelo: _modeloCtrl.text.trim(),
          anio: anio,
          tipoVehiculo: _tipo,
          kilometrajeActual: km,
          activo: true,
          alias: _aliasCtrl.text.trim().isEmpty ? null : _aliasCtrl.text.trim(),
          color: _colorCtrl.text.trim().isEmpty ? null : _colorCtrl.text.trim(),
          vin: _vinCtrl.text.trim().isEmpty ? null : _vinCtrl.text.trim(),
          notas: _notasCtrl.text.trim().isEmpty ? null : _notasCtrl.text.trim(),
        );
        await repo.crearVehiculo(nuevo);
      }

      ref.invalidate(misVehiculosProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _esEdicion ? 'Vehiculo actualizado' : 'Vehiculo creado',
          ),
        ),
      );
      context.pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: ${e.message}')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error inesperado: $e')));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_esEdicion ? 'Editar vehiculo' : 'Nuevo vehiculo'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            const _Seccion('Identificacion'),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _campo(
                  controller: _patenteCtrl,
                  label: 'Patente *',
                  hint: 'AB1234 o ABCD12',
                  enabled: !_esEdicion,
                  maxLength: 6,
                  textCapitalization: TextCapitalization.characters,
                  keyboardType: TextInputType.text,
                  autocorrect: false,
                  enableSuggestions: false,
                  inputFormatters: [PatenteAutoFormatter()],
                  helperText:
                      'Formatos: AB1234 (antiguo), '
                      'ABCD12 (2007-2026), BBBBB0 (2026+)',
                  helperMaxLines: 2,
                  onChanged: _onPatenteChanged,
                  validator: _validarPatente,
                ),
                if (_formatoPatenteDetectado != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 12, bottom: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle,
                          size: 14,
                          color: Colors.green[700],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatoPatenteDetectado!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_buscandoPatente)
                  const Padding(
                    padding: EdgeInsets.only(left: 12, bottom: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Buscando datos del vehiculo...',
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  )
                else if (_patenteNoEncontrada)
                  Padding(
                    padding: const EdgeInsets.only(left: 12, bottom: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 14,
                          color: Colors.orange[800],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Patente no encontrada. Ingresa los datos manualmente.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange[800],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            _campo(
              controller: _marcaCtrl,
              label: 'Marca *',
              hint: 'Toyota',
              validator: _req,
            ),
            _campo(
              controller: _modeloCtrl,
              label: 'Modelo *',
              hint: 'Corolla',
              validator: _req,
            ),
            _campo(
              controller: _anioCtrl,
              label: 'Anio *',
              hint: '2020',
              keyboardType: TextInputType.number,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Requerido';
                final n = int.tryParse(v.trim());
                if (n == null) return 'Numero invalido';
                if (n < 1900 || n > 2100) return 'Anio fuera de rango';
                return null;
              },
            ),
            _campo(controller: _colorCtrl, label: 'Color', hint: 'Rojo'),
            const SizedBox(height: 8),
            DropdownButtonFormField<TipoVehiculo>(
              initialValue: _tipo,
              decoration: const InputDecoration(
                labelText: 'Tipo de vehiculo',
                border: OutlineInputBorder(),
              ),
              items: TipoVehiculo.values
                  .map((t) => DropdownMenuItem(value: t, child: Text(t.label)))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _tipo = v);
              },
            ),
            const SizedBox(height: 16),
            const _Seccion('Estado'),
            _campo(
              controller: _kmCtrl,
              label: 'Kilometraje actual',
              hint: '45000',
              keyboardType: TextInputType.number,
            ),
            _campo(
              controller: _vinCtrl,
              label: 'VIN (opcional)',
              hint: '17 caracteres',
              maxLength: 17,
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 16),
            const _Seccion('Personalizacion'),
            _campo(
              controller: _aliasCtrl,
              label: 'Alias (opcional)',
              hint: 'Mi auto, La camioneta del trabajo',
              maxLength: 80,
            ),
            _campo(
              controller: _notasCtrl,
              label: 'Notas (opcional)',
              hint: 'Detalles utiles',
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _guardando ? null : _guardar,
              icon: _guardando
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              label: Text(_esEdicion ? 'Guardar cambios' : 'Crear vehiculo'),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _campo({
    required TextEditingController controller,
    required String label,
    String? hint,
    bool enabled = true,
    int? maxLength,
    int maxLines = 1,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    String? Function(String?)? validator,
    List<TextInputFormatter>? inputFormatters,
    String? helperText,
    int helperMaxLines = 1,
    bool autocorrect = true,
    bool enableSuggestions = true,
    void Function(String)? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        enabled: enabled,
        maxLength: maxLength,
        maxLines: maxLines,
        keyboardType: keyboardType,
        textCapitalization: textCapitalization,
        inputFormatters: inputFormatters,
        autocorrect: autocorrect,
        enableSuggestions: enableSuggestions,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
          counterText: maxLength != null ? null : '',
          helperText: helperText,
          helperMaxLines: helperMaxLines,
        ),
        validator: validator,
      ),
    );
  }

  String? _validarPatente(String? v) {
    if (v == null || v.trim().isEmpty) return 'Requerido';
    final p = v.trim().toUpperCase();
    if (p.length != 6) return 'Deben ser 6 caracteres';
    final patrones = [
      RegExp(r'^[A-Z]{2}\d{4}$'),
      RegExp(r'^[A-Z]{4}\d{2}$'),
      RegExp(r'^[A-Z]{5}\d{1}$'),
    ];
    if (!patrones.any((r) => r.hasMatch(p))) {
      return 'Formato invalido';
    }
    return null;
  }

  void _onPatenteChanged(String v) {
    final p = v.trim().toUpperCase();
    String? formato;
    if (RegExp(r'^[A-Z]{2}\d{4}$').hasMatch(p)) {
      formato = 'Formato antiguo (AB1234)';
    } else if (RegExp(r'^[A-Z]{4}\d{2}$').hasMatch(p)) {
      formato = 'Formato 2007-2026 (ABCD12)';
    } else if (RegExp(r'^[A-Z]{5}\d{1}$').hasMatch(p)) {
      formato = 'Formato 2026 (BBBBB0)';
    }

    setState(() {
      _formatoPatenteDetectado = formato;
      _patenteNoEncontrada = false;
    });

    _debouncePatente?.cancel();
    if (formato == null || p.length != 6) return;

    _debouncePatente = Timer(const Duration(milliseconds: 600), () async {
      if (!mounted) return;
      setState(() => _buscandoPatente = true);

      final repo = ref.read(oficiosRepositoryProvider);
      final data = await repo.consultarPatente(p);

      if (!mounted) return;
      setState(() {
        _buscandoPatente = false;
        if (data == null) {
          _patenteNoEncontrada = true;
        } else {
          _marcaCtrl.text = (data['make'] ?? '').toString();
          _modeloCtrl.text = (data['model'] ?? '').toString();
          final anio = data['year'];
          if (anio != null) _anioCtrl.text = anio.toString();
          final color = data['color'];
          if (color != null) _colorCtrl.text = color.toString();
          final chassis = data['chassis'];
          if (chassis != null) _vinCtrl.text = chassis.toString();
          final km = data['kilometers'];
          if (km != null) _kmCtrl.text = km.toString();
          _patenteNoEncontrada = false;
        }
      });
    });
  }

  String? _req(String? v) {
    if (v == null || v.trim().isEmpty) return 'Requerido';
    return null;
  }
}

class _Seccion extends StatelessWidget {
  const _Seccion(this.titulo);
  final String titulo;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 4),
      child: Text(
        titulo,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
