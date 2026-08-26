#!/usr/bin/env bash
# poblar-flota.sh — meter devs hasta que la RAM diga basta.
#
# ── LA ARITMÉTICA DADA VUELTA ──────────────────────────────────────────────
#
# Los devs ox alpha son GRATIS E ILIMITADOS. El único límite es la memoria de
# esta máquina. Con eso, la cuenta de siempre se invierte: un panel apagado no
# ahorra nada. **Un gramo de RAM libre es un obrero que no contratamos.**
#
# Por eso este script no pregunta "¿cuántos paneles quiero?". Pregunta
# "¿cuánta RAM sobra?" y mete devs de a uno hasta que no sobre más.
#
# ── POR QUÉ DE A UNO Y NO UNA CUENTA DE UNA ────────────────────────────────
#
# Un dev recién abierto pesa ~230 MB y uno con horas de sesión encima llega a
# ~1.6 GB. Cualquier número calculado de antemano con un promedio se equivoca
# en la dirección peligrosa. Midiendo DESPUÉS DE CADA UNO, el propio consumo
# frena la expansión sin que nadie tenga que adivinar.
#
# ── EL PISO NO ES COBARDÍA ─────────────────────────────────────────────────
#
# `rustc` compilando este workspace llega a 5 GB él solo, y el carril de build
# es de a uno por máquina pero existe siempre. Si la flota se come esa reserva,
# el OOM killer no elige con criterio: se lleva paneles con trabajo a medio
# hacer, y perdemos más de lo que ganamos. El piso ES la política de máximo
# aprovechamiento, no su excepción.
#
# ── A QUIÉN LE TOCA EL DEV QUE SOBRA ───────────────────────────────────────
#
# Al repo con más HAMBRE: pendientes por panel. Un tablero con 2500 ítems y 12
# paneles tiene más hambre que uno con 40 y 9, y se lleva el próximo. Así la
# flota se reequilibra sola sin que nadie reparta a mano.
#
# ── USO ────────────────────────────────────────────────────────────────────
#
#   bash scripts/poblar-flota.sh            # llenar hasta el piso
#   bash scripts/poblar-flota.sh --seco     # decir qué haría, sin tocar nada
#   bash scripts/poblar-flota.sh --max 3    # agregar como mucho 3
#   PISO_MB=6000 bash scripts/poblar-flota.sh
set -u

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG="${POBLAR_LOG:-$(cd "$DIR/.." && pwd)/.logs/poblar-flota.log}"
mkdir -p "$(dirname "$LOG")" 2>/dev/null || true

PISO_MB="${PISO_MB:-9000}"        # MemAvailable que NUNCA se baja (rustc solo llega a 5 GB)
COSTO_MIN_MB="${COSTO_MIN_MB:-900}"  # lo que se presume que va a pesar un dev nuevo
POR_PESTANA="${POR_PESTANA:-4}"   # más de esto y los paneles quedan astillas ilegibles
PISO_PANELES="${PISO_PANELES:-4}" # devs que todo proyecto con trabajo tiene antes de que otro repita
MAX="${MAX:-99}"
SECO=0

# `for a in "$@"` con un `shift` adentro no consume el argumento del --max:
# la lista ya está fijada cuando el for arranca. Va while, que sí avanza.
while [ $# -gt 0 ]; do
  case "$1" in
    --seco)  SECO=1 ;;
    --max)   shift; MAX="${1:-99}" ;;
    --max=*) MAX="${1#--max=}" ;;
    *) echo "opción desconocida: $1" >&2; exit 64 ;;
  esac
  shift
done

# Los repos, en orden de prioridad para desempatar. El de más hambre gana
# igual; esto sólo decide entre dos que tienen la misma.
# Los repos de esta máquina, en orden de prioridad. Se ajusta por instalación.
REPOS_DEFAULT="${POBLAR_REPOS_DEFAULT:-$(cd "$DIR/.." && pwd)}"
REPOS="${POBLAR_REPOS:-$REPOS_DEFAULT}"

# El harness, si el repo lo trae: da el plan B de `agregar_dev`.
# shellcheck source=/dev/null
[ -f "$DIR/harness.sh" ] && . "$DIR/harness.sh" 2>/dev/null || true

registrar() { printf '%s %s\n' "$(date '+%F %T')" "$*" | tee -a "$LOG"; }

disponible_mb() { awk '/^MemAvailable:/{print int($2/1024)}' /proc/meminfo; }

