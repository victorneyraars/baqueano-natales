import 'dart:convert';

/// Hash FNV-1a 32-bit, estable entre isolates y runs.
/// Retorna un entero no-negativo de 31 bits (rango válido para Android
/// notification IDs, que son enteros de 32 bits).
int stableHash32(String input) {
  var hash = 0x811c9dc5;
  for (final byte in utf8.encode(input)) {
    hash ^= byte;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return hash & 0x7FFFFFFF;
}
