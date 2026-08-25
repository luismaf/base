#!/usr/bin/env bash
# avisar-jefe.sh — avisá al que está a cargo que terminaste, sin quedarte mudo.
#
# El problema que resuelve: un panel que termina su tarea queda en idle y
# NADIE se entera — hay que ir a mirar `herdr agent list` a mano. Con este
# script, el cierre de un bloque le llega al que está a cargo en el acto.
#
# La cadena de escalado (docs/jefe.md): JEFE REAL (Claude) → JEFE (el
# subjefe en funciones) → SUBJEFE → disco. Antes de mandar se consulta
# climax --blocked: un Claude en hard limit no recibe prompt (quedaría en
# cola y se procesaría de golpe al reset), y el jefe real recibe SIEMPRE
# primero cuando no está bloqueado — no hay devolución de jefatura.
# La verificación NO es externa (cuota, plugins): es la recepción misma.
# Un panel que recibió el aviso pasa a `working` (procesando) — si no
# procesa tras el prompt + Enter, no está operativo y se escala al
# siguiente de la cadena. La prueba de que el mensaje llegó es que se
# puso a trabajar.
#
# Reglas:
#   - Si vos SOS el destinatario (PANEL_PROPIO), no te avisás a vos
#     mismo: el aviso salta al siguiente de la cadena.
#   - `working` = confirmación de recepción (el prompt quedó TIPIADO sin
#     Enter y el agente no arranca — DELEGACION §0: por eso el Enter y la
#     verificación).
#
# Uso:
#   bash scripts/avisar-jefe.sh "feat(x): cerré Y — 2 tests verdes, sigue Z"
#   PANEL_PROPIO=w5:p7 bash scripts/avisar-jefe.sh "..."

set -euo pipefail

# ── Raíz del repo (DELEGACION §0.0: nunca rutas de memoria) ──
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && git rev-parse --show-toplevel)"
JEFE_MD="$RAIZ/docs/jefe.md"

MENSAJE="${1:-}"
if [ -z "$MENSAJE" ]; then
  echo "uso: bash scripts/avisar-jefe.sh \"2 líneas: qué commiteaste y qué sigue\"" >&2
  exit 1
fi
# ── Quién soy (para firmar el aviso y para no avisarme a mí mismo) ──
# herdr exporta HERDR_PANE_ID en cada panel: se usa solo, sin que nadie tenga
# que acordarse de exportar nada. Antes dependía de PANEL_PROPIO, que no
# seteaba nadie, y TODOS los avisos llegaban firmados "panel ?" — el jefe leía
# "cerré tal cosa" sin saber quién lo cerró, y tenía que ir a adivinarlo panel
# por panel. PANEL_PROPIO sigue ganando por si hay que forzarlo.
PANEL_PROPIO="${PANEL_PROPIO:-${HERDR_PANE_ID:-}}"

# ── Quién es quién (leído del archivo, no hardcodeado) ──
# Tabla: | **Jefe** | dev2 | `w5:p2` | Claude | → panel = w5:p2
panel_de() {
  grep -E "^\| \*\*$1\*\*" "$JEFE_MD" | head -1 | sed -E 's/.*\|\s*`([^`]+)`.*/\1/'
}
PANEL_JEFE="$(panel_de Jefe-supervisor)"
# Compatibilidad con la tabla vieja (fila "Jefe" a secas) por si vuelve:
[ -z "$PANEL_JEFE" ] && PANEL_JEFE="$(panel_de Jefe)"
PANEL_SUBJEFE="$(panel_de Subjefe)"
# El jefe REAL (Claude): recibe los avisos SIEMPRE primero cuando no está en
# hard limit — no hay devolución de jefatura (dueño 2026-08-10), el aviso es
# suyo apenas se desbloquea. La fila "Jefe" es el subjefe en funciones.
PANEL_JEFE_REAL="$(panel_de 'Jefe real')"
if [ -z "$PANEL_JEFE" ]; then
  echo "error: no encontré la fila '| **Jefe**' en $JEFE_MD" >&2
  exit 1
fi

# ── Estado de un panel según herdr ──
# imprime: working | idle | blocked | done | unknown | inexistente
estado_panel() {
  herdr agent get "$1" 2>/dev/null | python3 -c "
import json,sys
try:
    d=json.load(sys.stdin)
    if 'result' in d and 'agent' in d['result']:
        print(d['result']['agent']['agent_status'])
    else:
        print('inexistente')
except Exception:
    print('inexistente')" || echo inexistente
}

