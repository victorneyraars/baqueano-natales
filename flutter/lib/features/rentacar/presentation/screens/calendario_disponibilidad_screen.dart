/// Calendario de disponibilidad por vehiculo (Fase 1.1).
///
/// Practicas de industria aplicadas:
/// - RangeSelectionMode.toggledOn (seleccion de rango).
/// - Bloqueo de rangos que abarcan dias no disponibles (validacion
///   antes de aceptar, patron Vega UI Calendar / ATOM Mobility).
/// - Colores semanticos: reserva=naranja, mantenimiento=gris, manual=azul.
/// - eventLoader con LinkedHashMap + hash custom para performance
///   (recomendacion oficial de table_calendar).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';

import 'package:baqueano_natales/core/network/api_exceptions.dart';
import 'package:baqueano_natales/features/rentacar/data/rentacar_providers.dart';
import 'package:baqueano_natales/features/rentacar/domain/bloqueo.dart';
import 'package:baqueano_natales/features/rentacar/domain/vehiculo.dart';

class CalendarioDisponibilidadScreen extends ConsumerStatefulWidget {
  const CalendarioDisponibilidadScreen({super.key, required this.vehiculo});
  final Vehiculo vehiculo;

  @override
  ConsumerState<CalendarioDisponibilidadScreen> createState() =>
      _CalendarioDisponibilidadScreenState();
}

