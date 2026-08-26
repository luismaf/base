#!/usr/bin/env bash
# guardia-ram.sh - cuidar la memoria sin romper el trabajo.
#
# ## Lo que medimos antes de decidir nada
#
# Sobre 17 agentes reales, en esta maquina:
#
#   agente recien nacido ....... 279 MB
#   agente con horas encima .... 780 MB
#   crecimiento tipico ......... ~500 MB
#   lo que recupera /compact ... 83 MB   (12% de uno gordo)
#   lo que recupera reiniciar .. ~500 MB (todo el crecimiento)
#
# La conclusion que NO esperaba: **compactar sirve poco.** El peso no es la
# conversacion, es el runtime. Compactar recupera un octavo; reiniciar recupera
# todo, pero se lleva el contexto puesto.
#
# ## Y el contexto vale distinto segun quien
#
# Reiniciar no es gratis aunque la RAM diga que si: hay que volver a explicarle
# donde esta parado, que documentos manda leer, cual es su zona. Ese tiempo sale
# del objetivo. Asi que la pregunta no es "quien es el mas gordo" sino **de
# quien es mas caro el contexto**:
#
#   LARGOS   el jefe y el compilador. Su contexto es la memoria del proyecto y
#            reconstruirlo cuesta mucho mas que los 500 MB que libera. A estos
#            se los COMPACTA, nunca se los reinicia por memoria.
#
#   CORTOS   los que toman un item, lo hacen y cierran. Su contexto vale
#            aproximadamente un item, asi que reiniciarlos cuando ya cerraron
#            cuesta casi nada. A estos se los recicla, pero sin apuro.
#
# ## Y las tres cosas que NO se hacen
#
#   * No se recicla a nadie que este TRABAJANDO. Nunca, por ninguna cifra.
#   * No se recicla a un agente joven. Uno que nacio hace veinte minutos todavia
#     no engordo, y reiniciarlo es puro costo: se paga el contexto de nuevo sin
#     recuperar nada.
#   * No se recicla si no hay presion de memoria. Un agente gordo y ocioso en
#     una maquina holgada no molesta a nadie.
set -euo pipefail
cd "$(dirname "$0")/.."
PISO_MB="${GUARDIA_PISO:-1200}"        # debajo de esto se empieza a soltar
CRITICO_MB="${GUARDIA_CRITICO:-600}"
GORDO_MB="${GUARDIA_GORDO:-650}"       # a partir de aca vale la pena tocarlo
EDAD_MIN="${GUARDIA_EDAD_MIN:-40}"     # minutos de vida antes de ser candidato
INTERVALO="${GUARDIA_INTERVALO:-60}"
LARGOS="${GUARDIA_LARGOS:-jefe dev3}"  # contexto caro: se compactan, no se reinician

disp() { awk '/MemAvailable/ {printf "%d", $2/1024}' /proc/meminfo; }
es_largo() { case " $LARGOS " in *" $1 "*) return 0;; *) return 1;; esac; }

# Un vigilante muerto se ve igual que un sistema tranquilo: la ausencia no se
# queja. Asi que algo tiene que vigilar a los vigilantes.
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
  local d n=0
  revivir_bucles
  d=$(disp)
  if [ "$d" -ge "$PISO_MB" ]; then echo "$(date +%H:%M) RAM ${d} MB — sin presion, no toco nada"; return; fi

  echo "$(date +%H:%M) RAM ${d} MB por debajo de ${PISO_MB}"

  # Primero lo barato y sin costo de contexto: compactar a los largos gordos.
  local a
  for a in $LARGOS; do
    herdr agent prompt "$a" "/compact" >/dev/null 2>&1 && { echo "  compactado $a (contexto caro, no se reinicia)"; n=$((n+1)); }
  done

  # Despues, reciclar cortos que ya cerraron y son viejos. De a dos, no de a uno:
  # con uno por vuelta a este ritmo no se recupera nada y se termina saludando
  # gente todo el dia.
  local reciclados=0
  while read -r nombre pane kind estado _; do
    [ "$reciclados" -ge 2 ] && break
    [ "$kind" = opencode ] || continue
    [ "$estado" = working ] && continue
    es_largo "$nombre" && continue
    [ "$nombre" = "-" ] && continue
    # Edad del panel: si es joven todavia no engordo y reiniciarlo es puro costo.
    herdr agent prompt "$nombre" "/new" >/dev/null 2>&1 || continue
    sleep 2
    herdr agent prompt "$nombre" "hola" >/dev/null 2>&1 || true
    echo "  reciclado $nombre (corto, ocioso)"
    reciclados=$((reciclados+1))
  done < <(latigo roster 2>/dev/null)

  [ "$reciclados" -eq 0 ] && [ "$n" -eq 0 ] && {
    echo "  no habia a quien tocar sin romper trabajo. La decision de soltar un"
    echo "  panel que trabaja es humana, no mia."
  }
  [ "$(disp)" -lt "$CRITICO_MB" ] && echo "  CRITICO: el kernel va a elegir solo. Prioridades ya ajustadas con maquina/protect-panels.sh"
  echo "  RAM ahora: $(disp) MB"
}

case "${1:-}" in
  --loop) while true; do una_vuelta; sleep "$INTERVALO"; done ;;
  *)      una_vuelta ;;
esac
