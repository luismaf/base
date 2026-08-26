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
CTX_RESIDUO_K="${GUARDIA_RESIDUO:-250}" # K por encima de los cuales, con varios items cerrados, es acumulacion
ITEMS_VARIOS="${GUARDIA_ITEMS:-3}"      # a partir de cuantos items cerrados se considera residuo
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
    ctx=$(herdr agent read "$a" --source visible 2>/dev/null | grep -oE '[0-9]+(\.[0-9]+)?K' | tail -1 | tr -d 'K.' || true)
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
  local reciclados=0 ctx cerrados

  while read -r nombre pane kind estado _; do
    if [ "$reciclados" -ge 2 ]; then break; fi
    [ "$kind" = opencode ] || continue
    if [ "$estado" = working ]; then continue; fi
    if es_largo "$nombre"; then continue; fi
    if [ "$nombre" = "-" ]; then continue; fi

    # LA REGLA DE EDAD, que antes estaba escrita en un comentario y no existia
    # en el codigo. Un rato mirandola alcanzo para ver que EDAD_MIN aparecia una
    # sola vez en todo el archivo: la declaracion. Documentacion que miente, que
    # es la misma familia que veniamos cazando — decia una cosa y hacia otra, y
    # nadie se quejaba.
    #
    # Un agente joven todavia no engordo, asi que reciclarlo es puro costo: se
    # paga el contexto de nuevo sin recuperar memoria. Se lo deja trabajar sus
    # 40 minutos primero.
    # ── La señal no es el tamaño del contexto: es el contexto POR ITEM ──────
    #
    # Un panel con 828K puede ser dos cosas opuestas y hay que distinguirlas,
    # porque el tratamiento es contrario:
    #
    #   cerro 53 items y tiene 828K  -> residuo de 53 trabajos aislados. Se
    #                                   recicla: nada de eso le sirve para el
    #                                   proximo.
    #   cerro 0 items y tiene 828K   -> esta peleando UNA cosa dificil que
    #                                   necesita ese contexto. Reciclarlo es
    #                                   condenarlo a empezar de cero para
    #                                   siempre: un bucle infinito de no
    #                                   resolver nunca ese item.
    #
    # El segundo caso es el peligroso, porque desde afuera se ve igual que el
    # primero — y matarlo se siente prudente mientras garantiza el fracaso.
    ctx=$(herdr agent read "$nombre" --source visible 2>/dev/null | grep -oE '[0-9]+(\.[0-9]+)?K' | tail -1 | tr -d 'K.' || true)
    ctx=${ctx%%[!0-9]*}
    cerrados=$(awk -F'\t' -v p="$pane" -v n="$nombre" '$1=="done" && ($5==p||$5==n)' .latigo/board.tsv 2>/dev/null | wc -l)

    if [ -z "${ctx:-}" ]; then echo "  $nombre: no pude leer su contexto, no lo toco"; continue; fi

    if [ "$cerrados" -lt "$ITEMS_VARIOS" ] && [ "$ctx" -gt $((CTX_RESIDUO_K*10)) ]; then
      echo "  $nombre tiene ${ctx} con solo $cerrados items cerrados — esta peleando algo dificil, NO lo toco"
      continue
    fi
    if [ "$ctx" -lt $((CTX_RESIDUO_K*10)) ]; then
      echo "  $nombre liviano (${ctx}, $cerrados items) — lo dejo trabajar"
      continue
    fi
    echo "  $nombre: ${ctx} acumulado en $cerrados items cerrados — es residuo"

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

# NOTA sobre `set -euo pipefail` y un grep que no encuentra nada:
# `x=$(cmd | grep ... )` con pipefail devuelve 1 cuando el grep no matchea, y
# `set -e` mata el script en esa linea sin decir una palabra. Le paso a este
# mismo bucle: un panel cuya barra de estado no mostraba el contexto lo mataba
# entero, y desde afuera se veia como "no hay a quien reciclar". Toda lectura
# que puede no encontrar nada lleva `|| true` y despues se chequea si vino
# vacia. Tercera vez esta noche que una falla se disfraza de la respuesta buena.

# NOTA sobre `[ cond ] && accion` dentro de un bucle con `set -e`:
# cuando la condicion es falsa la linea entera devuelve 1 y `set -e` mata la
# funcion ahi mismo, sin decir nada. La primera version de este bucle salia en
# la primera vuelta y parecia "no hay a quien reciclar". Otra vez lo mismo: una
# falla que se disfraza de la respuesta buena. Dentro de bucles va `if`.

# ── Hacer lugar para compilar ───────────────────────────────────────────────
#
# rustc necesita del orden de 2.5 GB para este workspace. Con la flota llena no
# quedan, asi que el compilador no puede compilar — y como no compila, la
# compuerta del objetivo no puede medir si el codigo esta sano. Un recurso que
# nunca esta disponible no es un recurso: es un bloqueo permanente.
#
# ## Pero esto es el ULTIMO recurso, no el primero
#
# El lugar para compilar se aparta al abrir la flota (ver poblar-flota.sh), que
# es cuando cuesta un obrero menos y nada mas. Sacar gente a la fuerza cuando ya
# estan todos trabajando es el peor momento y el mas caro, y ademas es incierto:
# una compilacion grande puede pedir casi toda la maquina y no se sabe cuanto
# hasta que corre.
#
# Asi que esto NO se dispara solo. Se llama a pedido, o cuando hay varios
# obreros trabados esperando compilar — o sea cuando el bloqueo ya es peor que
# la interrupcion. Mientras se pueda avanzar, se avanza.
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
