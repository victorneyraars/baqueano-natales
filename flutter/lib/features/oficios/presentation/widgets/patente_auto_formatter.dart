import 'package:flutter/services.dart';

/// Formatter de patente chilena de auto.
///
/// Fuerza mayusculas, filtra solo [A-Z0-9] y limita a 6 caracteres.
/// No valida formato (eso lo hace el validator del campo, para no
/// bloquear el tipeo mientras el usuario escribe).
class PatenteAutoFormatter extends TextInputFormatter {
  static final _permitidos = RegExp(r'[A-Za-z0-9]');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final texto = newValue.text.toUpperCase();
    final filtrado = texto
        .split('')
        .where(_permitidos.hasMatch)
        .join();
    final recortado = filtrado.length > 6 ? filtrado.substring(0, 6) : filtrado;
    return newValue.copyWith(
      text: recortado,
      selection: TextSelection.collapsed(offset: recortado.length),
    );
  }
}
