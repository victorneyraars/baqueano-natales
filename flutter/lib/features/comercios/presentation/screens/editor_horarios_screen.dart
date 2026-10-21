/// Editor de horarios de un comercio (dueño).
///
/// Permite configurar los 7 días (Lunes a Domingo) con **multi-franja**
/// (típico de restaurantes chilenos: 12-15 y 19-23).
///
/// Por cada día:
/// - Toggle "Abierto / Cerrado"
/// - Lista de franjas con hora apertura + hora cierre (picker nativo)
/// - Botón "+ Agregar franja" (si abierto)
/// - Botón eliminar por franja
///
/// Al guardar: PUT bulk replace al endpoint `/mis-comercios/{id}/horarios`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:baqueano_natales/core/network/api_exceptions.dart';
import 'package:baqueano_natales/features/comercios/data/comercio_providers.dart';

class EditorHorariosScreen extends ConsumerStatefulWidget {
  const EditorHorariosScreen({super.key, required this.comercioId});

  final String comercioId;

  @override
  ConsumerState<EditorHorariosScreen> createState() =>
      _EditorHorariosScreenState();
}

class _EditorHorariosScreenState extends ConsumerState<EditorHorariosScreen> {
  /// Mapa día → lista de franjas. día: 0=lunes ... 6=domingo.
  final Map<int, List<_FranjaDraft>> _porDia = {};

  bool _cargando = true;
  bool _guardando = false;
  String? _errorCarga;

  static const _diasSemana = [
    'Lunes',
    'Martes',
    'Miércoles',
    'Jueves',
    'Viernes',
    'Sábado',
    'Domingo',
  ];

  @override
  void initState() {
    super.initState();
    _cargarHorarios();
  }

  /// Carga los horarios actuales del comercio desde el provider del detalle.
  Future<void> _cargarHorarios() async {
    setState(() {
      _cargando = true;
      _errorCarga = null;
    });

    try {
      final repo = ref.read(comercioRepositoryProvider);
      final comercio = await repo.obtenerMiComercio(widget.comercioId);

      final porDia = <int, List<_FranjaDraft>>{};
      // Inicializar todos los días como vacíos
      for (var i = 0; i <= 6; i++) {
        porDia[i] = [];
      }
      // Poblar con los horarios existentes
      for (final h in comercio.horarios) {
        porDia
            .putIfAbsent(h.diaSemana, () => [])
            .add(
              _FranjaDraft(
                cerrado: h.cerrado,
                abre: _parseTime(h.abre),
                cierra: _parseTime(h.cierra),
              ),
            );
      }

      if (!mounted) return;
      setState(() {
        _porDia.clear();
        _porDia.addAll(porDia);
        _cargando = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _errorCarga = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _errorCarga = 'Error inesperado: $e';
      });
    }
  }

