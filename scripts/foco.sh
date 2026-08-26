#!/usr/bin/env bash
# foco.sh - el foco vuelve solo a la persona.
#
# ## El problema
#
# Mandarle un mensaje a un panel a veces necesita enfocarlo: si el envio no
# entra a la primera, la herramienta enfoca y manda Enter. Eso le roba la
# pantalla a quien esta trabajando en la suya, incluso desde otro espacio de
# trabajo. Y como la maquinaria manda mensajes todo el tiempo, el robo es
# constante.
#
# ## La regla, que tiene que ser fina
#
# Devolver el foco siempre seria peor: si la persona se movio a proposito, se lo
# estariamos peleando. Pero nuestra automatizacion SOLO enfoca paneles de
# obreros. Entonces:
#
#   foco en un panel obrero  -> se lo robamos nosotros -> devolver
#   foco en un panel humano  -> se movio la persona    -> no tocar
#
# Asi nunca peleamos con el usuario y siempre le devolvemos lo que le sacamos.
set -euo pipefail
cd "$(dirname "$0")/.."
CASA=".latigo/foco.casa"
INTERVALO="${FOCO_INTERVALO:-3}"

estado() {
  herdr agent list 2>/dev/null | python3 -c '
import sys,json
try: d=json.load(sys.stdin)
except Exception: sys.exit(0)
for x in d.get("result",{}).get("agents",[]):
    if x.get("focused"): print(x.get("pane_id",""), x.get("agent","")); break
' 2>/dev/null
}

una_vuelta() {
  local pane kind casa
  read -r pane kind < <(estado) || return 0
  [ -z "${pane:-}" ] && return 0

  # Un panel que no es obrero es de la persona: se recuerda como su casa.
  if [ "$kind" != opencode ]; then
    echo "$pane" > "$CASA"
    return 0
  fi

  # Es un obrero: se lo robamos. Devolver.
  casa=$(cat "$CASA" 2>/dev/null || true)
  [ -n "$casa" ] && herdr agent focus "$casa" >/dev/null 2>&1 || true
}

case "${1:-}" in
  --loop) while true; do una_vuelta; sleep "$INTERVALO"; done ;;
  casa)   cat "$CASA" 2>/dev/null || echo "(sin registrar)" ;;
  *)      una_vuelta; echo "casa: $(cat "$CASA" 2>/dev/null || echo '?')  foco: $(estado)" ;;
esac
