import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:baqueano_natales/features/prestadores/data/prestador_providers.dart';
import 'package:baqueano_natales/features/prestadores/domain/audit_log_entry.dart';

/// Pantalla de auditoría (solo owner).
///
/// Muestra el log append-only de todas las acciones sobre el prestador
/// (reservas, canales, colaboradores, vehículos) con quién y cuándo.
class AuditoriaScreen extends ConsumerStatefulWidget {
  const AuditoriaScreen({super.key, required this.prestadorId});
  final String prestadorId;

  @override
  ConsumerState<AuditoriaScreen> createState() => _AuditoriaScreenState();
}

class _AuditoriaScreenState extends ConsumerState<AuditoriaScreen> {
  int _page = 1;
  String? _filtroEntidad;

  @override
  Widget build(BuildContext context) {
    final params = AuditLogParams(
      prestadorId: widget.prestadorId,
      page: _page,
      pageSize: 50,
      entidad: _filtroEntidad,
    );
    final async = ref.watch(auditLogProvider(params));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Auditoría'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Recargar',
            onPressed: () => ref.invalidate(auditLogProvider(params)),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFiltros(),
          const Divider(height: 1),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _errorView(e, params),
              data: (page) => _lista(page, params),
            ),
          ),
          _buildPaginacion(async.asData?.value),
        ],
      ),
    );
  }

  Widget _buildFiltros() {
    final opciones = <String?>[
      null,
      'reserva',
      'colaborador',
      'canal',
      'vehiculo',
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: opciones.map((e) {
          final selected = _filtroEntidad == e;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(
                e == null ? 'Todas' : e[0].toUpperCase() + e.substring(1),
              ),
              selected: selected,
              onSelected: (_) => setState(() {
                _filtroEntidad = e;
                _page = 1;
              }),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _errorView(Object error, AuditLogParams params) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text('$error', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => ref.invalidate(auditLogProvider(params)),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _lista(AuditLogPage page, AuditLogParams params) {
    if (page.data.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.history, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text(
                'Sin eventos registrados',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Las acciones sobre reservas, canales y colaboradores aparecerán acá',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(auditLogProvider(params));
      },
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: page.data.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (_, i) => _entryCard(page.data[i]),
      ),
    );
  }

  Widget _entryCard(AuditLogEntry e) {
    final icono = _iconoPorEntidad(e.entidad);
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue.shade50,
          child: Icon(icono, color: Colors.blue.shade700, size: 20),
        ),
        title: Text(
          e.accionLegible,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              e.userEmail,
              style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
            ),
            Text(
              _formatFecha(e.createdAt),
              style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
            ),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }

  IconData _iconoPorEntidad(String entidad) {
    switch (entidad) {
      case 'reserva':
        return Icons.event_available;
      case 'colaborador':
        return Icons.person;
      case 'canal':
        return Icons.email;
      case 'vehiculo':
        return Icons.directions_car;
      default:
        return Icons.history;
    }
  }

  String _formatFecha(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildPaginacion(AuditLogPage? page) {
    if (page == null || page.data.isEmpty) return const SizedBox.shrink();
    final totalPages = (page.total / page.pageSize).ceil();
    if (totalPages <= 1) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.grey.shade50,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: _page > 1 ? () => setState(() => _page--) : null,
          ),
          Text(
            'Página $_page de $totalPages',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _page < totalPages
                ? () => setState(() => _page++)
                : null,
          ),
        ],
      ),
    );
  }
}
