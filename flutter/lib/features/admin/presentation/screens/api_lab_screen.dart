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
  DateTimeRange? _historyDateRange;
  int _historyOffset = 0;
  int _historyTotal = 0;
  bool _historyHasMore = false;
  bool _historyLoadingMore = false;
  final ScrollController _historyScroll = ScrollController();
  static const _pageSize = 50;
  // Filtros avanzados
  String? _historyQ;
  int? _historyRemainingMin;
  int? _historyRemainingMax;
  int? _historyDurationMin;
  int? _historyDurationMax;
  bool? _historyHasError;
  String _historySortBy = 'created_at';
  String _historySortOrder = 'desc';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _historyScroll.addListener(_onHistoryScroll);
    _fetchStats();
    _fetchHistory(reset: true);
    _fetchAnalytics();
  }

  @override
  void dispose() {
    _historyScroll.removeListener(_onHistoryScroll);
    _historyScroll.dispose();
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

  Future<void> _fetchHistory({bool reset = false}) async {
    if (_historyLoadingMore) return;
    if (!reset && !_historyHasMore) return;
    if (reset) {
      setState(() {
        _events = [];
        _historyOffset = 0;
        _historyTotal = 0;
        _historyHasMore = true;
        _historyLoadingMore = false;
      });
    } else {
      setState(() => _historyLoadingMore = true);
    }
    try {
      final t = await _token();
      final qp = <String, String>{
        'limit': '$_pageSize',
        'offset': '$_historyOffset',
      };
      if (_historyFilterApi != null) {
        qp['api'] = _historyFilterApi!;
      }
      if (_historyFilterCached != null) {
        qp['was_cached'] = _historyFilterCached.toString();
      }
      if (_historyDateRange != null) {
        qp['date_from'] = _historyDateRange!.start.toUtc().toIso8601String();
        qp['date_to'] = _historyDateRange!.end.toUtc().toIso8601String();
      }
      if (_historyQ != null && _historyQ!.isNotEmpty) {
        qp['q'] = _historyQ!;
      }
      if (_historyRemainingMin != null) {
        qp['remaining_min'] = _historyRemainingMin.toString();
      }
      if (_historyRemainingMax != null) {
        qp['remaining_max'] = _historyRemainingMax.toString();
      }
      if (_historyDurationMin != null) {
        qp['duration_min'] = _historyDurationMin.toString();
      }
      if (_historyDurationMax != null) {
        qp['duration_max'] = _historyDurationMax.toString();
      }
      if (_historyHasError != null) {
        qp['has_error'] = _historyHasError.toString();
      }
      qp['sort_by'] = _historySortBy;
      qp['sort_order'] = _historySortOrder;
      final uri = Uri.parse(
        '${AppConfig.apiBaseUrl}/api/v1/integrations/stats/history',
      ).replace(queryParameters: qp);
      final r = await http.get(uri, headers: {'Authorization': 'Bearer $t'});
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body);
        final items = data['items'] as List<dynamic>;
        setState(() {
          _events = [..._events, ...items];
          _historyTotal = (data['total'] as int?) ?? items.length;
          _historyHasMore = (data['has_more'] as bool?) ?? false;
          _historyOffset = _events.length;
          _historyLoadingMore = false;
        });
      } else {
        setState(() => _historyLoadingMore = false);
      }
    } catch (_) {
      setState(() => _historyLoadingMore = false);
    }
  }

  Future<void> _loadMoreHistory() async {
    if (!_historyHasMore || _historyLoadingMore) return;
    await _fetchHistory();
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

  void _onHistoryScroll() {
    if (!_historyScroll.hasClients) return;
    if (_historyScroll.position.pixels >=
        _historyScroll.position.maxScrollExtent - 200) {
      _loadMoreHistory();
    }
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: now,
      initialDateRange: _historyDateRange,
    );
    if (picked != null) {
      setState(() => _historyDateRange = picked);
      await _fetchHistory(reset: true);
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
        _buildHistoryFilters(),
        _buildHistoryCounter(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => _fetchHistory(reset: true),
            child: _events.isEmpty
                ? ListView(
                    children: [
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.2,
                      ),
                      Center(
                        child: Text(
                          'Sin consultas registradas',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    controller: _historyScroll,
                    itemCount: _events.length + (_historyHasMore ? 1 : 0),
                    itemBuilder: (context, i) {
                      if (i >= _events.length) {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        );
                      }
                      return _buildHistoryRow(
                        _events[i] as Map<String, dynamic>,
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          FilterChip(
            label: const Text('Todas'),
            selected: _historyFilterApi == null && _historyFilterCached == null,
            onSelected: (_) {
              setState(() {
                _historyFilterApi = null;
                _historyFilterCached = null;
              });
              _fetchHistory(reset: true);
            },
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: const Text('RUT'),
            selected: _historyFilterApi == 'rut',
            onSelected: (_) {
              setState(() {
                _historyFilterApi = 'rut';
                _historyFilterCached = null;
              });
              _fetchHistory(reset: true);
            },
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: const Text('Patente'),
            selected: _historyFilterApi == 'patente',
            onSelected: (_) {
              setState(() {
                _historyFilterApi = 'patente';
                _historyFilterCached = null;
              });
              _fetchHistory(reset: true);
            },
          ),
          const SizedBox(width: 16),
          FilterChip(
            label: const Text('API'),
            selected: _historyFilterCached == false,
            onSelected: (_) {
              setState(() {
                _historyFilterApi = null;
                _historyFilterCached = false;
              });
              _fetchHistory(reset: true);
            },
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: const Text('Caché'),
            selected: _historyFilterCached == true,
            onSelected: (_) {
              setState(() {
                _historyFilterApi = null;
                _historyFilterCached = true;
              });
              _fetchHistory(reset: true);
            },
          ),
          const SizedBox(width: 16),
          ActionChip(
            avatar: const Icon(Icons.calendar_today, size: 16),
            label: Text(
              _historyDateRange == null
                  ? 'Fechas'
                  : '${_historyDateRange!.start.day}/${_historyDateRange!.start.month} - ${_historyDateRange!.end.day}/${_historyDateRange!.end.month}',
              style: const TextStyle(fontSize: 12),
            ),
            onPressed: _pickDateRange,
          ),
          if (_historyDateRange != null) ...[
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.clear, size: 18),
              onPressed: () {
                setState(() => _historyDateRange = null);
                _fetchHistory(reset: true);
              },
            ),
          ],
          const SizedBox(width: 16),
          ActionChip(
            avatar: Badge(
              isLabelVisible: _activeAdvancedFilters > 0,
              label: Text('$_activeAdvancedFilters'),
              child: const Icon(Icons.tune, size: 16),
            ),
            label: const Text(
              'Filtros avanzados',
              style: TextStyle(fontSize: 12),
            ),
            onPressed: _showAdvancedFilters,
          ),
        ],
      ),
    );
  }

  int get _activeAdvancedFilters {
    var n = 0;
    if (_historyQ != null && _historyQ!.isNotEmpty) n++;
    if (_historyRemainingMin != null || _historyRemainingMax != null) n++;
    if (_historyDurationMin != null || _historyDurationMax != null) n++;
    if (_historyHasError != null) n++;
    if (_historySortBy != 'created_at' || _historySortOrder != 'desc') n++;
    return n;
  }

  Future<void> _showAdvancedFilters() async {
    final qCtrl = TextEditingController(text: _historyQ ?? '');
    final remMinCtrl = TextEditingController(
      text: _historyRemainingMin?.toString() ?? '',
    );
    final remMaxCtrl = TextEditingController(
      text: _historyRemainingMax?.toString() ?? '',
    );
    final durMinCtrl = TextEditingController(
      text: _historyDurationMin?.toString() ?? '',
    );
    final durMaxCtrl = TextEditingController(
      text: _historyDurationMax?.toString() ?? '',
    );
    String? localHasError = _historyHasError?.toString();
    String localSortBy = _historySortBy;
    String localSortOrder = _historySortOrder;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Filtros avanzados',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: qCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Buscar texto',
                    hintText: 'Ej: 16163631 o "not found"',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Remaining (créditos restantes)',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: remMinCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Min',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: remMaxCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Max',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Duración (ms)',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: durMinCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Min',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: durMaxCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Max',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: localHasError,
                  decoration: const InputDecoration(
                    labelText: 'Estado',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('Todos')),
                    DropdownMenuItem(
                      value: 'false',
                      child: Text('Solo exitosos'),
                    ),
                    DropdownMenuItem(
                      value: 'true',
                      child: Text('Solo con error'),
                    ),
                  ],
                  onChanged: (v) => setLocal(() => localHasError = v),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: localSortBy,
                        decoration: const InputDecoration(
                          labelText: 'Ordenar por',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'created_at',
                            child: Text('Fecha'),
                          ),
                          DropdownMenuItem(
                            value: 'duration_ms',
                            child: Text('Duración'),
                          ),
                          DropdownMenuItem(
                            value: 'remaining',
                            child: Text('Remaining'),
                          ),
                        ],
                        onChanged: (v) =>
                            setLocal(() => localSortBy = v ?? 'created_at'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: localSortOrder,
                        decoration: const InputDecoration(
                          labelText: 'Orden',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: const [
                          DropdownMenuItem(value: 'desc', child: Text('Desc')),
                          DropdownMenuItem(value: 'asc', child: Text('Asc')),
                        ],
                        onChanged: (v) =>
                            setLocal(() => localSortOrder = v ?? 'desc'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          qCtrl.clear();
                          remMinCtrl.clear();
                          remMaxCtrl.clear();
                          durMinCtrl.clear();
                          durMaxCtrl.clear();
                          setLocal(() {
                            localHasError = null;
                            localSortBy = 'created_at';
                            localSortOrder = 'desc';
                          });
                        },
                        child: const Text('Limpiar'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          setState(() {
                            _historyQ = qCtrl.text.trim().isEmpty
                                ? null
                                : qCtrl.text.trim();
                            _historyRemainingMin = int.tryParse(
                              remMinCtrl.text,
                            );
                            _historyRemainingMax = int.tryParse(
                              remMaxCtrl.text,
                            );
                            _historyDurationMin = int.tryParse(durMinCtrl.text);
                            _historyDurationMax = int.tryParse(durMaxCtrl.text);
                            _historyHasError = localHasError == null
                                ? null
                                : localHasError == 'true';
                            _historySortBy = localSortBy;
                            _historySortOrder = localSortOrder;
                          });
                          Navigator.pop(context);
                          _fetchHistory(reset: true);
                        },
                        child: const Text('Aplicar'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryCounter() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Text(
            'Mostrando ${_events.length} de $_historyTotal',
            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
          ),
          const Spacer(),
          if (_historyFilterApi != null ||
              _historyFilterCached != null ||
              _historyDateRange != null)
            TextButton(
              onPressed: () {
                setState(() {
                  _historyFilterApi = null;
                  _historyFilterCached = null;
                  _historyDateRange = null;
                });
                _fetchHistory(reset: true);
              },
              child: const Text(
                'Limpiar filtros',
                style: TextStyle(fontSize: 11),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHistoryRow(Map<String, dynamic> e) {
    final cached = e['was_cached'] as bool? ?? false;
    final err = e['error_message'] as String?;
    final created = (e['created_at'] as String?) ?? '';
    final time = created.length > 19
        ? '${created.substring(8, 10)}/${created.substring(5, 7)} ${created.substring(11, 19)}'
        : created;
    final tipo = e['api'] == 'rut' ? 'RUT' : 'Pat.';
    final rem = '${e['remaining'] ?? '?'}/${e['api_limit'] ?? '?'}';
    final ms = e['duration_ms'] ?? '?';
    final origenBg = cached ? Colors.green[50] : Colors.blue[50];
    final origenFg = cached ? Colors.green[800] : Colors.blue[800];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              time,
              style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
            ),
          ),
          SizedBox(
            width: 45,
            child: Text(
              tipo,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(
              e['input_value'] ?? '',
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(
            width: 55,
            child: Text(
              rem,
              style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
            ),
          ),
          SizedBox(
            width: 50,
            child: Text(
              '${ms}ms',
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ),
          Container(
            width: 52,
            padding: const EdgeInsets.symmetric(vertical: 2),
            decoration: BoxDecoration(
              color: origenBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              cached ? 'CACHÉ' : 'API',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: origenFg,
              ),
            ),
          ),
          if (err != null)
            const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Icon(Icons.error, size: 14, color: Colors.red),
            ),
        ],
      ),
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
