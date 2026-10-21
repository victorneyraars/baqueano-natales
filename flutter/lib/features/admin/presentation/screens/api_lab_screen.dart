import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:baqueano_natales/core/config/app_config.dart';
import 'package:baqueano_natales/core/storage/secure_storage.dart';

class ApiLabScreen extends ConsumerStatefulWidget {
  const ApiLabScreen({super.key});

  @override
  ConsumerState<ApiLabScreen> createState() => _ApiLabScreenState();
}

class _ApiLabScreenState extends ConsumerState<ApiLabScreen> {
  final _rutController = TextEditingController();
  final _patenteController = TextEditingController();
  String _rutResult = '{}';
  String _patenteResult = '{}';
  bool _isLoadingRut = false;
  bool _isLoadingPatente = false;

  Future<void> _consultarRut() async {
    setState(() => _isLoadingRut = true);
    try {
      final token = await SecureStorageService.getAccessToken();
      final url = Uri.parse(
        '${AppConfig.apiBaseUrl}/api/v1/integrations/rut/${_rutController.text.trim()}',
      );
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );

      final decoded = jsonDecode(response.body);
      setState(() {
        _rutResult = const JsonEncoder.withIndent('  ').convert(decoded);
        _isLoadingRut = false;
      });
    } catch (e) {
      setState(() {
        _rutResult = '{"error": "$e"}';
        _isLoadingRut = false;
      });
    }
  }

  Future<void> _consultarPatente() async {
    setState(() => _isLoadingPatente = true);
    try {
      final token = await SecureStorageService.getAccessToken();
      final url = Uri.parse(
        '${AppConfig.apiBaseUrl}/api/v1/integrations/patente/${_patenteController.text.trim()}',
      );
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );

      final decoded = jsonDecode(response.body);
      setState(() {
        _patenteResult = const JsonEncoder.withIndent('  ').convert(decoded);
        _isLoadingPatente = false;
      });
    } catch (e) {
      setState(() {
        _patenteResult = '{"error": "$e"}';
        _isLoadingPatente = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Laboratorio de APIs')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildCard(
            title: 'Consultar RUT (Boostr Starter)',
            controller: _rutController,
            hint: 'Ej: 16163631-2',
            onPressed: _consultarRut,
            isLoading: _isLoadingRut,
            result: _rutResult,
          ),
          const SizedBox(height: 24),
          _buildCard(
            title: 'Consultar Patente (Boostr Pro)',
            controller: _patenteController,
            hint: 'Ej: BBBB12',
            onPressed: _consultarPatente,
            isLoading: _isLoadingPatente,
            result: _patenteResult,
          ),
        ],
      ),
    );
  }

  Widget _buildCard({
    required String title,
    required TextEditingController controller,
    required String hint,
    required VoidCallback onPressed,
    required bool isLoading,
    required String result,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: 'Valor a consultar',
                hintText: hint,
                border: const OutlineInputBorder(),
                suffixIcon: isLoading
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : IconButton(
                        icon: const Icon(Icons.search),
                        onPressed: onPressed,
                      ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                result,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: Colors.greenAccent,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
