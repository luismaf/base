#!/usr/bin/env bash
# contar-errores.sh - cuenta errores de compilacion desde el parte de cargo.
#
# ## Por que existe
#
# La puerta leia `.latigo/errores/ultimo-conteo`, un numero que escribia el
# propio compilador. Un solo sensor, y encima en manos del interesado. El dia
# que el compilador paso a `--message-format short`, un `grep -c '^error'`
# conto 1 donde habia 31 -la unica linea que empieza con "error" en ese formato
# es el resumen- y la puerta estuvo a un paso de abrirse con el workspace roto.
# Instrumento roto, buena noticia, compuerta abierta: el patron completo.
#
# Este cuenta solo, entiende los dos formatos de cargo, y ante discrepancia
# **se queda con el numero MAS ALTO**. Equivocarse hacia arriba cuesta una
# vuelta de mas; hacia abajo cuesta dar por terminado algo que no compila.
#
# Sale por stdout el numero, o "?" si no puede medir. Nunca 0 por no saber.
set -uo pipefail
cd "$(dirname "$0")/.."
PARTE="${1:-.latigo/errores/actual.txt}"

nomedible() { echo "?"; exit 3; }
[ -s "$PARTE" ] || nomedible
# Un parte de hace tres horas no habla del codigo de ahora.
[ "$(find "$PARTE" -mmin -180 2>/dev/null | wc -l)" -gt 0 ] || nomedible

cuenta() { grep -cE "$1" "$PARTE" 2>/dev/null | head -1; }

# 1. Lo que declara cargo al cerrar cada crate: "due to N previous errors".
#    Es la cifra autoritativa, y hay una por crate que fallo, asi que se suman.
declarado=$( { grep -oE 'due to [0-9]+ previous error' "$PARTE" || true; } \
             | grep -oE '[0-9]+' | awk '{s+=$1} END{print s+0}')
sueltos=$(cuenta 'due to previous error')
declarado=$(( declarado + ${sueltos:-0} ))

# 2. Formato corto: `ruta.rs:linea:col: error[E0381]: ...`
corto=$(cuenta '^[^ ]+\.rs:[0-9]+:[0-9]+: error')

# 3. Formato largo: `error[E0308]: ...`, sin contar los resumenes.
largo=$(cuenta '^error(\[E[0-9]+\])?: ')
resumen=$(cuenta '^error: (could not compile|aborting due to)')
largo=$(( ${largo:-0} > ${resumen:-0} ? ${largo:-0} - ${resumen:-0} : 0 ))

# Un parte truncado no es un parte. cargo aborta al primer crate que falla y
# deja "build failed, waiting for other jobs to finish": lo que quedaba por
# compilar NUNCA se midio. Dar por bueno ese numero es reportar menos errores
# de los que hay, que es la direccion mas cara de equivocarse — nos dio "1
# error" con el workspace a medio medir.
if grep -q 'waiting for other jobs to finish' "$PARTE" && ! grep -qE '^\s*Finished' "$PARTE"; then
  echo "?"; exit 3
fi

max=${declarado:-0}
[ "${corto:-0}" -gt "$max" ] && max=${corto:-0}
[ "$largo" -gt "$max" ] && max=$largo

# Un parte reciente del que las tres estrategias sacan cero puede significar
# que compila de verdad, o que el formato cambio otra vez y no entendemos
# nada. Se distinguen por una sola cosa: cargo, cuando trabaja, lo dice.
if [ "$max" -eq 0 ] && ! grep -qE '^\s*(Finished|Compiling|Checking)' "$PARTE"; then
  nomedible
fi
echo "$max"
