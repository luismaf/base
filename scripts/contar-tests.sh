#!/usr/bin/env bash
# contar-tests.sh - cuantos tests pasan y cuantos fallan, desde el parte.
#
# ## Por que existe
#
# `cargo check` sin `--all-targets` NO compila el codigo de los tests. Tuvimos
# el parte en cero errores, el workspace "compilando", y `cargo test` reventando
# con 37 errores: los 1337 tests no se podian ni construir. Cero suites
# corrieron y el tablero de control decia que estaba todo bien.
#
# Que "compila" no dice nada sobre si los tests corren, y "1337 tests" no dice
# nada si ninguno se ejecuto. Este mide lo unico que importa: cuantos CORRIERON
# y cuantos pasaron.
#
# Sale "pasan fallan" o "? ?" si no puede medir. Cero suites es NO PUEDO MEDIR,
# nunca "cero fallas".
set -uo pipefail
cd "$(dirname "$0")/.."
PARTE="${1:-.latigo/errores/tests.txt}"
nomedible() { echo "? ?"; exit 3; }
[ -s "$PARTE" ] || nomedible
[ "$(find "$PARTE" -mmin -240 2>/dev/null | wc -l)" -gt 0 ] || nomedible

# Si el parte tiene errores de compilacion, los tests NO corrieron: da igual
# cuantas lineas "test result" haya de una corrida anterior mezclada.
if grep -qE '^error(\[E[0-9]+\])?[:\[]|^[^ ]+\.rs:[0-9]+:[0-9]+: error' "$PARTE"; then
  nomedible
fi

res=$(grep -E '^test result:' "$PARTE" 2>/dev/null || true)
[ -n "$res" ] || nomedible
echo "$res" | awk '{p+=$4; f+=$6} END{print p+0, f+0}'
