#!/usr/bin/env bash
# saludar-dev.sh — dejar un panel TIBIO antes de darle trabajo.
#
# ── EL BUG QUE ESTO CIERRA ──────────────────────────────────────────────────
#
# Los tres repartidores (latigo, autopiloto, nadie-ocioso) escribían a ciegas.
# `herdr agent prompt` se llamaba con `>/dev/null 2>&1` y sin mirar el código
# de salida, así que el reparto "salía bien" incluso cuando:
#
#   a) LA VENTANA ESTABA CERRADA. El panel ya no existe; el texto no va a
#      ningún lado. El ítem quedó `tomado` por un panel muerto y ahí se murió
#      con él. Así se perdieron 92 ítems, que hubo que rescatar a mano con
#      `tablero.sh huerfanos`.
#
#   b) EN LA VENTANA NO HABÍA NINGÚN DEV. El shell está vivo pero opencode se
#      cerró. El pedido se escribe sobre el prompt de bash, que lo intenta
#      ejecutar como comando y escupe "command not found" cuarenta veces.
#      Caso real y todavía en pantalla: w5:p3C, título del terminal
#      "Freebuff: Tomá el ítem 20260824-110251-0172347 del tablero:…",
#      parado ahí desde el 24 de agosto.
#
#   c) EL DEV ESTABA RECHAZANDO. El error de conexión típico de ox alpha. El
#      panel sigue existiendo, sigue mostrándose `idle`, y no recibe nada.
#
# Y encima `take` cuenta INTENTOS. Tres repartos fallidos contra una ventana
# cerrada marcan TRABADO a un ítem perfecto: el ítem paga el error del
# repartidor. Por eso el que llama debe usar `tablero.sh devolver` y no
# `soltar` cuando el saludo falla — devolver no cobra el intento.
#
# ── EL RITUAL (el dueño lo llama "inicializar al dev", "saludar al dev") ────
#
# Un chat recién abierto al que le tirás una chorrera inmensa se bloquea y no
# contesta más. El mismo chat, saludado con una palabra y esperado hasta que
# conteste, después acepta el pedido largo entero. Es la diferencia entre
# gastar cinco tokens y perder un ítem.
#
#   1. ¿existe la ventana?          no  -> 2, y que el ítem vuelva SIN castigo
#   2. ¿hay un dev corriendo?       no  -> abrir `opencode --auto` y esperar
#   3. ¿la pantalla muestra rechazo? sí -> /new (sesión limpia)
#   4. si hubo (2) o (3): "hola", Y ESPERAR LA RESPUESTA
#   5. recién ahí el que llama manda el pedido de verdad
#
# El paso 4 es el que importa: esperar. Mandar "hola" y seguir de largo no
# sirve, porque la chorrera llega igual con la ventana fría.
#
# ── CUÁNDO NO HACE NADA ────────────────────────────────────────────────────
#
# Si el panel tiene su dev vivo y la pantalla limpia, sale 0 sin gastar un
# token. El saludo es para ventana nueva o para panel que hay que revivir; a
# una conversación que ya viene andando saludarla cada vuelta es tirar plata.
#
# ── USO ────────────────────────────────────────────────────────────────────
#
#   bash scripts/saludar-dev.sh w5:p3C          # el ritual, lo que haga falta
#   bash scripts/saludar-dev.sh w5:p3C --forzar # saludar aunque esté limpio
#   bash scripts/saludar-dev.sh --revisar       # informe de toda la flota
#
#   0  el panel está tibio y listo para recibir el pedido
#   1  no se pudo dejarlo listo  -> devolvé el ítem, no le mandes nada
#   2  la ventana no existe      -> devolvé el ítem y avisá al dueño
#   3  la ventana está ocupada con otra cosa (vim, un build) -> no es momento
set -u

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$DIR/.." && pwd)"
LOG="${SALUDO_LOG:-$ROOT/.logs/saludar-dev.log}"
mkdir -p "$(dirname "$LOG")" 2>/dev/null || true

