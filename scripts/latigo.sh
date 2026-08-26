#!/usr/bin/env bash
# latigo.sh - fleet watchdog: when a panel goes idle without telling the boss,
# it asks why and hands it an item from the board.
#
# ── FOUR BUGS THIS FILE SHIPPED WITH (1-3 fixed 2026-08-24, 4 on 2026-08-26) ─
#
# 1. IT WHIPPED THE BOSS. There was no exclusion of any kind: `herdr agent
#    list` returns every pane in every workspace, and each idle one got the
#    whip. That includes the supervisor's Claude pane and the owner's own
#    interactive session. The owner watched an automated "why are you idle"
#    land in his conversation, and every one of those costs him tokens.
#    The durable invariant, the same one autopiloto.sh already relies on:
#    the workers in this repo are ALL opencode. A `claude` pane here is a
#    conversation, never a worker. That check survives panels dying, ids
#    changing and roles being renamed in docs/jefe.md - which is exactly how
#    the id-based and name-based exclusions rotted in the first place.
#
# 2. IT WHIPPED OTHER PROJECTS. No cwd filter, so panels working in
#    sibling repos and $HOME were handed
#    items from the project board. autopiloto.sh learned this lesson months ago
#    (see the note at the end of scripts/colas.conf); this script never did.
#
# 3. IT HANDED THE SAME ITEM TO EVERY PANEL. `next_item` read the FIRST
#    pending title straight off the tsv without claiming it, so a sweep that
#    found four idle panels told all four to do the same ticket. Four panels
#    colliding on one file is worse than four panels idle. Now the item is
#    claimed atomically through `tablero.sh take`, which is the only writer
#    allowed to touch that file, and the panel is given the id so it can
#    close it.
# 4. IT WROTE INTO CLOSED WINDOWS (fixed 2026-08-26). Both `herdr agent
#    prompt` and `send-keys` were called with `>/dev/null 2>&1` and their exit
#    status was never read, so a dispatch "succeeded" even when the pane was
#    gone, when the pane was alive but its opencode had died (the prompt then
#    lands on a bash prompt, which tries to RUN it), or when opencode was
#    refusing every request with a connection error. The item stayed `tomado`
#    by a panel that could not possibly close it, and `take` had already
#    charged it an attempt - three closed windows in a row are enough to mark
#    a perfectly good item TRABADO. That is where the 92 items rescued by
#    `tablero.sh huerfanos` came from, and why w5:p3C sat since 24 Aug with
#    "Tomá el ítem 20260824-110251-0172347" frozen in its terminal title.
#
#    The fix is scripts/saludar-dev.sh: before naming an item, make sure the
#    window exists, that a dev is running in it (open `opencode --auto` if
#    not), and that it is not refusing; then greet it with "hola" AND WAIT FOR
#    THE ANSWER. A cold window handed a forty-line request locks up and stops
#    answering; the same window greeted first takes it whole. If the ritual
#    fails the item goes back with `tablero.sh devolver`, which does not
#    charge the attempt - the item did nothing wrong, the dispatcher did.
#
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOG="$ROOT/.logs/latigo.log"
STATE="$ROOT/.logs/latigo.state"
# ── LAS VÁLVULAS ESTABAN CALIBRADAS PARA OBREROS QUE SE PAGAN (2026-08-26) ──
#
# COOLDOWN era 900: un panel que cerraba su ítem en dos minutos esperaba
# QUINCE para recibir el siguiente, con el tablero lleno al lado. Esa moderación
# tiene sentido cuando cada prompt cuesta plata y hay una persona del otro lado
# a la que se puede acosar. Con obreros ox alpha —gratis, ilimitados, sin
# nadie a quien molestar— está exactamente al revés: un panel parado con
# treinta ítems esperando no es prudencia, es desperdicio.
#
# El hallazgo es del jefe de munix, que tuvo tres paneles quietos con 31 ítems
# en cola y los tres salieron en el mismo segundo al poner las válvulas en cero.
#
# El anti-acoso que SÍ hace falta no es este: es el tope de intentos de
# `tablero.sh take`, que protege al ÍTEM de rebotar para siempre. Eso queda.
COOLDOWN=${COOLDOWN:-0}     # seconds between whips to the same panel; 0 = sin freno
INTERVAL=${INTERVAL:-120}   # sweep frequency
VUELTAS=${VUELTAS:-6}       # barridos por pasada: uno solo no vacía la lista de libres
touch "$STATE"

