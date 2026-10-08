/// Formulario de creación/edición de comercio (dueño).
///
/// PLACEHOLDER: se completa en la próxima iteración.
library;

import 'package:flutter/material.dart';

class FormularioComercioScreen extends StatelessWidget {
  const FormularioComercioScreen({super.key, this.comercioId});

  /// Si es null → modo crear. Si tiene ID → modo editar.
  final String? comercioId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(comercioId == null ? 'Nuevo comercio' : 'Editar comercio'),
      ),
      body: const Center(child: Text('En construcción')),
    );
  }
}