/// Editor del catálogo de servicios de un prestador (dueño).
///
/// PLACEHOLDER: se completa en la próxima iteración.
library;

import 'package:flutter/material.dart';

class EditorServiciosScreen extends StatelessWidget {
  const EditorServiciosScreen({super.key, required this.prestadorId});

  final String prestadorId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Servicios')),
      body: const Center(child: Text('En construcción')),
    );
  }
}