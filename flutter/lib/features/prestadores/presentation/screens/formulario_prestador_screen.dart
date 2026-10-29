import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:baqueano_natales/core/network/api_exceptions.dart';
import 'package:baqueano_natales/features/prestadores/data/prestador_providers.dart';
import 'package:baqueano_natales/features/prestadores/domain/perfil_negocio.dart';
import 'package:baqueano_natales/features/prestadores/domain/perfil_negocio_copy.dart';
import 'package:baqueano_natales/features/prestadores/domain/prestador_form_state.dart';
import 'package:baqueano_natales/features/prestadores/presentation/widgets/perfil_negocio/seccion_atributos.dart';
import 'package:baqueano_natales/features/prestadores/presentation/widgets/perfil_negocio/seccion_datos_fiscales.dart';
import 'package:baqueano_natales/features/prestadores/presentation/widgets/perfil_negocio/seccion_fotos.dart';
import 'package:baqueano_natales/features/prestadores/presentation/widgets/perfil_negocio/seccion_gbp.dart';
import 'package:baqueano_natales/features/prestadores/presentation/widgets/perfil_negocio/seccion_horario.dart';
import 'package:baqueano_natales/features/prestadores/presentation/widgets/perfil_negocio/seccion_redes.dart';
import 'package:baqueano_natales/features/prestadores/presentation/widgets/perfil_negocio/seccion_reserva.dart';
import 'package:baqueano_natales/features/prestadores/presentation/widgets/perfil_negocio/seccion_ubicacion.dart';

/// Form unificado de prestador (crear / editar).
///
/// Cambios clave respecto a v1:
/// - Modelo de estado: PrestadorFormState (inmutable)
/// - 8 secciones del perfil_negocio como widgets separados
/// - ExpansionTile colapsables con maintainState: true
/// - Submit envía perfil_negocio completo al backend
class FormularioPrestadorScreen extends ConsumerStatefulWidget {
  const FormularioPrestadorScreen({super.key, this.prestadorId});

  /// null = crear nuevo, no-null = editar existente.
  final String? prestadorId;

  @override
  ConsumerState<FormularioPrestadorScreen> createState() =>
      _FormularioPrestadorScreenState();
}