  /// Convierte "HH:MM:SS" o "HH:MM" a TimeOfDay.
  TimeOfDay? _parseTime(String? s) {
    if (s == null || s.isEmpty) return null;
    final partes = s.split(':');
    if (partes.length < 2) return null;
    final h = int.tryParse(partes[0]);
    final m = int.tryParse(partes[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  /// Convierte TimeOfDay a "HH:MM:SS" (formato del backend).
  String _formatTime(TimeOfDay t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m:00';
  }

  /// Marca el día como abierto/cerrado.
  void _toggleDia(int dia, bool abierto) {
    setState(() {
      if (!abierto) {
        // Marcarlo como cerrado: una sola franja con `cerrado=true`
        _porDia[dia] = [_FranjaDraft(cerrado: true)];
      } else {
        // Marcarlo como abierto: una franja con horario por defecto
        _porDia[dia] = [
          _FranjaDraft(
            cerrado: false,
            abre: const TimeOfDay(hour: 9, minute: 0),
            cierra: const TimeOfDay(hour: 18, minute: 0),
          ),
        ];
      }
    });
  }

  /// Agrega una franja nueva al día (con valores por defecto o copiados).
  void _agregarFranja(int dia) {
    setState(() {
      final lista = _porDia[dia]!;
      if (lista.isEmpty || lista.every((f) => f.cerrado)) {
        // Si estaba vacío o cerrado, empezar con una franja 9-18
        _porDia[dia] = [
          _FranjaDraft(
            cerrado: false,
            abre: const TimeOfDay(hour: 9, minute: 0),
            cierra: const TimeOfDay(hour: 18, minute: 0),
          ),
        ];
      } else {
        // Agregar otra franja partida con 19-23 por defecto
        lista.add(
          _FranjaDraft(
            cerrado: false,
            abre: const TimeOfDay(hour: 19, minute: 0),
            cierra: const TimeOfDay(hour: 23, minute: 0),
          ),
        );
      }
    });
  }

  /// Elimina una franja por índice.
  void _eliminarFranja(int dia, int index) {
    setState(() {
      final lista = _porDia[dia]!;
      if (lista.length > 1) {
        lista.removeAt(index);
      } else {
        // Si era la última, dejarlo como cerrado
        _porDia[dia] = [_FranjaDraft(cerrado: true)];
      }
    });
  }

  /// Actualiza la hora de apertura o cierre de una franja.
  Future<void> _editarHora(int dia, int index, bool esApertura) async {
    final franja = _porDia[dia]![index];
    final inicial = esApertura
        ? (franja.abre ?? const TimeOfDay(hour: 9, minute: 0))
        : (franja.cierra ?? const TimeOfDay(hour: 18, minute: 0));

    final picked = await showTimePicker(
      context: context,
      initialTime: inicial,
      helpText: esApertura ? 'Hora de apertura' : 'Hora de cierre',
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
    );

    if (picked == null || !mounted) return;

    setState(() {
      if (esApertura) {
        franja.abre = picked;
      } else {
        franja.cierra = picked;
      }
    });
  }

  /// Copia los horarios de un día a todos los demás (excepto sábado y domingo).
  void _copiarATodos(int diaOrigen) {
    final origen = _porDia[diaOrigen]!;
    setState(() {
      for (var i = 0; i <= 6; i++) {
        if (i == diaOrigen) continue;
        _porDia[i] = origen
            .map(
              (f) => _FranjaDraft(
                cerrado: f.cerrado,
                abre: f.abre,
                cierra: f.cierra,
              ),
            )
            .toList();
      }
    });
  }

  /// Guarda todos los horarios (bulk replace) en el backend.
  Future<void> _guardar() async {
    // Validación básica: si una franja no está cerrada, debe tener abre y cierra
    for (var dia = 0; dia <= 6; dia++) {
      for (final f in _porDia[dia]!) {
        if (!f.cerrado && (f.abre == null || f.cierra == null)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Completá abre y cierra para ${_diasSemana[dia]}'),
              backgroundColor: Colors.red.shade700,
            ),
          );
          return;
        }
      }
    }

    setState(() => _guardando = true);

    try {
      // Convertir el draft al formato del backend
      final horarios = <Map<String, dynamic>>[];
      for (var dia = 0; dia <= 6; dia++) {
        for (final f in _porDia[dia]!) {
          horarios.add({
            'dia_semana': dia,
            'cerrado': f.cerrado,
            'abre': f.cerrado || f.abre == null ? null : _formatTime(f.abre!),
            'cierra': f.cerrado || f.cierra == null
                ? null
                : _formatTime(f.cierra!),
          });
        }
      }

      final repo = ref.read(comercioRepositoryProvider);
      await repo.setearHorarios(
        comercioId: widget.comercioId,
        horarios: horarios,
      );

      ref.invalidate(miComercioDetalleProvider(widget.comercioId));
      ref.invalidate(misComerciosProvider);

      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Horarios guardados')));
      context.pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_cargando) {
      return Scaffold(
        appBar: AppBar(title: const Text('Horarios')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorCarga != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Horarios')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text(_errorCarga!, textAlign: TextAlign.center),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _cargarHorarios,
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Horarios'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'Ayuda',
            onPressed: () => _mostrarAyuda(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          // Encabezado
          Card(
            color: theme.colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Configurá cada día. Podés tener varias franjas '
                      '(ej: 12-15 y 19-23 para almuerzo y cena).',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Días
          for (var dia = 0; dia <= 6; dia++) _buildDia(theme, dia),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            icon: _guardando
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.save),
            label: Text(_guardando ? 'Guardando...' : 'Guardar horarios'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            onPressed: _guardando ? null : _guardar,
          ),
        ),
      ),
    );
  }

  Widget _buildDia(ThemeData theme, int dia) {
    final franjas = _porDia[dia]!;
    final estaCerrado = franjas.isEmpty || franjas.every((f) => f.cerrado);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- Header del día ---
            Row(
              children: [
                Expanded(
                  child: Text(
                    _diasSemana[dia],
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                // Toggle abierto/cerrado
                Switch(
                  value: !estaCerrado,
                  onChanged: (v) => _toggleDia(dia, v),
                ),
              ],
            ),

            if (!estaCerrado) ...[
              const Divider(height: 1),
              const SizedBox(height: 8),

              // --- Franjas ---
              ...List.generate(franjas.length, (index) {
                final f = franjas[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      // Hora apertura
                      Expanded(
                        child: _botonHora(
                          theme,
                          icon: Icons.login,
                          label: 'Abre',
                          hora: f.abre,
                          onTap: () => _editarHora(dia, index, true),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text('→'),
                      ),
                      // Hora cierre
                      Expanded(
                        child: _botonHora(
                          theme,
                          icon: Icons.logout,
                          label: 'Cierra',
                          hora: f.cierra,
                          onTap: () => _editarHora(dia, index, false),
                        ),
                      ),
                      const SizedBox(width: 4),
                      // Eliminar franja
                      IconButton(
                        icon: Icon(
                          Icons.close,
                          size: 18,
                          color: Colors.red.shade700,
                        ),
                        onPressed: () => _eliminarFranja(dia, index),
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Quitar franja',
                      ),
                    ],
                  ),
                );
              }),

              // Botón agregar franja
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Agregar franja'),
                  onPressed: () => _agregarFranja(dia),
                ),
              ),
            ],

            // Botón copiar a todos (solo días 0-4)
            if (dia == 0 && !estaCerrado) ...[
              const Divider(height: 1),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('Copiar a todos los días'),
                  onPressed: () => _copiarATodos(dia),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _botonHora(
    ThemeData theme, {
    required IconData icon,
    required String label,
    required TimeOfDay? hora,
    required VoidCallback onTap,
  }) {
    return OutlinedButton.icon(
      icon: Icon(icon, size: 14),
      label: Text(
        hora == null
            ? label
            : '$label ${hora.hour.toString().padLeft(2, '0')}:'
                  '${hora.minute.toString().padLeft(2, '0')}',
        style: const TextStyle(fontSize: 13),
      ),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        visualDensity: VisualDensity.compact,
      ),
      onPressed: onTap,
    );
  }

  void _mostrarAyuda(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cómo configurar horarios'),
        content: const Text(
          '• Tocá "Abre" o "Cierra" para elegir la hora.\n\n'
          '• Si tenés horario partido (ej: almuerzo y cena), '
          'tocá "Agregar franja" para sumar la segunda.\n\n'
          '• Para días cerrados, apagá el switch del día.\n\n'
          '• Podés copiar los horarios de un día a todos los demás '
          'con "Copiar a todos los días".',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }
}

/// Franja horaria en edición (draft local, no persistido).
class _FranjaDraft {
  _FranjaDraft({required this.cerrado, this.abre, this.cierra});

  bool cerrado;
  TimeOfDay? abre;
  TimeOfDay? cierra;
}
