/// Formulario de creación/edición de comercio (dueño).
///
/// Modo crear: `comercioId == null`.
/// Modo editar: carga los datos del comercio y hace PATCH.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:baqueano_natales/core/network/api_exceptions.dart';
import 'package:baqueano_natales/features/comercios/data/comercio_providers.dart';
import 'package:baqueano_natales/features/comercios/domain/categoria.dart';

class FormularioComercioScreen extends ConsumerStatefulWidget {
  const FormularioComercioScreen({super.key, this.comercioId});

  /// Si es null → modo crear. Si tiene ID → modo editar.
  final String? comercioId;

  @override
  ConsumerState<FormularioComercioScreen> createState() =>
      _FormularioComercioScreenState();
}

class _FormularioComercioScreenState
    extends ConsumerState<FormularioComercioScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _nombreCtrl = TextEditingController();
  final _descCortaCtrl = TextEditingController();
  final _descLargaCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _whatsappCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _sitioWebCtrl = TextEditingController();
  final _direccionCtrl = TextEditingController();
  final _referenciaCtrl = TextEditingController();
  final _costoEnvioCtrl = TextEditingController();
  final _pedidoMinimoCtrl = TextEditingController();
  final _radioEntregaCtrl = TextEditingController();
  final _tiempoPrepCtrl = TextEditingController();

  // Estado
  String? _categoriaId;
  bool _aceptaDelivery = false;
  bool _aceptaRetiro = true;
  bool _guardando = false;
  bool _cargandoEdicion = false;
  String? _errorCarga;

  bool get _esEdicion => widget.comercioId != null;

  @override
  void initState() {
    super.initState();
    if (_esEdicion) {
      _cargarComercio();
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _descCortaCtrl.dispose();
    _descLargaCtrl.dispose();
    _telefonoCtrl.dispose();
    _whatsappCtrl.dispose();
    _emailCtrl.dispose();
    _sitioWebCtrl.dispose();
    _direccionCtrl.dispose();
    _referenciaCtrl.dispose();
    _costoEnvioCtrl.dispose();
    _pedidoMinimoCtrl.dispose();
    _radioEntregaCtrl.dispose();
    _tiempoPrepCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarComercio() async {
    setState(() {
      _cargandoEdicion = true;
      _errorCarga = null;
    });
    try {
      final repo = ref.read(comercioRepositoryProvider);
      final c = await repo.obtenerMiComercio(widget.comercioId!);
      if (!mounted) return;
      setState(() {
        _nombreCtrl.text = c.nombre;
        _descCortaCtrl.text = c.descripcionCorta ?? '';
        _descLargaCtrl.text = c.descripcionLarga ?? '';
        _telefonoCtrl.text = c.telefono ?? '';
        _whatsappCtrl.text = c.whatsapp ?? '';
        _emailCtrl.text = c.email ?? '';
        _sitioWebCtrl.text = c.sitioWeb ?? '';
        _direccionCtrl.text = c.direccion;
        _referenciaCtrl.text = c.referencia ?? '';
        _categoriaId = c.categoria?.id ?? c.categoriaId;
        _aceptaDelivery = c.aceptaDelivery;
        _aceptaRetiro = c.aceptaRetiro;
        if (c.costoEnvioClp > 0) {
          _costoEnvioCtrl.text = c.costoEnvioClp.toString();
        }
        if (c.pedidoMinimoClp > 0) {
          _pedidoMinimoCtrl.text = c.pedidoMinimoClp.toString();
        }
        if (c.radioEntregaKm != null) {
          _radioEntregaCtrl.text = c.radioEntregaKm.toString();
        }
        if (c.tiempoPreparacionMin != null) {
          _tiempoPrepCtrl.text = c.tiempoPreparacionMin.toString();
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

    FocusScope.of(context).unfocus();
    setState(() => _guardando = true);

    try {
      final repo = ref.read(comercioRepositoryProvider);

      if (_esEdicion) {
        await repo.editarComercio(
          id: widget.comercioId!,
          cambios: _buildPayload(),
        );
        ref.invalidate(miComercioDetalleProvider(widget.comercioId!));
        ref.invalidate(misComerciosProvider);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Comercio actualizado')),
        );
        context.pop();
      } else {
        final nuevo = await repo.crearComercio(
          nombre: _nombreCtrl.text.trim(),
          direccion: _direccionCtrl.text.trim(),
          descripcionCorta: _nullable(_descCortaCtrl.text),
          descripcionLarga: _nullable(_descLargaCtrl.text),
          categoriaId: _categoriaId,
          telefono: _nullable(_telefonoCtrl.text),
          whatsapp: _nullable(_whatsappCtrl.text),
          email: _nullable(_emailCtrl.text),
          sitioWeb: _nullable(_sitioWebCtrl.text),
          referencia: _nullable(_referenciaCtrl.text),
          aceptaDelivery: _aceptaDelivery,
          aceptaRetiro: _aceptaRetiro,
          costoEnvioClp: _parseInt(_costoEnvioCtrl.text),
          pedidoMinimoClp: _parseInt(_pedidoMinimoCtrl.text),
        );
        ref.invalidate(misComerciosProvider);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Comercio creado')),
        );
        context.pop();
        // Reemplazamos la ruta por el detalle del nuevo
        context.push('/mis-comercios/${nuevo.id}');
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

  Map<String, dynamic> _buildPayload() {
    return {
      'nombre': _nombreCtrl.text.trim(),
      'direccion': _direccionCtrl.text.trim(),
      'descripcion_corta': _nullable(_descCortaCtrl.text),
      'descripcion_larga': _nullable(_descLargaCtrl.text),
      'categoria_id': _categoriaId,
      'telefono': _nullable(_telefonoCtrl.text),
      'whatsapp': _nullable(_whatsappCtrl.text),
      'email': _nullable(_emailCtrl.text),
      'sitio_web': _nullable(_sitioWebCtrl.text),
      'referencia': _nullable(_referenciaCtrl.text),
      'acepta_delivery': _aceptaDelivery,
      'acepta_retiro': _aceptaRetiro,
      'costo_envio_clp': _parseInt(_costoEnvioCtrl.text),
      'pedido_minimo_clp': _parseInt(_pedidoMinimoCtrl.text),
      'radio_entrega_km': _parseDouble(_radioEntregaCtrl.text),
      'tiempo_preparacion_min': _parseIntOrNull(_tiempoPrepCtrl.text),
    };
  }

  String? _nullable(String s) {
    final t = s.trim();
    return t.isEmpty ? null : t;
  }

  int _parseInt(String s) {
    final t = s.trim();
    if (t.isEmpty) return 0;
    return int.tryParse(t) ?? 0;
  }

  int? _parseIntOrNull(String s) {
    final t = s.trim();
    if (t.isEmpty) return null;
    return int.tryParse(t);
  }

  double? _parseDouble(String s) {
    final t = s.trim();
    if (t.isEmpty) return null;
    return double.tryParse(t);
  }

  @override
  Widget build(BuildContext context) {
    if (_cargandoEdicion) {
      return Scaffold(
        appBar: AppBar(
          title: Text(_esEdicion ? 'Editar comercio' : 'Nuevo comercio'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorCarga != null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(_esEdicion ? 'Editar comercio' : 'Nuevo comercio'),
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
                  onPressed: _cargarComercio,
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
        title: Text(_esEdicion ? 'Editar comercio' : 'Nuevo comercio'),
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
                labelText: 'Nombre *',
                hintText: 'Ej: La Picada de Natales',
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
              controller: _descCortaCtrl,
              decoration: const InputDecoration(
                labelText: 'Descripción corta',
                hintText: 'Ej: Comida casera con vista al fiordo',
                border: OutlineInputBorder(),
              ),
              maxLength: 300,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 8),

            TextFormField(
              controller: _descLargaCtrl,
              decoration: const InputDecoration(
                labelText: 'Descripción larga',
                hintText: 'Contá más sobre tu comercio...',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 4,
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
              controller: _emailCtrl,
              decoration: const InputDecoration(
                labelText: 'Email',
                hintText: 'contacto@comercio.cl',
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
                hintText: 'https://comercio.cl',
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
                labelText: 'Dirección *',
                hintText: 'Ej: Av. Pedro Montt 1234',
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.next,
              validator: (v) {
                final t = v?.trim() ?? '';
                if (t.isEmpty) return 'Ingresá la dirección';
                if (t.length < 3) return 'Mínimo 3 caracteres';
                return null;
              },
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _referenciaCtrl,
              decoration: const InputDecoration(
                labelText: 'Referencia',
                hintText: 'Ej: Frente a la plaza de armas',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 24),

            // ====================================================
            // Delivery
            // ====================================================
            const _SeccionTitulo('Delivery'),

            SwitchListTile(
              title: const Text('Acepta delivery'),
              subtitle: const Text('¿Hacés entregas a domicilio?'),
              value: _aceptaDelivery,
              onChanged: (v) => setState(() => _aceptaDelivery = v),
              contentPadding: EdgeInsets.zero,
            ),

            SwitchListTile(
              title: const Text('Acepta retiro en local'),
              subtitle: const Text('¿El cliente puede retirar?'),
              value: _aceptaRetiro,
              onChanged: (v) => setState(() => _aceptaRetiro = v),
              contentPadding: EdgeInsets.zero,
            ),

            if (_aceptaDelivery) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _costoEnvioCtrl,
                decoration: const InputDecoration(
                  labelText: 'Costo de envío (CLP)',
                  hintText: '0 = gratis',
                  border: OutlineInputBorder(),
                  prefixText: '\$ ',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _pedidoMinimoCtrl,
                decoration: const InputDecoration(
                  labelText: 'Pedido mínimo (CLP)',
                  hintText: '0 = sin mínimo',
                  border: OutlineInputBorder(),
                  prefixText: '\$ ',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _radioEntregaCtrl,
                decoration: const InputDecoration(
                  labelText: 'Radio de entrega (km)',
                  hintText: 'Ej: 5',
                  border: OutlineInputBorder(),
                  suffixText: 'km',
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                ],
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _tiempoPrepCtrl,
                decoration: const InputDecoration(
                  labelText: 'Tiempo de preparación',
                  hintText: 'Ej: 30',
                  border: OutlineInputBorder(),
                  suffixText: 'min',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
            ],

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
                  : (_esEdicion ? 'Guardar cambios' : 'Crear comercio'),
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
    final asyncCats = ref.watch(categoriasProvider);

    return asyncCats.when(
      data: (cats) {
        // Si el ID actual no existe en la lista, lo limpiamos para
        // evitar que DropdownButtonFormField tire error.
        final idsValidos = cats.map((c) => c.id).toSet();
        final valor =
            (categoriaId != null && idsValidos.contains(categoriaId))
                ? categoriaId
                : null;

        return DropdownButtonFormField<String>(
          initialValue: valor,
          decoration: const InputDecoration(
            labelText: 'Categoría',
            border: OutlineInputBorder(),
          ),
          items: [
            const DropdownMenuItem<String>(
              value: null,
              child: Text('Sin categoría'),
            ),
            ...cats.map(
              (Categoria c) => DropdownMenuItem<String>(
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
        );
      },
      loading: () => const InputDecorator(
        decoration: InputDecoration(
          labelText: 'Categoría',
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
      error: (_, _) => const InputDecorator(
        decoration: InputDecoration(
          labelText: 'Categoría',
          border: OutlineInputBorder(),
          errorText: 'Error al cargar categorías',
        ),
        child: SizedBox(height: 20, child: Center(child: Text('—'))),
      ),
    );
  }

  /// Mapea nombre de ícono Material a IconData.
  static IconData _iconoFromName(String name) {
    switch (name) {
      case 'restaurant':
        return Icons.restaurant;
      case 'local_cafe':
        return Icons.local_cafe;
      case 'bakery_dining':
        return Icons.bakery_dining;
      case 'storefront':
        return Icons.storefront;
      case 'local_pharmacy':
        return Icons.local_pharmacy;
      case 'hardware':
        return Icons.hardware;
      case 'handyman':
        return Icons.handyman;
      case 'spa':
        return Icons.spa;
      case 'category':
      default:
        return Icons.category;
    }
  }
}