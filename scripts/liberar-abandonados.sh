#!/usr/bin/env bash
# liberar-abandonados.sh - devuelve al tablero lo que alguien tomo y no cerro.
#
# ## Por que existe
#
# Un panel tomo 83 items y no cerro ninguno; los mas viejos llevaban 34 horas.
# Ochenta y tres trabajos fuera del sistema: no los hacia el que los tenia, y
# nadie mas podia agarrarlos. El tablero figuraba vacio y la flota parada
# mientras habia decenas de items secuestrados.
#
# Y no se veia: un item "taken" se lee como trabajo en curso. Uno tomado hace
# media hora y uno tomado hace un dia y medio se ven exactamente igual en el
# listado — otra vez dos estados muy distintos con la misma cara.
#
# Tomar no es hacer. Pasado cierto tiempo sin cerrar, el item vuelve al tablero.
#
#   liberar-abandonados.sh [horas]   por defecto 3
#   liberar-abandonados.sh --ver     muestra sin liberar
set -uo pipefail
cd "$(dirname "$0")/.."
. "$(dirname "$0")/herdr-entorno.sh" 2>/dev/null || true
VER=0; [ "${1:-}" = --ver ] && { VER=1; shift; }
HORAS="${1:-3}"
now=$(date +%s)

# Dos criterios, no uno.
#
# El tiempo solo no alcanzaba: los paneles toman de a decenas y los items
# recien tomados no entran por edad. Llegamos a 337 items en "taken" con 18
# obreros —dieciocho por cabeza— y el tablero figurando vacio. Un agente
# trabaja de a UNO: todo lo demas que tenga tomado no lo esta haciendo, lo
# esta reservando, y reservar es sacarlo del sistema sin que se note.
#
# Asi que se libera lo viejo Y el exceso por panel, dejando los MAX_PANEL mas
# recientes de cada uno (los mas nuevos son los que probablemente esta mirando).
MAX_PANEL="${MAX_PANEL:-2}"
mapfile -t viejos < <(awk -F'\t' -v n="$now" -v h="$HORAS" -v m="$MAX_PANEL" '
  $1=="taken" {
    n_p[$5]++
    id[NR]=$2; pan[NR]=$5; ts[NR]=$3
    # guardamos por panel para ordenar despues
    lista[$5] = lista[$5] NR " "
  }
  END {
    for (p in lista) {
      c = split(lista[p], idx, " ")
      # ordenar indices por timestamp descendente (los mas nuevos primero)
      for (i=1; i<c; i++) for (j=i+1; j<c; j++)
        if (ts[idx[j]] > ts[idx[i]]) { t=idx[i]; idx[i]=idx[j]; idx[j]=t }
      for (i=1; i<c; i++) {
        k = idx[i]
        edad = int((n - ts[k]) / 3600)
        if (i > m || (n - ts[k]) > h*3600)
          print id[k] "\t" pan[k] "\t" edad
      }
    }
  }' .latigo/board.tsv 2>/dev/null)

[ "${#viejos[@]}" -eq 0 ] && { echo "sin items abandonados (umbral ${HORAS}h)"; exit 0; }
echo "a liberar: ${#viejos[@]} (mas de ${HORAS}h, o mas de ${MAX_PANEL} por panel)"
for v in "${viejos[@]}"; do
  id="${v%%$'\t'*}"; resto="${v#*$'\t'}"; panel="${resto%%$'\t'*}"; hs="${resto##*$'\t'}"
  if [ "$VER" = 1 ]; then
    echo "  $id  $panel  ${hs}h"
  else
    latigo board release "$id" >/dev/null 2>&1 && echo "  liberado $id (de $panel, ${hs}h)"
  fi
done
