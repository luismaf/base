#!/usr/bin/env bash
# nadie-ocioso.sh — el guardián que no deja ningún panel parado.
#
# EL PROBLEMA QUE RESUELVE (pasó hoy, 2026-08-10, y ya había pasado antes):
# la regla "nadie ocioso" de docs/IMPETU.md §1.3 estaba escrita y se cumplía
# igual de mal, porque dependía de que ALGUIEN MIRARA. El jefe se fue por
# cuota, el subjefe terminó su bloque, avisó, y se quedó en idle "a la orden";
# los otros dos paneles llevaban rato parados. Cuatro agentes esperando que
# alguien apriete Enter es exactamente el costo que la regla quería evitar.
#
# El aviso ya estaba resuelto en una dirección: avisar-jefe.sh empuja el
# cierre HACIA ARRIBA. Faltaba la vuelta: algo que empuje trabajo HACIA ABAJO
# cuando el de arriba no está. Eso es este script — un lazo cerrado que no
# necesita jefe despierto.
#
# QUÉ HACE
#   Cada INTERVALO segundos: pregunta a herdr quién está idle EN ESTE REPO
#   (los paneles de otros proyectos no se tocan), y a cada ocioso le manda sus
#   órdenes permanentes: "sos el panel X = devN, tu cola es docs/COLAS.md §devN,
#   tomá el próximo ítem y arrancá". Después verifica que pasó a `working`.
#
# POR QUÉ NO LE MANDA LA TAREA CONCRETA
#   Porque un despachador que elige el ítem se desincroniza con la cola en dos
#   días y termina mandando trabajo ya hecho. El panel sabe leer su cola y
#   `git log`; lo único que le faltaba era el empujón. Estado mínimo = menos
#   para que se pudra.
#
# LA VÁLVULA (para que no gaste tokens en vano)
#   Si un panel vuelve a idle MAX_INSISTENCIAS veces seguidas, deja de
#   insistirle y escala al jefe: "este panel se queda sin trabajo real,
#   decidí vos". Un bucle que le grita a un panel sin cola es peor que el
#   panel parado.
#
# USO
#   bash scripts/nadie-ocioso.sh --una-vez        # una pasada, para probar
#   bash scripts/nadie-ocioso.sh                  # bucle en primer plano
#   bash scripts/nadie-ocioso.sh --demonio        # bucle detached + pidfile
#   bash scripts/nadie-ocioso.sh --parar          # matar el demonio
#   bash scripts/nadie-ocioso.sh --estado         # ¿está corriendo? ¿qué vio?
#
# VARIABLES
#   NADIE_OCIOSO_INTERVALO=60    segundos entre pasadas
#   NADIE_OCIOSO_MAX=3           insistencias antes de escalar
#   NADIE_OCIOSO_QUIETO=2        pasadas con la pantalla idéntica para dejar de
#                                creerle a un "working" (ver huella_panel)
#   NADIE_OCIOSO_SECO=1          no manda nada, sólo imprime lo que haría

set -euo pipefail

# ── Raíz del repo (DELEGACION §0.0: ningún script sabe una ruta de memoria) ──
# realpath a propósito: el mismo repo se alcanza por más de un camino (hubo una
# copia en $HOME/proyecto que iba a volverse enlace al repo real). Si se compara
# el texto del path, un panel que entró por el otro camino queda INVISIBLE para
# el vigilante — y un panel invisible es un panel ocioso que nadie empuja.
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && git rev-parse --show-toplevel)"
RAIZ="$(realpath "$RAIZ")"
COLAS_MD="$RAIZ/docs/COLAS.md"
JEFE_MD="$RAIZ/docs/jefe.md"
ESTADO_DIR="$RAIZ/.logs/paneles"
LOG="$RAIZ/.logs/nadie-ocioso.log"
PIDFILE="$RAIZ/.logs/nadie-ocioso.pid"

INTERVALO="${NADIE_OCIOSO_INTERVALO:-60}"
MAX_INSISTENCIAS="${NADIE_OCIOSO_MAX:-3}"
SECO="${NADIE_OCIOSO_SECO:-0}"
# Pasadas seguidas con la pantalla idéntica para dejar de creerle al "working".
PASADAS_QUIETO="${NADIE_OCIOSO_QUIETO:-2}"
MODO="bucle"