# The supervisor loop invokes this as `latigo.sh --una`: one sweep, then exit.
# Without it the script ran forever and only stopped because the caller wrapped
# it in `timeout 240` - so every sweep was killed mid-flight, which is a fine
# way to lose a claimed item between `take` and the prompt landing.
ONCE=0
[ "${1:-}" = "--una" ] && ONCE=1

# ── EL FOCO ES DE LA PERSONA, NO DEL SISTEMA ───────────────────────────────
#
# Mandarle un mensaje a un panel a veces lo enfoca, y eso le roba la pantalla
# al dueño aunque esté en otro workspace. Se anota quién tenía el foco antes de
# barrer y se lo devuelve al terminar. Que la maquinaria ande no puede costarle
# la pantalla al que la está usando.
foco_actual() {
  herdr agent list 2>/dev/null | python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
for a in d.get("result", {}).get("agents", []):
    if a.get("focused"):
        print(a.get("pane_id", "")); break
' 2>/dev/null
}

# La regla fina, y es la que evita que el arreglo sea peor que el problema:
# devolver el foco SIEMPRE es pelearselo a la persona que se movio a proposito.
# Nuestra automatizacion solo enfoca paneles de obreros. Entonces:
#   el foco quedo en un panel `opencode`  -> lo movimos nosotros, se devuelve
#   el foco quedo en cualquier otra cosa  -> se movio la persona, NO SE TOCA
foco_es_obrero() {
  herdr agent list 2>/dev/null | PANE="${1:-}" python3 -c '
import json, os, sys
pane = os.environ.get("PANE", "")
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(1)
for a in d.get("result", {}).get("agents", []):
    if a.get("pane_id") == pane:
        sys.exit(0 if a.get("agent") == "opencode" else 1)
sys.exit(1)
' 2>/dev/null
}

devolver_foco() {
  [ -n "${1:-}" ] || return 0
  local ahora; ahora="$(foco_actual)"
  [ "$ahora" = "$1" ] && return 0
  foco_es_obrero "$ahora" || return 0
  herdr agent focus "$1" >/dev/null 2>&1 || true
}

last_whip() { awk -F'\t' -v p="$1" '$1==p{print $2}' "$STATE" 2>/dev/null | tail -1; }

# Panels that must never be whipped, by explicit id. Same file autopiloto.sh
# reads, so there is one list and not two that drift apart. This is only the
# manual override; the real defence is the `claude` filter below.
never_whip() {
  [ -f "$ROOT/scripts/no-repartir.conf" ] || return 1
  sed 's/#.*//' "$ROOT/scripts/no-repartir.conf" | tr -d ' \t' | grep -qx "$1"
}

# Panels adopted by this repo despite living in another cwd (see the conf).
adopted() {
  [ -f "$ROOT/scripts/paneles-adoptados.conf" ] || return 1
  sed 's/#.*//' "$ROOT/scripts/paneles-adoptados.conf" | tr -d ' \t' | grep -qx "$1"
}

adopted_list() {
  [ -f "$ROOT/scripts/paneles-adoptados.conf" ] || return 0
  sed 's/#.*//' "$ROOT/scripts/paneles-adoptados.conf" | tr -d ' \t' | grep -v '^$'
}

