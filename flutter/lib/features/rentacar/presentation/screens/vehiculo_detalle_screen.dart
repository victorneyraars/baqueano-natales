import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:baqueano_natales/core/network/api_exceptions.dart';
import 'package:baqueano_natales/core/network/dio_client.dart';
import 'package:baqueano_natales/features/rentacar/data/rentacar_providers.dart';
import 'package:baqueano_natales/features/rentacar/domain/vehiculo.dart';

class VehiculoDetalleScreen extends ConsumerWidget {
  const VehiculoDetalleScreen({super.key, required this.vehiculoId});

  final String vehiculoId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncVehiculos = ref.watch(misVehiculosRentacarProvider);
    return asyncVehiculos.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('Error: $e')),
      ),
      data: (vehiculos) {
        final v = vehiculos.where((x) => x.id == vehiculoId).firstOrNull;
        if (v == null) {
          return const Scaffold(
            body: Center(child: Text('Vehiculo no encontrado')),
          );
        }
        return _VehiculoDetalleBody(vehiculo: v);
      },
    );
  }
}

class _VehiculoDetalleBody extends ConsumerStatefulWidget {
  const _VehiculoDetalleBody({required this.vehiculo});
  final Vehiculo vehiculo;

  @override
  ConsumerState<_VehiculoDetalleBody> createState() =>
      _VehiculoDetalleBodyState();
}

class _VehiculoDetalleBodyState extends ConsumerState<_VehiculoDetalleBody> {
  bool _subiendo = false;

  Future<void> _subirImagen() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (picked == null) return;

    setState(() => _subiendo = true);
    try {
      // 1. Obtener presigned URL
      final res = await DioClient.instance.post(
        '/api/v1/mis-vehiculos-rentacar/${widget.vehiculo.id}/imagen/presigned',
        data: {'filename': picked.name, 'content_type': 'image/jpeg'},
      );
      final uploadUrl = res.data['upload_url'] as String;
      final objectKey = res.data['object_key'] as String;

      // 2. PUT directo a R2
      final bytes = await picked.readAsBytes();
      await Dio().put(
        uploadUrl,
        data: Stream.fromIterable([bytes]),
        options: Options(
          headers: {
            'Content-Type': 'image/jpeg',
            'Content-Length': bytes.length,
          },
        ),
      );

      // 3. Confirmar
      await DioClient.instance.post(
        '/api/v1/mis-vehiculos-rentacar/${widget.vehiculo.id}/imagen/confirmar'
        '?object_key=${Uri.encodeComponent(objectKey)}',
      );

      ref.invalidate(misVehiculosRentacarProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Imagen subida'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.message}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error inesperado: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _subiendo = false);
    }
  }

  Future<void> _eliminar() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar vehiculo?'),
        content: const Text('Esta accion no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final repo = ref.read(rentacarRepositoryProvider);
      await repo.eliminarVehiculo(widget.vehiculo.id);
      ref.invalidate(misVehiculosRentacarProvider);
      if (mounted) context.pop();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.message}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.vehiculo;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('${v.marca} ${v.modelo}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => context.push(
              '/mis-vehiculos-rentacar/${v.id}/editar',
              extra: v,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _eliminar,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AspectRatio(
            aspectRatio: 16 / 10,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: v.imagenUrl != null
                  ? Image.network(v.imagenUrl!, fit: BoxFit.cover)
                  : Container(
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: const Center(
                        child: Icon(Icons.directions_car, size: 64),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _subiendo ? null : _subirImagen,
            icon: _subiendo
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.upload),
            label: Text(_subiendo ? 'Subiendo...' : 'Cambiar imagen'),
          ),
          const SizedBox(height: 24),
          _info(theme, 'Patente', v.patente),
          _info(theme, 'Ano', v.anio.toString()),
          _info(theme, 'Categoria', v.categoria),
          _info(theme, 'Precio por dia', '\$${v.precioDia.toStringAsFixed(0)}'),
          _info(theme, 'Disponible', v.disponible ? 'Si' : 'No'),
        ],
      ),
    );
  }

  Widget _info(ThemeData theme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodyMedium),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
