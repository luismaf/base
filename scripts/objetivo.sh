#!/usr/bin/env bash
# objetivo.sh - ¿el objetivo está REALMENTE logrado?
#
# ## Por que existe
#
# Queremos un equipo fanatico de mejorar: que mire a la competencia, que le robe
# lo mejor a los mejores del mundo, que piense como se vende. Todo eso vale.
#
# Y todo eso es tambien la forma mas facil de no terminar nunca. Investigar es
# comodo, se siente productivo, no tiene final claro y no lo audita nadie. Un
# equipo que estudia competidores con el producto a medio hacer no esta
# mejorando: se esta escapando de terminar.
#
# La solucion no es pedirle disciplina a nadie — la disciplina se gasta y nadie
# se da cuenta de cuando se gasto. Es una COMPUERTA que se mide sola: el trabajo
# exploratorio esta cerrado hasta que los numeros digan que el objetivo esta
# logrado. No hay criterio humano que negociar, ni conversacion que ganar.
#
# ## Como se configura
#
# En `.tablero/objetivo.conf`, una condicion por linea:
#
#     nombre<TAB>comando-que-imprime-un-numero<TAB>minimo
#
# Ejemplo:
#     cobertura	./scripts/marcador.sh | awk '/COBERTURA/{print $2+0}'	100
#     errores	cat .tablero/errores-compilacion	0
#
# Dos reglas al escribirlas:
#
# 1. **Si una condicion no se puede medir, no es una condicion: es un deseo.**
#    "Que la interfaz este linda" no va. "Cero violaciones del contrato de
#    diseno en el recorrido automatico" si.
# 2. **Los umbrales van altos.** "Casi" no abre la puerta: la mitad de los
#    productos que no se terminan estaban en 85% y alguien decidio que
#    alcanzaba.
#
#   objetivo.sh           el estado, con los numeros
#   objetivo.sh --puerta  imprime ABIERTA o CERRADA y sale 0 o 1
set -euo pipefail
cd "$(dirname "$0")/.."
CONF="${OBJETIVO_CONF:-.tablero/objetivo.conf}"

[ -f "$CONF" ] || {
  if [ "${1:-}" = --puerta ]; then echo CERRADA; exit 1; fi
  echo "no hay condiciones en $CONF" >&2
  echo >&2
  echo "Sin condiciones escritas no hay objetivo, y sin objetivo el equipo no" >&2
  echo "puede terminar: siempre va a haber algo mas que mejorar. Escribi las" >&2
  echo "condiciones —medibles, con umbral— antes de poner a nadie a trabajar." >&2
  exit 1
}

abierta=1; filas=()
while IFS=$'\t' read -r nombre cmd minimo; do
  [ -z "${nombre:-}" ] && continue
  case "$nombre" in \#*) continue;; esac
  val=$(eval "$cmd" 2>/dev/null | head -1 | grep -oE '^-?[0-9]+' || echo "")
  if [ -z "$val" ]; then
    filas+=("$(printf '%-30s %s' "$nombre" "no se pudo medir (hace falta $minimo)")")
    abierta=0; continue
  fi
  # Un minimo de 0 se lee como "como maximo 0" (errores, violaciones).
  if [ "$minimo" -eq 0 ]; then ok=$([ "$val" -le 0 ] && echo 1 || echo 0)
  else ok=$([ "$val" -ge "$minimo" ] && echo 1 || echo 0); fi
  [ "$ok" = 0 ] && abierta=0
  filas+=("$(printf '%-30s %s' "$nombre" "$val (hace falta $minimo)")")
done < "$CONF"

if [ "${1:-}" = --puerta ]; then
  [ "$abierta" = 1 ] && { echo ABIERTA; exit 0; } || { echo CERRADA; exit 1; }
fi

printf '%s\n' "${filas[@]}"
echo
if [ "$abierta" = 1 ]; then
  echo "PUERTA ABIERTA — el objetivo esta logrado."
  echo "Recien ahora vale la pena mirar afuera: competencia, como se vende, que"
  echo "robarle a los mejores del mundo. Antes era escaparse de terminar."
else
  echo "PUERTA CERRADA — falta terminar."
  echo "Todo el trabajo va a cerrar lo de arriba. Nada de competencia, marketing"
  echo "ni exploracion todavia."
fi
