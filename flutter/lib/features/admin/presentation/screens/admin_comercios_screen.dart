/// Listado de comercios para admin.
///
/// Filtros por estado:
/// - Pendientes (prioridad)
/// - Verificados
/// - Rechazados
/// - Suspendidos
/// - Borradores
/// - Todos
///
/// Búsqueda por nombre. Paginación básica.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:baqueano_natales/features/comercios/data/comercio_providers.dart';
import 'package:baqueano_natales/features/comercios/domain/comercio.dart';

class AdminComerciosScreen extends ConsumerStatefulWidget {
  const AdminComerciosScreen({super.key});

  @override
  ConsumerState<AdminComerciosScreen> createState() =>
      _AdminComerciosScreenState();
}

class _AdminComerciosScreenState
    extends ConsumerState<AdminComerciosScreen> {
  EstadoComercio? _estadoFiltro = EstadoComercio.pendiente;
  final _searchController = TextEditingController();
  String? _busqueda;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _setEstado(EstadoComercio? estado) {
    setState(() => _estadoFiltro = estado);
  }

  void _buscar(String valor) {
    setState(() {
      _busqueda = valor.trim().isEmpty ? null : valor.trim();
    });
  }

  @override
  Widget build(BuildContext context) {
    final params = AdminComerciosParams(
      estado: _estadoFiltro,
      busqueda: _busqueda,
    );
    final asyncComercios = ref.watch(adminComerciosProvider(params));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Comercios'),
      ),
      body: Column(
        children: [
          // --- Buscador ---
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar por nombre...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _buscar('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                isDense: true,
              ),
              onSubmitted: _buscar,
            ),
          ),

          // --- Chips de estado ---
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _estadoChip(null, 'Todos'),
                _estadoChip(EstadoComercio.pendiente, 'Pendientes'),
                _estadoChip(EstadoComercio.verificado, 'Verificados'),
                _estadoChip(EstadoComercio.rechazado, 'Rechazados'),
                _estadoChip(EstadoComercio.suspendido, 'Suspendidos'),
                _estadoChip(EstadoComercio.borrador, 'Borradores'),
              ],
            ),
          ),

          const Divider(height: 1),

          // --- Lista ---
          Expanded(
            child: asyncComercios.when(
              data: (paginated) {
                if (paginated.items.isEmpty) {
                  return const _EmptyState();
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(adminComerciosProvider);
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: paginated.items.length,
                    itemBuilder: (context, index) {
                      final c = paginated.items[index];
                      return _ComercioAdminCard(
                        comercio: c,
                        onTap: () =>
                            context.push('/admin/comercios/${c.id}'),
                      );
                    },
                  ),
                );
              },
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => _ErrorState(
                error: e.toString(),
                onRetry: () => ref.invalidate(adminComerciosProvider),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _estadoChip(EstadoComercio? estado, String label) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: _estadoFiltro == estado,
        onSelected: (_) => _setEstado(estado),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

// =========================================================
// Card del comercio
// =========================================================
class _ComercioAdminCard extends StatelessWidget {
  const _ComercioAdminCard({
    required this.comercio,
    required this.onTap,
  });

  final Comercio comercio;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _thumb(theme),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            comercio.nombre,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _EstadoBadge(estado: comercio.estado),
                      ],
                    ),
                    if (comercio.categoria != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        comercio.categoria!.nombre,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            comercio.direccion,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _thumb(ThemeData theme) {
    if (comercio.logoUrl != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          comercio.logoUrl!,
          width: 56,
          height: 56,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _thumbPlaceholder(theme),
        ),
      );
    }
    return _thumbPlaceholder(theme);
  }

  Widget _thumbPlaceholder(ThemeData theme) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.storefront,
        color: theme.colorScheme.onPrimaryContainer,
      ),
    );
  }
}

class _EstadoBadge extends StatelessWidget {
  const _EstadoBadge({required this.estado});

  final EstadoComercio? estado;

  @override
  Widget build(BuildContext context) {
    final (color, bg) = _colors();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        estado?.label ?? '-',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  (Color, Color) _colors() {
    switch (estado) {
      case EstadoComercio.verificado:
        return (Colors.green.shade800, Colors.green.shade50);
      case EstadoComercio.pendiente:
        return (Colors.orange.shade800, Colors.orange.shade50);
      case EstadoComercio.rechazado:
        return (Colors.red.shade800, Colors.red.shade50);
      case EstadoComercio.suspendido:
        return (Colors.grey.shade800, Colors.grey.shade200);
      case EstadoComercio.borrador:
      default:
        return (Colors.blueGrey.shade800, Colors.blueGrey.shade50);
    }
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No hay comercios',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Probá cambiar el filtro o la búsqueda.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error al cargar', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(error, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}