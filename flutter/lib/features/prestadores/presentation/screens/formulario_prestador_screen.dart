/// Formulario de creación/edición de prestador (dueño).
///
/// PLACEHOLDER: se completa en la próxima iteración.
library;

import 'package:flutter/material.dart';

class FormularioPrestadorScreen extends StatelessWidget {
  const FormularioPrestadorScreen({super.key, this.prestadorId});

  /// Si es null → modo crear. Si tiene ID → modo editar.
  final String? prestadorId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          prestadorId == null ? 'Nuevo oficio' : 'Editar oficio',
        ),
      ),
      body: const Center(child: Text('En construcción')),
    );
  }
}