class _CalendarioDisponibilidadScreenState
    extends ConsumerState<CalendarioDisponibilidadScreen> {
  DateTime _focusedDay = DateTime.now();
  final DateTime _firstDay = DateTime.now().subtract(const Duration(days: 30));
  DateTime? _rangeStart;
  DateTime? _rangeEnd;

  static DateTime _norm(DateTime d) => DateTime(d.year, d.month, d.day);

  static int _dayKey(DateTime d) => d.year * 10000 + d.month * 100 + d.day;

  /// Mapea dia -> lista de bloqueos (para el eventLoader).
  Map<int, List<Bloqueo>> _buildEventMap(List<Bloqueo> bloqueos) {
    final map = <int, List<Bloqueo>>{};
    for (final b in bloqueos) {
      // Expandir el rango [fechaInicio, fechaFin) dia por dia
      var d = _norm(b.fechaInicio);
      final fin = _norm(b.fechaFin);
      while (d.isBefore(fin)) {
        map.putIfAbsent(_dayKey(d), () => []).add(b);
        d = d.add(const Duration(days: 1));
      }
    }
    return map;
  }

  /// True si el rango [start, end] contiene algun dia con bloqueo.
  bool _rangeHasConflict(
    DateTime start,
    DateTime end,
    Map<int, List<Bloqueo>> events,
  ) {
    var d = _norm(start);
    final last = _norm(end);
    while (!d.isAfter(last)) {
      if ((events[_dayKey(d)] ?? []).isNotEmpty) return true;
      d = d.add(const Duration(days: 1));
    }
    return false;
  }

  Future<void> _crearBloqueo(
    DateTime start,
    DateTime end,
    String tipo,
    String? motivo,
  ) async {
    final repo = ref.read(rentacarRepositoryProvider);
    try {
      await repo.crearBloqueo(
        widget.vehiculo.id,
        _norm(start),
        _norm(end).add(const Duration(days: 1)),
        tipo: tipo,
        motivo: motivo,
      );
      ref.invalidate(
        bloqueosRentacarProvider((
          vehiculoId: widget.vehiculo.id,
          mes: _focusedDay,
        )),
      );
      setState(() {
        _rangeStart = null;
        _rangeEnd = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bloqueo creado'),
            backgroundColor: Colors.green,
          ),
        );
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error inesperado: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _eliminarBloqueo(Bloqueo b) async {
    final repo = ref.read(rentacarRepositoryProvider);
    try {
      await repo.eliminarBloqueo(b.id);
      ref.invalidate(
        bloqueosRentacarProvider((
          vehiculoId: widget.vehiculo.id,
          mes: _focusedDay,
        )),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bloqueo eliminado'),
            backgroundColor: Colors.green,
          ),
        );
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
    }
  }

  Color _colorForTipo(String tipo) {
    switch (tipo) {
      case 'reserva':
        return Colors.orange;
      case 'mantenimiento':
        return Colors.grey;
      case 'manual':
      default:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final key = (vehiculoId: widget.vehiculo.id, mes: _focusedDay);
    final asyncBloqueos = ref.watch(bloqueosRentacarProvider(key));
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Disponibilidad · ${widget.vehiculo.marca} ${widget.vehiculo.modelo}',
          style: const TextStyle(fontSize: 15),
        ),
      ),
      body: asyncBloqueos.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (bloqueos) => _buildCalendar(context, bloqueos),
      ),
    );
  }

  Widget _buildCalendar(BuildContext context, List<Bloqueo> bloqueos) {
    final events = _buildEventMap(bloqueos);
    final conflict =
        _rangeStart != null &&
        _rangeEnd != null &&
        _rangeHasConflict(_rangeStart!, _rangeEnd!, events);

    return Column(
      children: [
        _buildLeyenda(),
        TableCalendar<Bloqueo>(
          firstDay: _firstDay,
          lastDay: DateTime.now().add(const Duration(days: 730)),
          focusedDay: _focusedDay,
          rangeStartDay: _rangeStart,
          rangeEndDay: _rangeEnd,
          rangeSelectionMode: RangeSelectionMode.toggledOn,
          eventLoader: (day) => events[_dayKey(day)] ?? const [],
          calendarFormat: CalendarFormat.month,
          availableCalendarFormats: const {CalendarFormat.month: 'Mes'},
          startingDayOfWeek: StartingDayOfWeek.monday,
          locale: 'es_CL',
          headerStyle: const HeaderStyle(
            formatButtonVisible: false,
            titleCentered: true,
          ),
          calendarStyle: CalendarStyle(
            todayDecoration: const BoxDecoration(
              color: Colors.blueAccent,
              shape: BoxShape.circle,
            ),
            rangeStartDecoration: const BoxDecoration(
              color: Colors.teal,
              shape: BoxShape.circle,
            ),
            rangeEndDecoration: const BoxDecoration(
              color: Colors.teal,
              shape: BoxShape.circle,
            ),
            rangeHighlightColor: Colors.teal.withValues(alpha: 0.2),
            markerDecoration: const BoxDecoration(),
          ),
          calendarBuilders: CalendarBuilders<Bloqueo>(
            markerBuilder: (context, day, dayEvents) {
              if (dayEvents.isEmpty) return null;
              // Mostrar hasta 3 dots por tipo
              final tipos = dayEvents.map((e) => e.tipo).toSet().toList();
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: tipos.take(3).map((t) {
                  return Container(
                    width: 5,
                    height: 5,
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    decoration: BoxDecoration(
                      color: _colorForTipo(t),
                      shape: BoxShape.circle,
                    ),
                  );
                }).toList(),
              );
            },
          ),
          onRangeSelected: (start, end, focusedDay) {
            setState(() {
              _rangeStart = start;
              _rangeEnd = end;
              _focusedDay = focusedDay;
            });
          },
          onPageChanged: (focusedDay) {
            setState(() => _focusedDay = focusedDay);
          },
        ),
        const Divider(),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: _buildPanel(context, events, conflict),
          ),
        ),
      ],
    );
  }

  Widget _buildLeyenda() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Wrap(
        spacing: 16,
        runSpacing: 8,
        children: [
          _legendDot(Colors.orange, 'Reserva'),
          _legendDot(Colors.grey, 'Mantenimiento'),
          _legendDot(Colors.blue, 'Manual'),
          _legendDot(Colors.teal, 'Seleccion'),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildPanel(
    BuildContext context,
    Map<int, List<Bloqueo>> events,
    bool conflict,
  ) {
    if (_rangeStart == null) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'Toca un dia o selecciona un rango para gestionar bloqueos.',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    if (_rangeEnd == null) {
      // Dia unico seleccionado
      final bs = events[_dayKey(_rangeStart!)] ?? <Bloqueo>[];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Dia seleccionado: ${_formatDate(_rangeStart!)}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 12),
          if (bs.isEmpty)
            _buildAccionesCrear(_rangeStart!, _rangeStart!)
          else
            ...bs.map(_buildBloqueoCard),
        ],
      );
    }

    // Rango completo
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Rango: ${_formatDate(_rangeStart!)} → ${_formatDate(_rangeEnd!)}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 12),
        if (conflict)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              border: Border.all(color: Colors.red.shade200),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Icon(Icons.warning_amber, color: Colors.red),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'El rango incluye dias ya reservados o bloqueados. Elegi otro rango.',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ),
          )
        else
          _buildAccionesCrear(_rangeStart!, _rangeEnd!),
      ],
    );
  }

  Widget _buildAccionesCrear(DateTime start, DateTime end) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          onPressed: () => _pedirMotivoYCrear(start, end, 'manual'),
          icon: const Icon(Icons.block),
          label: const Text('Bloquear (manual)'),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
        ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: () => _pedirMotivoYCrear(start, end, 'mantenimiento'),
          icon: const Icon(Icons.build),
          label: const Text('Mantenimiento'),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildBloqueoCard(Bloqueo b) {
    final color = _colorForTipo(b.tipo);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          b.tipo == 'reserva'
              ? Icons.event_busy
              : b.tipo == 'mantenimiento'
              ? Icons.build
              : Icons.block,
          color: color,
        ),
        title: Text(b.tipoLabel),
        subtitle: Text(
          '${_formatDate(b.fechaInicio)} → ${_formatDate(b.fechaFin)}'
          '${b.motivo != null ? '\n${b.motivo}' : ''}',
        ),
        trailing: b.tipo == 'reserva'
            ? const Tooltip(
                message: 'Cancelar la reserva desde la lista de reservas',
                child: Icon(Icons.lock, size: 20, color: Colors.grey),
              )
            : IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => _confirmarEliminar(b),
              ),
      ),
    );
  }

  Future<void> _pedirMotivoYCrear(
    DateTime start,
    DateTime end,
    String tipo,
  ) async {
    final controller = TextEditingController();
    final motivo = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          tipo == 'mantenimiento'
              ? 'Bloquear por mantenimiento'
              : 'Bloquear fechas',
        ),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Motivo (opcional)',
            hintText: 'Ej: Taller, vacaciones, etc.',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Bloquear'),
          ),
        ],
      ),
    );
    if (motivo == null) return;
    await _crearBloqueo(start, end, tipo, motivo.isEmpty ? null : motivo);
  }

  Future<void> _confirmarEliminar(Bloqueo b) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar bloqueo'),
        content: Text(
          'Eliminar el bloqueo ${b.tipoLabel} del '
          '${_formatDate(b.fechaInicio)} al ${_formatDate(b.fechaFin)}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok == true) await _eliminarBloqueo(b);
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}