# Idle panels OF THIS REPO that are actual workers.
# "Of this repo" means cwd == root OR listed in paneles-adoptados.conf: a panel
# whose shell happened to start in the home directory is still a worker, and before the
# adoption list it was skipped without ever appearing in the log.
idle_workers() {
  herdr agent list 2>/dev/null | ROOT="$ROOT" ADOPTED="$(adopted_list | tr '\n' ' ')" python3 -c "
import json, os, sys
root = os.path.realpath(os.environ['ROOT'])
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
adopted = set(os.environ.get('ADOPTED', '').split())
for a in d.get('result', {}).get('agents', []):
    if a.get('agent_status') not in ('idle', 'done'):
        continue
    # A claude pane in this repo is the supervisor or the owner, not a worker.
    if a.get('agent') != 'opencode':
        continue
    pid = a.get('pane_id', '')
    if os.path.realpath(a.get('cwd') or '/dev/null') != root and pid not in adopted:
        continue
    print(pid)
"
}

while true; do
    # ── UN TABLERO VACÍO YA NO ES UNA RAZÓN PARA DORMIR (2026-08-26) ────────
    #
    # Esto decía: "no hay pendientes, recargar es decisión del jefe, a dormir".
    # Con obreros gratis e ilimitados eso es lo contrario de lo que hay que
    # hacer — un tablero vacío no es "terminamos", es un jefe que se quedó sin
    # escribir, y esa falta de prosa apagaba la flota entera.
    #
    # Ahora se sube la escalera de nunca-ocioso.sh: recarga medible, después
    # trabajo de negocio, y en últimísima instancia se le pide prestado a otro
    # proyecto. Ver docs/DOCTRINA-DEL-JEFE.md.
    if [ "$(grep -cP '^pendiente\t' "$ROOT/.logs/tablero.tsv" 2>/dev/null)" = "0" ]; then
        if [ -x "$ROOT/scripts/nunca-ocioso.sh" ]; then
            bash "$ROOT/scripts/nunca-ocioso.sh" >>"$LOG" 2>&1
        fi
        # Si la escalera tampoco consiguió nada, no hay trabajo en ningún repo
        # y eso ya quedó avisado. Recién ahí se duerme.
        if [ "$(grep -cP '^pendiente\t' "$ROOT/.logs/tablero.tsv" 2>/dev/null)" = "0" ]; then
            [ "$ONCE" = "1" ] && break
            sleep "$INTERVAL"; continue
        fi
    fi
    now=$(date +%s)
    foco_previo="$(foco_actual)"

    # ── UNA PASADA NO ALCANZA ──────────────────────────────────────────────
    # `idle_workers` se lee una vez y se reparte a ésos. Los que quedaron
    # libres a mitad del barrido —o los que se liberaron JUSTO cuando el
    # barrido pasó por al lado— esperaban el próximo INTERVAL entero. Con
    # obreros gratis eso son dos minutos de flota apagada por cada vuelta.
    # Ahora se barre hasta que no quede nadie libre o se vacíe el tablero.
    for vuelta in $(seq 1 "$VUELTAS"); do
    repartidos=0
    for p in $(idle_workers); do
        [ -n "$p" ] || continue
        never_whip "$p" && continue
        lw=$(last_whip "$p")
        [ -n "$lw" ] && [ $((now - lw)) -lt $COOLDOWN ] && continue

        # Claim the item for THIS panel before naming it, so two panels can
        # never be sent the same one.
        id=$(bash "$ROOT/scripts/tablero.sh" take "$p" 2>/dev/null | tail -1)
        if [ -z "$id" ]; then
            echo "$(date '+%F %T') sin items para $p" >> "$LOG"
            continue
        fi
        title=$(awk -F'\t' -v i="$id" '$2==i{print $6}' "$ROOT/.logs/tablero.tsv" 2>/dev/null | head -1)

        # EL SALUDO VA ANTES DEL PEDIDO. Sin esto el látigo le escribe a
        # ventanas cerradas, a shells sin dev adentro y a devs que están
        # rechazando, y el ítem se muere tomado por un panel que no existe.
        # Ver la nota 4 de arriba y scripts/saludar-dev.sh.
        bash "$ROOT/scripts/saludar-dev.sh" "$p" >/dev/null 2>&1
        listo=$?
        if [ "$listo" != "0" ]; then
            # `devolver`, no `soltar`: el pedido nunca llegó, así que el ítem
            # no paga el intento.
            bash "$ROOT/scripts/tablero.sh" devolver "$p" >/dev/null 2>&1
            case "$listo" in
              2) echo "$(date '+%F %T') VENTANA CERRADA $p - item=$id devuelto" >> "$LOG" ;;
              3) echo "$(date '+%F %T') OCUPADO $p (no es momento) - item=$id devuelto" >> "$LOG" ;;
              *) echo "$(date '+%F %T') NO RESPONDE $p (ni con sesion nueva) - item=$id devuelto" >> "$LOG" ;;
            esac
            continue
        fi

        # An adopted panel's shell is NOT in the repo, so every relative path
        # in the prompt below would resolve against the home directory and quietly fail.
        preamble=""
        adopted "$p" && preamble="PRIMERO: cd $ROOT   (tu shell arranco en otro lado; todo lo de abajo es relativo a ese directorio)
