import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:baqueano_natales/core/storage/secure_storage.dart';
import 'package:baqueano_natales/features/prestadores/data/prestador_providers.dart';

class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final modoAsync = ref.watch(onboardingModeProvider);
    final puedeCrear = modoAsync.maybeWhen(
      data: (m) => m == 'open',
      orElse: () => false,
    );
    return Scaffold(body: _buildBody(context, theme, puedeCrear));
  }

  Widget _buildBody(BuildContext context, ThemeData theme, bool puedeCrear) {
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [Colors.grey.shade900, Colors.black]
              : [
                  theme.colorScheme.primary.withValues(alpha: 0.1),
                  Colors.white,
                ],
        ),
      ),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Icons.handyman_rounded,
                  size: 80,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 24),
                Text(
                  'Baqueano Natales',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tu superapp de servicios locales',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 48),
                _WelcomeCard(
                  icon: Icons.person_outline_rounded,
                  title: 'Soy Cliente',
                  subtitle: 'Encontra profesionales y reserva turnos',
                  isPrimary: true,
                  onTap: () async {
                    await SecureStorageService.setHasSeenWelcome(true);
                    if (context.mounted) context.go('/home');
                  },
                ),
                const SizedBox(height: 16),
                _WelcomeCard(
                  icon: Icons.handyman_outlined,
                  title: 'Soy Prestador',
                  subtitle: puedeCrear
                      ? 'Ofrece tus servicios'
                      : 'Muy pronto disponible',
                  isPrimary: false,
                  isComingSoon: puedeCrear == false,
                  onTap: () async {
                    if (puedeCrear == false) {
                      _showComingSoonDialog(context);
                      return;
                    }
                    await SecureStorageService.setHasSeenWelcome(true);
                    if (context.mounted) context.push('/mis-prestadores/nuevo');
                  },
                ),
                const SizedBox(height: 48),
                Text(
                  'Se Alquila Marido',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Multiples oficios bajo una misma marca',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showComingSoonDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Proximamente'),
        content: const Text(
          'El registro de prestadores estara disponible muy pronto.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }
}

class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isPrimary = false,
    this.isComingSoon = false,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isPrimary;
  final bool isComingSoon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isPrimary
        ? theme.colorScheme.primary
        : theme.colorScheme.secondary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            color: isPrimary
                ? color.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isComingSoon)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Pronto',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                else
                  Icon(Icons.arrow_forward_ios, size: 16, color: color),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
