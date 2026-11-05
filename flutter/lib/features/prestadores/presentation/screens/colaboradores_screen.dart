import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:baqueano_natales/core/network/api_exceptions.dart';
import 'package:baqueano_natales/features/prestadores/data/prestador_providers.dart';
import 'package:baqueano_natales/features/prestadores/domain/colaborador.dart';

/// Pantalla de colaboradores (solo owner).
///
/// Permite:
/// - Ver colaboradores activos + invitaciones pendientes
/// - Invitar por email (envía email con link firmado 7d)
/// - Eliminar colaboradores
class ColaboradoresScreen extends ConsumerWidget {
  const ColaboradoresScreen({super.key, required this.prestadorId});
  final String prestadorId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(colaboradoresProvider(prestadorId));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Colaboradores'),
        actions: [
          IconButton(
            tooltip: 'Recargar',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(colaboradoresProvider(prestadorId)),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirInvitar(context, ref),
        icon: const Icon(Icons.person_add),
        label: const Text('Invitar'),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _errorView(context, ref, e),
        data: (items) => _lista(context, ref, items),
      ),
    );
  }

  Widget _errorView(BuildContext context, WidgetRef ref, Object error) {
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
              onPressed: () =>
                  ref.invalidate(colaboradoresProvider(prestadorId)),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _lista(BuildContext context, WidgetRef ref, List<Colaborador> items) {
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.group_outlined, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text(
                'No hay colaboradores todavia',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Invita a alguien de confianza para que te ayude con la gestion',
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
        ref.invalidate(colaboradoresProvider(prestadorId));
        await ref.read(colaboradoresProvider(prestadorId).future);
      },
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (_, i) => _colaboradorCard(context, ref, items[i]),
      ),
    );
  }

  Widget _colaboradorCard(BuildContext context, WidgetRef ref, Colaborador c) {
    final activo = c.activo;
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: activo
              ? Colors.green.shade100
              : Colors.amber.shade100,
          child: Text(
            c.nombre.isNotEmpty ? c.nombre[0].toUpperCase() : '?',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: activo ? Colors.green.shade800 : Colors.amber.shade800,
            ),
          ),
        ),
        title: Text(
          c.nombre,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(c.email, style: TextStyle(color: Colors.grey.shade600)),
            if (c.whatsapp != null && c.whatsapp!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Row(
                children: [
                  Icon(Icons.phone, size: 12, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    c.whatsapp!,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 4),
            Chip(
              label: Text(activo ? 'Activo' : 'Pendiente'),
              backgroundColor: activo
                  ? Colors.green.shade50
                  : Colors.amber.shade50,
              labelStyle: TextStyle(
                color: activo ? Colors.green.shade800 : Colors.amber.shade800,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!activo)
              IconButton(
                icon: const Icon(Icons.send, color: Colors.blue),
                tooltip: 'Reenviar invitación',
                onPressed: () => _reenviar(context, ref, c),
              ),
            if (activo)
              IconButton(
                icon: const Icon(Icons.settings, color: Colors.grey),
                tooltip: 'Editar permisos',
                onPressed: () => _abrirPermisos(context, ref, c),
              ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              tooltip: 'Eliminar colaborador',
              onPressed: () => _eliminar(context, ref, c),
            ),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }

  Future<void> _abrirInvitar(BuildContext context, WidgetRef ref) async {
    final emailCtrl = TextEditingController();
    final nombreCtrl = TextEditingController();
    final whatsappCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Invitar colaborador'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nombreCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nombre',
                  hintText: 'Juan Perez',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v ?? '').trim().length < 2 ? 'Minimo 2 caracteres' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  hintText: 'juan@email.com',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  final s = (v ?? '').trim();
                  if (!RegExp(r'^[\w\.\-]+@[\w\.\-]+\.\w+$').hasMatch(s)) {
                    return 'Email invalido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: whatsappCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'WhatsApp (opcional)',
                  hintText: '+56912345678',
                  helperText: 'Para notificaciones de reservas por WhatsApp',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) Navigator.pop(ctx, true);
            },
            child: const Text('Enviar invitacion'),
          ),
        ],
      ),
    );

    if (ok == true && context.mounted) {
      try {
        final repo = ref.read(prestadorRepositoryProvider);
        final whatsappText = whatsappCtrl.text.trim();
        await repo.invitarColaborador(
          prestadorId: prestadorId,
          email: emailCtrl.text.trim().toLowerCase(),
          nombre: nombreCtrl.text.trim(),
          whatsapp: whatsappText.isEmpty ? null : whatsappText,
        );
        ref.invalidate(colaboradoresProvider(prestadorId));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Invitacion enviada. El colaborador recibira un email.',
              ),
            ),
          );
        }
      } on ApiException catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.message), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _abrirPermisos(
    BuildContext context,
    WidgetRef ref,
    Colaborador c,
  ) async {
    final seleccionados = List<String>.from(c.permisos);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text('Permisos de ${c.nombre}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CheckboxListTile(
                  title: const Text('Gestionar Calendario'),
                  value: seleccionados.contains('gestionar_calendario'),
                  onChanged: (val) {
                    setState(() {
                      if (val == true) {
                        seleccionados.add('gestionar_calendario');
                      } else {
                        seleccionados.remove('gestionar_calendario');
                      }
                    });
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Guardar'),
              ),
            ],
          );
        },
      ),
    );
    if (ok == true && context.mounted) {
      try {
        await ref
            .read(prestadorRepositoryProvider)
            .actualizarPermisosColaborador(
              prestadorId: prestadorId,
              email: c.email,
              permisos: seleccionados,
            );
        ref.invalidate(colaboradoresProvider(prestadorId));
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Permisos actualizados')));
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _reenviar(
    BuildContext context,
    WidgetRef ref,
    Colaborador c,
  ) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Reenviando invitación...'),
        duration: Duration(seconds: 1),
      ),
    );
    try {
      final repo = ref.read(prestadorRepositoryProvider);
      await repo.reenviarInvitacion(prestadorId: prestadorId, email: c.email);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invitación reenviada con éxito.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _eliminar(
    BuildContext context,
    WidgetRef ref,
    Colaborador c,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar colaborador?'),
        content: Text(
          'Se eliminara a ${c.nombre} (${c.email}). No podra acceder mas.',
        ),
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
    if (ok != true) return;
    try {
      final repo = ref.read(prestadorRepositoryProvider);
      await repo.eliminarColaborador(prestadorId: prestadorId, email: c.email);
      ref.invalidate(colaboradoresProvider(prestadorId));
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.red),
        );
      }
    }
  }
}
