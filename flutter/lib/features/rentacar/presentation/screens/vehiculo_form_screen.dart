import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:baqueano_natales/core/network/api_exceptions.dart';
import 'package:baqueano_natales/features/rentacar/data/rentacar_providers.dart';
import 'package:baqueano_natales/features/rentacar/domain/patente_lookup.dart';
import 'package:baqueano_natales/features/rentacar/domain/vehiculo.dart';

class VehiculoFormScreen extends ConsumerStatefulWidget {
  const VehiculoFormScreen({super.key, this.vehiculo});

  final Vehiculo? vehiculo;

  @override
  ConsumerState<VehiculoFormScreen> createState() => _VehiculoFormScreenState();
}

class _VehiculoFormScreenState extends ConsumerState<VehiculoFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _patenteCtrl;
  late final TextEditingController _marcaCtrl;
  late final TextEditingController _modeloCtrl;
  late final TextEditingController _anioCtrl;
  late final TextEditingController _precioCtrl;
  String _categoria = 'SUV';
  bool _disponible = true;
  bool _loading = false;

  // ── Patente lookup ────────────────────────────────────────
  Timer? _patenteTimer;
  String? _ultimaConsulta;
  bool _consultando = false;
  PatenteLookupResult? _lookup;

  static const _categorias = ['SUV', 'SEDAN', 'PICKUP', 'FURGONETA'];
  static final _patenteRegex = RegExp(r'^([A-Z]{2}\d{4}|[A-Z]{4}\d{2})$');

  @override
  void initState() {
    super.initState();
    final v = widget.vehiculo;
    _patenteCtrl = TextEditingController(text: v?.patente ?? '');
    _marcaCtrl = TextEditingController(text: v?.marca ?? '');
    _modeloCtrl = TextEditingController(text: v?.modelo ?? '');
    _anioCtrl = TextEditingController(text: v?.anio.toString() ?? '');
    _precioCtrl = TextEditingController(
      text: v?.precioDia.toStringAsFixed(0) ?? '',
    );
    _categoria = v?.categoria ?? 'SUV';
    _disponible = v?.disponible ?? true;

    // Al editar un vehículo existente, no consultar automáticamente.
    if (v == null) {
      _patenteCtrl.addListener(_onPatenteChanged);
    }
  }

  @override
  void dispose() {
    _patenteTimer?.cancel();
    _patenteCtrl.dispose();
    _marcaCtrl.dispose();
    _modeloCtrl.dispose();
    _anioCtrl.dispose();
    _precioCtrl.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════
  // PATENTE LOOKUP (debounce 500ms + validación formato CL)
  // ══════════════════════════════════════════════════════════

  void _onPatenteChanged() {
    _patenteTimer?.cancel();
    final raw = _patenteCtrl.text.trim().toUpperCase();

    // Limpiar estado si la patente cambió
    if (raw != _ultimaConsulta) {
      setState(() => _lookup = null);
    }

    if (raw.length < 6 || !_patenteRegex.hasMatch(raw)) return;
    if (raw == _ultimaConsulta) return;

    _patenteTimer = Timer(
      const Duration(milliseconds: 500),
      () => _consultarPatente(raw),
    );
  }

  Future<void> _consultarPatente(String patente) async {
    setState(() => _consultando = true);
    _ultimaConsulta = patente;
    try {
      final repo = ref.read(rentacarRepositoryProvider);
      final result = await repo.consultarPatente(patente);
      if (!mounted) return;
      setState(() {
        _lookup = result;
        _consultando = false;
      });
      if (result.encontrado) _autocompletar(result);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _consultando = false;
        _lookup = PatenteLookupResult(
          patente: patente,
          encontrado: false,
          mensaje: e.message,
        );
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _consultando = false;
        _lookup = PatenteLookupResult(
          patente: patente,
          encontrado: false,
          mensaje: 'Error: $e',
        );
      });
    }
  }

  /// Autocompleta SOLO los campos vacíos (no pisa lo que el usuario escribió).
  void _autocompletar(PatenteLookupResult r) {
    if (r.marca != null && _marcaCtrl.text.trim().isEmpty) {
      _marcaCtrl.text = r.marca!;
    }
    if (r.modelo != null && _modeloCtrl.text.trim().isEmpty) {
      _modeloCtrl.text = r.modelo!;
    }
    if (r.anio != null && _anioCtrl.text.trim().isEmpty) {
      _anioCtrl.text = r.anio!.toString();
    }
    if (r.categoria != null && _categorias.contains(r.categoria)) {
      _categoria = r.categoria!;
    }
    setState(() {});
  }

  // ══════════════════════════════════════════════════════════
  // GUARDAR
  // ══════════════════════════════════════════════════════════

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final payload = {
        'patente': _patenteCtrl.text.trim().toUpperCase(),
        'marca': _marcaCtrl.text.trim(),
        'modelo': _modeloCtrl.text.trim(),
        'anio': int.parse(_anioCtrl.text.trim()),
        'categoria': _categoria,
        'precio_dia': double.parse(_precioCtrl.text.trim()),
        'disponible': _disponible,
      };
      final repo = ref.read(rentacarRepositoryProvider);
      if (widget.vehiculo == null) {
        await repo.crearVehiculo(payload);
      } else {
        await repo.actualizarVehiculo(widget.vehiculo!.id, payload);
      }
      ref.invalidate(misVehiculosRentacarProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.vehiculo == null
                  ? 'Vehiculo creado'
                  : 'Vehiculo actualizado',
            ),
            backgroundColor: Colors.green,
          ),
        );
        context.pop();
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.message}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.vehiculo != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Editar vehiculo' : 'Nuevo vehiculo'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildPatenteField(),
            const SizedBox(height: 12),
            TextFormField(
              controller: _marcaCtrl,
              decoration: const InputDecoration(
                labelText: 'Marca',
                hintText: 'Toyota',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Requerido' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _modeloCtrl,
              decoration: const InputDecoration(
                labelText: 'Modelo',
                hintText: 'RAV4',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Requerido' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _anioCtrl,
              decoration: const InputDecoration(
                labelText: 'Año',
                hintText: '2023',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Requerido';
                final n = int.tryParse(v);
                if (n == null || n < 1990 || n > 2030) return 'Año invalido';
                return null;
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _categoria,
              decoration: const InputDecoration(
                labelText: 'Categoria',
                border: OutlineInputBorder(),
              ),
              items: _categorias
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => setState(() => _categoria = v ?? 'SUV'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _precioCtrl,
              decoration: const InputDecoration(
                labelText: 'Precio por dia (CLP)',
                hintText: '45000',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Requerido';
                final n = double.tryParse(v);
                if (n == null || n <= 0) return 'Precio invalido';
                return null;
              },
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text('Disponible para reservas'),
              value: _disponible,
              onChanged: (v) => setState(() => _disponible = v),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _loading ? null : _guardar,
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(isEdit ? 'Guardar cambios' : 'Crear vehiculo'),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  // FIELD: Patente con chip de estado
  // ══════════════════════════════════════════════════════════

  Widget _buildPatenteField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _patenteCtrl,
          decoration: InputDecoration(
            labelText: 'Patente',
            hintText: 'BBCC12 o BBBB12',
            border: const OutlineInputBorder(),
            suffixIcon: _consultando
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : null,
          ),
          textCapitalization: TextCapitalization.characters,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
            LengthLimitingTextInputFormatter(6),
          ],
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Requerido';
            final p = v.trim().toUpperCase();
            if (!_patenteRegex.hasMatch(p)) {
              return 'Formato inválido (BBCC12 o BBBB12)';
            }
            return null;
          },
        ),
        if (_lookup != null) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: _buildLookupChip(_lookup!),
          ),
        ],
      ],
    );
  }

  Widget _buildLookupChip(PatenteLookupResult r) {
    final theme = Theme.of(context);
    if (r.encontrado) {
      return Row(
        children: [
          Icon(Icons.check_circle, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              'Datos consultados — podés editarlos si hace falta',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        ],
      );
    }
    return Row(
      children: [
        Icon(Icons.info_outline, size: 16, color: theme.colorScheme.error),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            r.mensaje ?? 'No se pudo consultar — completá manualmente',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ),
      ],
    );
  }
}