ESPERA_ARRANQUE="${SALUDO_ARRANQUE_MS:-90000}"   # cuánto se le da a opencode para abrir
ESPERA_HOLA="${SALUDO_HOLA_MS:-120000}"          # cuánto se le da para contestar "hola"
LINEAS="${SALUDO_LINEAS:-40}"                    # cuánta pantalla se mira para buscar el rechazo
CONF="${SALUDO_CONF:-$DIR/errores-conexion.conf}"
KIND="${SALUDO_KIND:-opencode}"
ARRANCAR="${SALUDO_ARRANCAR:-1}"                 # 0 = no abrir devs, sólo diagnosticar

# Procesos que cuentan como "hay un dev acá". freebuff no lo detecta herdr
# como agente pero es un dev del dueño y NO se lo pisa.
DEVS_RE='^(opencode|claude|freebuff|codex|gemini|cursor|aider|amp|droid|kimi|grok|copilot|pi)$'
SHELLS_RE='^(bash|zsh|fish|sh|dash|-bash|-zsh|login)$'

registrar() { printf '%s %s\n' "$(date '+%F %T')" "$*" >> "$LOG"; }

# ── Qué hay en la ventana ──────────────────────────────────────────────────
# Devuelve el nombre del proceso en primer plano, o "" si la ventana no está.
proceso_en() {
  herdr pane process-info --pane "$1" 2>/dev/null | python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(1)
pi = d.get("result", {}).get("process_info")
if not pi:
    sys.exit(1)
fg = pi.get("foreground_processes") or []
print(fg[0].get("name", "") if fg else "")
' 2>/dev/null
}

pantalla() {
  herdr agent read "$1" 2>/dev/null | tail -n "$LINEAS" \
    || herdr pane read "$1" 2>/dev/null | tail -n "$LINEAS"
}

# ── El rechazo ─────────────────────────────────────────────────────────────
# Imprime la huella que matcheó, o nada. Los patrones viven en el .conf para
# que agregar uno nuevo no sea tocar código.
rechazo_en_pantalla() {
  local txt="$1" pat
  [ -f "$CONF" ] || return 1
  while IFS= read -r pat; do
    pat="${pat%%#*}"; pat="$(printf '%s' "$pat" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    [ -z "$pat" ] && continue
    if printf '%s' "$txt" | grep -qiE -- "$pat"; then printf '%s' "$pat"; return 0; fi
  done < "$CONF"
  return 1
}

# ── Abrir un dev donde no hay ninguno ──────────────────────────────────────
# `herdr agent start` hace las dos cosas de una: lanza el binario Y espera a
# que herdr lo detecte listo para recibir. Arrancarlo con send-text dejaría un
# opencode que anda pero que ningún repartidor ve, que es medio arreglo.
abrir_dev() {
  local p="$1" nombre="dev-${1//:/-}" salida
  salida="$(herdr agent start "$nombre" --kind "$KIND" --pane "$p" \
              --timeout "$ESPERA_ARRANQUE" -- --auto 2>&1)"
  if [ $? -eq 0 ]; then registrar "$p: abierto $KIND --auto como $nombre"; return 0; fi
  # El nombre sobrevive al agente que murió: si está tomado, se desempata.
  if printf '%s' "$salida" | grep -qi 'name_taken\|already'; then
    nombre="$nombre-$(date +%s)"
    if herdr agent start "$nombre" --kind "$KIND" --pane "$p" \
         --timeout "$ESPERA_ARRANQUE" -- --auto >/dev/null 2>&1; then
      registrar "$p: abierto $KIND --auto como $nombre (el nombre corto estaba tomado)"
      return 0
    fi
  fi
  registrar "$p: NO pude abrir $KIND --auto: $(printf '%s' "$salida" | tr '\n' ' ' | cut -c1-200)"
  return 1
}