"

        herdr agent prompt "$p" \
"${preamble}LATIGAZO AUTOMATICO: estas ocioso y no avisaste al jefe.
1) Avisale AHORA: bash scripts/avisar-jefe.sh \"<que hiciste / por que paraste>\"
2) Ya te reserve este item, es TUYO: $id
   ${title}
   El pedido completo esta en .logs/tablero/$id.md - leelo entero antes de tocar nada.
3) Al cerrarlo: commit + push + aviso al jefe + bash scripts/tablero.sh done $id
   y enseguida bash scripts/tablero.sh take $p para el siguiente. Nunca ocioso.
REGLA DEL DUENO: PROHIBIDO correr suites de tests (vitest/cargo test) - verifica con tsc --noEmit (tus archivos), lectura de codigo o vista en vivo :3000/:8080. Builds rust DE A UNO: pgrep cargo/rustc antes de compilar; si hay otro build corriendo, espera.
REGLA DEL DUENO: codigo y comentarios NUEVOS en INGLES (el espanol vive solo en i18n). Traduci lo que toques." >/dev/null 2>&1
        mando=$?
        # herdr's submit does not always land in opencode: the text can sit
        # typed in the prompt box. The separate Enter is not optional.
        herdr agent send-keys "$p" enter >/dev/null 2>&1

        # Y AHORA SE MIRA SI LLEGÓ. `herdr agent prompt` devuelve error cuando
        # el panel no existe o cuando el texto quedó tipeado sin arrancar
        # (agent_prompt_stalled); tirar ese código a /dev/null es exactamente
        # como se perdían los ítems.
        if [ "$mando" != "0" ]; then
            bash "$ROOT/scripts/tablero.sh" devolver "$p" >/dev/null 2>&1
            echo "$(date '+%F %T') NO LLEGO el pedido a $p - item=$id devuelto" >> "$LOG"
            continue
        fi

        printf '%s\t%s\n' "$p" "$now" >> "$STATE"
        echo "$(date '+%F %T') LATIGAZO $p item=$id ${title:0:60}" >> "$LOG"
        repartidos=$((repartidos + 1))
        sleep 2
    done
    # Nadie libre, o nada que repartir: la vuelta siguiente sería en vano.
    [ "$repartidos" = "0" ] && break
    [ "$(grep -cP '^pendiente\t' "$ROOT/.logs/tablero.tsv" 2>/dev/null)" = "0" ] && break
    done

    devolver_foco "$foco_previo"
    [ "$ONCE" = "1" ] && break
    sleep "$INTERVAL"
done
