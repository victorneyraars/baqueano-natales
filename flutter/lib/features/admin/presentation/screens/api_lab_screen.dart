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

class _ApiLabScreenState extends ConsumerState<ApiLabScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final _rutController = TextEditingController();
  final _patenteController = TextEditingController();
  String _rutResult = '{}';
  String _patenteResult = '{}';
  bool _isLoadingRut = false;
  bool _isLoadingPatente = false;

  Map<String, dynamic> _stats = {};
  List<dynamic> _events = [];
  Map<String, dynamic> _analytics = {};
  String? _historyFilterApi;
  bool? _historyFilterCached;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchStats();
    _fetchHistory();
    _fetchAnalytics();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _rutController.dispose();
    _patenteController.dispose();
    super.dispose();
  }

  Future<String?> _token() async => await SecureStorageService.getAccessToken();

  Future<void> _fetchStats() async {
    try {
      final t = await _token();
      final r = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/api/v1/integrations/stats'),
        headers: {'Authorization': 'Bearer $t'},
      );
      if (r.statusCode == 200) {
        setState(() => _stats = jsonDecode(r.body));
      }
    } catch (_) {}
  }

  Future<void> _fetchHistory() async {
    try {
      final t = await _token();
      final qp = <String, String>{'limit': '50'};
      if (_historyFilterApi != null) {
        qp['api'] = _historyFilterApi!;
      }
      if (_historyFilterCached != null) {
        qp['was_cached'] = _historyFilterCached.toString();
      }
      final uri = Uri.parse(
        '${AppConfig.apiBaseUrl}/api/v1/integrations/stats/history',
      ).replace(queryParameters: qp);
      final r = await http.get(uri, headers: {'Authorization': 'Bearer $t'});
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body);
        setState(() => _events = data['items'] as List<dynamic>);
      }
    } catch (_) {}
  }

  Future<void> _fetchAnalytics() async {
    try {
      final t = await _token();
      final r = await http.get(
        Uri.parse(
          '${AppConfig.apiBaseUrl}/api/v1/integrations/stats/analytics?days=30',
        ),
        headers: {'Authorization': 'Bearer $t'},
      );
      if (r.statusCode == 200) {
        setState(() => _analytics = jsonDecode(r.body));
      }
    } catch (_) {}
  }

  Future<void> _consultarRut() async {
    setState(() => _isLoadingRut = true);
    try {
      final t = await _token();
      final url = Uri.parse(
        '${AppConfig.apiBaseUrl}/api/v1/integrations/rut/${_rutController.text.trim()}',
      );
      final r = await http.get(url, headers: {'Authorization': 'Bearer $t'});
      final d = jsonDecode(r.body);
      setState(() {
        _rutResult = const JsonEncoder.withIndent('  ').convert(d);
        _isLoadingRut = false;
      });
      await _fetchStats();
      await _fetchHistory();
      await _fetchAnalytics();
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
      final t = await _token();
      final url = Uri.parse(
        '${AppConfig.apiBaseUrl}/api/v1/integrations/patente/${_patenteController.text.trim()}',
      );
      final r = await http.get(url, headers: {'Authorization': 'Bearer $t'});
      final d = jsonDecode(r.body);
      setState(() {
        _patenteResult = const JsonEncoder.withIndent('  ').convert(d);
        _isLoadingPatente = false;
      });
      await _fetchStats();
      await _fetchHistory();
      await _fetchAnalytics();
    } catch (e) {
      setState(() {
        _patenteResult = '{"error": "$e"}';
        _isLoadingPatente = false;
      });
    }
  }

  String _formatReset(int s) {
    if (s <= 0) return 'Ahora';
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Laboratorio de APIs'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: 'Estado'),
            Tab(icon: Icon(Icons.history), text: 'Historial'),
            Tab(icon: Icon(Icons.analytics), text: 'Análisis'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildEstadoTab(),
          _buildHistorialTab(),
          _buildAnalisisTab(),
        ],
      ),
    );
  }

  Widget _buildEstadoTab() {
    return RefreshIndicator(
      onRefresh: _fetchStats,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildStatsCard('RUT (Plan Starter)', _stats['rut'], Colors.blue),
          const SizedBox(height: 12),
          _buildStatsCard(
            'Patente (Plan Pro)',
            _stats['patente'],
            Colors.purple,
          ),
          const SizedBox(height: 24),
          _buildInputCard(
            title: 'Consultar RUT',
            controller: _rutController,
            hint: 'Ej: 16163631-2',
            onPressed: _consultarRut,
            isLoading: _isLoadingRut,
            result: _rutResult,
          ),
          const SizedBox(height: 24),
          _buildInputCard(
            title: 'Consultar Patente',
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

  Widget _buildStatsCard(
    String title,
    Map<String, dynamic>? data,
    MaterialColor color,
  ) {
    if (data == null) return const SizedBox.shrink();
    final remaining = data['remaining'] ?? '?';
    final limit = data['limit'] ?? '?';
    final apiCalls = data['api_calls'] ?? 0;
    final cachedHits = data['cached_hits'] ?? 0;
    final reset = data['reset_seconds_now'] ?? 0;
    final pct = (limit is int && remaining is int && limit > 0)
        ? (remaining / limit).clamp(0.0, 1.0)
        : 0.0;
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.api, color: color[700]),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$remaining / $limit',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: color[700],
                  ),
                ),
                Text(
                  'Reset: ${_formatReset(reset)}',
                  style: TextStyle(color: Colors.grey[700]),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: pct.toDouble(),
              backgroundColor: color[100],
              valueColor: AlwaysStoppedAnimation(color[700]),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _chip('API: $apiCalls', color),
                const SizedBox(width: 8),
                _chip('Caché: $cachedHits', Colors.green),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String text, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color[200]!),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: color[900],
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildHistorialTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Wrap(
            spacing: 8,
            children: [
              FilterChip(
                label: const Text('Todos'),
                selected:
                    _historyFilterApi == null && _historyFilterCached == null,
                onSelected: (_) {
                  setState(() {
                    _historyFilterApi = null;
                    _historyFilterCached = null;
                  });
                  _fetchHistory();
                },
              ),
              FilterChip(
                label: const Text('RUT'),
                selected: _historyFilterApi == 'rut',
                onSelected: (_) {
                  setState(() {
                    _historyFilterApi = 'rut';
                    _historyFilterCached = null;
                  });
                  _fetchHistory();
                },
              ),
              FilterChip(
                label: const Text('Patente'),
                selected: _historyFilterApi == 'patente',
                onSelected: (_) {
                  setState(() {
                    _historyFilterApi = 'patente';
                    _historyFilterCached = null;
                  });
                  _fetchHistory();
                },
              ),
              FilterChip(
                label: const Text('API'),
                selected: _historyFilterCached == false,
                onSelected: (_) {
                  setState(() {
                    _historyFilterApi = null;
                    _historyFilterCached = false;
                  });
                  _fetchHistory();
                },
              ),
              FilterChip(
                label: const Text('Caché'),
                selected: _historyFilterCached == true,
                onSelected: (_) {
                  setState(() {
                    _historyFilterApi = null;
                    _historyFilterCached = true;
                  });
                  _fetchHistory();
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _fetchHistory,
            child: _events.isEmpty
                ? Center(
                    child: Text(
                      'Sin eventos',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  )
                : ListView.separated(
                    itemCount: _events.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final e = _events[i] as Map<String, dynamic>;
                      final cached = e['was_cached'] as bool? ?? false;
                      final err = e['error_message'] as String?;
                      final created = (e['created_at'] as String?) ?? '';
                      final shortTime = created.length > 19
                          ? created.substring(11, 19)
                          : created;
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: cached
                              ? Colors.green[100]
                              : Colors.blue[100],
                          child: Icon(
                            cached ? Icons.bolt : Icons.cloud_download,
                            color: cached
                                ? Colors.green[800]
                                : Colors.blue[800],
                            size: 20,
                          ),
                        ),
                        title: Row(
                          children: [
                            Text(
                              e['api'] == 'rut' ? 'RUT' : 'Patente',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                e['input_value'] ?? '',
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            if (err != null)
                              Icon(
                                Icons.error,
                                color: Colors.red[700],
                                size: 16,
                              ),
                          ],
                        ),
                        subtitle: Text(
                          'Rem: ${e['remaining']}/${e['api_limit']} · ${e['duration_ms']}ms · $shortTime',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[700],
                          ),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: cached ? Colors.green[50] : Colors.blue[50],
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            cached ? 'CACHÉ' : 'API',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: cached
                                  ? Colors.green[800]
                                  : Colors.blue[800],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildAnalisisTab() {
    final byApi = (_analytics['by_api'] as Map<String, dynamic>?) ?? {};
    final daily = (_analytics['daily'] as List<dynamic>?) ?? [];
    final peak = _analytics['peak_hour'] as Map<String, dynamic>?;
    final rutStats = byApi['rut'] as Map<String, dynamic>? ?? {};
    final patStats = byApi['patente'] as Map<String, dynamic>? ?? {};
    return RefreshIndicator(
      onRefresh: _fetchAnalytics,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Consumo total (30 días)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  _analyticsRow('RUT', rutStats),
                  const Divider(),
                  _analyticsRow('Patente', patStats),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Hora pico',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    peak != null
                        ? 'Hora ${peak['hour']}:00 (${peak['count']} consultas)'
                        : 'Sin datos',
                    style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Consultas por día',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  if (daily.isEmpty)
                    Text('Sin datos', style: TextStyle(color: Colors.grey[600]))
                  else
                    ...daily.take(10).map((d) {
                      final m = d as Map<String, dynamic>;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 90,
                              child: Text(
                                (m['day'] as String? ?? '').substring(0, 10),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ),
                            Expanded(
                              child: LinearProgressIndicator(
                                value: ((m['count'] as int? ?? 0) / 20).clamp(
                                  0.0,
                                  1.0,
                                ),
                                minHeight: 8,
                              ),
                            ),
                            SizedBox(
                              width: 40,
                              child: Text(
                                '${m['count']}',
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _analyticsRow(String api, Map<String, dynamic> s) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            api,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            'Total: ${s['total'] ?? 0} (API: ${s['api_calls'] ?? 0}, Caché: ${s['cached_hits'] ?? 0})',
            style: const TextStyle(fontSize: 12),
          ),
          Text(
            'Ratio caché: ${s['cache_ratio_pct'] ?? 0}%  ·  Mín. remaining: ${s['min_remaining'] ?? '?'}',
            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
          ),
        ],
      ),
    );
  }

  Widget _buildInputCard({
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
                labelText: 'Valor',
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
                  fontSize: 11,
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
