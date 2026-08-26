#!/usr/bin/env bash
# autoservicio.sh - el tablero se recarga solo desde el inventario del proyecto.
#
# ## Por que existe
#
# Si el tablero solo se llena cuando alguien redacta, se vacia. Y cuando se
# vacia, la flota entera se para hasta que ese alguien conteste. Nos paso: trece
# obreros mirando el techo porque el jefe estaba pensando.
#
# La salida es que el trabajo YA este escrito en algun lado y que convertirlo en
# items sea mecanico. Casi todo proyecto tiene ese "algun lado": un inventario de
# funcionalidades, una lista de pantallas a portar, una tabla de huecos medidos.
# Este script lo lee y lo convierte, gratis y sin criterio.
#
# El jefe sigue escribiendo los items que SI requieren criterio. Esto cubre el
# piso, que es lo unico que no puede faltar.
#
# ## De donde lee
#
# De `.tablero/inventario.tsv`, una linea por trabajo:
#
#     ID<TAB>titulo<TAB>de-donde-sale<TAB>terminado-cuando
#
# Si tu proyecto ya tiene el inventario en otro formato (una tabla en un .md, un
# JSON, la salida de un script que mide huecos), no lo dupliques: escribi un
# generador de tres lineas que produzca ese TSV y corrélo antes. Es mejor tener
# una fuente de verdad y un adaptador que dos inventarios que se desincronizan.
#
#   autoservicio.sh            recargar hasta el minimo
#   autoservicio.sh -n 40      recargar hasta 40 pendientes
#   autoservicio.sh --lista    que queda sin tomar
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR/.."
INV="${AUTOSERVICIO_INVENTARIO:-.tablero/inventario.tsv}"
ESTADO="${AUTOSERVICIO_ESTADO:-.tablero/tomados}"
TABLERO="$DIR/tablero.sh"
MIN=15; [ "${1:-}" = "-n" ] && MIN="${2:-15}"
mkdir -p "$(dirname "$ESTADO")"; touch "$ESTADO"

[ -f "$INV" ] || {
  echo "no hay inventario en $INV" >&2
  echo "Escribí uno: una línea por trabajo, ID<TAB>título<TAB>origen<TAB>terminado-cuando." >&2
  echo "Que la flota arranque no puede depender de que alguien redacte a mano." >&2
  exit 1
}

# Un id esta tomado cuando figura en el registro, y SOLO ahi.
#
# Antes esto miraba tambien el texto de los items y fue un error caro: varios
# items mencionan RANGOS de ids, asi que la busqueda por substring daba por
# cubierto medio inventario y el tablero quedaba vacio con la flota parada. Y lo
# peor del bug: un match parcial que sale positivo de mas no falla ruidosamente,
# apaga la flota en silencio. Registro explicito, campo entero, sin regex.
tomado() { grep -qxF -- "$1" "$ESTADO"; }

pendientes_inv() {
  while IFS=$'\t' read -r id titulo origen criterio; do
    [ -z "${id:-}" ] && continue
    case "$id" in \#*) continue;; esac
    tomado "$id" || printf '%s\t%s\t%s\t%s\n' "$id" "$titulo" "${origen:-—}" "${criterio:-ver el inventario}"
  done < "$INV"
}

[ "${1:-}" = --lista ] && { pendientes_inv; exit 0; }

hay=$("$TABLERO" count 2>/dev/null || echo 0)
faltan=$(( MIN - hay ))
[ "$faltan" -le 0 ] && { echo "el tablero ya tiene $hay pendientes"; exit 0; }

n=0
while IFS=$'\t' read -r id titulo origen criterio && [ "$n" -lt "$faltan" ]; do
  "$TABLERO" add "$titulo ($id)

Zona: la que corresponda. Antes de escribir una línea, mirá el tablero y verificá que ningún ítem tomado toque tus archivos. Si choca, decilo en el informe y tomá otro.
Cierra: $id del inventario del proyecto. Leé la entrada completa antes de empezar.
De dónde sale: $origen
Construir: lo que dice la entrada, respetando el contrato de diseño del proyecto y su vocabulario.
Terminado cuando: $criterio
Reportar: qué cerraste, qué quedó afuera y qué te faltó de otro lado. Un párrafo." >/dev/null 2>&1 \
    && { echo "$id" >> "$ESTADO"; n=$(( n + 1 )); echo "  + $id $titulo"; }
done < <(pendientes_inv)

echo "agregados: $n — tablero ahora en $("$TABLERO" count 2>/dev/null || echo '?')"
