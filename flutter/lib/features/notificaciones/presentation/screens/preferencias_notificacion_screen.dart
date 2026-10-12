/// Pantalla del usuario: preferencias de notificacion.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:baqueano_natales/core/network/api_exceptions.dart';
import 'package:baqueano_natales/features/notificaciones/data/notificaciones_providers.dart';
import 'package:baqueano_natales/features/notificaciones/domain/preferencia_notificacion.dart';

class PreferenciasNotificacionScreen extends ConsumerWidget {
  const PreferenciasNotificacionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(misPreferenciasProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Preferencias de notificacion')),
      body: async.when(
        data: (prefs) => _Contenido(prefs: prefs, ref: ref),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Error: $e'),
          ),
        ),
      ),
    );
  }
}

class _Contenido extends StatefulWidget {
  const _Contenido({required this.prefs, required this.ref});
  final PreferenciaNotificacion prefs;
  final WidgetRef ref;

  @override
  State<_Contenido> createState() => _ContenidoState();
}

class _ContenidoState extends State<_Contenido> {
  late bool _recordatorios;
  late bool _promociones;
  late bool _confirmaciones;
  late bool _sistema;
  late bool _quietHoursEnabled;
  late String? _quietHoursInicio;
  late String? _quietHoursFin;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.prefs;
    _recordatorios = p.recordatorios;
    _promociones = p.promociones;
    _confirmaciones = p.confirmaciones;
    _sistema = p.sistema;
    _quietHoursEnabled = p.quietHoursEnabled;
    _quietHoursInicio = p.quietHoursInicio;
    _quietHoursFin = p.quietHoursFin;
  }

  Future<void> _guardar() async {
    setState(() => _saving = true);
    try {
      await widget.ref
          .read(notificacionesRepositoryProvider)
          .actualizarPreferencias(
            recordatorios: _recordatorios,
            promociones: _promociones,
            confirmaciones: _confirmaciones,
            sistema: _sistema,
            quietHoursEnabled: _quietHoursEnabled,
            quietHoursInicio: _quietHoursInicio,
            quietHoursFin: _quietHoursFin,
          );
      if (!mounted) return;
      widget.ref.invalidate(misPreferenciasProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preferencias guardadas')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.message}')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickHora({required bool esInicio}) async {
    final actual = esInicio ? _quietHoursInicio : _quietHoursFin;
    final partes = (actual ?? '22:00').split(':');
    final inicial = TimeOfDay(
      hour: int.tryParse(partes[0]) ?? 22,
      minute: int.tryParse(partes.length > 1 ? partes[1] : '0') ?? 0,
    );
    final picked = await showTimePicker(
      context: context,
      initialTime: inicial,
    );
    if (picked != null) {
      setState(() {
        final hh = picked.hour.toString().padLeft(2, '0');
        final mm = picked.minute.toString().padLeft(2, '0');
        if (esInicio) {
          _quietHoursInicio = '$hh:$mm';
        } else {
          _quietHoursFin = '$hh:$mm';
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Tipos de notificacion',
            style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),

        SwitchListTile(
          title: const Text('Recordatorios de mantenimiento'),
          subtitle: const Text('Cuando tu vehiculo cumple km o fecha'),
          value: _recordatorios,
          onChanged: (v) => setState(() => _recordatorios = v),
        ),
        SwitchListTile(
          title: const Text('Novedades de talleres'),
          subtitle: const Text('Promociones y avisos de oficios'),
          value: _promociones,
          onChanged: (v) => setState(() => _promociones = v),
        ),
        SwitchListTile(
          title: const Text('Confirmaciones de turnos'),
          subtitle: const Text('Recordatorios de turnos agendados'),
          value: _confirmaciones,
          onChanged: (v) => setState(() => _confirmaciones = v),
        ),
        SwitchListTile(
          title: const Text('Avisos del sistema'),
          subtitle: const Text('Mantenimiento y cambios importantes'),
          value: _sistema,
          onChanged: (v) => setState(() => _sistema = v),
        ),

        const SizedBox(height: 24),
        Text('Horario de silencio', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),

        SwitchListTile(
          title: const Text('No molestar'),
          subtitle: const Text('Las notifs no criticas se posponen'),
          value: _quietHoursEnabled,
          onChanged: (v) => setState(() => _quietHoursEnabled = v),
        ),
        if (_quietHoursEnabled) ...[
          ListTile(
            title: const Text('Desde'),
            trailing: Text(_quietHoursInicio ?? '22:00',
                style: theme.textTheme.titleMedium),
            onTap: () => _pickHora(esInicio: true),
          ),
          ListTile(
            title: const Text('Hasta'),
            trailing: Text(_quietHoursFin ?? '08:00',
                style: theme.textTheme.titleMedium),
            onTap: () => _pickHora(esInicio: false),
          ),
        ],

        const SizedBox(height: 32),
        FilledButton.icon(
          onPressed: _saving ? null : _guardar,
          icon: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save),
          label: Text(_saving ? 'Guardando...' : 'Guardar cambios'),
        ),
      ],
    );
  }
}
