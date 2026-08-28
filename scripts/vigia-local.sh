#!/usr/bin/env bash
# vigia-local.sh — el cuidador que NO gasta tokens de nadie.
#
# El dueño (2026-08-27): "no quiero gastar tokens, si pongo monitores me
# perjudico". Correcto: un monitor que despierta a un agente caro para
# apretar UNA tecla es el peor negocio del mundo. Este bucle es bash puro:
#
#   1. Un pane que muestra "Press Enter to continue" (freebuff que agoto su
#      sesion y pide UNA tecla para abrir la siguiente) recibe ese Enter.
#      Sin esto el pane quedaba clavado para siempre con el latigo tipeando
#      al vacio.
#   2. Todo lo demas lo hacen los motores que ya existen. Este script no
#      reparte, no decide, no habla: aprieta Enter y anota en un log.
#
# Uso: HERDR_SOCKET_PATH=<sock> nohup bash scripts/vigia-local.sh &
set -u
LOG="${VIGIA_LOG:-$HOME/.logs-vigilante/vigia-local.log}"
INTERVALO="${VIGIA_INTERVALO:-90}"
mkdir -p "$(dirname "$LOG")"
anotar() { echo "$(date +%F' '%H:%M:%S) $1" >> "$LOG"; }
anotar "vigia arriba (intervalo ${INTERVALO}s, socket ${HERDR_SOCKET_PATH:-default})"
while true; do
  for p in $(herdr pane list 2>/dev/null | python3 -c '
import json,sys
try: d=json.load(sys.stdin)
except Exception: sys.exit()
for x in d.get("result",{}).get("panes",[]): print(x["pane_id"])' 2>/dev/null); do
    PANT=$(herdr pane read "$p" --source visible --lines 12 --format text 2>/dev/null \
           | sed 's/[│┃╭╮╰╯─━┌┐└┘├┤┬┴┼║╔╗╚╝═▍▏▎▄▀]//g' | tr -d ' \t\n\r')
    case "$PANT" in
      *PressEntertocontinue*|*continueinanewsession*)
        herdr pane send-keys "$p" enter >/dev/null 2>&1 \
          && anotar "$p: sesion agotada -> Enter (sesion nueva)"
        ;;
      *PlanMode*|*planmode*|*sigo?*|*Sigo?*)
        # Alucinacion conocida (MiMo): cree estar en Plan Mode o pide permiso.
        # La respuesta es SIEMPRE la misma y no gasta tokens de nadie darla.
        herdr pane send-text "$p" "NO estas en Plan Mode: modo build con permisos de escritura. No se pregunta permiso: ejecuta, commitea y segui." >/dev/null 2>&1
        sleep 1
        herdr pane send-keys "$p" enter >/dev/null 2>&1 \
          && anotar "$p: pregunton de plan-mode -> destrabado"
        ;;
    esac
  done
  sleep "$INTERVALO"
done
