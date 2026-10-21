/// Pantalla admin: historial de notificaciones con filtros.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:baqueano_natales/features/notificaciones/data/notificaciones_providers.dart';
import 'package:baqueano_natales/features/notificaciones/domain/notificacion.dart';

class AdminNotificacionesHistorialScreen extends ConsumerStatefulWidget {
  const AdminNotificacionesHistorialScreen({super.key});

  @override
  ConsumerState<AdminNotificacionesHistorialScreen> createState() =>
      _AdminNotificacionesHistorialScreenState();
}

class _AdminNotificacionesHistorialScreenState
    extends ConsumerState<AdminNotificacionesHistorialScreen> {
  String? _tipoFiltro;
  String? _estadoFiltro;

  @override
  Widget build(BuildContext context) {
    final params = HistorialParams(tipo: _tipoFiltro, estado: _estadoFiltro);
    final async = ref.watch(historialNotificacionesProvider(params));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                ref.invalidate(historialNotificacionesProvider(params)),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filtros
          Container(
            padding: const EdgeInsets.all(12),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    initialValue: _tipoFiltro,
                    decoration: const InputDecoration(
                      labelText: 'Tipo',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('Todos')),
                      DropdownMenuItem(
                        value: 'sistema',
                        child: Text('Sistema'),
                      ),
                      DropdownMenuItem(
                        value: 'promocion',
                        child: Text('Promocion'),
                      ),
                      DropdownMenuItem(
                        value: 'recordatorio',
                        child: Text('Recordatorio'),
                      ),
                      DropdownMenuItem(
                        value: 'campana',
                        child: Text('Campana'),
                      ),
                    ],
                    onChanged: (v) => setState(() => _tipoFiltro = v),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    initialValue: _estadoFiltro,
                    decoration: const InputDecoration(
                      labelText: 'Estado',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('Todos')),
                      DropdownMenuItem(
                        value: 'enviada',
                        child: Text('Enviada'),
                      ),
                      DropdownMenuItem(
                        value: 'entregada',
                        child: Text('Entregada'),
                      ),
                      DropdownMenuItem(
                        value: 'abierta',
                        child: Text('Abierta'),
                      ),
                      DropdownMenuItem(
                        value: 'fallida',
                        child: Text('Fallida'),
                      ),
                      DropdownMenuItem(
                        value: 'skipped',
                        child: Text('Skipped'),
                      ),
                    ],
                    onChanged: (v) => setState(() => _estadoFiltro = v),
                  ),
                ),
              ],
            ),
          ),
          // Lista
          Expanded(
            child: async.when(
              data: (items) {
                if (items.isEmpty) {
                  return const Center(
                    child: Text('No hay notificaciones con esos filtros.'),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async =>
                      ref.invalidate(historialNotificacionesProvider(params)),
                  child: ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (ctx, i) => _NotificacionCard(notif: items[i]),
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Error: $e'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificacionCard extends StatelessWidget {
  const _NotificacionCard({required this.notif});
  final NotificacionAdmin notif;

  Color _colorEstado() {
    switch (notif.estado) {
      case 'abierta':
        return Colors.green;
      case 'entregada':
        return Colors.blue;
      case 'enviada':
        return Colors.grey;
      case 'fallida':
        return Colors.red;
      case 'skipped':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: _colorEstado().withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    notif.estado.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: _colorEstado(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(notif.tipo, style: Theme.of(context).textTheme.bodySmall),
                const Spacer(),
                Text(
                  _formatFecha(notif.creadoEn),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              notif.titulo,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Text(notif.body, maxLines: 2, overflow: TextOverflow.ellipsis),
            if (notif.error != null) ...[
              const SizedBox(height: 4),
              Text(
                'Error: ${notif.error}',
                style: TextStyle(color: Colors.red.shade700, fontSize: 11),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatFecha(DateTime d) {
    final local = d.toLocal();
    return '${local.day}/${local.month} '
        '${local.hour.toString().padLeft(2, "0")}:'
        '${local.minute.toString().padLeft(2, "0")}';
  }
}
