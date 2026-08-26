#!/usr/bin/env bash
# teatro.sh — cazar el ocio DISFRAZADO de trabajo.
#
# ── POR QUE ES PEOR QUE EL OCIO ────────────────────────────────────────────
#
# El panel apagado al menos se ve: sale en toda lista de ociosos y alguien lo
# levanta. El que corre tests cada dos minutos al pedo, o hace un cambio de una
# linea y compila otra vez, y otra vez, **se ve trabajando**. Cuesta la misma
# RAM, ocupa la misma maquina, y no figura en ninguna lista.
#
# ── EL CRITERIO: SALIDA, NUNCA ACTIVIDAD ───────────────────────────────────
#
# El estado del panel MIENTE. Dice `working` tanto cuando escribe codigo como
# cuando mira el mismo error por quinta vez. Lo que no miente es si produjo
# algo. Entonces:
#
#   ocupado + su pantalla cambio   -> trabajo
#   ocupado + su pantalla congelada hace media hora -> teatro
#
# ── LA VENTANA TIENE QUE SER GENEROSA ──────────────────────────────────────
#
# 30 minutos, no uno. Leer y pensar son trabajo legitimo y no dejan rastro. Lo
# que se persigue no es el minuto quieto: es la media hora sin producir nada.
#
# ── POR QUE NO SE MIDE CON mtime EN ESTA MAQUINA ───────────────────────────
#
# La primera version comparaba `find -newermt`. Sobre el montaje ntfs3 de
# /run/media/yo/A eso devuelve CERO archivos aunque git muestre veinte commits
# en la misma ventana — los mtime estan bien, el predicado no encuentra nada.
# Un detector que mide con una regla rota reporta teatro en toda la flota y
# manda a rescatar paneles que estan trabajando. La verdad la dice `git log`.
#
# ── Y LA PARTE QUE MAS IMPORTA: LA SALIDA HONESTA ──────────────────────────
#
# Un agente sin trabajo FINGE si no tiene una salida. No por maldad: es lo que
# hace cualquiera cuando no sabe que sigue. Por eso el mensaje le ofrece las
# tres — cerralo si ya esta, soltalo si esta mal escrito, o deci que no hay
# nada. **"No tengo nada" es una respuesta correcta y nadie se enoja.**
#
# ── LA REGLA DE DIAGNOSTICO ────────────────────────────────────────────────
#
#   Cuando veas teatro, sospecha del ITEM antes que del agente.
#
# Un item mal escrito, o uno ya terminado que nadie cerro, produce esto casi
# automaticamente.
#
#   bash scripts/teatro.sh          # mide, y le habla al que este actuando
#   bash scripts/teatro.sh --seco   # mide y dice, sin hablarle a nadie
set -u

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$DIR/.." && pwd)"
HUELLAS="$ROOT/.logs/teatro"
LOG="${TEATRO_LOG:-$ROOT/.logs/teatro.log}"
VENTANA="${TEATRO_VENTANA:-1800}"   # segundos de pantalla congelada para sospechar
mkdir -p "$HUELLAS" 2>/dev/null || true

SECO=0
[ "${1:-}" = "--seco" ] && SECO=1

registrar() { printf '%s %s\n' "$(date '+%F %T')" "$*" | tee -a "$LOG"; }

# La huella de la pantalla, SIN la barra de estado. El contador de tokens y el
# cronometro del build cambian cada segundo: dejarlos adentro hace que todo
# panel parezca vivo y el detector no encuentre nunca nada.
huella_de() {
  herdr agent read "$1" 2>/dev/null | tail -n 60 \
    | grep -vE '·[[:space:]]*[0-9]+(\.[0-9]+)?[ms]|ctrl\+p|[0-9]+(\.[0-9]+)?K \([0-9]+%\)|^[[:space:]]*$' \
    | md5sum | cut -c1-32
}

# Los paneles de ESTE repo que dicen estar trabajando.
ocupados() {
  herdr agent list 2>/dev/null | ROOT="$ROOT" python3 -c '
import json, os, sys
raiz = os.path.realpath(os.environ["ROOT"])
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
for a in d.get("result", {}).get("agents", []):
    if a.get("agent") != "opencode":
        continue
    if a.get("agent_status") != "working":
        continue
    if os.path.realpath(a.get("cwd") or "/dev/null") != raiz:
        continue
    print(a["pane_id"])
'
}

