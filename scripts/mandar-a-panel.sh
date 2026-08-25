#!/usr/bin/env bash
# mandar-a-panel.sh — mandá un mensaje a CUALQUIER panel de herdr por el CLI,
# sin escribir las tres llamadas a mano (prompt + Enter + verificación).
#
# El caso típico: "avisale a X que estoy al pedo", "pedile a Y un estado".
# Para el aviso de CIERRE al jefe existe avisar-jefe.sh (lee docs/jefe.md y
# escala si no recibe); este es el caso general, con el panel explícito.
#
# Uso:
#   bash scripts/mandar-a-panel.sh w5:p2 "📩 estoy idle, listo para lo que venga"
#   MANDAR_SIN_VERIFICAR=1 bash scripts/mandar-a-panel.sh w5:p2 "..."  # sin reintentos
#
# La verificación NO es externa (cuota, plugins): es la recepción misma. El
# panel que procesó el mensaje pasa a `working` — si no arranca tras el
# prompt + Enter, no está operativo y se imprime su estado final. La trampa
# de DELEGACION §0: el prompt sin Enter queda tipeado y el agente no arranca,
# por eso el Enter y el reintento.

set -euo pipefail

PANEL="${1:-}"
MENSAJE="${2:-}"
if [ -z "$PANEL" ] || [ -z "$MENSAJE" ]; then
  echo "uso: bash scripts/mandar-a-panel.sh <panel> \"mensaje\"" >&2
  exit 1
fi

# Estado de un panel según herdr (working | idle | blocked | done | inexistente).
estado_panel() {
  herdr agent get "$1" 2>/dev/null | python3 -c "
import json,sys
try:
    d=json.load(sys.stdin)
    if 'result' in d and 'agent' in d['result']:
        print(d['result']['agent']['agent_status'])
    else:
        print('inexistente')
except Exception:
    print('inexistente')" || echo inexistente
}

herdr agent prompt "$PANEL" "$MENSAJE" >/dev/null 2>&1 || true
herdr agent send-keys "$PANEL" enter >/dev/null 2>&1 || true

if [ "${MANDAR_SIN_VERIFICAR:-0}" != "1" ]; then
  for _ in 1 2 3; do
    sleep 2
    if [ "$(estado_panel "$PANEL")" = "working" ]; then
      echo "mensaje mandado a $PANEL (working — recibido y procesando)"
      exit 0
    fi
    herdr agent send-keys "$PANEL" enter >/dev/null 2>&1 || true
  done
fi
echo "mensaje mandado a $PANEL (estado final: $(estado_panel "$PANEL"))"