while [ $# -gt 0 ]; do
  case "$1" in
    --una-vez)   MODO="una-vez" ;;
    --demonio)   MODO="demonio" ;;
    --parar)     MODO="parar" ;;
    --estado)    MODO="estado" ;;
    --seco)      SECO=1 ;;
    --intervalo) INTERVALO="$2"; shift ;;
    --max)       MAX_INSISTENCIAS="$2"; shift ;;
    *) echo "opción desconocida: $1" >&2; exit 1 ;;
  esac
  shift
done

mkdir -p "$ESTADO_DIR"

# El hijo demonio ya tiene stdout y stderr redirigidos al log: si además
# hacemos tee, cada línea sale DOS veces y el log se vuelve ilegible (pasó).
registrar() {
  local linea="$(date -Iseconds) — $*"
  printf '%s\n' "$linea" >> "$LOG"
  [ "${NADIE_OCIOSO_HIJO:-0}" = "1" ] || printf '%s\n' "$linea" >&2
}

# ── La huella de lo que se ve en el panel ──────────────────────────────────
# EXISTE PORQUE EL ESTADO MIENTE. herdr marca los paneles de opencode con
# screen_detection_skipped, así que su agent_status se queda pegado en
# "working" aunque el agente haya terminado hace media hora: el evento de
# cambio nunca llega. Un panel así es INVISIBLE para el guardián —nunca
# aparece como ocioso— y se queda parado hasta que un humano lo mira. Pasó el
# 2026-08-10 con dev4: el log decía "0 ociosos" durante 20 minutos mientras el
# panel estaba en el prompt vacío, y lo tuvo que reiniciar el dueño.
#
# El desempate no interpreta la interfaz de ningún agente (eso se pudre con la
# próxima versión): sólo pregunta si la PANTALLA CAMBIÓ. Un agente que trabaja
# de verdad escribe algo —tokens, spinner, salida de un comando—; uno que
# terminó muestra lo mismo pase tras pase.
huella_panel() {
  herdr agent read "$1" 2>/dev/null | sha1sum | cut -d' ' -f1
}

# ── Quién es el jefe (docs/jefe.md es la fuente única; nunca hardcodeado) ──
# El nombre del rol puede traer sufijo —la fila dice **Jefe-supervisor**, no
# **Jefe**— y el patrón anclado a `\*\*Jefe\*\*` devolvía VACÍO. Un jefe que no
# se reconoce se trata como obrero ocioso y recibe latigazos, que es lo que
# pasó el 2026-08-24. Se matchea el PREFIJO del rol y nada más.
panel_de_rol() {
  grep -E "^\| \*\*$1[^*]*\*\*" "$JEFE_MD" 2>/dev/null | head -1 |
    sed -E 's/.*\|[[:space:]]*`([^`]+)`.*/\1/'
}

# ── Qué dev es cada panel (docs/COLAS.md §0.1, una sola fuente) ──
# Filas: | `w5:p1` | dev1 | tema | ...
dev_de_panel() {
  grep -E "^\| \`$1\`" "$COLAS_MD" 2>/dev/null | head -1 |
    sed -E 's/^\|[^|]*\|[[:space:]]*([^ |]+).*/\1/'
}

# ── Paneles de ESTE repo, con su estado, según herdr ──
# Imprime líneas "panel<TAB>estado". El filtro por cwd es esencial: en el
# mismo herdr viven paneles de otros proyectos y no son nuestros para mandar.
paneles_del_repo() {
  herdr agent list 2>/dev/null | RAIZ="$RAIZ" python3 -c '
import json, os, sys
raiz = os.path.realpath(os.environ["RAIZ"])
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
for a in d.get("result", {}).get("agents", []):
    # realpath en los DOS lados: el mismo repo se alcanza por más de un camino.
    if os.path.realpath(a.get("cwd") or "/dev/null") != raiz:
        continue
    print("%s\t%s\t%s" % (a.get("pane_id",""), a.get("agent_status","?"), a.get("agent","?")))
' || true
}