item_de() { awk -F'\t' -v p="$1" '$1=="tomado" && $5==p {print $2"\t"$6; exit}' "$ROOT/.logs/tablero.tsv" 2>/dev/null; }

ahora=$(date +%s)
# Cuánto produjo el repo entero en la ventana. Si esto es cero, el problema no
# es un panel: es que a nadie le llega trabajo, y eso lo arregla nunca-ocioso.
commits=$(git -C "$ROOT" log --since="$((VENTANA / 60)) minutes ago" --oneline 2>/dev/null | wc -l)
registrar "$(basename "$ROOT"): $commits commits en los ultimos $((VENTANA / 60)) min"

sospechosos=0
for p in $(ocupados); do
  h="$(huella_de "$p")"
  [ -z "$h" ] && continue
  f="$HUELLAS/$p"
  if [ -f "$f" ]; then
    prev_h="$(cut -d' ' -f1 "$f")"; prev_t="$(cut -d' ' -f2 "$f")"
  else
    prev_h=""; prev_t="$ahora"
  fi

  if [ "$h" != "$prev_h" ]; then
    printf '%s %s\n' "$h" "$ahora" > "$f"   # produjo algo: el reloj se reinicia
    continue
  fi

  quieto=$((ahora - prev_t))
  [ "$quieto" -lt "$VENTANA" ] && continue

  IFS=$'\t' read -r iid titulo <<< "$(item_de "$p")"
  registrar "TEATRO $p: $((quieto / 60)) min con la pantalla congelada — item=${iid:-ninguno} ${titulo:0:50}"
  sospechosos=$((sospechosos + 1))
  [ "$SECO" = "1" ] && continue

  # El reloj se reinicia igual, para no repetirle el mensaje cada vuelta.
  printf '%s %s\n' "$h" "$ahora" > "$f"

  bash "$DIR/mandar-a-panel.sh" "$p" "Llevas $((quieto / 60)) minutos sin que tu pantalla cambie. Puede ser que estes leyendo, y leer es trabajo — pero si no, pasa esto:

SOSPECHA DEL ITEM ANTES QUE DE VOS. Casi siempre es el item: ya esta hecho y nadie lo cerro, o esta mal escrito y no se puede cerrar.

Tenes TRES SALIDAS y las tres son correctas:
  1. Si tu item YA ESTA HECHO: bash scripts/tablero.sh done ${iid:-<tu-id>}
  2. Si esta MAL ESCRITO o no se puede hacer: bash scripts/tablero.sh soltar $p y deci en una linea por que.
  3. Si de verdad no hay nada que hacer: decilo en UNA linea. \"No tengo nada\" es una respuesta correcta y nadie se enoja.

Lo que NO sirve es fabricar actividad. Correr la suite otra vez, recompilar lo mismo, o cambiar una linea para tener algo que mostrar cuesta la misma RAM que trabajar y no produce nada. Un panel apagado se ve; uno actuando, no.

Y si estabas trabajando de verdad, ignorame y segui." >/dev/null 2>&1 || true
done

# ── EL CONTROL: ¿Y SI EL ROTO ES EL DETECTOR? ──────────────────────────────
#
# Si el repo produjo commits y ESTE script cree que TODOS los paneles están
# congelados, lo que está roto es el script, no la flota. Es la misma trampa
# que el `find -newermt` de más arriba: un instrumento roto devuelve un valor
# plausible, no un error. Un detector que no puede contradecirse a sí mismo no
# es un detector, es una opinión — y ésta manda a rescatar gente que trabaja.
ocupados_n=$(ocupados | grep -c .)
# El umbral es la MAYORIA, no la unanimidad. Pedir que esten marcados los 24
# de 24 deja pasar el caso real: 14 de 24 marcados mientras el repo mete 23
# commits ya es imposible, y ese es el numero que dio la primera prueba con el
# instrumento roto a proposito.
if [ "$sospechosos" -gt 0 ] && [ $((sospechosos * 2)) -gt "$ocupados_n" ] && [ "$commits" -gt 0 ]; then
  registrar "$(basename "$ROOT"): NO ME CREAS — $sospechosos de $ocupados_n paneles marcados con $commits commits en la ventana. El roto soy yo, no la flota. Revisa huella_de(): probablemente la barra de estado dejo de filtrarse, o herdr agent read no devuelve nada."
  exit 2
fi

registrar "$(basename "$ROOT"): $sospechosos panel(es) con sospecha de teatro"
