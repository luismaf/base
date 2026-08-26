#!/usr/bin/env bash
# nunca-ocioso.sh — la escalera que se sube cuando el tablero se vacía.
#
# ── POR QUÉ EXISTE ─────────────────────────────────────────────────────────
#
# Los repartidores tienen todos la misma línea: si no hay pendientes, dormir.
# Con obreros gratis e ilimitados eso es exactamente lo que no hay que hacer.
# Un tablero vacío no es "terminamos", es **un jefe que se quedó sin escribir**,
# y hasta que este script existió esa falta de prosa apagaba la flota entera.
#
# Ver docs/DOCTRINA-DEL-JEFE.md. Acá está el músculo de la regla 5:
# "no tengo nada" no es una respuesta.
#
# ── LA ESCALERA ────────────────────────────────────────────────────────────
#
#   1. ¿Hay pendientes?      -> no hay nada que hacer, y está bien.
#   2. RECARGA MEDIBLE.      -> los generadores del repo convierten señales
#                               (huecos de cobertura, errores medidos,
#                               inventario sin cerrar) en ítems, sin redacción.
#   3. NEGOCIO.              -> las cinco preguntas del chip de jefe humano.
#                               Trabajo legítimo, no relleno.
#   4. OTRO PROYECTO.        -> últimísima instancia, y aun así antes que
#                               dejar un dev apagado.
#
# Se sube un peldaño sólo si el anterior no alcanzó. Nunca se saltean.
#
# ── USO ────────────────────────────────────────────────────────────────────
#
#   bash scripts/nunca-ocioso.sh          # sube lo que haga falta
#   bash scripts/nunca-ocioso.sh --seco   # dice qué haría
#   MINIMO=10 bash scripts/nunca-ocioso.sh
set -u

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$DIR/.." && pwd)"
NOMBRE="$(basename "$REPO")"
LOG="${OCIOSO_LOG:-$REPO/.logs/nunca-ocioso.log}"
TSV="$REPO/.logs/tablero.tsv"
mkdir -p "$(dirname "$LOG")" 2>/dev/null || true

MINIMO="${MINIMO:-12}"        # por debajo de esto el tablero se considera vacío
PRESTAMO="${PRESTAMO:-6}"     # cuántos ítems se piden prestados de una
SECO=0
[ "${1:-}" = "--seco" ] && SECO=1

# Los otros repos, en el orden en que se les pide prestado.
# Los otros repos de esta máquina, en el orden en que se les pide prestado.
# Se configura por instalación; vacío = no hay a quién pedirle.
VECINOS="${OCIOSO_VECINOS:-}"

registrar() { printf '%s %s\n' "$(date '+%F %T')" "$*" | tee -a "$LOG"; }
pendientes() { grep -cP '^pendiente\t' "$TSV" 2>/dev/null || echo 0; }

agregar() { # $1=titulo $2=cuerpo
  if [ "$SECO" = "1" ]; then registrar "[seco] agregaría: ${1:0:70}"; return 0; fi
  printf '%s\n\n%s\n' "$1" "$2" | bash "$DIR/tablero.sh" add "$1" >/dev/null 2>&1
}

# Un ítem que ya está en el tablero no se vuelve a poner. Sin esto, cada vuelta
# de la escalera duplica las mismas cinco preguntas y el tablero se convierte
# en un eco.
ya_esta() { grep -qP "^(pendiente|tomado)\t[^\t]*\t[^\t]*\t[^\t]*\t[^\t]*\t\Q$1\E" "$TSV" 2>/dev/null; }

