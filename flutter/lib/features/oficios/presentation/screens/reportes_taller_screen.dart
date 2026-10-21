/// Pantalla de reportes del taller (M5.3).
///
/// Muestra:
/// - Selector de rango (30d / 90d / 12m / custom).
/// - KPIs en cards.
/// - Chart de barras (CustomPaint, sin dependencias externas).
/// - Top 10 servicios + Top 10 clientes.
/// - Boton de descarga de CSV (share_plus).
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:baqueano_natales/core/network/api_exceptions.dart';
import 'package:baqueano_natales/features/oficios/data/oficios_providers.dart';
import 'package:baqueano_natales/features/oficios/domain/reporte_taller.dart';

enum _RangoPreset {
  treintaDias('30d', '30 dias', 30),
  noventaDias('90d', '90 dias', 90),
  doceMeses('12m', '12 meses', 365);

  const _RangoPreset(this.value, this.label, this.dias);
  final String value;
  final String label;
  final int dias;
}

class ReportesTallerScreen extends ConsumerStatefulWidget {
  const ReportesTallerScreen({super.key, required this.prestadorId});

  final String prestadorId;

  @override
  ConsumerState<ReportesTallerScreen> createState() =>
      _ReportesTallerScreenState();
}

class _ReportesTallerScreenState extends ConsumerState<ReportesTallerScreen> {
  _RangoPreset _preset = _RangoPreset.doceMeses;
  late DateTime _desde;
  late DateTime _hasta;
  bool _descargando = false;

  @override
  void initState() {
    super.initState();
    _recalcularFechas();
  }

  /// Recalcula `_desde`/`_hasta` segun el preset actual.
  ///
  /// IMPORTANTE: los DateTime se guardan como estado (no como getters con
  /// `now()`), porque Riverpod family usa `==` para decidir si el provider
  /// es el mismo. Dos `DateTime.now()` seguidos dan valores distintos
  /// (microsegundos), lo que disparaba un loop infinito de fetches.
  void _recalcularFechas() {
    final ahora = DateTime.now();
    _hasta = ahora;
    _desde = ahora.subtract(Duration(days: _preset.dias));
  }

  ReportePrestadorParams get _params => ReportePrestadorParams(
    prestadorId: widget.prestadorId,
    desde: _desde,
    hasta: _hasta,
  );

