import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:baqueano_natales/features/prestadores/data/prestador_providers.dart';
import 'package:baqueano_natales/features/prestadores/domain/prestador.dart';
import 'package:baqueano_natales/features/prestadores/domain/prestador_servicio.dart';
import 'package:baqueano_natales/features/prestadores/presentation/widgets/review_list.dart';

class DetallePrestadorScreen extends ConsumerWidget {
  const DetallePrestadorScreen({super.key, required this.slug});
  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncPrestador = ref.watch(prestadorDetalleProvider(slug));
    return asyncPrestador.when(
      data: (prestador) => _Contenido(prestador: prestador),
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
    );
  }
}

class _Contenido extends StatefulWidget {
  const _Contenido({required this.prestador});
  final Prestador prestador;

  @override
  State<_Contenido> createState() => _ContenidoState();
}

class _ContenidoState extends State<_Contenido> {
  String? _categoriaSeleccionada;

  @override
  Widget build(BuildContext context) {
    final prestador = widget.prestador;
    final theme = Theme.of(context);
    final servicios = prestador.servicios;

    // Agrupar servicios por categoria
    final categorias = <String, List<PrestadorServicio>>{};
    for (final s in servicios) {
      final cat = s.categoriaServicio ?? 'Otros';
      categorias.putIfAbsent(cat, () => []).add(s);
    }
    final catKeys = categorias.keys.toList();
    final catActual =
        _categoriaSeleccionada ?? (catKeys.isNotEmpty ? catKeys.first : null);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(prestador, theme),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoHeader(prestador, theme),
                  const SizedBox(height: 16),
                  if (prestador.descripcion != null &&
                      prestador.descripcion != '') ...[
                    Text(
                      'Sobre el servicio',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      prestador.descripcion ?? '',
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                    ),
                    const SizedBox(height: 20),
                  ],
                  _buildEspecialidades(prestador, theme),
                  const SizedBox(height: 24),
                  if (catKeys.isNotEmpty) ...[
                    Text(
                      'Servicios',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildCategoriasFilter(catKeys, catActual, theme),
                    const SizedBox(height: 16),
                    if (catActual != null)
                      ...categorias[catActual]!.map(
                        (s) => _buildServicioCard(s, theme, prestador),
                      ),
                  ],
                  const SizedBox(height: 24),
                  _buildHorarioContacto(prestador, theme),
                  const SizedBox(height: 24),
                  _buildGaleria(prestador, theme),
                  const SizedBox(height: 24),
                  _buildResenas(prestador, theme),
                  const SizedBox(height: 100), // Espacio para el bottom bar
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(prestador, theme),
    );
  }

  Widget _buildSliverAppBar(Prestador p, ThemeData theme) {
    return SliverAppBar(
      expandedHeight: 220.0,
      pinned: true,
      backgroundColor: theme.colorScheme.primary,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            p.fotoPortadaUrl != null
                ? Image.network(p.fotoPortadaUrl!, fit: BoxFit.cover)
                : Container(color: theme.colorScheme.primaryContainer),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.3),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.6),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoHeader(Prestador p, ThemeData theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.colorScheme.surface, width: 3),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
            image: DecorationImage(
              image: NetworkImage(
                p.fotoUrl ?? 'https://via.placeholder.com/150',
              ),
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      p.nombre,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (p.verificado)
                    Icon(Icons.verified, color: theme.colorScheme.primary),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.star, color: Colors.amber, size: 20),
                  const SizedBox(width: 4),
                  Text(
                    '${p.calificacionPromedio} (${p.totalResenas} reseñas)',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(width: 12),
                  Icon(
                    Icons.location_on,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  Text(p.comuna, style: theme.textTheme.bodyMedium),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  if (p.atiendeDomicilio)
                    _miniBadge('A domicilio', Icons.home, theme),
                  if (p.atiendeLocal)
                    _miniBadge('En local', Icons.store, theme),
                  if (p.atiendeEmergencias)
                    _miniBadge(
                      '24/7',
                      Icons.emergency,
                      theme,
                      color: Colors.red,
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _miniBadge(
    String text,
    IconData icon,
    ThemeData theme, {
    Color? color,
  }) {
    final c = color ?? theme.colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: c),
          const SizedBox(width: 4),
          Text(
            text,
            style: theme.textTheme.labelSmall?.copyWith(
              color: c,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEspecialidades(Prestador p, ThemeData theme) {
    if (p.especialidades == null || p.especialidades!.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Especialidades',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: p.especialidades!
              .map(
                (e) => Chip(
                  label: Text(e),
                  backgroundColor: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.5),
                  side: BorderSide.none,
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _buildCategoriasFilter(
    List<String> cats,
    String? actual,
    ThemeData theme,
  ) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: cats.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final isSelected = cats[i] == actual;
          return ChoiceChip(
            label: Text(cats[i]),
            selected: isSelected,
            onSelected: (v) => setState(() => _categoriaSeleccionada = cats[i]),
          );
        },
      ),
    );
  }

  Widget _buildServicioCard(PrestadorServicio s, ThemeData theme, Prestador p) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    s.nombre,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  s.precioLegible,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            if (s.descripcion != null) ...[
              const SizedBox(height: 4),
              Text(
                s.descripcion!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                if (s.duracionLegible != null)
                  _buildIconText(Icons.schedule, s.duracionLegible!, theme),
                const SizedBox(width: 12),
                if (s.garantiaLegible != null)
                  _buildIconText(
                    Icons.verified_user,
                    'Garantía ${s.garantiaLegible}',
                    theme,
                  ),
                const Spacer(),
                TextButton(
                  onPressed: () => context.push(
                    '/mis-prestadores/${p.id}/reservar?nombre=${Uri.encodeComponent(p.nombre)}',
                  ),
                  child: const Text('Agendar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconText(IconData icon, String text, ThemeData theme) {
    return Row(
      children: [
        Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(
          text,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildHorarioContacto(Prestador p, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (p.horarioDescripcion != null) ...[
          Text(
            'Horario',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(p.horarioDescripcion!, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 16),
        ],
        Text(
          'Contacto',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        if (p.telefono != null)
          ListTile(
            leading: const Icon(Icons.phone),
            title: Text(p.telefono!),
            contentPadding: EdgeInsets.zero,
          ),
        if (p.email != null)
          ListTile(
            leading: const Icon(Icons.email),
            title: Text(p.email!),
            contentPadding: EdgeInsets.zero,
          ),
      ],
    );
  }

  Widget _buildBottomBar(Prestador p, ThemeData theme) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 10,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          children: [
            if (p.whatsapp != null)
              Expanded(
                flex: 1,
                child: OutlinedButton.icon(
                  onPressed: () =>
                      launchUrl(Uri.parse('https://wa.me/${p.whatsapp}')),
                  icon: const Icon(Icons.chat),
                  label: const Text('WhatsApp'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                  ),
                ),
              ),
            if (p.whatsapp != null) const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                onPressed: () => context.push(
                  '/mis-prestadores/${p.id}/reservar?nombre=${Uri.encodeComponent(p.nombre)}',
                ),
                icon: const Icon(Icons.calendar_month),
                label: const Text('Reservar turno'),
                style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGaleria(Prestador p, ThemeData theme) {
    if (p.fotosTrabajos.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Trabajos recientes',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 120,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: p.fotosTrabajos.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  p.fotosTrabajos[i].url,
                  width: 120,
                  height: 120,
                  fit: BoxFit.cover,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildResenas(Prestador p, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Resenas',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        ReviewList(slug: p.slug),
      ],
    );
  }
}
