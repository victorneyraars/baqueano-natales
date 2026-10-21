#!/bin/bash
if git diff --cached --name-only | grep -q "^flutter/.*\.dart$"; then
  echo "🔍 Ejecutando dart format en flutter..."
  cd flutter
  dart format --set-exit-if-changed . > /dev/null 2>&1
  if [ $? -ne 0 ]; then
    echo "❌ ERROR: Hay archivos Dart sin formatear."
    echo "👉 Ejecutá 'cd flutter && dart format .' y volvé a intentar el commit."
    exit 1
  fi
  echo "✅ Código Dart formateado correctamente."
fi
exit 0
