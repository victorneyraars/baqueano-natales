/// Pantalla admin: enviar una notificacion a un segmento.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:baqueano_natales/core/network/api_exceptions.dart';
import 'package:baqueano_natales/features/notificaciones/data/notificaciones_providers.dart';
import 'package:baqueano_natales/features/notificaciones/data/notificaciones_repository.dart';
import 'package:baqueano_natales/features/notificaciones/domain/segmento.dart';

class AdminNotificacionesComposerScreen extends ConsumerStatefulWidget {
  const AdminNotificacionesComposerScreen({super.key});

  @override
  ConsumerState<AdminNotificacionesComposerScreen> createState() =>
      _AdminNotificacionesComposerScreenState();
}

class _AdminNotificacionesComposerScreenState
    extends ConsumerState<AdminNotificacionesComposerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tituloCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  final _labelCtrl = TextEditingController();

  String _tipo = 'sistema';
  TipoSegmento _segmentoTipo = TipoSegmento.todos;
  String _rolSegmento = 'cliente';
  bool _enviando = false;

  @override
  void dispose() {
    _tituloCtrl.dispose();
    _bodyCtrl.dispose();
    _labelCtrl.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _enviando = true);

    try {
      final segmento = _segmentoTipo == TipoSegmento.rol
          ? Segmento(tipo: _segmentoTipo, valor: _rolSegmento)
          : Segmento(tipo: _segmentoTipo);

      final result = await ref.read(notificacionesRepositoryProvider).enviar(
            titulo: _tituloCtrl.text.trim(),
            body: _bodyCtrl.text.trim(),
            tipo: _tipo,
            segmento: segmento,
            analyticsLabel: _labelCtrl.text.trim().isEmpty
                ? null
                : _labelCtrl.text.trim(),
          );

      if (!mounted) return;
      _showResultDialog(result);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.message}')),
      );
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  void _showResultDialog(EnvioMasivoResult result) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Envio completado'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Total destinatarios: ${result.total}'),
            const SizedBox(height: 4),
            Text('Enviados: ${result.enviados}',
                style: const TextStyle(color: Colors.green)),
            Text('Fallidos: ${result.fallidos}',
                style: TextStyle(color: Colors.red.shade700)),
            Text('Skipped: ${result.skipped}',
                style: TextStyle(color: Colors.orange.shade700)),
            const SizedBox(height: 8),
            const Text(
              'Skipped incluye usuarios con preferencia deshabilitada o en quiet hours.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _tituloCtrl.clear();
              _bodyCtrl.clear();
              _labelCtrl.clear();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Enviar notificacion')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _tituloCtrl,
              maxLength: 200,
              decoration: const InputDecoration(
                labelText: 'Titulo',
                border: OutlineInputBorder(),
                hintText: 'Ej: Recordatorio de mantenimiento',
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'El titulo es obligatorio'
                  : null,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _bodyCtrl,
              maxLines: 4,
              maxLength: 2000,
              decoration: const InputDecoration(
                labelText: 'Cuerpo',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'El cuerpo es obligatorio'
                  : null,
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _tipo,
              decoration: const InputDecoration(
                labelText: 'Tipo',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'sistema', child: Text('Sistema')),
                DropdownMenuItem(value: 'promocion', child: Text('Promocion')),
                DropdownMenuItem(
                    value: 'recordatorio', child: Text('Recordatorio')),
                DropdownMenuItem(value: 'campana', child: Text('Campana')),
              ],
              onChanged: (v) => setState(() => _tipo = v ?? 'sistema'),
            ),
            const SizedBox(height: 24),
            Text(
              'Destinatarios',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            RadioGroup<TipoSegmento>(
              groupValue: _segmentoTipo,
              onChanged: (v) => setState(() => _segmentoTipo = v!),
              child: const Column(
                children: [
                  RadioListTile<TipoSegmento>(
                    value: TipoSegmento.todos,
                    title: Text('Todos los usuarios'),
                  ),
                  RadioListTile<TipoSegmento>(
                    value: TipoSegmento.rol,
                    title: Text('Por rol'),
                  ),
                ],
              ),
            ),
            if (_segmentoTipo == TipoSegmento.rol)
              Padding(
                padding: const EdgeInsets.only(left: 32, bottom: 8, right: 16),
                child: DropdownButtonFormField<String>(
                  initialValue: _rolSegmento,
                  decoration: const InputDecoration(
                    labelText: 'Rol',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'cliente', child: Text('Cliente')),
                    DropdownMenuItem(
                        value: 'prestador', child: Text('Prestador')),
                    DropdownMenuItem(
                        value: 'comercio', child: Text('Comercio')),
                    DropdownMenuItem(value: 'admin', child: Text('Admin')),
                  ],
                  onChanged: (v) =>
                      setState(() => _rolSegmento = v ?? 'cliente'),
                ),
              ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _labelCtrl,
              maxLength: 50,
              decoration: const InputDecoration(
                labelText: 'Analytics label (opcional)',
                border: OutlineInputBorder(),
                hintText: 'Ej: promo_verano_2026',
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _enviando ? null : _enviar,
              icon: _enviando
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
              label: Text(_enviando ? 'Enviando...' : 'Enviar notificacion'),
            ),
            const SizedBox(height: 8),
            Text(
              'Las notificaciones respetan las preferencias del usuario y quiet hours.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