# ── Huella de la pantalla de un panel ──
# La prueba de que un panel arrancó NO puede ser `agent_status`: ese campo
# miente en las dos direcciones y lo comprobamos los dos jefes el mismo día
# (2026-08-10). En un proyecto real: cuatro pedidos entraron TIPEADOS en p1/p3/p7/pA y el
# estado siguió diciendo `idle` hasta que fue el Enter — con la verificación
# vieja, el script daba "no procesó" y escalaba (o reescribía la fila del
# jefe) sobre paneles que estaban perfectos. En ux, al revés: el estado se
# queda pegado en `working` y entonces CUALQUIER aviso se daba por recibido,
# que es el error caro — el que avisa se va tranquilo y del otro lado no
# había nadie. Un panel que procesa mueve la pantalla (spinner, contador de
# tokens, la respuesta misma); uno que quedó con el texto tipeado, no. Esa
# huella es evidencia; el estado es una opinión.
sha_pantalla() {
  herdr agent read "$1" --source visible 2>/dev/null | sha1sum | cut -c1-40
}

# ── Mandar el aviso a un panel y verificar que lo recibió ──
# Devuelve 0 si el panel procesó el aviso, 1 si no (se escala).
mandar_aviso() {
  local pane="$1"
  local antes sha0
  antes="$(estado_panel "$pane")"
  sha0="$(sha_pantalla "$pane")"
  herdr agent prompt "$pane" "📩 AVISO DE CIERRE (panel ${PANEL_PROPIO:-?}): $MENSAJE" >/dev/null 2>&1 || true
  herdr agent send-keys "$pane" enter >/dev/null 2>&1 || true
  # La confirmación: la pantalla se movió DESPUÉS del Enter. Se le da unos
  # segundos y un reintento del Enter (la trampa de DELEGACION §0).
  for _ in 1 2 3; do
    sleep 2
    if [ "$(sha_pantalla "$pane")" != "$sha0" ]; then
      echo "aviso mandado a $pane (la pantalla se movió — recibido y procesando)"
      return 0
    fi
    # Sigue clavada: el texto quedó tipeado sin Enter. Insistir con el Enter
    # es exactamente lo que destrabó los cuatro paneles de ese proyecto.
    herdr agent send-keys "$pane" enter >/dev/null 2>&1 || true
  done
  # Tres intentos con la pantalla clavada: el panel no arrancó, o está
  # apagado. Si estaba trabajando en OTRA cosa, el aviso quedó en su cola y
  # lo va a ver — se considera recibido igual (no escala). Se comprueba
  # leyendo de nuevo, no confiando en el `antes`: un panel que terminó su
  # tarea justo ahora dejó de mover la pantalla por eso, no por no recibir.
  if [ "$antes" = "working" ]; then
    echo "aviso mandado a $pane (ya estaba working — queda en su cola)"
    return 0
  fi
  echo "el panel $pane no procesó el aviso (pantalla sin cambios tras 3 Enter; estado: $(estado_panel "$pane")) — sigo con el siguiente" >&2
   return 1
}

# ── ¿Está el panel de Claude en hard limit? (climax --blocked, 0 | lista) ──
# climax --blocked imprime "0" si nada está bloqueado, o los paneles uno por
# línea (dueño 2026-08-10). A un Claude bloqueado NO se le manda el prompt:
# quedaría tipeado y se procesaría de golpe al reset — órdenes viejas sobre
# un estado nuevo (mismo criterio que nadie-ocioso.sh). Sin climax, nada
# está bloqueado.
es_claude_bloqueado() {
  command -v climax >/dev/null 2>&1 || return 1
  climax --blocked 2>/dev/null | grep -qx "$1"
}