# ── Paneles que NUNCA se arrean ───────────────────────────────────────────
# La MISMA lista que usa autopiloto.sh. Hasta hoy sólo la leía él: este script
# arreaba igual a la sesión interactiva del dueño y al panel del supervisor.
declare -A NO_REPARTIR
if [ -f "$RAIZ/scripts/no-repartir.conf" ]; then
  while IFS= read -r l; do
    l="${l%%#*}"; l="${l// /}"
    [ -n "$l" ] && NO_REPARTIR["$l"]=conf
  done < "$RAIZ/scripts/no-repartir.conf"
fi

contador() { cat "$ESTADO_DIR/$1.insistencias" 2>/dev/null || echo 0; }

# ── Las órdenes permanentes que recibe un ocioso ──
# Sin $( ) ni backticks: DELEGACION §0 — el shell del panel los ejecutaría.
ordenes_para() {
  local panel="$1" dev="$2"
  printf '%s' "⏰ Estás IDLE y hay trabajo. Regla IMPETU §3.1: nadie pide permiso para seguir. \
Sos el panel ${panel} = ${dev}. Tu cola es docs/COLAS.md, sección ${dev}: abrila, mirá tu git log \
para saber dónde quedaste, tomá el próximo ítem que no tenga cumplido su criterio de terminado y \
ARRANCÁ. No contestes 'a la orden' ni 'quedo a disposición': eso es seguir ocioso con más palabras. \
Si tu cola está entera terminada, docs/ROADMAP_MVP.md §2 y agarrás un bloque sin dueño o atrasado. \
Prioridad del dueño HOY: que el 99% de la app corra sin señal — el estado real y los gaps exactos \
están en docs/OFFLINE_ESTADO.md. Al cerrar el bloque avisás con scripts/avisar-jefe.sh y SEGUÍS con \
el ítem siguiente; el aviso no es el final de tu turno. Si de verdad no queda nada, respondé UNA \
línea al jefe explicando por qué. (Si estabas en el medio de algo y este mensaje te llegó igual, \
ignoralo y seguí: te lo mandé porque tu panel no dio señales de vida en varios minutos.)"
}

escalar_al_jefe() {
  local panel="$1" dev="$2"
  local jefe subjefe
  jefe="$(panel_de_rol Jefe)"
  subjefe="$(panel_de_rol Subjefe)"
  local msg="🚨 NADIE-OCIOSO: el panel ${panel} (${dev}) volvió a idle ${MAX_INSISTENCIAS} veces \
seguidas después de mandarle sus órdenes permanentes. O su cola en docs/COLAS.md está terminada, o \
lo que queda no lo puede tomar solo. Dejo de insistirle: decidí vos qué hace. Los demás paneles \
siguen bajo vigilancia."
  for candidato in "$jefe" "$subjefe"; do
    [ -n "$candidato" ] || continue
    [ "$candidato" = "$panel" ] && continue
    if bash "$RAIZ/scripts/mandar-a-panel.sh" "$candidato" "$msg" 2>/dev/null | grep -q working; then
      registrar "escalado a $candidato: $panel ($dev) sin trabajo tomable"
      return 0
    fi
  done
  echo "$(date -Iseconds) — $msg" > "$ESTADO_DIR/${panel}.sin-trabajo"
  registrar "nadie recibió el escalado de $panel — quedó en .logs/paneles/${panel}.sin-trabajo"
}

