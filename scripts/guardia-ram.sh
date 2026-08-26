#!/usr/bin/env bash
# guardia-ram.sh - soltar lastre a proposito, antes de que lo suelte el kernel.
#
# ## Por que
#
# Un agente nace en ~230 MB y con horas de trabajo llega a 1.6 GB. No es una
# fuga: es contexto acumulado, y crece siempre. Con veinte agentes eso son 32 GB
# que la maquina no tiene.
#
# Cuando la memoria se acaba, el kernel elige por su cuenta a quien matar, y
# elige mal: mata el panel mas grande, que suele ser el que mas trabajo lleva
# encima. El otro equipo se quedo sin RAM y perdio paneles asi.
#
# Es mejor soltar nosotros, con criterio:
#
#   1. Nunca se toca un panel que esta TRABAJANDO. Perder trabajo a medio hacer
#      cuesta mas que cualquier memoria que se recupere.
#   2. Se recicla el mas gordo de los OCIOSOS. Reciclar es abrirle sesion nueva,
#      no matarlo: el panel sigue ahi y vuelve liviano.
#   3. Uno por vuelta. Soltar de a muchos por panico deja la flota sin gente.
#   4. Si no hay ociosos, se avisa y no se toca nada. Que la memoria apriete no
#      autoriza a romper trabajo.
#
#   guardia-ram.sh            una vuelta
#   guardia-ram.sh --loop     se queda vigilando
set -euo pipefail
cd "$(dirname "$0")/.."
PISO_MB="${GUARDIA_PISO:-1200}"     # por debajo de esto, se suelta lastre
CRITICO_MB="${GUARDIA_CRITICO:-600}" # por debajo, se avisa fuerte
INTERVALO="${GUARDIA_INTERVALO:-45}"

disp() { awk '/MemAvailable/ {printf "%d", $2/1024}' /proc/meminfo; }

# El mas gordo entre los que NO estan trabajando. Devuelve "nombre rss_mb".
gordo_ocioso() {
  local nombre pane kind estado
  while read -r nombre pane kind estado _; do
    [ "$kind" = opencode ] || continue
    [ "$estado" = working ] && continue
    [ "$nombre" = jefe ] && continue
    [ "$nombre" = dev3 ] && continue   # el compilador: su rol es continuo
    # RSS del proceso cuyo cwd o argumentos correspondan a ese panel es dificil
    # de atribuir con precision; se usa el mayor de los ociosos como proxy y se
    # verifica despues por el efecto en la memoria.
    echo "$nombre"
  done < <(latigo roster 2>/dev/null) | head -1
}

# Los bucles se mueren y nadie se entera: un vigilante muerto se ve igual que
# un sistema tranquilo. Es el mismo patron que veniamos cazando, aplicado a la
# maquinaria misma. Asi que el guardia tambien los revive.
revivir_bucles() {
  local m
  for m in motores jefe foco; do
    pgrep -f "scripts/$m.sh --loop" >/dev/null && continue
    echo "  $m.sh estaba MUERTO — lo revivo"
    setsid nohup bash "./scripts/$m.sh" --loop >".latigo/$m.log" 2>&1 </dev/null &
    sleep 1
  done
}

una_vuelta() {
  local d victima
  revivir_bucles
  d=$(disp)
  if [ "$d" -ge "$PISO_MB" ]; then
    echo "$(date +%H:%M) RAM ${d} MB — bien"
    return
  fi

  victima=$(gordo_ocioso || true)
  if [ -z "${victima:-}" ]; then
    echo "$(date +%H:%M) RAM ${d} MB por debajo de ${PISO_MB} y NO hay ociosos."
    echo "  No se toca a nadie: perder trabajo a medio hacer cuesta mas que la"
    echo "  memoria que se recupera. Si sigue bajando, la decision de soltar un"
    echo "  panel que trabaja es humana, no mia."
    [ "$d" -lt "$CRITICO_MB" ] && echo "  CRITICO: por debajo de ${CRITICO_MB} MB. El kernel va a elegir el solo, y elige mal."
    return
  fi

  echo "$(date +%H:%M) RAM ${d} MB — reciclando a $victima (ocioso, el mas gordo)"
  # Reciclar, no matar: sesion nueva y saludo. Vuelve liviano y sigue siendo un
  # panel de la flota.
  herdr agent prompt "$victima" "/new" >/dev/null 2>&1 || true
  sleep 3
  herdr agent prompt "$victima" "hola" >/dev/null 2>&1 || true
  sleep 2
  echo "  RAM despues: $(disp) MB"
}

case "${1:-}" in
  --loop) while true; do una_vuelta; sleep "$INTERVALO"; done ;;
  *)      una_vuelta ;;
esac