# ── Peldaño 2: recarga medible ─────────────────────────────────────────────
#
# Los generadores del repo van en scripts/recarga.conf, uno por línea, cada uno
# un comando que imprime ítems (uno por línea) o que carga el tablero solo. El
# punto es que sean MEDICIONES: cobertura, errores, inventario. Una medición no
# se agota ni se repite sola, y no necesita que nadie redacte.
peldano_recarga() {
  local conf="$DIR/recarga.conf" cmd n=0
  [ -f "$conf" ] || return 1
  while IFS= read -r cmd; do
    cmd="${cmd%%#*}"; cmd="$(printf '%s' "$cmd" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    [ -z "$cmd" ] && continue
    if [ "$SECO" = "1" ]; then registrar "[seco] correría el generador: $cmd"; n=$((n+1)); continue; fi
    registrar "generador: $cmd"
    ( cd "$REPO" && timeout 600 bash -c "$cmd" ) >>"$LOG" 2>&1 && n=$((n+1))
  done < "$conf"
  [ "$n" -gt 0 ]
}

# ── Peldaño 3: las cinco preguntas del chip de jefe humano ─────────────────
#
# No son tareas de relleno: cada una manda a MEDIR algo del negocio y a actuar
# sobre lo peor que encuentre. Un panel que cierra una de éstas deja el
# producto mejor vendido, no el tablero más lleno.
peldano_negocio() {
  local n=0
  agregar_si_falta() {
    ya_esta "$1" && return 0
    agregar "$1" "$2"; n=$((n+1))
  }

  agregar_si_falta \
    "NEGOCIO-SOFTWARE ($NOMBRE): lo que esta flojo, medido y arreglado" \
"Elegi UNA parte del producto que este floja y dejala bien. No preguntes cual: medila.
Como medirla, en este orden:
  1. Que se rompe seguido: mira los errores del backend y del frontend de los ultimos dias.
  2. Que da verguenza mostrar: abri la app y busca la pantalla que no mostrarias en una demo.
  3. Que esta a medias: buscar TODO/FIXME/unimplemented en el codigo que se toco este mes.
Elegi UNA sola, la peor, y arreglala entera. Al cerrar decí que mediste, que elegiste y por que.
NO agregues una funcionalidad nueva en este item. Este item es dejar bien lo que ya existe."

  agregar_si_falta \
    "NEGOCIO-PLATA ($NOMBRE): que se puede cobrar de lo que ya tenemos casi hecho" \
"Pensa como el dueno de la empresa, no como programador.
Recorre el producto y armá una lista corta de lo que YA EXISTE o esta al 80% y se podria cobrar aparte:
un modulo que se vende solo, una integracion que otro cobra, un informe que un cliente pagaria.
Para cada uno: que falta para poder venderlo, cuanto trabajo es, y a quien se le vende.
Dejalo en docs/ como un documento corto y honesto (si algo no da para vender, decilo).
Al cerrar, cargá en el tablero los items concretos del que mas cerca este de poder venderse."

  agregar_si_falta \
    "NEGOCIO-USUARIO ($NOMBRE): que le hace perder tiempo al que usa esto" \
"Buscá las tres cosas que mas tiempo le hacen perder al usuario todos los dias.
Pistas: pantallas con muchos clicks para algo frecuente, datos que se cargan a mano y podrian venir solos,
cosas que hay que hacer dos veces, informes que se arman exportando a Excel.
Elegi la peor y sacale el dolor de cabeza: menos clicks, valor por defecto, carga automatica, lo que sea.
Al cerrar decí cuanto tiempo le ahorra por semana, con la cuenta hecha."

  agregar_si_falta \
    "NEGOCIO-VENTA ($NOMBRE): que le falta para ganarle al de al lado" \
"Compará el producto contra la competencia en una funcionalidad concreta que el cliente pregunte.
Si el repo tiene una matriz de competencia, arrancá por ahi y buscá una celda en rojo que se pueda dar vuelta hoy.
Si no la tiene, armala para el area que mejor conozcas.
Elegi UNA celda en rojo, hacela verde de verdad (no en el documento: en el producto) y actualizá la matriz.
Al cerrar decí que celda era y como se demuestra que ahora esta."

  agregar_si_falta \
    "NEGOCIO-VELOCIDAD ($NOMBRE): la deuda que nos frena todos los dias" \
"La deuda que frena a los que trabajan es mas cara que la que molesta al usuario, porque se paga todos los dias.
Buscá que nos hace lentos: el build, un script que hay que correr a mano, un paso del deploy que falla seguido,
un archivo gigante que todos tienen que tocar, una parte del codigo donde siempre se rompe lo mismo.
Elegi UNA y arreglala para siempre. Al cerrar decí cuanto tiempo se ahorra por vuelta y cuantas vueltas hay por dia."

  [ "$n" -gt 0 ]
}

