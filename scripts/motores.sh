#!/usr/bin/env bash
# motores.sh - que ningun panel quede parado.
#
# ## Dos frenos que hay que soltar cuando los obreros son gratis
#
# 1. Las valvulas del reparto —gracia y enfriamiento— existen para no acosar a
#    un panel y no gastar de mas. Estan calibradas para obreros que se pagan.
#    Con obreros gratis estan al reves: un panel parado con treinta items en la
#    cola no es prudencia, es desperdicio. Van a cero.
#
#    Lo que NO va a cero es el tope de intentos de un item: eso protege al ITEM
#    de rebotar para siempre entre paneles, no al panel de recibir trabajo. Son
#    dos cosas distintas y sólo una sobra.
#
# 2. El reparto entrega de a poco por pasada, y quien se libera a mitad de la
#    vuelta espera el intervalo entero. Hay que barrer en bucle hasta que no
#    quede nadie libre o se vacie el tablero.
#
# ## Portabilidad
#
# Este script habla SOLO por `harness.sh` y `tablero.sh`. No invoca ningun
# binario externo. Esa restriccion no es estetica: la version anterior llamaba a
# un binario que existe en un proyecto y no en otro, y como todo iba con
# `|| true` fallaba en silencio y parecia andar. Si vas a agregar algo aca,
# pasalo por el harness o no lo agregues.
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
RAIZ="$(cd "$DIR/.." && pwd)"
. "$DIR/harness.sh"
TABLERO="$DIR/tablero.sh"
AUTOPILOTO="$DIR/autopiloto.sh"
JEFE="${JEFE_PANEL:-jefe}"
INTERVALO="${MOTORES_INTERVALO:-25}"
VUELTAS="${MOTORES_VUELTAS:-6}"

libres() {
  # Cuenta tambien a los "manual": un freebuff/TUI que herdr no reconoce
  # como agente ES un obrero — harness_list ya lo clasifica idle/working
  # por pantalla. Filtrarlos dejaba "libres:0" con un freebuff esperando
  # (2026-08-27, ux): el latigo nunca llegaba a llamar al autopiloto.
  harness_list 2>/dev/null | awk -F'\t' -v j="$JEFE" '($4=="obrero"||$4=="agente"||$4=="manual") && $1!=j && ($2=="idle"||$2=="done")' | wc -l
}
pendientes() { "$TABLERO" count 2>/dev/null || echo 0; }

una_vuelta() {
  local i
  for i in $(seq 1 "$VUELTAS"); do
    [ "$(libres)" -eq 0 ] && break
    [ "$(pendientes)" -eq 0 ] && break
    # Valvulas en cero: con obreros gratis, esperar es tirar plata.
    GRACIA=0 COOLDOWN=0 ESPERA=0 bash "$AUTOPILOTO" >/dev/null 2>&1 || true
  done
  "$DIR/foco.sh" >/dev/null 2>&1 || true
  echo "$(date +%H:%M) libres:$(libres) pendientes:$(pendientes)"
}

case "${1:-}" in
  --loop) while true; do una_vuelta; sleep "$INTERVALO"; done ;;
  *)      una_vuelta ;;
esac