# ── El saludo, esperando la respuesta ──────────────────────────────────────
saludar() {
  local p="$1"
  if herdr agent prompt "$p" "hola" --wait --until idle --until done \
       --timeout "$ESPERA_HOLA" >/dev/null 2>&1; then
    registrar "$p: saludado y contestó"
    return 0
  fi
  # El prompt puede quedar TIPEADO sin arrancar: el Enter aparte no es opcional.
  herdr agent send-keys "$p" enter >/dev/null 2>&1
  if herdr agent wait "$p" --until idle --until done --timeout 30000 >/dev/null 2>&1; then
    registrar "$p: saludado, contestó tras el Enter suelto"
    return 0
  fi
  registrar "$p: no contestó el saludo"
  return 1
}

sesion_nueva() {
  herdr agent prompt "$1" "/new" >/dev/null 2>&1 || true
  herdr agent send-keys "$1" enter >/dev/null 2>&1 || true
  sleep 3
}

# ── El ritual completo, para un panel ──────────────────────────────────────
ritual() {
  local p="$1" forzar="${2:-0}" proc txt huella saludo_obligatorio=0

  proc="$(proceso_en "$p")"
  if [ $? -ne 0 ] || [ -z "${proc+x}" ]; then :; fi

  if ! herdr pane get "$p" >/dev/null 2>&1; then
    registrar "$p: VENTANA CERRADA — no existe el panel"
    return 2
  fi

  if [ -z "$proc" ] || printf '%s' "$proc" | grep -qE "$SHELLS_RE"; then
    registrar "$p: sin dev (primer plano: ${proc:-nada})"
    [ "$ARRANCAR" = "1" ] || return 1
    abrir_dev "$p" || return 1
    saludo_obligatorio=1
  elif ! printf '%s' "$proc" | grep -qE "$DEVS_RE"; then
    # vim, un build, un pager: la ventana está ocupada con otra cosa y
    # escribirle un pedido sería tipear adentro de lo que el dueño esté
    # haciendo. No es un fallo, es que no es el momento.
    registrar "$p: ocupado con '$proc' — no es momento"
    return 3
  fi

  if [ "$saludo_obligatorio" = "0" ]; then
    txt="$(pantalla "$p")"
    if huella="$(rechazo_en_pantalla "$txt")"; then
      registrar "$p: RECHAZO en pantalla ($huella) — sesión nueva"
      sesion_nueva "$p"
      saludo_obligatorio=1
    fi
  fi

  [ "$forzar" = "1" ] && saludo_obligatorio=1

  if [ "$saludo_obligatorio" = "0" ]; then
    return 0   # dev vivo y pantalla limpia: no se gasta un token
  fi

  saludar "$p" && return 0

  # No contestó ni con sesión nueva: se lo deja anotado y el que llama NO le
  # manda el pedido. Insistirle a un panel que no contesta es la forma más
  # cara de no lograr nada.
  sesion_nueva "$p"
  saludar "$p" && return 0
  return 1
}

# ── Informe de flota ───────────────────────────────────────────────────────
revisar() {
  local p proc
  herdr pane list 2>/dev/null | python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
for p in d.get("result", {}).get("panes", []):
    print(p["pane_id"])
' | while read -r p; do
    proc="$(proceso_en "$p")"
    if [ -z "$proc" ]; then echo -e "$p\tSIN-VENTANA"
    elif printf '%s' "$proc" | grep -qE "$SHELLS_RE"; then echo -e "$p\tSIN-DEV\t$proc"
    elif ! printf '%s' "$proc" | grep -qE "$DEVS_RE"; then echo -e "$p\tOCUPADO\t$proc"
    else
      if huella="$(rechazo_en_pantalla "$(pantalla "$p")")"; then
        echo -e "$p\tRECHAZO\t$proc\t$huella"
      else
        echo -e "$p\tOK\t$proc"
      fi
    fi
  done
}

case "${1:-}" in
  --revisar) revisar; exit 0 ;;
  "" ) echo "uso: saludar-dev.sh <panel> [--forzar] | --revisar" >&2; exit 64 ;;
esac

PANEL="$1"; shift
FORZAR=0
for a in "$@"; do [ "$a" = "--forzar" ] && FORZAR=1; done
ritual "$PANEL" "$FORZAR"
