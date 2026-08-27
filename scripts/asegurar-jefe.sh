#!/usr/bin/env bash
# asegurar-jefe.sh — si no hay jefe, se crea solito (dueño, 2026-08-27).
#
# El jefe es el unico al que nada reinicia: cuando muere (cuota agotada, OOM,
# sesion perdida) la flota entera queda sin quien reponga el tablero y "todo
# medio parado". Este script corre ANTES de jefe.sh en el reloj:
#
#   1. Lee el pane del jefe de .logs/jefe.panel (id dinamico, no hardcodeado:
#      los panes se renumeran y un id fijo en un unit de systemd es una mentira
#      a futuro).
#   2. Si el pane existe y su agente responde (registro de agente vivo o TUI
#      en pantalla), no hace nada.
#   3. Si no: reusa un pane SHELL del repo o parte uno nuevo, arranca
#      `opencode --agent jefe` con nombre unico, y guarda el pane id.
#
# Tres resultados, nunca dos: JEFE VIVO / JEFE CREADO en X / NO PUDE (motivo).
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
RAIZ="$(cd "$DIR/.." && pwd)"
ESTADO="$RAIZ/.logs/jefe.panel"
LOG="${JEFE_LOG:-$HOME/.logs-vigilante/asegurar-jefe.log}"
KIND="${JEFE_KIND:-opencode}"
ARGS="${JEFE_ARGS:---agent jefe}"
mkdir -p "$(dirname "$LOG")" "$RAIZ/.logs"
anotar() { echo "$(date +%F' '%H:%M:%S) $1" >> "$LOG"; echo "$1"; }

panes_json() { herdr pane list 2>/dev/null; }

vivo() { # $1 = pane id -> 0 si tiene TUI/agente
  local p="$1"
  panes_json | python3 -c "
import json,sys
try: d=json.load(sys.stdin)
except Exception: sys.exit(1)
for x in d.get('result',{}).get('panes',[]):
    if x.get('pane_id')=='$p':
        sys.exit(0 if x.get('agent') else 2)
sys.exit(3)" && return 0
  # sin registro de agente: la pantalla decide (misma doctrina del harness)
  herdr pane read "$p" --source visible --lines 12 --format text 2>/dev/null \
    | tr -d ' \t\n\r' | grep -qE 'Enteracodingtask|working|PressEnter'
}

JEFE="$(cat "$ESTADO" 2>/dev/null || true)"
if [ -n "$JEFE" ] && vivo "$JEFE"; then
  anotar "JEFE VIVO en $JEFE"
  exit 0
fi

# Buscar donde ponerlo: primero un SHELL parado en el repo, sino partir uno.
DESTINO=$(panes_json | python3 -c "
import json,sys
try: d=json.load(sys.stdin)
except Exception: sys.exit(1)
ps=d.get('result',{}).get('panes',[])
for x in ps:
    if not x.get('agent') and x.get('cwd','').startswith('$RAIZ'):
        print(x['pane_id']); sys.exit(0)
print(ps[0]['pane_id'] if ps else '')" 2>/dev/null)
[ -z "$DESTINO" ] && { anotar "NO PUDE: el harness no lista panes"; exit 3; }

ES_SHELL=$(panes_json | python3 -c "
import json,sys
d=json.load(sys.stdin)
for x in d.get('result',{}).get('panes',[]):
    if x.get('pane_id')=='$DESTINO': print('si' if not x.get('agent') else 'no')" 2>/dev/null)
if [ "$ES_SHELL" != "si" ]; then
  NUEVO=$(herdr pane split --pane "$DESTINO" --direction right --cwd "$RAIZ" --no-focus 2>/dev/null \
          | python3 -c "import json,sys; print(json.load(sys.stdin)['result']['pane']['pane_id'])" 2>/dev/null)
  [ -z "$NUEVO" ] && { anotar "NO PUDE: split fallo desde $DESTINO"; exit 3; }
  DESTINO="$NUEVO"
fi

NOMBRE="jefe-$(date +%s)"
if herdr agent start "$NOMBRE" --kind "$KIND" --pane "$DESTINO" --timeout 60000 -- $ARGS >/dev/null 2>&1; then
  echo "$DESTINO" > "$ESTADO"
  anotar "JEFE CREADO en $DESTINO ($KIND $ARGS)"
  exit 0
fi
anotar "NO PUDE: agent start fallo en $DESTINO"
exit 3
