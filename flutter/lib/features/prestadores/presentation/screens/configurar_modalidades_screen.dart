/// Pantalla para configurar las 7 modalidades de prestación del servicio.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:baqueano_natales/core/network/api_exceptions.dart';
import 'package:baqueano_natales/features/prestadores/data/prestador_providers.dart';
import 'package:baqueano_natales/features/prestadores/domain/modalidades.dart';

class ConfigurarModalidadesScreen extends ConsumerStatefulWidget {
  const ConfigurarModalidadesScreen({super.key, required this.prestadorId});
  final String prestadorId;

  @override
  ConsumerState<ConfigurarModalidadesScreen> createState() =>
      _ConfigurarModalidadesScreenState();
}

class _ConfigurarModalidadesScreenState
    extends ConsumerState<ConfigurarModalidadesScreen> {
  ModalidadesConfig? _config;
  bool _guardando = false;

  final _radioCtrl = TextEditingController();
  final _costoDespCtrl = TextEditingController();
  final _costoTrasladoCtrl = TextEditingController();
  final _puntoDescCtrl = TextEditingController();

  @override
  void dispose() {
    _radioCtrl.dispose();
    _costoDespCtrl.dispose();
    _costoTrasladoCtrl.dispose();
    _puntoDescCtrl.dispose();
    super.dispose();
  }

  void _initFromConfig(ModalidadesConfig config) {
    _config = config;
    _radioCtrl.text = config.domicilio.radioKm.toString();
    _costoDespCtrl.text = config.domicilio.costoDesplazamientoClp.toString();
    _costoTrasladoCtrl.text =
        config.recogidaEntrega.costoTrasladoClp.toString();
    _puntoDescCtrl.text = config.puntoEstrategico.puntoDescripcion ?? '';
  }

  Future<void> _guardar() async {
    if (_config == null) return;
    setState(() => _guardando = true);
    try {
      final updated = _config!.copyWith(
        domicilio: _config!.domicilio.copyWith(
          radioKm: int.tryParse(_radioCtrl.text) ?? 15,
          costoDesplazamientoClp: int.tryParse(_costoDespCtrl.text) ?? 0,
        ),
        recogidaEntrega: ConfigRecogidaEntrega(
          activo: _config!.recogidaEntrega.activo,
          notas: _config!.recogidaEntrega.notas,
          costoTrasladoClp: int.tryParse(_costoTrasladoCtrl.text) ?? 0,
        ),
        puntoEstrategico: ConfigPuntoEstrategico(
          activo: _config!.puntoEstrategico.activo,
          notas: _config!.puntoEstrategico.notas,
          puntoDescripcion: _puntoDescCtrl.text.trim().isEmpty
              ? null
              : _puntoDescCtrl.text.trim(),
        ),
      );

      final repo = ref.read(prestadorRepositoryProvider);
      await repo.actualizarModalidades(
        prestadorId: widget.prestadorId,
        config: updated,
      );
      ref.invalidate(modalidadesConfigProvider(widget.prestadorId));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Modalidades guardadas')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.message}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(modalidadesConfigProvider(widget.prestadorId));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Modalidades de servicio'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(
              modalidadesConfigProvider(widget.prestadorId),
            ),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 12),
                Text('$e', textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => ref.invalidate(
                    modalidadesConfigProvider(widget.prestadorId),
                  ),
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ),
        data: (config) {
          if (_config == null) _initFromConfig(config);
          return _buildContenido(context);
        },
      ),
    );
  }

  /// FIX: lee SIEMPRE de _config, nunca del config del provider.
  /// Antes recibía `config` como parámetro y los SwitchListTile.value
  /// leían del provider, haciendo que el toggle rebote al rebuild.
  Widget _buildContenido(BuildContext context) {
    final config = _config;
    if (config == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Configurá cómo prestás el servicio. Podés activar todas las modalidades que ofrezcas.',
          style: TextStyle(fontSize: 13),
        ),
        const SizedBox(height: 16),
        _SwitchModalidad(
          titulo: 'Taller físico',
          subtitulo: 'El cliente lleva el auto a tu taller',
          icono: Icons.storefront,
          activo: config.tallerFisico.activo,
          onChanged: (v) => setState(() {
            _config = _config!.copyWith(
              tallerFisico: _config!.tallerFisico.copyWith(activo: v),
            );
          }),
        ),
        _SwitchModalidad(
          titulo: 'Servicio a domicilio',
          subtitulo: 'Vas al domicilio u oficina del cliente',
          icono: Icons.home_repair_service,
          activo: config.domicilio.activo,
          onChanged: (v) => setState(() {
            _config = _config!.copyWith(
              domicilio: _config!.domicilio.copyWith(activo: v),
            );
          }),
          expandido: config.domicilio.activo,
          config: Column(
            children: [
              TextField(
                controller: _radioCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Radio de cobertura (km)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _costoDespCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Costo de desplazamiento (CLP)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ],
          ),
        ),
        _SwitchModalidad(
          titulo: 'Punto estratégico',
          subtitulo: 'Atendés en un punto fijo (empresa, mall, etc.)',
          icono: Icons.place,
          activo: config.puntoEstrategico.activo,
          onChanged: (v) => setState(() {
            _config = _config!.copyWith(
              puntoEstrategico:
                  _config!.puntoEstrategico.copyWith(activo: v),
            );
          }),
          expandido: config.puntoEstrategico.activo,
          config: TextField(
            controller: _puntoDescCtrl,
            decoration: const InputDecoration(
              labelText: 'Descripción del punto (opcional)',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ),
        _SwitchModalidad(
          titulo: 'Recogida y entrega',
          subtitulo: 'Retirás el auto, lo reparás y lo devolvés',
          icono: Icons.local_shipping,
          activo: config.recogidaEntrega.activo,
          onChanged: (v) => setState(() {
            _config = _config!.copyWith(
              recogidaEntrega: _config!.recogidaEntrega.copyWith(activo: v),
            );
          }),
          expandido: config.recogidaEntrega.activo,
          config: TextField(
            controller: _costoTrasladoCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Costo de traslado (CLP)',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ),
        _SwitchModalidad(
          titulo: 'Suscripción',
          subtitulo: 'Planes mensuales con servicios incluidos',
          icono: Icons.card_membership,
          activo: config.suscripcion.activo,
          onChanged: (v) => setState(() {
            _config = _config!.copyWith(
              suscripcion: _config!.suscripcion.copyWith(activo: v),
            );
          }),
        ),
        _SwitchModalidad(
          titulo: 'Flotas y empresas',
          subtitulo: 'Acuerdos de mantenimiento corporativo',
          icono: Icons.business,
          activo: config.flotas.activo,
          onChanged: (v) => setState(() {
            _config = _config!.copyWith(
              flotas: _config!.flotas.copyWith(activo: v),
            );
          }),
        ),
        _SwitchModalidad(
          titulo: 'Híbrido',
          subtitulo: 'Combinás varias modalidades a la vez',
          icono: Icons.merge_type,
          activo: config.hibrido.activo,
          onChanged: (v) => setState(() {
            _config = _config!.copyWith(
              hibrido: _config!.hibrido.copyWith(activo: v),
            );
          }),
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
          label: Text(_guardando ? 'Guardando...' : 'Guardar cambios'),
          style: FilledButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}

class _SwitchModalidad extends StatelessWidget {
  const _SwitchModalidad({
    required this.titulo,
    required this.subtitulo,
    required this.icono,
    required this.activo,
    required this.onChanged,
    this.expandido = false,
    this.config,
  });

  final String titulo;
  final String subtitulo;
  final IconData icono;
  final bool activo;
  final ValueChanged<bool> onChanged;
  final bool expandido;
  final Widget? config;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            value: activo,
            onChanged: onChanged,
            secondary: Icon(icono, color: theme.colorScheme.primary),
            title: Text(
              titulo,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text(subtitulo, style: theme.textTheme.bodySmall),
          ),
          if (expandido && config != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: config!,
            ),
        ],
      ),
    );
  }
}
