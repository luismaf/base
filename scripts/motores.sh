#!/usr/bin/env bash
# motores.sh - que ningun panel quede parado, y que el foco vuelva a donde estaba.
#
# ## Dos problemas que resuelve
#
# 1. El latigo reparte de a poco por pasada y tiene valvulas de gracia y
#    cooldown pensadas para obreros que se pagan. Con obreros gratis e
#    ilimitados esa moderacion esta al reves: un panel parado con treinta items
#    esperando no es prudencia, es desperdicio. Este bucle barre corto y sigue
#    barriendo hasta que no queda nadie libre.
#
# 2. Mandar un mensaje a un panel a veces necesita enfocarlo, y eso le roba el
#    foco a la persona que esta trabajando en el suyo. Antes de cada vuelta se
#    anota quien tenia el foco y al terminar se lo devuelve. Que la maquinaria
#    ande no puede costarle la pantalla al que la esta usando.
set -euo pipefail
cd "$(dirname "$0")/.."
INTERVALO="${MOTORES_INTERVALO:-25}"

foco_actual() {
  herdr agent list 2>/dev/null | python3 -c '
import sys,json
try: d=json.load(sys.stdin)
except Exception: sys.exit(0)
a=d.get("result",{}).get("agents", d if isinstance(d,list) else [])
for x in a:
    if x.get("focused"): print(x.get("pane_id","")); break
' 2>/dev/null
}

una_vuelta() {
  local antes libres
  antes=$(foco_actual || true)

  # Barrer hasta que no quede nadie libre o el tablero se vacie. El latigo
  # reparte de a poco por pasada, asi que una sola no alcanza.
  for _ in 1 2 3 4 5 6; do
    libres=$(latigo sweep --grace 0 --cooldown 0 2>/dev/null | grep -oE '^free:[0-9]+' | cut -d: -f2 || echo 0)
    [ "${libres:-0}" -eq 0 ] && break
    [ "$(latigo board pending 2>/dev/null || echo 0)" -eq 0 ] && break
  done

  # Si quedo alguien libre y no hay items, es que se agoto la fuente: recargar.
  if [ "${libres:-0}" -gt 0 ] && [ "$(latigo board pending 2>/dev/null || echo 0)" -eq 0 ]; then
    ./scripts/autoservicio.sh -n 40 >/dev/null 2>&1 || true
    latigo sweep --grace 0 --cooldown 0 >/dev/null 2>&1 || true
  fi

  # Devolver el foco a quien lo tenia.
  [ -n "${antes:-}" ] && herdr agent focus "$antes" >/dev/null 2>&1 || true
}

case "${1:-}" in
  --loop) while true; do una_vuelta; sleep "$INTERVALO"; done ;;
  *)      una_vuelta; echo "libres:$(latigo sweep --grace 0 --cooldown 0 2>/dev/null|grep -oE '^free:[0-9]+'|cut -d: -f2) pendientes:$(latigo board pending)" ;;
esac