# Lo que de verdad cuesta un dev acá, ahora.
#
# PSS y no RSS: RSS cuenta dos veces las páginas compartidas entre treinta
# procesos del mismo binario y haría parecer que la flota pesa el doble.
#
# Y el PERCENTIL 90, no la mediana. Un dev recién abierto pesa ~230 MB y con
# horas de sesión encima llega a ~1.6 GB. Presupuestar por la mediana es
# presupuestar el precio de un obrero el primer día y sorprenderse en el
# tercero: el bucle mide después de cada uno, pero mide devs que todavía no
# crecieron. La única equivocación que se paga cara acá es quedarse corto de
# RAM, así que se presupuesta por lo que van a pesar, no por lo que pesan.
costo_mb() {
  local m
  m=$(for pid in $(pgrep -x opencode 2>/dev/null); do
        awk '/^Pss:/{s+=$2} END{if (s) print int(s/1024)}' "/proc/$pid/smaps_rollup" 2>/dev/null
      done | sort -n | awk '{v[NR]=$1} END{if (NR) print v[int((NR*9+9)/10)]}')
  [ -z "$m" ] && m=0
  [ "$m" -lt "$COSTO_MIN_MB" ] && m="$COSTO_MIN_MB"
  echo "$m"
}

# Paneles por repo: cuántos devs vivos tiene cada uno (cwd real == raíz).
paneles_de() {
  herdr agent list 2>/dev/null | REPO="$1" python3 -c '
import json, os, sys
raiz = os.path.realpath(os.environ["REPO"])
try:
    d = json.load(sys.stdin)
except Exception:
    print(0); sys.exit(0)
n = 0
for a in d.get("result", {}).get("agents", []):
    if a.get("agent") != "opencode":
        continue
    if os.path.realpath(a.get("cwd") or "/dev/null") == raiz:
        n += 1
print(n)
'
}

pendientes_de() { grep -cP '^pendiente\t' "$1/.logs/tablero.tsv" 2>/dev/null || echo 0; }

# El repo con más pendientes POR PANEL. Sin pendientes no se le suma gente:
# poner un dev a mirar un tablero vacío es exactamente lo que nunca-ocioso.sh
# viene a resolver, y no se arregla con más paneles.
#
# ── EL PISO POR PROYECTO VA ANTES QUE EL HAMBRE ────────────────────────────
#
# El hambre cruda manda todo al tablero más grande, y el tamaño de un tablero
# dice más de cómo se cargó que de cuánto importa el proyecto. El 2026-08-26
# agp tenía 2441 pendientes porque su tablero se había reconstruido y 2270
# ítems ya cerrados volvieron como pendientes; ux tenía 39 y tuti 21. Con
# hambre pura, los ocho devs nuevos fueron los ocho a agp y tuti se quedó con
# dos, cuando tuti también tiene objetivos que cumplir.
#
# La regla del dueño es que TODOS los proyectos lleguen a sus objetivos. Así
# que primero se cubre el piso de cada uno y recién después se reparte por
# hambre. Un proyecto con trabajo pendiente y menos de PISO_PANELES devs gana
# siempre, sin importar cuántos ítems tenga el vecino.
repo_mas_hambriento() {
  local mejor="" mejor_h=-1 r pend pan h
  # Primera vuelta: pisos sin cubrir, el más flaco primero.
  local flaco="" flaco_n=99999
  for r in $REPOS; do
    [ -d "$r/.logs" ] || continue
    pend=$(pendientes_de "$r"); [ "$pend" -eq 0 ] && continue
    pan=$(paneles_de "$r")
    if [ "$pan" -lt "$PISO_PANELES" ] && [ "$pan" -lt "$flaco_n" ]; then
      flaco_n=$pan; flaco="$r"
    fi
  done
  [ -n "$flaco" ] && { echo "$flaco"; return; }
  # Segunda vuelta: todos con su piso cubierto, gana el hambre.
  for r in $REPOS; do
    [ -d "$r/.logs" ] || continue
    pend=$(pendientes_de "$r"); pan=$(paneles_de "$r")
    [ "$pend" -eq 0 ] && continue
    h=$(( pend * 100 / (pan + 1) ))
    if [ "$h" -gt "$mejor_h" ]; then mejor_h=$h; mejor="$r"; fi
  done
  [ -n "$mejor" ] && echo "$mejor"
}

# Dónde poner el panel nuevo: una pestaña de la flota con lugar, o una nueva.
# Sin esto todos los splits caen en la misma pestaña y a los seis los paneles
# son astillas de doce columnas donde no se lee nada.
pestana_con_lugar() {
  local cwd="$1"
  herdr tab list 2>/dev/null | POR="$POR_PESTANA" REPO="$1" python3 -c '
import json, os, sys
tope = int(os.environ["POR"])
marca = "flota-" + os.path.basename(os.environ["REPO"].rstrip("/"))
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
for t in d.get("result", {}).get("tabs", []):
    if not (t.get("label") or "").startswith(marca):
        continue
    if int(t.get("pane_count") or 0) < tope:
        print(t.get("tab_id")); break
'
}

# `tab get` no lista los paneles de la pestaña, sólo los cuenta. Los ids salen
# de `pane list`, que trae el tab_id de cada uno.
pane_libre_en() {
  herdr pane list 2>/dev/null | TAB="$1" python3 -c '
import json, os, sys
tab = os.environ["TAB"]
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
p = [x["pane_id"] for x in d.get("result", {}).get("panes", []) if x.get("tab_id") == tab]
if p: print(p[-1])
'
}

