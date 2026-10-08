/// Pantalla de listado público de comercios (cliente).
///
/// Permite:
/// - Buscar por nombre/descripción.
/// - Filtrar por categoría.
/// - Filtrar por destacados / con delivery.
/// - Navegar al detalle al tocar una card.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:baqueano_natales/features/comercios/data/comercio_providers.dart';
import 'package:baqueano_natales/features/comercios/domain/categoria.dart';
import 'package:baqueano_natales/features/comercios/presentation/widgets/comercio_card.dart';

class ListaComerciosScreen extends ConsumerStatefulWidget {
  const ListaComerciosScreen({super.key});

  @override
  ConsumerState<ListaComerciosScreen> createState() =>
      _ListaComerciosScreenState();
}

class _ListaComerciosScreenState extends ConsumerState<ListaComerciosScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtros = ref.watch(comerciosFiltrosProvider);
    final comerciosAsync = ref.watch(comerciosProvider);
    final categoriasAsync = ref.watch(categoriasProvider);

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
                hintText: 'Buscar comercios...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          ref
                              .read(comerciosFiltrosProvider.notifier)
                              .setBusqueda(null);
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                isDense: true,
              ),
              onSubmitted: (value) {
                ref
                    .read(comerciosFiltrosProvider.notifier)
                    .setBusqueda(value);
              },
            ),
          ),

          // --- Chips de categorías ---
          categoriasAsync.when(
            data: (cats) => _CategoriasChips(
              categorias: cats,
              seleccionada: filtros.categoriaId,
              onSeleccionar: (id) {
                ref
                    .read(comerciosFiltrosProvider.notifier)
                    .setCategoria(id);
              },
            ),
            loading: () => const SizedBox(
              height: 48,
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
            error: (_, __) => const SizedBox(height: 8),
          ),

          // --- Chips de filtros adicionales ---
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('Destacados'),
                  selected: filtros.soloDestacados,
                  onSelected: (_) => ref
                      .read(comerciosFiltrosProvider.notifier)
                      .toggleDestacados(),
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Con delivery'),
                  selected: filtros.soloDelivery,
                  onSelected: (_) => ref
                      .read(comerciosFiltrosProvider.notifier)
                      .toggleDelivery(),
                  visualDensity: VisualDensity.compact,
                ),
                const Spacer(),
                if (filtros.hayFiltrosActivos)
                  TextButton(
                    onPressed: () {
                      _searchController.clear();
                      ref.read(comerciosFiltrosProvider.notifier).limpiar();
                    },
                    child: const Text('Limpiar'),
                  ),
              ],
            ),
          ),

          const Divider(height: 1),

          // --- Lista ---
          Expanded(
            child: comerciosAsync.when(
              data: (paginated) {
                if (paginated.items.isEmpty) {
                  return const _EmptyState();
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(comerciosProvider);
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: paginated.items.length,
                    itemBuilder: (context, index) {
                      final comercio = paginated.items[index];
                      return ComercioCard(
                        comercio: comercio,
                        onTap: () =>
                            context.push('/comercios/${comercio.slug}'),
                      );
                    },
                  ),
                );
              },
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (error, _) => _ErrorState(
                error: error.toString(),
                onRetry: () => ref.invalidate(comerciosProvider),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoriasChips extends StatelessWidget {
  const _CategoriasChips({
    required this.categorias,
    required this.seleccionada,
    required this.onSeleccionar,
  });

  final List<Categoria> categorias;
  final String? seleccionada;
  final ValueChanged<String?> onSeleccionar;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: categorias.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == 0) {
            return ChoiceChip(
              label: const Text('Todos'),
              selected: seleccionada == null,
              onSelected: (_) => onSeleccionar(null),
              visualDensity: VisualDensity.compact,
            );
          }
          final cat = categorias[index - 1];
          return ChoiceChip(
            label: Text(cat.nombre),
            selected: seleccionada == cat.id,
            onSelected: (_) => onSeleccionar(cat.id),
            visualDensity: VisualDensity.compact,
          );
        },
      ),
    );
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
              Icons.storefront_outlined,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No hay comercios disponibles',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Probá ajustar los filtros o volver más tarde.',
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