class _FormularioPrestadorScreenState
    extends ConsumerState<FormularioPrestadorScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers de campos planos (los que quedan en el form)
  final _nombreCtrl = TextEditingController();
  final _descripcionCtrl = TextEditingController();
  final _aniosCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _whatsappCtrl = TextEditingController();
  final _whatsappMensajeCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _sitioWebCtrl = TextEditingController();
  final _especialidadCtrl = TextEditingController();

  // Controllers de campos nuevos (van al Prestador, no al perfil_negocio)
  final _razonSocialCtrl = TextEditingController();
  final _rutCtrl = TextEditingController();
  final _precioDesdeCtrl = TextEditingController();

  // Estado del perfil de negocio (JSONB)
  PerfilNegocio _perfilNegocio = const PerfilNegocio();
  String? _gbpPlaceId;
  String? _gbpMapsUrl;

  // Estado simple
  String? _categoriaId;
  final List<String> _especialidades = [];
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
    _especialidadCtrl.dispose();
    _razonSocialCtrl.dispose();
    _rutCtrl.dispose();
    _precioDesdeCtrl.dispose();
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
      final state = PrestadorFormState.fromPrestador(p);
      setState(() {
        _nombreCtrl.text = state.nombre;
        _descripcionCtrl.text = state.descripcion ?? '';
        _aniosCtrl.text = state.aniosExperiencia?.toString() ?? '';
        _telefonoCtrl.text = state.telefono ?? '';
        _whatsappCtrl.text = state.whatsapp ?? '';
        _whatsappMensajeCtrl.text = state.whatsappMensaje ?? '';
        _emailCtrl.text = state.email ?? '';
        _sitioWebCtrl.text = state.sitioWeb ?? '';
        _razonSocialCtrl.text = state.razonSocial ?? '';
        _rutCtrl.text = state.rutEmpresa ?? '';
        _precioDesdeCtrl.text = state.precioDesde?.toString() ?? '';
        _gbpPlaceId = state.gbpPlaceId;
        _gbpMapsUrl = state.gbpMapsUrl;
        _perfilNegocio = state.perfilNegocio;
        _categoriaId =
            state.categoriaId ??
            (p.categoria.id.isNotEmpty ? p.categoria.id : null);
        _atiendeDomicilio = p.atiendeDomicilio;
        _atiendeLocal = p.atiendeLocal;
        _atiendeEmergencias = p.atiendeEmergencias;
        _especialidades
          ..clear()
          ..addAll(state.especialidades);
        _cargandoEdicion = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _cargandoEdicion = false;
        _errorCarga = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargandoEdicion = false;
        _errorCarga = 'Error al cargar: $e';
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
      final state = PrestadorFormState(
        nombre: _nombreCtrl.text.trim(),
        categoriaId: _categoriaId,
        descripcion: _nullable(_descripcionCtrl.text),
        aniosExperiencia: _parseIntOrNull(_aniosCtrl.text),
        telefono: _nullable(_telefonoCtrl.text),
        whatsapp: _nullable(_whatsappCtrl.text),
        whatsappMensaje: _nullable(_whatsappMensajeCtrl.text),
        email: _nullable(_emailCtrl.text),
        sitioWeb: _nullable(_sitioWebCtrl.text),
        razonSocial: _nullable(_razonSocialCtrl.text),
        rutEmpresa: _nullable(_rutCtrl.text),
        gbpPlaceId: _gbpPlaceId,
        gbpMapsUrl: _gbpMapsUrl,
        precioDesde: double.tryParse(_precioDesdeCtrl.text.trim()),
        brandKitSlug: null,
        especialidades: List.from(_especialidades),
        perfilNegocio: _perfilNegocio,
      );

      if (_esEdicion) {
        await repo.editarPrestador(
          id: widget.prestadorId!,
          cambios: state.toJson(),
        );
        ref.invalidate(miPrestadorDetalleProvider(widget.prestadorId!));
        ref.invalidate(misPrestadoresProvider);
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Oficio actualizado')));
        context.pop();
      } else {
        final nuevo = await repo.crearPrestador(
          nombre: state.nombre,
          categoriaId: _categoriaId!,
          descripcion: state.descripcion,
          aniosExperiencia: state.aniosExperiencia,
          telefono: state.telefono,
          whatsapp: state.whatsapp,
          whatsappMensaje: state.whatsappMensaje,
          email: state.email,
          sitioWeb: state.sitioWeb,
          direccion: null,
          atiendeDomicilio: _atiendeDomicilio,
          atiendeLocal: _atiendeLocal,
          atiendeEmergencias: _atiendeEmergencias,
          horarioDescripcion: null,
          especialidades: state.especialidades.isEmpty
              ? null
              : state.especialidades,
          redesSociales: null,
        );
        ref.invalidate(misPrestadoresProvider);
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Oficio creado')));
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
            _seccionDatosBasicos(),
            _seccionContacto(),
            if (_esEdicion) ...[
              _seccionDatosFiscales(),
              _seccionUbicacion(),
              _seccionHorario(),
              _seccionAtributos(),
              _seccionGbp(),
              _seccionRedes(),
              _seccionReserva(),
              _seccionFotos(),
            ],
          ],
        ),
      ),
      bottomNavigationBar: _barraGuardar(),
    );
  }

  Widget _seccionDatosBasicos() {
    return ExpansionTile(
      key: const PageStorageKey('seccion_datos_basicos'),
      maintainState: true,
      initiallyExpanded: true,
      title: const Text('Información básica'),
      children: [
        TextFormField(
          controller: _nombreCtrl,
          decoration: const InputDecoration(
            labelText: 'Nombre del oficio o servicio *',
          ),
          validator: (v) =>
              (v == null || v.trim().length < 3) ? 'Mínimo 3 caracteres' : null,
        ),
        const SizedBox(height: 12),
        _CategoriaDropdown(
          initialValue: _categoriaId,
          onChanged: (v) => setState(() => _categoriaId = v),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _descripcionCtrl,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Descripción'),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _aniosCtrl,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(labelText: 'Años de experiencia'),
        ),
        const SizedBox(height: 16),
        Text('Especialidades', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        _chipsEspecialidades(),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _especialidadCtrl,
                decoration: const InputDecoration(
                  labelText: 'Agregar especialidad',
                ),
                onSubmitted: (_) => _agregarEspecialidad(),
              ),
            ),
            IconButton.filled(
              onPressed: _agregarEspecialidad,
              icon: const Icon(Icons.add),
            ),
          ],
        ),
      ],
    );
  }

  Widget _seccionContacto() {
    return ExpansionTile(
      key: const PageStorageKey('seccion_contacto'),
      maintainState: true,
      title: const Text('Contacto'),
      children: [
        TextFormField(
          controller: _telefonoCtrl,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: 'Teléfono'),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _whatsappCtrl,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: 'WhatsApp'),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _whatsappMensajeCtrl,
          maxLength: 255,
          decoration: const InputDecoration(
            labelText: 'Mensaje pre-armado de WhatsApp',
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Email'),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _sitioWebCtrl,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(labelText: 'Sitio web'),
        ),
      ],
    );
  }

  Widget _seccionDatosFiscales() {
    return ExpansionTile(
      key: const PageStorageKey('seccion_datos_fiscales'),
      maintainState: true,
      title: const Text('Datos fiscales'),
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: SeccionDatosFiscales(
            initialRazonSocial: _razonSocialCtrl.text.isEmpty
                ? null
                : _razonSocialCtrl.text,
            initialRut: _rutCtrl.text.isEmpty ? null : _rutCtrl.text,
            initialPrecioDesde: double.tryParse(_precioDesdeCtrl.text.trim()),
            onRazonSocialChanged: (v) {
              _razonSocialCtrl.text = v ?? '';
            },
            onRutChanged: (v) {
              _rutCtrl.text = v ?? '';
            },
            onPrecioDesdeChanged: (v) {
              _precioDesdeCtrl.text = v?.toString() ?? '';
            },
          ),
        ),
      ],
    );
  }

  Widget _seccionUbicacion() {
    return ExpansionTile(
      key: const PageStorageKey('seccion_ubicacion'),
      maintainState: true,
      title: const Text('Ubicación'),
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: SeccionUbicacion(
            initialDireccion: _perfilNegocio.direccionEstructurada,
            initialCoordenadas: _perfilNegocio.coordenadas,
            onDireccionChanged: (d) {
              setState(() {
                _perfilNegocio = _perfilNegocio.copyWith(
                  direccionEstructurada: d,
                );
              });
            },
            onCoordenadasChanged: (c) {
              setState(() {
                _perfilNegocio = _perfilNegocio.copyWith(coordenadas: c);
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _seccionHorario() {
    return ExpansionTile(
      key: const PageStorageKey('seccion_horario'),
      maintainState: true,
      title: const Text('Horario de atención'),
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: SeccionHorario(
            initialValue: _perfilNegocio.horario,
            onChanged: (h) {
              setState(() {
                _perfilNegocio = _perfilNegocio.copyWith(horario: h);
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _seccionAtributos() {
    return ExpansionTile(
      key: const PageStorageKey('seccion_atributos'),
      maintainState: true,
      title: const Text('Atributos del negocio'),
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: SeccionAtributos(
            initialValue: _perfilNegocio.atributos,
            onChanged: (a) {
              setState(() {
                _perfilNegocio = _perfilNegocio.copyWith(atributos: a);
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _seccionGbp() {
    return ExpansionTile(
      key: const PageStorageKey('seccion_gbp'),
      maintainState: true,
      title: const Text('Google Business Profile'),
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: SeccionGbp(
            initialPlaceId: _gbpPlaceId,
            initialMapsUrl: _gbpMapsUrl,
            onPlaceIdChanged: (v) => setState(() => _gbpPlaceId = v),
            onMapsUrlChanged: (v) => setState(() => _gbpMapsUrl = v),
          ),
        ),
      ],
    );
  }

  Widget _seccionRedes() {
    return ExpansionTile(
      key: const PageStorageKey('seccion_redes'),
      maintainState: true,
      title: const Text('Redes sociales'),
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: SeccionRedes(
            initialValue: _perfilNegocio.redes,
            onChanged: (r) {
              setState(() {
                _perfilNegocio = _perfilNegocio.copyWith(redes: r);
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _seccionReserva() {
    return ExpansionTile(
      key: const PageStorageKey('seccion_reserva'),
      maintainState: true,
      title: const Text('Reservas'),
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: SeccionReserva(
            initialValue: _perfilNegocio.reserva,
            onChanged: (r) {
              setState(() {
                _perfilNegocio = _perfilNegocio.copyWith(reserva: r);
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _seccionFotos() {
    return ExpansionTile(
      key: const PageStorageKey('seccion_fotos'),
      maintainState: true,
      title: const Text('Fotos'),
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: SeccionFotos(initialValue: _perfilNegocio.fotos),
        ),
      ],
    );
  }

  Widget _chipsEspecialidades() {
    if (_especialidades.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'Sin especialidades cargadas',
          style: TextStyle(fontStyle: FontStyle.italic),
        ),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _especialidades
          .map(
            (e) => Chip(
              label: Text(_humanizar(e)),
              onDeleted: () => _quitarEspecialidad(e),
            ),
          )
          .toList(),
    );
  }

  Widget _barraGuardar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: FilledButton.icon(
          onPressed: _guardando ? null : _guardar,
          icon: _guardando
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save),
          label: Text(_guardando ? 'Guardando...' : 'Guardar cambios'),
          style: FilledButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
          ),
        ),
      ),
    );
  }
}

/// Dropdown de categorías con carga desde el backend.
///
/// Recibe `initialValue` (categoriaId actual) y notifica cambios
/// via `onChanged` para que el padre actualice su estado.
class _CategoriaDropdown extends ConsumerWidget {
  const _CategoriaDropdown({
    required this.initialValue,
    required this.onChanged,
  });

  final String? initialValue;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncCats = ref.watch(categoriasOficioProvider);

    return asyncCats.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text(
        'Error al cargar categorías: $e',
        style: const TextStyle(color: Colors.red),
      ),
      data: (cats) {
        final activas = cats.where((c) => c.activo).toList();
        final current = activas.any((c) => c.id == initialValue)
            ? initialValue
            : null;
        return DropdownButtonFormField<String>(
          initialValue: current,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Categoría *'),
          items: activas
              .map((c) => DropdownMenuItem(value: c.id, child: Text(c.nombre)))
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
          validator: (v) => v == null ? 'Seleccioná una categoría' : null,
        );
      },
    );
  }
}