# ── Asumir el rol de jefe (orden del dueño 2026-08-10) ──
# El jefe en funciones no procesó el aviso (bloqueado por cuota, sin
# operatividad): el que envía se pone como jefe en docs/jefe.md y deja el
# aviso registrado. El jefe REAL (Claude) no pasa por acá: si no procesa,
# la cadena sigue — la asunción es del jefe en funciones.
# El panel debe saber QUÉ es: esto se corre por accidente si el destinatario
# estaba `working` en otra cosa (ese caso no escala, ver mandar_aviso).
asumir_jefatura() {
  local quien="${PANEL_PROPIO:-panel-?}"
  local fecha
  fecha="$(date '+%Y-%m-%d %H:%M')"
  # La fila del Jefe se reescribe con el panel del que envía. El nombre del
  # dev se conserva del mapeo de COLAS 0.1 si existe; si no, queda el panel.
  local dev=""
  if [ -n "$PANEL_PROPIO" ]; then
    dev="$(grep -E "^\| \`$PANEL_PROPIO\`" "$RAIZ/docs/COLAS.md" 2>/dev/null | head -1 | sed -E 's/^\|\s*`[^`]+`\s*\| (dev[0-9]+) .*/\1/')"
  fi
  [ -n "$dev" ] || dev="panel $quien"

  sed -i -E "s#^\| \*\*Jefe\*\* .*#\| **Jefe** | $dev | \`$quien\` | (asumido $fecha — el jefe en funciones no recibió el aviso) |#" "$JEFE_MD"
  mkdir -p "$RAIZ/.logs/paneles"
  echo "$(date -Iseconds) — $MENSAJE" > "$RAIZ/.logs/paneles/$quien.asumio-jefatura"
  echo "el jefe en funciones no recibió el aviso: $quien asumió como JEFE ($JEFE_MD actualizado)" >&2
}

# ── El buzón del jefe real: a disco, no a su pantalla ──
# El panel del jefe real (Claude) es la MISMA terminal donde el dueño
# escribe. Cada aviso que le entraba como prompt le cortaba la frase por la
# mitad al dueño — el 2026-08-10 le partió tres mensajes seguidos mientras
# nos pedía cosas. Ocho paneles avisando cada ítem cerrado convierten esa
# terminal en un teletipo.
#
# Así que al jefe real el aviso le va al BUZÓN: un archivo por día que él
# lee cuando corta, sin que nadie le pise el teclado al dueño. No se pierde
# nada (era el riesgo de mandarlo a disco) porque el jefe real está vivo y
# lo lee en el mismo turno; los avisos a los otros paneles siguen yendo por
# prompt, que es como se enteran los que no comparten terminal con nadie.
buzon_del_jefe() {
  mkdir -p "$RAIZ/.logs/paneles"
  local buzon="$RAIZ/.logs/paneles/buzon-jefe-$(date +%F).log"
  printf '%s — [%s] %s\n' "$(date -Iseconds)" "${PANEL_PROPIO:-panel-?}" "$MENSAJE" >> "$buzon"
  echo "aviso al buzón del jefe ($buzon) — no se le interrumpe la terminal al dueño"
}

# ── La cadena: Jefe real (buzón) → Jefe → Subjefe → disco ──
# 1. El jefe REAL (Claude) recibe el aviso SIEMPRE primero cuando no está en
#    hard limit (dueño 2026-08-10). No hay devolución de jefatura: apenas se
#    desbloquea, el aviso es suyo. Ahora por buzón en vez de por prompt.
if [ -n "$PANEL_JEFE_REAL" ] \
   && [ "$PANEL_JEFE_REAL" != "$PANEL_PROPIO" ] \
   && [ "$PANEL_JEFE_REAL" != "$PANEL_JEFE" ] \
   && ! es_claude_bloqueado "$PANEL_JEFE_REAL"; then
  buzon_del_jefe
  exit 0
fi

for candidato in "$PANEL_JEFE" "$PANEL_SUBJEFE"; do
  [ -n "$candidato" ] || continue
  # ¿Soy yo el candidato? No me aviso a mí mismo: salto al siguiente.
  if [ -n "$PANEL_PROPIO" ] && [ "$PANEL_PROPIO" = "$candidato" ]; then
    echo "sos $candidato: no te avisás a vos mismo, sigo con el siguiente de la cadena" >&2
    continue
  fi
  # Un Claude en hard limit NO procesa nada hasta el reset: no se le manda
  # el prompt (quedaría en cola y se procesaría de golpe al volver — órdenes
  # viejas sobre un estado nuevo). Si es el JEFE, el que envía asume la
  # posta — "el primer bloqueado ya puede" (dueño 2026-08-10).
  if es_claude_bloqueado "$candidato"; then
    if [ "$candidato" = "$PANEL_JEFE" ]; then
      asumir_jefatura
      exit 0
    fi
    echo "el subjefe $candidato está bloqueado por cuota — sigo con el siguiente" >&2
    continue
  fi
  if mandar_aviso "$candidato"; then
    exit 0
  fi
  # El candidato no procesó. Si era el JEFE, el que envía asume el rol
  # (orden del dueño) — el aviso no cae al subjefe ni al disco sin mando.
  if [ "$candidato" = "$PANEL_JEFE" ]; then
    asumir_jefatura
    exit 0
  fi
done

# ── Nadie operativo: el aviso va al disco (contrato DELEGACION §0.3) ──
mkdir -p "$RAIZ/.logs/paneles"
FECHA="$(date -Iseconds)"
echo "$FECHA — $MENSAJE" > "$RAIZ/.logs/paneles/${PANEL_PROPIO:-panel}.estado"
echo "ningún jefe/subjefe recibió el aviso (jefe: $PANEL_JEFE, subjefe: $PANEL_SUBJEFE)" >&2
echo "aviso guardado en .logs/paneles/${PANEL_PROPIO:-panel}.estado — el que vuelva lo lee" >&2
