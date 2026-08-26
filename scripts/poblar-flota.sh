#!/usr/bin/env bash
# poblar-flota.sh - abrir tantos obreros como la maquina aguante, y ni uno mas.
#
# ## Por que no alcanza con mirar la memoria libre
#
# Dos trampas, las dos aprendidas rompiendo una maquina:
#
# 1. **Un agente no pesa lo que pesa recien nacido.** Arranca en ~230 MB y con
#    horas de trabajo encima llega a 1.6 GB. Presupuestar por la mediana de lo
#    que hay abierto ahora es planificar para el mejor caso: se presupuesta por
#    el **percentil 90**, que es el que dice cuanto va a pesar el que ya lleva
#    rato.
#
# 2. **El crecimiento es diferido.** Si se crean ocho y se mide despues de cada
#    uno, ninguna medicion individual miente y aun asi la maquina se hunde: cada
#    uno todavia no engordo. Por eso se **descuenta el costo completo apenas se
#    crea**, sin esperar a medirlo.
#
# Y el piso: se deja un colchon libre. Cuando el kernel empieza a matar, mata
# paneles de trabajo, no al que sobra.
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
. "$DIR/harness.sh"

PISO_MB="${FLOTA_PISO_MB:-2500}"      # colchon que no se toca
COSTO_MIN_MB="${FLOTA_COSTO_MIN:-700}" # cuanto se asume por obrero si no hay con que medir
TOPE="${FLOTA_TOPE:-24}"               # tope duro, por las dudas
KIND="${FLOTA_KIND:-opencode}"
ARGS="${FLOTA_ARGS:---auto}"

disponible_mb() { awk '/MemAvailable/ {printf "%d", $2/1024}' /proc/meminfo; }

# Percentil 90 del PSS de los obreros que ya corren. Si no hay ninguno todavia,
# no hay con que medir y se usa el minimo asumido.
costo_por_obrero() {
  local vals
  vals=$(for p in $(pgrep -f "$KIND" 2>/dev/null); do
           awk '/^Pss:/ {s+=$2} END {if (s) printf "%d\n", s/1024}' "/proc/$p/smaps_rollup" 2>/dev/null
         done | sort -n)
  [ -z "$vals" ] && { echo "$COSTO_MIN_MB"; return; }
  local n p90
  n=$(echo "$vals" | wc -l)
  p90=$(echo "$vals" | awk -v n="$n" 'NR==int(n*0.9)+((n*0.9)==int(n*0.9)?0:1){print; exit}')
  [ -z "$p90" ] && p90="$COSTO_MIN_MB"
  [ "$p90" -lt "$COSTO_MIN_MB" ] && p90="$COSTO_MIN_MB"
  echo "$p90"
}

obreros_vivos() { harness_list 2>/dev/null | awk -F'\t' '$4=="obrero"' | wc -l; }

main() {
  local disp costo vivos cabe creados=0 restante
  disp=$(disponible_mb); costo=$(costo_por_obrero); vivos=$(obreros_vivos)
  restante=$(( disp - PISO_MB ))
  cabe=$(( restante / costo ))
  [ "$cabe" -lt 0 ] && cabe=0
  [ $(( vivos + cabe )) -gt "$TOPE" ] && cabe=$(( TOPE - vivos ))
  [ "$cabe" -lt 0 ] && cabe=0

  echo "disponible ${disp} MB · piso ${PISO_MB} · costo estimado por obrero ${costo} MB (p90)"
  echo "vivos ${vivos} · entran ${cabe} mas"

  local i
  for i in $(seq 1 "$cabe"); do
    # Descontar el costo COMPLETO al crearlo, sin esperar a medirlo: el
    # crecimiento es diferido y medir despues de cada uno da siempre verde
    # hasta que es tarde.
    restante=$(( restante - costo ))
    [ "$restante" -lt 0 ] && { echo "se acabo el presupuesto"; break; }
    if harness_start "obrero$(( vivos + i ))" "$KIND" $ARGS >/dev/null 2>&1; then
      creados=$(( creados + 1 ))
    else
      echo "no se pudo crear el obrero $(( vivos + i )) — probablemente no hay panel libre"
      break
    fi
  done
  echo "creados: $creados · total ahora: $(obreros_vivos)"
}
main "$@"
