/// Pantalla "Acerca de" con todos los datos de la versión actual.
library;

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:baqueano_natales/core/config/app_config.dart';

const _gitSha = String.fromEnvironment('GIT_SHA', defaultValue: 'local');

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Acerca de Baqueano')),
      body: FutureBuilder<PackageInfo>(
        future: PackageInfo.fromPlatform(),
        builder: (context, snapshot) {
          final info = snapshot.data;
          final rows = <(String, String)>[
            ('Versión', info?.version ?? '...'),
            ('Build', info?.buildNumber ?? '...'),
            ('Flavor', _flavorName()),
            ('Ambiente', AppConfig.environment.name),
            ('Tipo', AppConfig.appType.name),
            ('Commit SHA', _gitSha),
            ('API', AppConfig.apiBaseUrl),
            ('Package', info?.packageName ?? '...'),
          ];
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const SizedBox(height: 8),
              Center(
                child: Column(
                  children: [
                    const Icon(Icons.info_outline, size: 64),
                    const SizedBox(height: 12),
                    Text(
                      AppConfig.appName,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Card(
                child: Column(
                  children: [
                    for (var i = 0; i < rows.length; i++) ...[
                      ListTile(
                        dense: true,
                        title: Text(rows[i].$1),
                        trailing: SelectableText(
                          rows[i].$2,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                        ),
                      ),
                      if (i < rows.length - 1) const Divider(height: 1),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _flavorName() {
    final env = switch (AppConfig.environment) {
      Environment.dev => 'Dev',
      Environment.staging => 'Staging',
      Environment.prod => 'Prod',
    };
    final type = switch (AppConfig.appType) {
      AppType.client => 'client',
      AppType.admin => 'admin',
    };
    return '$type$env';
  }
}
