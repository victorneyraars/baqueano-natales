import 'dart:async';

import 'package:flutter/material.dart';
import 'package:baqueano_natales/features/oficios/domain/servicio.dart';

class ServiciosSelector extends StatefulWidget {
  final List<Servicio> servicios;
  final Servicio? seleccionado;
  final ValueChanged<Servicio> onSeleccionado;

  const ServiciosSelector({
    super.key,
    required this.servicios,
    required this.onSeleccionado,
    this.seleccionado,
  });

  @override
  State<ServiciosSelector> createState() => _ServiciosSelectorState();
}

class _ServiciosSelectorState extends State<ServiciosSelector> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() => _query = _searchCtrl.text.trim().toLowerCase());
      }
    });
  }

  List<Servicio> get _filtrados {
    if (_query.isEmpty) return widget.servicios;
    return widget.servicios.where((s) {
      final matchNombre = s.nombre.toLowerCase().contains(_query);
      final matchCat = (s.categoriaServicio ?? '').toLowerCase().contains(
        _query,
      );
      return matchNombre || matchCat;
    }).toList();
  }

  Map<String, List<Servicio>> get _agrupados {
    final map = <String, List<Servicio>>{};
    for (final s in _filtrados) {
      final cat = s.categoriaServicio ?? 'Otros';
      map.putIfAbsent(cat, () => []).add(s);
    }
    final entries = map.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return Map.fromEntries(entries);
  }

  List<Servicio> get _recomendados =>
      widget.servicios.where((s) => s.destacado).take(4).toList();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final grupos = _agrupados;
    final recomendados = _recomendados;
    final mostrarRecomendados = _query.isEmpty && recomendados.isNotEmpty;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SearchBar(
              controller: _searchCtrl,
              hintText: 'Buscar servicio...',
              leading: const Icon(Icons.search),
              elevation: const WidgetStatePropertyAll(0),
            ),
          ),
        ),
        if (mostrarRecomendados) ...[
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text(
                'Recomendados',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 100,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: recomendados.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, i) {
                  final s = recomendados[i];
                  return _TarjetaRecomendada(
                    servicio: s,
                    onTap: () => widget.onSeleccionado(s),
                  );
                },
              ),
            ),
          ),
        ],
        for (final entry in grupos.entries) ...[
          SliverPersistentHeader(
            pinned: true,
            delegate: _HeaderCategoriaDelegate(
              titulo: entry.key,
              total: entry.value.length,
              color: theme.colorScheme.surface,
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate((context, i) {
              final s = entry.value[i];
              final seleccionado = widget.seleccionado?.id == s.id;
              return ListTile(
                dense: true,
                title: Text(s.nombre),
                subtitle: Text('${s.precioLabel} · ${s.duracionLabel}'),
                trailing: seleccionado
                    ? Icon(Icons.check_circle, color: theme.colorScheme.primary)
                    : null,
                onTap: () => widget.onSeleccionado(s),
              );
            }, childCount: entry.value.length),
          ),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }
}

class _HeaderCategoriaDelegate extends SliverPersistentHeaderDelegate {
  final String titulo;
  final int total;
  final Color color;
  _HeaderCategoriaDelegate({
    required this.titulo,
    required this.total,
    required this.color,
  });

  @override
  double get minExtent => 40;
  @override
  double get maxExtent => 40;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: color,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      alignment: Alignment.centerLeft,
      child: Text(
        '$titulo ($total)',
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _HeaderCategoriaDelegate old) =>
      old.titulo != titulo || old.total != total;
}

class _TarjetaRecomendada extends StatelessWidget {
  final Servicio servicio;
  final VoidCallback onTap;
  const _TarjetaRecomendada({required this.servicio, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 220,
      child: Card(
        elevation: 0,
        color: theme.colorScheme.primaryContainer,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  servicio.nombre,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                Text(
                  '${servicio.precioLabel} · ${servicio.duracionLabel}',
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
