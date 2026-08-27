#!/usr/bin/env bash
# saludar-agentes.sh - decirle "hola" a un agente antes de darle trabajo.
#
# ## Por que existe
#
# Un agente recien abierto que recibe como PRIMER mensaje un pedido largo
# responde mal: se pierde, contesta a medias o directamente no arranca. El mismo
# agente, saludado primero con una sola palabra y esperado unos segundos,
# despues acepta el pedido largo sin problema.
#
# Es barato y funciona. El saludo cuesta un puñado de tokens y evita el caso
# caro: un pedido de cuarenta lineas que hay que reescribir y reenviar porque la
# ventana estaba fria.
#
# Tambien es el rescate de un panel trabado: sesion nueva y "hola". Un agente
# atascado, con un error que no importa, o al que ya se le insistio tres veces,
# se recupera mejor empezando limpio que recibiendo un cuarto recordatorio.
# Insistirle a un panel que no contesta es la forma mas cara de no lograr nada.
#
# ## Cuando NO hace falta
#
# Si la conversacion con ese panel ya viene andando, no. El saludo es para
# ventana nueva o para panel que hay que revivir.
#
# ## Uso
#
#   saludar-agentes.sh                 saluda a todo el que este ocioso
#   saludar-agentes.sh a1 a2           saluda a esos
#   saludar-agentes.sh --nuevo a1      sesion nueva y despues el saludo (rescate)
#   saludar-agentes.sh --todos         a toda la flota, este como este
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
. "$DIR/harness.sh"

ESPERA="${SALUDO_ESPERA:-6}"
JEFE="${JEFE_PANEL:-jefe}"
NUEVO=0; MODO=ociosos; OBJETIVOS=()

for a in "$@"; do
  case "$a" in
    --nuevo)  NUEVO=1 ;;
    --todos)  MODO=todos ;;
    -*)       echo "opcion desconocida: $a" >&2; exit 2 ;;
    *)        OBJETIVOS+=("$a"); MODO=lista ;;
  esac
done

if [ "$MODO" != lista ]; then
  while IFS=$'\t' read -r panel estado dir clase; do
    [ "$clase" = obrero ] || [ "$clase" = agente ] || continue
    [ "$panel" = "$JEFE" ] && continue
    if [ "$MODO" = todos ] || [ "$estado" = idle ] || [ "$estado" = done ]; then
      OBJETIVOS+=("$panel")
    fi
  done < <(harness_list 2>/dev/null)
fi

[ ${#OBJETIVOS[@]} -eq 0 ] && { echo "no hay a quien saludar"; exit 0; }

# REGIMEN PAGO: sin saludos de aceite — esto es para modelos gratuitos.
if [ "$(bash "$(dirname "$0")/regimen.sh" 2>/dev/null || echo pago)" = "pago" ]; then
  echo "regimen pago: sin saludos (la deteccion de paneles la hace el latigo)"
  exit 0
fi

listos=(); mudos=()
for a in "${OBJETIVOS[@]}"; do
  if [ "$NUEVO" = 1 ]; then
    harness_prompt "$a" "/new" >/dev/null 2>&1 || true
    sleep 2
  fi
  if harness_prompt "$a" "hola" >/dev/null 2>&1; then listos+=("$a"); else mudos+=("$a"); fi
done

# Se le da tiempo a contestar: el punto es que la ventana este tibia cuando
# llegue el pedido de verdad, no que conteste rapido.
sleep "$ESPERA"

echo "saludados y listos: ${listos[*]:-ninguno}"
[ ${#mudos[@]} -gt 0 ] && echo "no contestaron (probá --nuevo): ${mudos[*]}"
exit 0
