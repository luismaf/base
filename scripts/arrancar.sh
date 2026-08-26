#!/usr/bin/env bash
# arrancar.sh - de un repo con el kit instalado a una flota trabajando.
#
# Un solo comando. Si esto necesita que alguien despues "ademas arranque tal
# cosa", esta mal escrito: lo que se olvida de arrancar es exactamente lo que
# despues aparece apagado a las tres horas.
#
#   arrancar.sh              poblar segun RAM, saludar, cargar y encender motores
#   arrancar.sh --sin-poblar usar los paneles que ya hay
#   arrancar.sh --parar      apagar los motores (los obreros siguen)
#   arrancar.sh --estado     que esta andando
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
RAIZ="$(cd "$DIR/.." && pwd)"
cd "$RAIZ"
. "$DIR/harness.sh"
LOGS="${ARRANCAR_LOGS:-.tablero/logs}"; mkdir -p "$LOGS"

MOTORES=(motores jefe foco)

parar() { for m in "${MOTORES[@]}"; do pkill -f "scripts/$m.sh --loop" 2>/dev/null || true; done; echo "motores apagados"; }
estado() {
  for m in "${MOTORES[@]}"; do printf '%-9s %s\n' "$m" "$(pgrep -f "scripts/$m.sh --loop" >/dev/null && echo andando || echo APAGADO)"; done
  echo "obreros: $(harness_list 2>/dev/null | awk -F'\t' '($4=="obrero"||$4=="agente")' | wc -l)"
  echo "tablero: $("$DIR/tablero.sh" count 2>/dev/null || echo '?') pendientes"
}

case "${1:-}" in --parar) parar; exit 0;; --estado) estado; exit 0;; esac

echo "── 1. el harness"
if ! harness_vivo; then
  echo "   el harness no contesta. No es 'cero paneles': es que no hay con quien hablar." >&2
  echo "   Abri la sesion de agentes (herdr, tmux, lo que uses) y volve a correr esto." >&2
  exit 1
fi
echo "   ok"

echo "── 2. poblar la flota segun la RAM"
if [ "${1:-}" = --sin-poblar ]; then echo "   salteado"; else bash "$DIR/poblar-flota.sh" | sed 's/^/   /'; fi

echo "── 3. saludar antes de pedir"
# Una ventana fria que recibe el pedido largo como primer mensaje responde mal.
bash "$DIR/saludar-agentes.sh" 2>/dev/null | sed 's/^/   /' || echo "   (sin saludar)"

echo "── 4. cargar el tablero"
pend=$("$DIR/tablero.sh" count 2>/dev/null || echo 0)
if [ "$pend" -eq 0 ]; then
  if [ -x "$DIR/autoservicio.sh" ]; then
    bash "$DIR/autoservicio.sh" -n 40 2>/dev/null | tail -1 | sed 's/^/   /'
  else
    echo "   El tablero esta vacio y este proyecto no tiene autoservicio.sh."
    echo "   Escribi el inventario de lo que falta y un generador que lo convierta"
    echo "   en items: que la flota arranque NO puede depender de que alguien"
    echo "   redacte a mano. Mientras tanto, cargalo con tablero.sh add."
  fi
else
  echo "   ya hay $pend pendientes"
fi

echo "── 5. encender los motores"
for m in "${MOTORES[@]}"; do
  pgrep -f "scripts/$m.sh --loop" >/dev/null && { echo "   $m ya estaba"; continue; }
  setsid nohup bash "$DIR/$m.sh" --loop >"$LOGS/$m.log" 2>&1 </dev/null &
  sleep 1
  pgrep -f "scripts/$m.sh --loop" >/dev/null && echo "   $m andando" || echo "   $m NO ARRANCO — mira $LOGS/$m.log"
done

echo
echo "── estado"
estado
echo
echo "Que hace cada motor:"
echo "  motores  reparte con las valvulas en cero y no deja a nadie parado"
echo "  jefe     lo despierta con la proxima accion ya decidida; si el inventario"
echo "           se agota, sube un escalon de la escalera de mejora"
echo "  foco     te devuelve el foco cuando la maquinaria te lo saca"