pasada() {
  local vistos=0 ociosos=0
  while IFS=$'\t' read -r panel estado agente; do
    [ -n "$panel" ] || continue
    vistos=$((vistos + 1))

    # ── EL FILTRO QUE NO SE DESINCRONIZA ────────────────────────────────
    # Los obreros de este repo son TODOS opencode. Un panel `claude` acá es
    # una conversación —el dueño o el supervisor—, nunca alguien a quien
    # mandarle un ítem del tablero. Este filtro no depende de ningún id ni
    # de ninguna tabla: sobrevive a que se caigan los paneles, a que cambien
    # los ids y a que alguien renombre un rol en docs/jefe.md. Las otras dos
    # exclusiones de abajo son por nombre y por eso se pudren solas; ésta no.
    if [ "$agente" = "claude" ]; then
      continue
    fi
    if [ -n "${NO_REPARTIR[$panel]:-}" ]; then
      continue
    fi

    local jefe subjefe
    jefe="$(panel_de_rol Jefe)"
    subjefe="$(panel_de_rol Subjefe)"

    # El jefe decide, no se lo arrea. Y un panel que trabaja, no se toca.
    if [ "$panel" = "$jefe" ] || { [ -n "$subjefe" ] && [ "$panel" = "$subjefe" ]; }; then
      continue
    fi
    if [ "$estado" = "blocked" ]; then
      rm -f "$ESTADO_DIR/$panel.insistencias" "$ESTADO_DIR/$panel.sin-trabajo"
      continue
    fi

    # "working" no se cree de palabra: se corrobora con la pantalla.
    if [ "$estado" = "working" ]; then
      local huella previa quieto
      huella="$(huella_panel "$panel")"
      previa="$(cat "$ESTADO_DIR/$panel.huella" 2>/dev/null || true)"
      quieto="$(cat "$ESTADO_DIR/$panel.quieto" 2>/dev/null || echo 0)"
      printf '%s' "$huella" > "$ESTADO_DIR/$panel.huella"

      if [ -z "$huella" ] || [ "$huella" != "$previa" ]; then
        # La pantalla se movió: está trabajando de verdad.
        rm -f "$ESTADO_DIR/$panel.quieto" "$ESTADO_DIR/$panel.insistencias" \
              "$ESTADO_DIR/$panel.sin-trabajo"
        continue
      fi

      quieto=$((quieto + 1))
      printf '%s' "$quieto" > "$ESTADO_DIR/$panel.quieto"
      if [ "$quieto" -lt "$PASADAS_QUIETO" ]; then
        continue
      fi
      registrar "$panel dice working pero la pantalla no cambió en $quieto pasadas — lo trato como ocioso"
      rm -f "$ESTADO_DIR/$panel.quieto"
      estado="ocioso-encubierto"
    fi

    ociosos=$((ociosos + 1))
    local n dev
    n="$(contador "$panel")"
    dev="$(dev_de_panel "$panel")"
    dev="${dev:-tu dev}"

    if [ "$n" -ge "$MAX_INSISTENCIAS" ]; then
      if [ ! -f "$ESTADO_DIR/$panel.sin-trabajo" ]; then
        [ "$SECO" = "1" ] && registrar "[seco] escalaría $panel ($dev)" || escalar_al_jefe "$panel" "$dev"
      fi
      continue
    fi

    if [ "$SECO" = "1" ]; then
      registrar "[seco] empujaría $panel ($dev, $agente, $estado, insistencia $((n + 1)))"
      continue
    fi

    registrar "empujando $panel ($dev, $estado, insistencia $((n + 1)) de $MAX_INSISTENCIAS)"
    echo "$((n + 1))" > "$ESTADO_DIR/$panel.insistencias"
    bash "$RAIZ/scripts/mandar-a-panel.sh" "$panel" "$(ordenes_para "$panel" "$dev")" >>"$LOG" 2>&1 || true
  done < <(paneles_del_repo)

  registrar "pasada: $vistos paneles del repo, $ociosos ociosos"
}

case "$MODO" in
  parar)
    if [ -f "$PIDFILE" ] && kill "$(cat "$PIDFILE")" 2>/dev/null; then
      registrar "demonio parado (pid $(cat "$PIDFILE"))"; rm -f "$PIDFILE"
    else
      echo "no había demonio corriendo"; rm -f "$PIDFILE"
    fi
    ;;
  estado)
    if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
      echo "corriendo (pid $(cat "$PIDFILE"), intervalo ${INTERVALO}s)"
    else
      echo "NO está corriendo"
    fi
    echo "--- últimas 15 líneas ---"; tail -15 "$LOG" 2>/dev/null || echo "(sin log todavía)"
    ;;
  una-vez) pasada ;;
  demonio)
    if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
      echo "ya está corriendo (pid $(cat "$PIDFILE"))"; exit 0
    fi
    NADIE_OCIOSO_HIJO=1 nohup bash "$RAIZ/scripts/nadie-ocioso.sh" --intervalo "$INTERVALO" \
      --max "$MAX_INSISTENCIAS" >>"$LOG" 2>&1 &
    echo $! > "$PIDFILE"
    registrar "demonio arrancado (pid $(cat "$PIDFILE"), intervalo ${INTERVALO}s)"
    ;;
  bucle)
    registrar "vigilando cada ${INTERVALO}s (max $MAX_INSISTENCIAS insistencias)"
    while true; do pasada; sleep "$INTERVALO"; done
    ;;
esac
