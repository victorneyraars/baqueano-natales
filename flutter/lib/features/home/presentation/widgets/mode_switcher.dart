import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:baqueano_natales/features/home/data/home_providers.dart';

/// Dropdown para cambiar entre 'cliente' y 'prestador'.
/// Se muestra solo cuando hasDualRole = true.
class ModeSwitcher extends ConsumerWidget {
  const ModeSwitcher({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(activeModeProvider);
    final isPrestador = mode == 'prestador';
    return PopupMenuButton<String>(
      tooltip: 'Cambiar modo',
      onSelected: (newMode) async {
        await ref.read(activeModeProvider.notifier).setMode(newMode);
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'cliente',
          child: Row(
            children: [
              Icon(
                Icons.person_outline,
                color: !isPrestador ? Colors.green : null,
              ),
              const SizedBox(width: 8),
              const Text('Modo Cliente'),
              if (!isPrestador) ...[
                const Spacer(),
                const Icon(Icons.check, size: 16, color: Colors.green),
              ],
            ],
          ),
        ),
        PopupMenuItem(
          value: 'prestador',
          child: Row(
            children: [
              Icon(
                Icons.handyman_outlined,
                color: isPrestador ? Colors.green : null,
              ),
              const SizedBox(width: 8),
              const Text('Modo Prestador'),
              if (isPrestador) ...[
                const Spacer(),
                const Icon(Icons.check, size: 16, color: Colors.green),
              ],
            ],
          ),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.only(left: 16.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isPrestador ? Icons.handyman_outlined : Icons.person_outline,
              size: 20,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                isPrestador ? 'Prestador' : 'Cliente',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            const Icon(Icons.arrow_drop_down, size: 20),
          ],
        ),
      ),
    );
  }
}
