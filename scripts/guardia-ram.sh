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
CTX_COMPACTAR="${GUARDIA_CTX:-5000}"   # decimas de K: 500.0K. Compactar cuesta, se hace tarde
RESERVA_COMPILAR="${GUARDIA_RESERVA:-2500}"  # MB que rustc necesita para no morir
# Quien tiene contexto CARO de reconstruir. Solo el jefe: el suyo es la memoria
# del proyecto — que se escribio, que se probo, que decidio y por que.
#
# El compilador NO esta aca, aunque al principio lo puse. No necesita recordar
# la compilacion anterior: cada ciclo es leer errores nuevos y repartirlos. Su
# contexto no vale nada y engorda igual.
LARGOS="${GUARDIA_LARGOS:-jefe}"

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
  # Compactar NO es gratis: se pierde detalle y a veces foco. Solo cuando el
  # contexto ya esta grande de verdad — por debajo de eso el remedio cuesta mas
  # que la enfermedad, porque ademas recupera apenas 83 MB.
  local a ctx
  for a in $LARGOS; do
    ctx=$(herdr agent read "$a" --source visible 2>/dev/null | grep -oE '[0-9]+(\.[0-9]+)?K' | tail -1 | tr -d 'K.')
    [ -z "${ctx:-}" ] && continue
    if [ "${ctx%%[!0-9]*}" -ge "$CTX_COMPACTAR" ]; then
      herdr agent prompt "$a" "/compact" >/dev/null 2>&1 && { echo "  compactado $a (contexto ${ctx}, por encima del umbral)"; n=$((n+1)); }
    else
      echo "  $a en ${ctx} — por debajo del umbral, no lo toco"
    fi
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

    # LA REGLA DE EDAD, que antes estaba escrita en un comentario y no existia
    # en el codigo. Un rato mirandola alcanzo para ver que EDAD_MIN aparecia una
    # sola vez en todo el archivo: la declaracion. Documentacion que miente, que
    # es la misma familia que veniamos cazando — decia una cosa y hacia otra, y
    # nadie se quejaba.
    #
    # Un agente joven todavia no engordo, asi que reciclarlo es puro costo: se
    # paga el contexto de nuevo sin recuperar memoria. Se lo deja trabajar sus
    # 40 minutos primero.
    ctx=$(herdr agent read "$nombre" --source visible 2>/dev/null | grep -oE '[0-9]+(\.[0-9]+)?K' | tail -1 | tr -d 'K.')
    if [ -n "${ctx:-}" ] && [ "${ctx%%[!0-9]*}" -lt 2000 ]; then
      echo "  $nombre todavia esta liviano (${ctx}) — lo dejo trabajar"
      continue
    fi

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

# ── Hacer lugar para compilar ───────────────────────────────────────────────
#
# rustc necesita del orden de 2.5 GB para este workspace. Con la flota llena no
# quedan, asi que el compilador no puede compilar — y como no compila, la
# compuerta del objetivo no puede medir si el codigo esta sano. Un recurso que
# nunca esta disponible no es un recurso: es un bloqueo permanente.
#
# Asi que se hace lugar A PROPOSITO y por un rato: se reciclan ociosos hasta
# llegar a la reserva, se compila, y la flota se vuelve a llenar sola porque los
# paneles siguen ahi.
hacer_lugar() {
  local objetivo="${1:-$RESERVA_COMPILAR}" d n=0
  d=$(disp)
  echo "$(date +%H:%M) haciendo lugar para compilar: hay ${d} MB, hacen falta ${objetivo}"
  while [ "$d" -lt "$objetivo" ] && [ "$n" -lt 6 ]; do
    local libre
    libre=$(latigo roster 2>/dev/null | awk -v l="$LARGOS" '$3=="opencode" && $4!="working" && $1!="-" && index(l,$1)==0 {print $1; exit}')
    [ -z "${libre:-}" ] && { echo "  no quedan ociosos que reciclar sin romper trabajo"; break; }
    herdr agent prompt "$libre" "/new" >/dev/null 2>&1 || true
    echo "  reciclado $libre"
    n=$((n+1)); sleep 3; d=$(disp)
  done
  echo "  quedaron ${d} MB (hacian falta ${objetivo})"
  [ "$d" -ge "$objetivo" ] && return 0 || return 1
}

case "${1:-}" in
  --lugar-para-compilar) hacer_lugar "${2:-}"; exit $?;;
  --loop) while true; do una_vuelta; sleep "$INTERVALO"; done ;;
  *)      una_vuelta ;;
esac
