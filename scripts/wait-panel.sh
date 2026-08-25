#!/usr/bin/env bash
# Watcher de panel en BACKGROUND — esperar a un agente SIN quedarse parado.
#
# ## Para qué
#
# `herdr agent prompt` devuelve al instante; el panel trabaja en su terminal.
# Esperar con `sleep N` adivina la demora y bloquea el flujo del que delega.
# `herdr agent wait` espera de verdad al panel — este script lo envuelve para
# poder correrlo en background y consultar el resultado después, en disco.
#
# ## Contrato
#
#   archivo ausente  →  el panel está TRABAJANDO
#   archivo presente →  terminó (contiene el estado y la hora)
#
# ## Uso
#
#   # 1. Mandar la tarea
#   herdr agent prompt "w5:p1" "..." 
#   # 2. Lanzar el watcher (NO bloquea)
#   setsid bash -c 'bash scripts/wait-panel.sh w5:p1 900000 > /dev/null 2>&1 &'
#   # 3. Seguir con el propio trabajo; cuando haya que saber:
#   cat .logs/paneles/w5:p1.estado     # ausente = sigue trabajando
#
# ## Por qué setsid + archivo
#
# El shell de opencode mata los procesos hijos al terminar el comando; setsid
# despega al watcher y el resultado queda en disco, no en una salida que ya
# se cerró. Ver docs/DELEGACION.md "Cómo esperar a un panel".
PANE="${1:?uso: wait-panel.sh <pane_id> [timeout_ms]}"
TIMEOUT="${2:-900000}"
RAIZ="$(git -C "$(dirname "${BASH_SOURCE[0]}")/.." rev-parse --show-toplevel 2>/dev/null || echo "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)")"
LOG_DIR="$RAIZ/.logs/paneles"
mkdir -p "$LOG_DIR"
LOG="$LOG_DIR/$PANE.estado"
rm -f "$LOG"
RESULTADO=$(herdr agent wait "$PANE" --until idle --until blocked --until done --timeout "$TIMEOUT" 2>&1)
echo "$(date '+%H:%M:%S')|$RESULTADO" > "$LOG"