  Future<void> _descargarCsv() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _descargando = true);
    try {
      final repo = ref.read(oficiosRepositoryProvider);
      final bytes = await repo.descargarReporteCsv(
        widget.prestadorId,
        desde: _desde,
        hasta: _hasta,
      );
      if (bytes.isEmpty) {
        throw Exception('CSV vacio');
      }
      final dir = await getTemporaryDirectory();
      final nombre =
          'reporte-${widget.prestadorId.substring(0, 8)}-'
          '${_preset.value}.csv';
      final file = File('${dir.path}/$nombre');
      await file.writeAsBytes(bytes, flush: true);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'text/csv')],
          subject: 'Reporte del taller',
        ),
      );
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _descargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(reportePrestadorProvider(_params));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reportes del taller'),
        actions: [
          IconButton(
            icon: _descargando
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download_outlined),
            tooltip: 'Descargar CSV',
            onPressed: _descargando ? null : _descargarCsv,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refrescar',
            onPressed: () => ref.invalidate(reportePrestadorProvider(_params)),
          ),
        ],
      ),
      body: Column(
        children: [
          _SelectorRango(
            preset: _preset,
            onChanged: (p) => setState(() {
              _preset = p;
              _recalcularFechas();
            }),
          ),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _ErrorView(
                error: e,
                onRetry: () =>
                    ref.invalidate(reportePrestadorProvider(_params)),
              ),
              data: (reporte) => RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(reportePrestadorProvider(_params));
                },
                child: _ContenidoReporte(reporte: reporte),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =========================================================
// Selector de rango
// =========================================================
class _SelectorRango extends StatelessWidget {
  const _SelectorRango({required this.preset, required this.onChanged});

  final _RangoPreset preset;
  final ValueChanged<_RangoPreset> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          for (final p in _RangoPreset.values) ...[
            ChoiceChip(
              label: Text(p.label),
              selected: p == preset,
              onSelected: (_) => onChanged(p),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

// =========================================================
// Contenido (lista scrollable)
// =========================================================
class _ContenidoReporte extends StatelessWidget {
  const _ContenidoReporte({required this.reporte});

  final ReportePrestador reporte;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 32),
      children: [
        _KpisGrid(kpis: reporte.kpis),
        const SizedBox(height: 20),
        if (reporte.serieMensual.isNotEmpty) ...[
          const _SeccionTitulo('Ordenes por mes'),
          const SizedBox(height: 8),
          _ChartSerieMensual(serie: reporte.serieMensual),
          const SizedBox(height: 20),
        ],
        if (reporte.topServicios.isNotEmpty) ...[
          const _SeccionTitulo('Top servicios'),
          const SizedBox(height: 4),
          for (final s in reporte.topServicios) _FilaServicio(s: s),
          const SizedBox(height: 20),
        ],
        if (reporte.topClientes.isNotEmpty) ...[
          const _SeccionTitulo('Top clientes'),
          const SizedBox(height: 4),
          for (final c in reporte.topClientes) _FilaCliente(c: c),
        ],
        if (reporte.serieMensual.isEmpty &&
            reporte.topServicios.isEmpty &&
            reporte.topClientes.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 40),
            child: Center(
              child: Text(
                'Sin actividad en el periodo seleccionado.',
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}

class _SeccionTitulo extends StatelessWidget {
  const _SeccionTitulo(this.texto);
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Text(
      texto,
      style: Theme.of(context).textTheme.titleMedium
          ?.copyWith(fontWeight: FontWeight.bold),
    );
  }
}

// =========================================================
// KPIs (grid 2 columnas)
// =========================================================
class _KpisGrid extends StatelessWidget {
  const _KpisGrid({required this.kpis});

  final ReporteKPIs kpis;

  String _fmtMoneda(double v) {
    final entero = v.toStringAsFixed(0);
    final buffer = StringBuffer();
    for (var i = 0; i < entero.length; i++) {
      if (i > 0 && (entero.length - i) % 3 == 0) buffer.write('.');
      buffer.write(entero[i]);
    }
    return '\$$buffer';
  }

  @override
  Widget build(BuildContext context) {
    final tarjetas = [
      ('Ordenes', '${kpis.totalOrdenes}', Icons.receipt_long_outlined),
      ('Ingresos', _fmtMoneda(kpis.ingresosTotales), Icons.attach_money),
      ('Ticket promedio', _fmtMoneda(kpis.ticketPromedio), Icons.trending_up),
      (
        'Aprobacion items',
        '${(kpis.tasaAprobacionItems * 100).toStringAsFixed(0)}%',
        Icons.check_circle_outline,
      ),
      if (kpis.duracionPromedioDias != null)
        (
          'Duracion prom.',
          '${kpis.duracionPromedioDias!.toStringAsFixed(1)} d',
          Icons.schedule_outlined,
        ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1.6,
      ),
      itemCount: tarjetas.length,
      itemBuilder: (context, i) {
        final (titulo, valor, icono) = tarjetas[i];
        return _TarjetaKpi(titulo: titulo, valor: valor, icono: icono);
      },
    );
  }
}

class _TarjetaKpi extends StatelessWidget {
  const _TarjetaKpi({
    required this.titulo,
    required this.valor,
    required this.icono,
  });

  final String titulo;
  final String valor;
  final IconData icono;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icono, size: 20, color: scheme.primary),
            Text(titulo, style: Theme.of(context).textTheme.bodySmall),
            Text(
              valor,
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

// =========================================================
// Chart de barras (CustomPaint)
// =========================================================
class _ChartSerieMensual extends StatelessWidget {
  const _ChartSerieMensual({required this.serie});

  final List<ReporteSerieMes> serie;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
        child: SizedBox(
          height: 160,
          child: CustomPaint(
            painter: _BarrasPainter(
              datos: serie.map((s) => s.ordenes.toDouble()).toList(),
              etiquetas: serie.map((s) => s.mes).toList(),
              colorBarra: scheme.primary,
              colorTexto: scheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

class _BarrasPainter extends CustomPainter {
  _BarrasPainter({
    required this.datos,
    required this.etiquetas,
    required this.colorBarra,
    required this.colorTexto,
  });

  final List<double> datos;
  final List<String> etiquetas;
  final Color colorBarra;
  final Color colorTexto;

  @override
  void paint(Canvas canvas, Size size) {
    if (datos.isEmpty) return;

    const paddingBottom = 20.0;
    final alto = size.height - paddingBottom;
    final maxVal = datos.reduce((a, b) => a > b ? a : b);
    final maxAbs = maxVal == 0 ? 1.0 : maxVal;
    final anchoBarra = size.width / datos.length;
    final anchoUtil = anchoBarra * 0.7;
    final offset = (anchoBarra - anchoUtil) / 2;

    final paintBarra = Paint()..color = colorBarra;
    final tp = TextPainter(textDirection: TextDirection.ltr);

    for (var i = 0; i < datos.length; i++) {
      final h = (datos[i] / maxAbs) * (alto - 8);
      final rect = Rect.fromLTWH(
        i * anchoBarra + offset,
        alto - h,
        anchoUtil,
        h,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(3)),
        paintBarra,
      );

      // Etiqueta del eje X (YYYY-MM -> MM)
      final etiqueta = etiquetas[i].length >= 7
          ? etiquetas[i].substring(5)
          : etiquetas[i];
      tp.text = TextSpan(
        text: etiqueta,
        style: TextStyle(color: colorTexto, fontSize: 9),
      );
      tp.layout();
      tp.paint(
        canvas,
        Offset(
          i * anchoBarra + anchoBarra / 2 - tp.width / 2,
          size.height - paddingBottom + 4,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BarrasPainter old) =>
      old.datos != datos ||
      old.etiquetas != etiquetas ||
      old.colorBarra != colorBarra;
}

// =========================================================
// Filas de rankings
// =========================================================
class _FilaServicio extends StatelessWidget {
  const _FilaServicio({required this.s});

  final ReporteTopServicio s;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        radius: 14,
        child: Text('${s.cantidad}', style: const TextStyle(fontSize: 12)),
      ),
      title: Text(s.descripcion, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Text(
        '\$${s.ingresosTotales.toStringAsFixed(0)}',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _FilaCliente extends StatelessWidget {
  const _FilaCliente({required this.c});

  final ReporteTopCliente c;

  @override
  Widget build(BuildContext context) {
    final nombre = c.clienteNombre ?? c.clienteId.substring(0, 8);
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: const CircleAvatar(
        radius: 14,
        child: Icon(Icons.person_outline, size: 16),
      ),
      title: Text(nombre, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text('${c.ordenes} ordenes'),
      trailing: Text(
        '\$${c.ingresosTotales.toStringAsFixed(0)}',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }
}

// =========================================================
// Error
// =========================================================
class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final msg = error is ApiException
        ? (error as ApiException).message
        : 'No se pudo cargar el reporte.';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 12),
            Text(msg, textAlign: TextAlign.center),
            const SizedBox(height: 16),
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
