/// Pantalla del usuario: lista de mis notificaciones.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:baqueano_natales/features/notificaciones/data/notificaciones_providers.dart';
import 'package:baqueano_natales/features/notificaciones/domain/notificacion.dart';

class MisNotificacionesScreen extends ConsumerStatefulWidget {
  const MisNotificacionesScreen({super.key});

  @override
  ConsumerState<MisNotificacionesScreen> createState() =>
      _MisNotificacionesScreenState();
}

class _MisNotificacionesScreenState
    extends ConsumerState<MisNotificacionesScreen> {
  bool _soloNoLeidas = false;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(misNotificacionesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis notificaciones'),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: 'Preferencias',
            onPressed: () => context.push('/mis-notificaciones/preferencias'),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(misNotificacionesProvider),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filtros
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('Solo no leidas'),
                  selected: _soloNoLeidas,
                  onSelected: (v) => setState(() => _soloNoLeidas = v),
                ),
              ],
            ),
          ),
          // Lista
          Expanded(
            child: async.when(
              data: (items) {
                final visibles = _soloNoLeidas
                    ? items.where((n) => n.estado != 'abierta').toList()
                    : items;

                if (visibles.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        _soloNoLeidas
                            ? 'No tenes notificaciones sin leer.'
                            : 'No tenes notificaciones todavia.',
                        style: const TextStyle(fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async =>
                      ref.invalidate(misNotificacionesProvider),
                  child: ListView.builder(
                    itemCount: visibles.length,
                    itemBuilder: (ctx, i) =>
                        _NotifCard(notif: visibles[i], ref: ref),
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

class _NotifCard extends StatelessWidget {
  const _NotifCard({required this.notif, required this.ref});
  final NotificacionAdmin notif;
  final WidgetRef ref;

  /// Resuelve la ruta de navegacion segun el `data` de la notif.
  ///
  /// El backend inyecta `data = {"tipo": "...", ...ids}` para deep link.
  /// Si no hay data o el tipo es desconocido, devuelve null (solo se
  /// marca como leida, sin navegar).
  String? _resolverRuta() {
    final data = notif.data;
    if (data == null) return null;
    final tipo = data['tipo'] as String?;
    switch (tipo) {
      case 'orden':
        final ordenId = data['orden_id']?.toString();
        if (ordenId != null && ordenId.isNotEmpty) {
          return '/mis-ordenes/$ordenId';
        }
        return '/mis-ordenes';
      case 'turno':
        final turnoId = data['turno_id']?.toString();
        if (turnoId != null && turnoId.isNotEmpty) {
          return '/mis-turnos/$turnoId';
        }
        return '/mis-turnos';
      case 'recordatorio':
        final objId = data['objeto_servicio_id']?.toString();
        if (objId != null && objId.isNotEmpty) {
          return '/mis-vehiculos/$objId/recordatorios';
        }
        return '/mis-vehiculos';
      default:
        return null;
    }
  }

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
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: InkWell(
        onTap: () async {
          final messenger = ScaffoldMessenger.of(context);
          final router = GoRouter.of(context);

          // 1. Marcar como abierta (best-effort, no bloquea la navegacion)
          if (notif.estado != 'abierta') {
            try {
              await ref
                  .read(notificacionesRepositoryProvider)
                  .marcarAbierta(notif.id);
              ref.invalidate(misNotificacionesProvider);
            } catch (_) {
              // Best-effort
            }
          }

          // 2. Navegar segun el data (deep link)
          final ruta = _resolverRuta();
          if (ruta != null) {
            router.push(ruta);
          } else if (notif.estado == 'abierta') {
            // Ya estaba abierta y sin ruta -> no hacemos nada
            return;
          } else {
            // Sin ruta conocida -> solo feedback visual
            messenger.showSnackBar(
              const SnackBar(
                content: Text('Notificacion marcada como leida'),
                duration: Duration(seconds: 2),
              ),
            );
          }
        },
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
                      notif.tipo,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: _colorEstado(),
                      ),
                    ),
                  ),
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
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: notif.estado == 'abierta'
                      ? Theme.of(context).colorScheme.onSurfaceVariant
                      : null,
                ),
              ),
              const SizedBox(height: 2),
              Text(notif.body),
            ],
          ),
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
