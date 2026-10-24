/// Pantalla cliente: reservar un turno con un prestador.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:baqueano_natales/core/network/api_exceptions.dart';
import 'package:baqueano_natales/features/oficios/data/oficios_providers.dart';
import 'package:baqueano_natales/features/oficios/domain/vehiculo.dart';
import 'package:baqueano_natales/features/oficios/domain/servicio.dart';

class ReservarTurnoScreen extends ConsumerStatefulWidget {
  const ReservarTurnoScreen({
    super.key,
    required this.prestadorId,
    this.prestadorNombre,
  });

  final String prestadorId;
  final String? prestadorNombre;

  @override
  ConsumerState<ReservarTurnoScreen> createState() =>
      _ReservarTurnoScreenState();
}

class _ReservarTurnoScreenState extends ConsumerState<ReservarTurnoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _motivoCtrl = TextEditingController();
  final _notasCtrl = TextEditingController();

  Vehiculo? _vehiculoSel;
  Servicio? _servicioSel;
  DateTime? _fecha;
  TimeOfDay? _hora;
  int _duracionMin = 30;
  bool _guardando = false;

  @override
  void dispose() {
    _motivoCtrl.dispose();
    _notasCtrl.dispose();
    super.dispose();
  }

  Future<void> _elegirFecha() async {
    final ahora = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: ahora.add(const Duration(days: 1)),
      firstDate: ahora,
      lastDate: ahora.add(const Duration(days: 90)),
    );
    if (d != null) setState(() => _fecha = d);
  }

  Future<void> _elegirHora() async {
    final h = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 10, minute: 0),
    );
    if (h != null) setState(() => _hora = h);
  }

  Future<void> _guardar() async {
    if (_vehiculoSel == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Selecciona un vehiculo')));
      return;
    }
    if (_fecha == null || _hora == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Selecciona fecha y hora')));
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    final fechaInicio = DateTime(
      _fecha!.year,
      _fecha!.month,
      _fecha!.day,
      _hora!.hour,
      _hora!.minute,
    );
    if (fechaInicio.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('La fecha debe ser futura')));
      return;
    }

    setState(() => _guardando = true);
    final repo = ref.read(oficiosRepositoryProvider);

    try {
      await repo.crearTurno(
        prestadorId: widget.prestadorId,
        objetoId: _vehiculoSel!.objetoId,
        fechaInicio: fechaInicio,
        duracionMin: _duracionMin,
        servicioId: _servicioSel?.id,
        motivo: _motivoCtrl.text.trim().isEmpty
            ? null
            : _motivoCtrl.text.trim(),
        notasCliente: _notasCtrl.text.trim().isEmpty
            ? null
            : _notasCtrl.text.trim(),
      );

      ref.invalidate(misTurnosProvider(null));

      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Turno reservado')));
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
    final theme = Theme.of(context);
    final misVehiculosAsync = ref.watch(misVehiculosProvider);

    return Scaffold(
      appBar: AppBar(title: Text(widget.prestadorNombre ?? 'Reservar turno')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Vehiculo
            Text(
              'Vehiculo',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            misVehiculosAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(12),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Text('Error: $e'),
              data: (vehiculos) {
                if (vehiculos.isEmpty) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber_outlined),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Necesitas agregar un vehiculo en "Mis vehiculos" '
                                'antes de reservar un turno.',
                                style: theme.textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: () async {
                          await context.push('/mis-vehiculos/nuevo');
                          if (!mounted) return;
                          ref.invalidate(misVehiculosProvider);
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Agregar mi primer vehiculo'),
                      ),
                    ],
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<Vehiculo>(
                      initialValue: _vehiculoSel,
                      decoration: const InputDecoration(
                        labelText: 'Vehiculo *',
                        border: OutlineInputBorder(),
                      ),
                      items: vehiculos
                          .map(
                            (v) => DropdownMenuItem(
                              value: v,
                              child: Text(
                                v.nombreDisplay,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _vehiculoSel = v),
                    ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () async {
                          await context.push('/mis-vehiculos/nuevo');
                          if (!mounted) return;
                          ref.invalidate(misVehiculosProvider);
                          final v = await ref.read(misVehiculosProvider.future);
                          if (v.isNotEmpty && mounted) {
                            setState(() => _vehiculoSel = v.last);
                          }
                        },
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Agregar otro vehiculo'),
                      ),
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 20),
            // Servicio del catalogo
            Consumer(
              builder: (context, ref, _) {
                final serviciosAsync = ref.watch(
                  serviciosPrestadorProvider(widget.prestadorId),
                );
                return serviciosAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) {
                    debugPrint('[Reserva] error servicios: $e');
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'No se pudieron cargar los servicios: $e',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontSize: 12,
                        ),
                      ),
                    );
                  },
                  data: (servicios) {
                    if (servicios.isEmpty) return const SizedBox.shrink();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Servicio',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...servicios.map(
                          (s) => Card(
                            margin: const EdgeInsets.only(bottom: 6),
                            color: _servicioSel?.id == s.id
                                ? theme.colorScheme.primaryContainer
                                : null,
                            child: ListTile(
                              dense: true,
                              title: Text(s.nombre),
                              subtitle: Text(
                                '${s.precioLabel} · ${s.duracionLabel}',
                              ),
                              trailing: _servicioSel?.id == s.id
                                  ? Icon(
                                      Icons.check_circle,
                                      color: theme.colorScheme.primary,
                                    )
                                  : null,
                              onTap: () {
                                setState(() {
                                  _servicioSel = s;
                                  if (s.duracionEstimadaMin != null) {
                                    _duracionMin = s.duracionEstimadaMin!;
                                  }
                                  _motivoCtrl.text = s.nombre;
                                });
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    );
                  },
                );
              },
            ),
            // Fecha y hora
            Text(
              'Fecha y hora',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _elegirFecha,
                    icon: const Icon(Icons.calendar_today, size: 18),
                    label: Text(
                      _fecha == null
                          ? 'Elegir fecha'
                          : '${_fecha!.day}/${_fecha!.month}/${_fecha!.year}',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _elegirHora,
                    icon: const Icon(Icons.access_time, size: 18),
                    label: Text(
                      _hora == null
                          ? 'Elegir hora'
                          : '${_hora!.hour.toString().padLeft(2, '0')}:${_hora!.minute.toString().padLeft(2, '0')}',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: _duracionMin,
              decoration: const InputDecoration(
                labelText: 'Duracion estimada',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 20, child: Text('20 minutos')),
                DropdownMenuItem(value: 30, child: Text('30 minutos')),
                DropdownMenuItem(value: 45, child: Text('45 minutos')),
                DropdownMenuItem(value: 60, child: Text('1 hora')),
                DropdownMenuItem(value: 90, child: Text('1 hora 30 min')),
                DropdownMenuItem(value: 120, child: Text('2 horas')),
                DropdownMenuItem(value: 180, child: Text('3 horas')),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _duracionMin = v);
              },
            ),

            const SizedBox(height: 20),
            // Detalles
            Text(
              'Detalles',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _motivoCtrl,
              decoration: const InputDecoration(
                labelText: 'Motivo',
                hintText: 'Ej: Cambio de aceite',
                border: OutlineInputBorder(),
              ),
              maxLength: 255,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _notasCtrl,
              decoration: const InputDecoration(
                labelText: 'Notas (opcional)',
                hintText: 'Detalles adicionales',
                border: OutlineInputBorder(),
              ),
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
                  : const Icon(Icons.event_available),
              label: const Text('Reservar turno'),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