agregar_dev() {
  local cwd="$1" etiqueta tab pane
  # En una línea sola esto no anda: `local a="$1" b="$(… $a …)"` expande $a
  # ANTES de que `local` haya asignado nada, y con `set -u` eso es un error.
  etiqueta="flota-$(basename "$cwd")-$(date +%H%M%S)"
  tab="$(pestana_con_lugar "$cwd")"
  if [ -z "$tab" ]; then
    tab="$(herdr tab create --cwd "$cwd" --label "$etiqueta" 2>/dev/null | python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
t = d.get("result", {}).get("tab", {}) or {}
print(t.get("tab_id", ""))
')"
    [ -z "$tab" ] && { registrar "no pude crear pestaña para $cwd"; return 1; }
    sleep 1
    pane="$(pane_libre_en "$tab")"
  else
    pane="$(pane_libre_en "$tab")"
    [ -n "$pane" ] && pane="$(herdr pane split --pane "$pane" --direction right --cwd "$cwd" --no-focus 2>/dev/null | python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
print((d.get("result", {}).get("pane", {}) or {}).get("pane_id", ""))
')"
  fi
  # ── SI NO SE PUDO POR HERDR, EL HARNESS ────────────────────────────────
  # base existe para que cambiar de herramienta de agentes sea tocar
  # harness.sh y ningún archivo más. Todo lo de arriba —pestañas, splits, cwd
  # por panel— es específico de herdr y es lo que hace que un dev nazca EN SU
  # REPO y en una pestaña legible. Cuando esa herramienta no está, se cae al
  # contrato genérico: `harness_start` abre un obrero donde pueda. Pierde el
  # control del directorio, así que es el plan B y no el plan A.
  if [ -z "$pane" ] && command -v harness_start >/dev/null 2>&1; then
    if harness_start "obrero-$(date +%s)" "$KIND" --auto >/dev/null 2>&1; then
      registrar "DEV NUEVO por harness_start (sin control de cwd) para $cwd"
      return 0
    fi
  fi
  [ -z "$pane" ] && { registrar "no conseguí panel para $cwd"; return 1; }

  # Arrancar y DEJARLO TIBIO en el mismo movimiento. saludar-dev.sh abre
  # `opencode --auto` donde ve un shell pelado y saluda esperando respuesta,
  # que es justo lo que hace falta acá: un panel recién abierto al que el
  # repartidor le tire cuarenta líneas se bloquea.
  SALUDO_ARRANCAR=1 bash "$DIR/saludar-dev.sh" "$pane" --forzar >/dev/null 2>&1
  local rc=$?
  if [ "$rc" != "0" ]; then registrar "$pane ($cwd): no quedó listo (rc=$rc)"; return 1; fi
  registrar "DEV NUEVO $pane en $(basename "$cwd") (pestaña $tab)"
  return 0
}

# ── El bucle ───────────────────────────────────────────────────────────────
disp=$(disponible_mb); costo=$(costo_mb); sumados=0
registrar "arranco: disponible=${disp}MB piso=${PISO_MB}MB costo_por_dev=${costo}MB (medido)"

# ── POR QUÉ HAY UN PRESUPUESTO Y NO SÓLO UNA MEDICIÓN ──────────────────────
#
# Medir después de cada dev parece suficiente y no lo es: un dev recién abierto
# pesa ~230 MB y tarda minutos en llegar a su tamaño real. Midiendo entre uno y
# otro se ven ocho devs que "casi no pesan" y se siguen agregando. El
# 2026-08-26 así se pasó de 18.5 GB disponibles a 6.9 GB con un piso de 8 GB:
# ninguna medición individual mintió, mintió el momento en que se tomó.
#
# Entonces hay dos frenos y gana el más pesimista: un PRESUPUESTO que descuenta
# el costo completo de cada dev apenas se lo crea —como si ya hubiera crecido—,
# y la medición en vivo, que sólo puede recortarlo más, nunca ampliarlo.
presupuesto=$((disp - PISO_MB))

while [ "$sumados" -lt "$MAX" ]; do
  disp=$(disponible_mb)
  restante=$((disp - PISO_MB))
  [ "$restante" -lt "$presupuesto" ] && presupuesto=$restante
  if [ "$presupuesto" -lt "$costo" ]; then
    registrar "freno: presupuesto ${presupuesto}MB < ${costo}MB por dev (disponible ${disp}MB, piso ${PISO_MB}MB)"
    break
  fi
  destino="$(repo_mas_hambriento)"
  if [ -z "$destino" ]; then
    registrar "freno: ningún repo tiene pendientes. Más paneles no arreglan un tablero vacío — eso lo resuelve nunca-ocioso.sh"
    break
  fi
  if [ "$SECO" = "1" ]; then
    registrar "[seco] agregaría un dev en $(basename "$destino") (disponible ${disp}MB)"
    sumados=$((sumados + 1))
    [ "$sumados" -ge 6 ] && break
    continue
  fi
  agregar_dev "$destino" || break
  sumados=$((sumados + 1))
  presupuesto=$((presupuesto - costo))
  sleep 3
done

registrar "listo: $sumados dev(s) nuevos, disponible=$(disponible_mb)MB"
