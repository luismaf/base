#!/usr/bin/env bash
# vigilar-paneles.sh — el avisador del jefe: detecta CUANDO un panel queda
# libre o un commit cae, en vez de dormir a ciegas (dueño 2026-08-21:
# "con los freebuff perdes tiempo valioso... armate un scriptcito que te
# avise si alguno esta libre").
#
# Qué detecta, cada INTERVALO (30s):
#   1. Freebuff listo para trabajar: la caja de entrada muestra
#      "Enter a coding task" vacía (no thinking/working) — el panel
#      quedó libre.
#   2. Agente opencode idle con prompt previo consumido (revision cambió
#      y quedó idle): cerró un bloque.
#   3. Commit nuevo en main (git log cambió): algo se commiteó.
#   4. Cambios en el buzón del jefe (avisar-jefe.sh escribió).
#
# Escribe UN renglón por evento en .logs/paneles/vigilante.log con
# timestamp. El jefe lee ese log en cada ciclo en vez de hacer sleep
# largo. Al detectar algo escribe también a un archivo de "campana"
# (.logs/paneles/campana) que el jefe borra después de leerlo.
#
# Uso:
#   bash scripts/vigilar-paneles.sh --demonio   # arrancar (setsid)
#   bash scripts/vigilar-paneles.sh --campana   # ¿hubo novedades? (y limpia)
#   bash scripts/vigilar-paneles.sh --parar
#   bash scripts/vigilar-paneles.sh --log       # últimas líneas

DIR_LOG="$HOME/.logs-vigilante"
mkdir -p "$DIR_LOG"
LOG="$DIR_LOG/vigilante.log"
CAMPANA="$DIR_LOG/campana"
INTERVALO="${VIGILAR_INTERVALO:-30}"
# The repo comes from where this script LIVES, never from a literal path: a
# hardcoded one makes the script useless on any other machine, and silently
# wrong on this one the day the repo moves.
REPO="${VIGILAR_REPO:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
HERDR="herdr"

escribir() {
  echo "$(date +%H:%M:%S) — $1" >> "$LOG"
  echo "$(date +%H:%M:%S) — $1" >> "$CAMPANA"
}

# Estados previos
declare -A PREV_TITULO
PREV_LOG=""
PREV_BUZON=""
PREV_COMMIT=""

if [ "$1" = "--campana" ]; then
  if [ -f "$CAMPANA" ]; then
    cat "$CAMPANA"
    rm -f "$CAMPANA"
    exit 0
  fi
  echo "sin novedades"
  exit 0
fi

if [ "$1" = "--log" ]; then
  tail -20 "$LOG" 2>/dev/null || echo "(vacío)"
  exit 0
fi

if [ "$1" = "--parar" ]; then
  pkill -f "vigilar-paneles.sh --demonio" 2>/dev/null
  echo "vigilante parado"
  exit 0
fi

if [ "$1" != "--demonio" ]; then
  echo "uso: $0 --demonio | --campana | --log | --parar"
  exit 1
fi

# Estado inicial
PANES_JSON=$($HERDR pane list 2>/dev/null | python3 -c "
import json,sys
d=json.load(sys.stdin)
for p in d['result']['panes']:
    print(p['pane_id'], '|', p.get('agent_status',''), '|', p.get('terminal_title_stripped','')[:60])
" 2>/dev/null)
while IFS='|' read -r pid st titulo; do
  PREV_TITULO["$pid"]="$titulo"
done <<< "$PANES_JSON"

escribir "vigilante arrancado (intervalo ${INTERVALO}s)"

while true; do
  sleep "$INTERVALO"

  PANES_JSON=$($HERDR pane list 2>/dev/null | python3 -c "
import json,sys
d=json.load(sys.stdin)
for p in d['result']['panes']:
    print(p['pane_id'], '|', p.get('agent_status',''), '|', p.get('terminal_title_stripped','')[:60])
" 2>/dev/null)

  # 1 y 2: por cada pane, si el título cambió a "Enter a coding task" o
  # "New session" (freebuff libre) o quedó idle → campana.
  while IFS='|' read -r pid st titulo; do
    [ -z "$pid" ] && continue
    prev="${PREV_TITULO[$pid]}"
    PREV_TITULO["$pid"]="$titulo"
    if [ "$prev" != "$titulo" ]; then
      case "$titulo" in
        *"Enter a coding task"*|*"New session"*|*"OpenCode"*)
          # Libre: caja esperando input
          escribir "LIBRE: $pid ($st) — título: ${titulo:0:40}"
          ;;
        *"sessions"*)
          escribir "SESIONES: $pid — ${titulo:0:60}"
          ;;
      esac
    fi
  done <<< "$PANES_JSON"

  # 3: commit nuevo
  COMMIT_ACTUAL=$(git -C "$REPO" log --oneline -1 2>/dev/null)
  if [ -n "$PREV_COMMIT" ] && [ "$COMMIT_ACTUAL" != "$PREV_COMMIT" ]; then
    escribir "COMMIT: $COMMIT_ACTUAL"
  fi
  PREV_COMMIT="$COMMIT_ACTUAL"

  # 4: buzón nuevo
  BUZON_ACTUAL=$(ls -t "$REPO/.logs/paneles/buzon-jefe-"*.log 2>/dev/null | head -1)
  if [ -n "$BUZON_ACTUAL" ] && [ "$BUZON_ACTUAL" != "$PREV_BUZON" ]; then
    PREV_BUZON="$BUZON_ACTUAL"
  fi
  if [ -f "$PREV_BUZON" ]; then
    N=$(wc -l < "$PREV_BUZON")
    if [ "${PREV_N:-0}" != "$N" ] && [ -n "${PREV_N:-}" ]; then
      escribir "BUZON: $((N - PREV_N)) avisos nuevos"
    fi
    PREV_N=$N
  fi
done
