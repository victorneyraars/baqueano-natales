/// Pantalla de login.
///
/// Muestra:
/// - Logo + nombre de la app
/// - Botón "Continuar con Google"
/// - Botón "Continuar con WhatsApp" (placeholder, deshabilitado)
///
/// Al hacer login con Google, redirige automáticamente (el router
/// escucha el estado de auth).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:baqueano_natales/core/config/app_config.dart';
import 'package:baqueano_natales/features/auth/data/auth_notifier.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _isLoading = false;
  String? _lastError;

  Future<void> _handleGoogleLogin() async {
    setState(() {
      _isLoading = true;
      _lastError = null;
    });

    await ref.read(authNotifierProvider.notifier).loginWithGoogle();

    if (!mounted) return;

    // Revisar el estado después del login
    final authState = ref.read(authNotifierProvider);
    if (authState.errorMessage != null && authState.errorMessage != _lastError) {
      _lastError = authState.errorMessage;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authState.errorMessage!),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
      ref.read(authNotifierProvider.notifier).clearError();
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isClient = AppConfig.appType == AppType.client;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // --- Logo + Nombre ---
              Icon(
                isClient ? Icons.directions_car : Icons.admin_panel_settings,
                size: 100,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                AppConfig.appName,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                isClient
                    ? 'Movilidad y servicios en Puerto Natales'
                    : 'Panel de administración',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),

              const Spacer(flex: 3),

              // --- Botones de login ---
              Text(
                'Iniciá sesión para continuar',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 24),

              // Botón Google
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _handleGoogleLogin,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.login),
                  label: Text(
                    _isLoading ? 'Iniciando sesión...' : 'Continuar con Google',
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Botón WhatsApp (placeholder)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: null, // Deshabilitado por ahora
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: const Text('Continuar con WhatsApp'),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Próximamente',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),

              const Spacer(flex: 1),

              // --- Términos y condiciones ---
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  'Al continuar aceptás los términos y condiciones',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}