# ── Peldaño 4: pedirle prestado a otro proyecto ────────────────────────────
#
# Últimísima instancia. El ítem se copia con el prefijo PRESTADO y lleva
# adentro la advertencia de prioridad: en cuanto el propio repo tenga trabajo,
# esto se suelta. Un dev prestado no es un dev regalado.
peldano_prestamo() {
  local v n=0 pend
  for v in $VECINOS; do
    [ "$(cd "$v" 2>/dev/null && pwd)" = "$REPO" ] && continue
    [ -f "$v/.logs/tablero.tsv" ] || continue
    pend=$(grep -cP '^pendiente\t' "$v/.logs/tablero.tsv" 2>/dev/null || echo 0)
    [ "$pend" -lt 20 ] && continue   # no se le saca trabajo a un vecino justo
    while IFS=$'\t' read -r _ id _ _ _ titulo _; do
      [ -z "${titulo:-}" ] && continue
      ya_esta "PRESTADO $(basename "$v"): $titulo" && continue
      agregar "PRESTADO $(basename "$v"): $titulo" \
"ULTIMA INSTANCIA. No habia nada en $NOMBRE y un dev apagado cuesta mas que un dev prestado.

PRIMERO: cd $v
El pedido completo esta en $v/.logs/tablero/$id.md - leelo entero antes de tocar nada.
Al cerrarlo se cierra ALLA: cd $v && bash scripts/tablero.sh done $id
y ademas aca: bash scripts/tablero.sh done <el id de ESTE item>.

PRIORIDAD: si mientras trabajas en esto aparece trabajo de $NOMBRE, esto se suelta y volves.
El proyecto propio va primero, segundo y tercero."
      n=$((n+1))
      [ "$n" -ge "$PRESTAMO" ] && break
    done < <(grep -P '^pendiente\t' "$v/.logs/tablero.tsv" | head -"$PRESTAMO")
    [ "$n" -ge "$PRESTAMO" ] && break
  done
  [ "$n" -gt 0 ]
}

# ── La escalera ────────────────────────────────────────────────────────────
p=$(pendientes)
if [ "$p" -ge "$MINIMO" ]; then
  registrar "$NOMBRE: $p pendientes, la flota tiene de que agarrarse"
  exit 0
fi
registrar "$NOMBRE: SOLO $p pendientes (minimo $MINIMO) - subo la escalera"

if peldano_recarga; then
  registrar "$NOMBRE: peldano 2 (recarga medible) -> $(pendientes) pendientes"
  [ "$(pendientes)" -ge "$MINIMO" ] && exit 0
fi

if peldano_negocio; then
  registrar "$NOMBRE: peldano 3 (negocio) -> $(pendientes) pendientes"
  [ "$(pendientes)" -ge "$MINIMO" ] && exit 0
fi

if peldano_prestamo; then
  registrar "$NOMBRE: peldano 4 (prestamo a otro proyecto) -> $(pendientes) pendientes"
  exit 0
fi

# Si se llego hasta aca, no hay trabajo en NINGUN repo. Eso no es un estado
# normal: es una noticia, y el dueno tiene que enterarse.
registrar "$NOMBRE: ATENCION - sin trabajo en ningun repo. Esto lo tiene que ver el dueno."
[ -x "$DIR/avisar-jefe.sh" ] && [ "$SECO" = "0" ] && \
  bash "$DIR/avisar-jefe.sh" "NUNCA-OCIOSO: $NOMBRE se quedo sin trabajo y tampoco hay en los vecinos. Hace falta que el jefe cargue objetivos nuevos." >/dev/null 2>&1
exit 1
