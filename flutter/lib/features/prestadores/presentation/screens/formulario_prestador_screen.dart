/// Formulario de creación/edición de prestador (dueño).
///
/// Modo crear: `prestadorId == null`.
/// Modo editar: carga los datos del prestador y hace PATCH.
///
/// Incluye:
/// - Información básica: nombre, categoría, descripción, años exp.
/// - Contacto: teléfono, WhatsApp, mensaje pre-armado, email, web.
/// - Ubicación: dirección.
/// - Modalidad: domicilio/local/emergencias + horario.
/// - Especialidades: chips dinámicos.
/// - Redes sociales: Instagram, Facebook, TikTok, YouTube.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:baqueano_natales/core/network/api_exceptions.dart';
import 'package:baqueano_natales/features/prestadores/data/prestador_providers.dart';
import 'package:baqueano_natales/features/prestadores/domain/categoria_oficio.dart';

class FormularioPrestadorScreen extends ConsumerStatefulWidget {
  const FormularioPrestadorScreen({super.key, this.prestadorId});

  final String? prestadorId;

  @override
  ConsumerState<FormularioPrestadorScreen> createState() =>
      _FormularioPrestadorScreenState();
}

class _FormularioPrestadorScreenState
    extends ConsumerState<FormularioPrestadorScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _nombreCtrl = TextEditingController();
  final _descripcionCtrl = TextEditingController();
  final _aniosCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _whatsappCtrl = TextEditingController();
  final _whatsappMensajeCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _sitioWebCtrl = TextEditingController();
  final _direccionCtrl = TextEditingController();
  final _horarioCtrl = TextEditingController();

  // Redes sociales
  final _instagramCtrl = TextEditingController();
  final _facebookCtrl = TextEditingController();
  final _tiktokCtrl = TextEditingController();
  final _youtubeCtrl = TextEditingController();

  // Especialidades
  final _especialidadCtrl = TextEditingController();
  final List<String> _especialidades = [];

  // Estado
  String? _categoriaId;
  bool _atiendeDomicilio = false;
  bool _atiendeLocal = true;
  bool _atiendeEmergencias = false;
  bool _guardando = false;
  bool _cargandoEdicion = false;
  String? _errorCarga;

  bool get _esEdicion => widget.prestadorId != null;

  @override
  void initState() {
    super.initState();
    if (_esEdicion) {
      _cargarPrestador();
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _descripcionCtrl.dispose();
    _aniosCtrl.dispose();
    _telefonoCtrl.dispose();
    _whatsappCtrl.dispose();
    _whatsappMensajeCtrl.dispose();
    _emailCtrl.dispose();
    _sitioWebCtrl.dispose();
    _direccionCtrl.dispose();
    _horarioCtrl.dispose();
    _instagramCtrl.dispose();
    _facebookCtrl.dispose();
    _tiktokCtrl.dispose();
    _youtubeCtrl.dispose();
    _especialidadCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarPrestador() async {
    setState(() {
      _cargandoEdicion = true;
      _errorCarga = null;
    });
    try {
      final repo = ref.read(prestadorRepositoryProvider);
      final p = await repo.obtenerMiPrestador(widget.prestadorId!);
      if (!mounted) return;
      setState(() {
        _nombreCtrl.text = p.nombre;
        _descripcionCtrl.text = p.descripcion ?? '';
        _aniosCtrl.text = p.aniosExperiencia?.toString() ?? '';
        _telefonoCtrl.text = p.telefono ?? '';
        _whatsappCtrl.text = p.whatsapp ?? '';
        _whatsappMensajeCtrl.text = p.whatsappMensaje ?? '';
        _emailCtrl.text = p.email ?? '';
        _sitioWebCtrl.text = p.sitioWeb ?? '';
        _direccionCtrl.text = p.direccion ?? '';
        _horarioCtrl.text = p.horarioDescripcion ?? '';
        _categoriaId = p.categoriaId ??
            (p.categoria.id.isNotEmpty ? p.categoria.id : null);
        _atiendeDomicilio = p.atiendeDomicilio;
        _atiendeLocal = p.atiendeLocal;
        _atiendeEmergencias = p.atiendeEmergencias;
        _especialidades.clear();
        if (p.especialidades != null) {
          _especialidades.addAll(p.especialidades!);
        }
        final redes = p.redesSociales;
        if (redes != null) {
          _instagramCtrl.text = (redes['instagram'] as String?) ?? '';
          _facebookCtrl.text = (redes['facebook'] as String?) ?? '';
          _tiktokCtrl.text = (redes['tiktok'] as String?) ?? '';
          _youtubeCtrl.text = (redes['youtube'] as String?) ?? '';
        }
        _cargandoEdicion = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _cargandoEdicion = false;
        _errorCarga = e.message;
      });
    }
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_categoriaId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Seleccioná una categoría'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _guardando = true);

    try {
      final repo = ref.read(prestadorRepositoryProvider);

      // Redes sociales (solo las que tienen valor)
      final redes = <String, String>{};
      if (_instagramCtrl.text.trim().isNotEmpty) {
        redes['instagram'] = _instagramCtrl.text.trim();
      }
      if (_facebookCtrl.text.trim().isNotEmpty) {
        redes['facebook'] = _facebookCtrl.text.trim();
      }
      if (_tiktokCtrl.text.trim().isNotEmpty) {
        redes['tiktok'] = _tiktokCtrl.text.trim();
      }
      if (_youtubeCtrl.text.trim().isNotEmpty) {
        redes['youtube'] = _youtubeCtrl.text.trim();
      }

      if (_esEdicion) {
        final cambios = <String, dynamic>{
          'nombre': _nombreCtrl.text.trim(),
          'categoria_id': _categoriaId,
          'descripcion': _nullable(_descripcionCtrl.text),
          'anios_experiencia': _parseIntOrNull(_aniosCtrl.text),
          'telefono': _nullable(_telefonoCtrl.text),
          'whatsapp': _nullable(_whatsappCtrl.text),
          'whatsapp_mensaje': _nullable(_whatsappMensajeCtrl.text),
          'email': _nullable(_emailCtrl.text),
          'sitio_web': _nullable(_sitioWebCtrl.text),
          'direccion': _nullable(_direccionCtrl.text),
          'atiende_domicilio': _atiendeDomicilio,
          'atiende_local': _atiendeLocal,
          'atiende_emergencias': _atiendeEmergencias,
          'horario_descripcion': _nullable(_horarioCtrl.text),
          'especialidades':
              _especialidades.isEmpty ? null : _especialidades,
          'redes_sociales': redes.isEmpty ? null : redes,
        };
        await repo.editarPrestador(
          id: widget.prestadorId!,
          cambios: cambios,
        );
        ref.invalidate(miPrestadorDetalleProvider(widget.prestadorId!));
        ref.invalidate(misPrestadoresProvider);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Oficio actualizado')),
        );
        context.pop();
      } else {
        final nuevo = await repo.crearPrestador(
          nombre: _nombreCtrl.text.trim(),
          categoriaId: _categoriaId!,
          descripcion: _nullable(_descripcionCtrl.text),
          aniosExperiencia: _parseIntOrNull(_aniosCtrl.text),
          telefono: _nullable(_telefonoCtrl.text),
          whatsapp: _nullable(_whatsappCtrl.text),
          whatsappMensaje: _nullable(_whatsappMensajeCtrl.text),
          email: _nullable(_emailCtrl.text),
          sitioWeb: _nullable(_sitioWebCtrl.text),
          direccion: _nullable(_direccionCtrl.text),
          atiendeDomicilio: _atiendeDomicilio,
          atiendeLocal: _atiendeLocal,
          atiendeEmergencias: _atiendeEmergencias,
          horarioDescripcion: _nullable(_horarioCtrl.text),
          especialidades:
              _especialidades.isEmpty ? null : _especialidades,
          redesSociales: redes.isEmpty ? null : redes,
        );
        ref.invalidate(misPrestadoresProvider);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Oficio creado')),
        );
        context.pop();
        context.push('/mis-prestadores/${nuevo.id}');
      }
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

  String? _nullable(String s) {
    final t = s.trim();
    return t.isEmpty ? null : t;
  }

  int? _parseIntOrNull(String s) {
    final t = s.trim();
    if (t.isEmpty) return null;
    return int.tryParse(t);
  }

  void _agregarEspecialidad() {
    final t = _especialidadCtrl.text.trim().toLowerCase();
    if (t.isEmpty) return;
    if (_especialidades.contains(t)) {
      _especialidadCtrl.clear();
      return;
    }
    setState(() {
      _especialidades.add(t);
      _especialidadCtrl.clear();
    });
  }

  void _quitarEspecialidad(String esp) {
    setState(() => _especialidades.remove(esp));
  }

  static String _humanizar(String slug) {
    if (slug.isEmpty) return slug;
    final s = slug.replaceAll('_', ' ');
    return s[0].toUpperCase() + s.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    if (_cargandoEdicion) {
      return Scaffold(
        appBar: AppBar(
          title: Text(_esEdicion ? 'Editar oficio' : 'Nuevo oficio'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorCarga != null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(_esEdicion ? 'Editar oficio' : 'Nuevo oficio'),
        ),
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
                  onPressed: _cargarPrestador,
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
        title: Text(_esEdicion ? 'Editar oficio' : 'Nuevo oficio'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            // ====================================================
            // Información básica
            // ====================================================
            const _SeccionTitulo('Información básica'),

            TextFormField(
              controller: _nombreCtrl,
              decoration: const InputDecoration(
                labelText: 'Nombre del oficio o servicio *',
                hintText: 'Ej: Taller Mecánico del Sur',
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.next,
              validator: (v) {
                final t = v?.trim() ?? '';
                if (t.isEmpty) return 'Ingresá el nombre';
                if (t.length < 3) return 'Mínimo 3 caracteres';
                if (t.length > 150) return 'Máximo 150 caracteres';
                return null;
              },
            ),
            const SizedBox(height: 16),

            _CategoriaDropdown(
              categoriaId: _categoriaId,
              onChanged: (id) => setState(() => _categoriaId = id),
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _descripcionCtrl,
              decoration: const InputDecoration(
                labelText: 'Descripción',
                hintText: 'Qué hacés, experiencia, especialidades generales',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 4,
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _aniosCtrl,
              decoration: const InputDecoration(
                labelText: 'Años de experiencia',
                hintText: 'Ej: 15',
                border: OutlineInputBorder(),
                suffixText: 'años',
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textInputAction: TextInputAction.next,
            ),

            const SizedBox(height: 24),

            // ====================================================
            // Contacto
            // ====================================================
            const _SeccionTitulo('Contacto'),

            TextFormField(
              controller: _telefonoCtrl,
              decoration: const InputDecoration(
                labelText: 'Teléfono',
                hintText: '+56912345678',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _whatsappCtrl,
              decoration: const InputDecoration(
                labelText: 'WhatsApp',
                hintText: '+56912345678',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _whatsappMensajeCtrl,
              decoration: const InputDecoration(
                labelText: 'Mensaje pre-armado de WhatsApp',
                hintText: 'Hola, necesito una cotización...',
                border: OutlineInputBorder(),
                helperText: 'Este texto se precarga al contactarte',
              ),
              maxLength: 255,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 8),

            TextFormField(
              controller: _emailCtrl,
              decoration: const InputDecoration(
                labelText: 'Email',
                hintText: 'contacto@taller.cl',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              validator: (v) {
                final t = v?.trim() ?? '';
                if (t.isEmpty) return null;
                if (!t.contains('@') || !t.contains('.')) {
                  return 'Email inválido';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _sitioWebCtrl,
              decoration: const InputDecoration(
                labelText: 'Sitio web',
                hintText: 'https://taller.cl',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.url,
            ),

            const SizedBox(height: 24),

            // ====================================================
            // Ubicación
            // ====================================================
            const _SeccionTitulo('Ubicación'),

            TextFormField(
              controller: _direccionCtrl,
              decoration: const InputDecoration(
                labelText: 'Dirección',
                hintText: 'Ej: Av. España 1234',
                border: OutlineInputBorder(),
                helperText: 'Solo si atendés en local',
              ),
              textInputAction: TextInputAction.next,
            ),

            const SizedBox(height: 24),

            // ====================================================
            // Modalidad
            // ====================================================
            const _SeccionTitulo('Modalidad de atención'),

            SwitchListTile(
              title: const Text('Atiendo a domicilio'),
              subtitle: const Text('Me traslado al cliente'),
              value: _atiendeDomicilio,
              onChanged: (v) => setState(() => _atiendeDomicilio = v),
              contentPadding: EdgeInsets.zero,
            ),
            SwitchListTile(
              title: const Text('Atiendo en local'),
              subtitle: const Text('El cliente viene a mi taller/local'),
              value: _atiendeLocal,
              onChanged: (v) => setState(() => _atiendeLocal = v),
              contentPadding: EdgeInsets.zero,
            ),
            SwitchListTile(
              title: const Text('Atiendo emergencias 24/7'),
              subtitle: const Text('Urgencias, auxilio en ruta, etc.'),
              value: _atiendeEmergencias,
              onChanged: (v) => setState(() => _atiendeEmergencias = v),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 8),

            TextFormField(
              controller: _horarioCtrl,
              decoration: const InputDecoration(
                labelText: 'Horario de atención',
                hintText: 'Ej: Lun-Vie 9:00-19:00, Sáb 9:00-14:00',
                border: OutlineInputBorder(),
              ),
              maxLength: 255,
            ),

            const SizedBox(height: 24),

            // ====================================================
            // Especialidades
            // ====================================================
            const _SeccionTitulo('Especialidades'),
            Text(
              'Agregá las especialidades específicas de tu oficio '
              '(ej: frenos, motor, suspensión).',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _especialidadCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Agregar especialidad',
                      hintText: 'Ej: frenos',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _agregarEspecialidad(),
                    textInputAction: TextInputAction.done,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _agregarEspecialidad,
                  icon: const Icon(Icons.add),
                  tooltip: 'Agregar',
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (_especialidades.isEmpty)
              Text(
                'Sin especialidades cargadas',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
              )
            else
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _especialidades
                    .map(
                      (e) => Chip(
                        label: Text(_humanizar(e)),
                        onDeleted: () => _quitarEspecialidad(e),
                        visualDensity: VisualDensity.compact,
                      ),
                    )
                    .toList(),
              ),

            const SizedBox(height: 24),

            // ====================================================
            // Redes sociales
            // ====================================================
            const _SeccionTitulo('Redes sociales'),
            Text(
              'Opcional. Agregá tus links para que los clientes '
              'vean tu trabajo.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _instagramCtrl,
              decoration: const InputDecoration(
                labelText: 'Instagram',
                hintText: 'https://instagram.com/tuperfil',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.camera_alt_outlined),
              ),
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _facebookCtrl,
              decoration: const InputDecoration(
                labelText: 'Facebook',
                hintText: 'https://facebook.com/tupagina',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.facebook),
              ),
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _tiktokCtrl,
              decoration: const InputDecoration(
                labelText: 'TikTok',
                hintText: 'https://tiktok.com/@tuperfil',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.music_note),
              ),
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _youtubeCtrl,
              decoration: const InputDecoration(
                labelText: 'YouTube',
                hintText: 'https://youtube.com/@tucanal',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.play_circle_outline),
              ),
              keyboardType: TextInputType.url,
            ),

            const SizedBox(height: 32),
          ],
        ),
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
                : Icon(_esEdicion ? Icons.save : Icons.add),
            label: Text(
              _guardando
                  ? 'Guardando...'
                  : (_esEdicion ? 'Guardar cambios' : 'Crear oficio'),
            ),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            onPressed: _guardando ? null : _guardar,
          ),
        ),
      ),
    );
  }
}

// =========================================================
// Sub-widgets
// =========================================================
class _SeccionTitulo extends StatelessWidget {
  const _SeccionTitulo(this.titulo);

  final String titulo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        titulo,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _CategoriaDropdown extends ConsumerWidget {
  const _CategoriaDropdown({
    required this.categoriaId,
    required this.onChanged,
  });

  final String? categoriaId;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncCats = ref.watch(categoriasOficioProvider);

    return asyncCats.when(
      data: (cats) {
        final idsValidos = cats.map((c) => c.id).toSet();
        final valor =
            (categoriaId != null && idsValidos.contains(categoriaId))
                ? categoriaId
                : null;

        return DropdownButtonFormField<String>(
          initialValue: valor,
          decoration: const InputDecoration(
            labelText: 'Categoría *',
            border: OutlineInputBorder(),
          ),
          items: [
            ...cats.map(
              (CategoriaOficio c) => DropdownMenuItem<String>(
                value: c.id,
                child: Row(
                  children: [
                    if (c.icono != null) ...[
                      Icon(_iconoFromName(c.icono!), size: 18),
                      const SizedBox(width: 8),
                    ],
                    Text(c.nombre),
                  ],
                ),
              ),
            ),
          ],
          onChanged: onChanged,
          validator: (v) {
            if (v == null || v.isEmpty) return 'Seleccioná una categoría';
            return null;
          },
        );
      },
      loading: () => const InputDecorator(
        decoration: InputDecoration(
          labelText: 'Categoría *',
          border: OutlineInputBorder(),
        ),
        child: SizedBox(
          height: 20,
          child: Center(
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      ),
      error: (_, __) => const InputDecorator(
        decoration: InputDecoration(
          labelText: 'Categoría *',
          border: OutlineInputBorder(),
          errorText: 'Error al cargar categorías',
        ),
        child: SizedBox(height: 20, child: Center(child: Text('—'))),
      ),
    );
  }

  static IconData _iconoFromName(String name) {
    switch (name) {
      case 'build':
        return Icons.build;
      case 'electrical_services':
        return Icons.electrical_services;
      case 'plumbing':
        return Icons.plumbing;
      case 'carpenter':
        return Icons.carpenter;
      case 'construction':
        return Icons.construction;
      case 'format_paint':
        return Icons.format_paint;
      case 'vpn_key':
        return Icons.vpn_key;
      case 'yard':
        return Icons.yard;
      case 'cleaning_services':
        return Icons.cleaning_services;
      case 'local_shipping':
        return Icons.local_shipping;
      case 'handyman':
      default:
        return Icons.handyman;
    }
  }
}