import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:baqueano_natales/features/rentacar/data/rentacar_providers.dart';

class SeleccionarVehiculoCalendarioScreen extends ConsumerWidget {
  const SeleccionarVehiculoCalendarioScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncVehiculos = ref.watch(misVehiculosRentacarProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Calendario de disponibilidad')),
      body: asyncVehiculos.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (vehiculos) {
          if (vehiculos.isEmpty) {
            return const Center(child: Text('No tienes vehiculos registrados'));
          }
          return ListView.separated(
            itemCount: vehiculos.length,
            separatorBuilder: (_, _) => const Divider(),
            itemBuilder: (context, index) {
              final v = vehiculos[index];
              return ListTile(
                leading: v.imagenUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.network(
                          v.imagenUrl!,
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              const Icon(Icons.directions_car, size: 32),
                        ),
                      )
                    : const Icon(Icons.directions_car, size: 32),
                title: Text('${v.marca} ${v.modelo}'),
                subtitle: Text(v.patente),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  context.push(
                    '/calendario-disponibilidad-rentacar/detalle',
                    extra: v,
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
