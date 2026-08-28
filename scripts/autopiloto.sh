#!/usr/bin/env bash
# autopiloto.sh — que nunca haya un panel libre con trabajo pendiente esperando
# a que un humano se siente a repartirlo.
#
# EL PROBLEMA QUE RESUELVE, contado como pasó:
# Encadenar dependía de que el jefe —una sesión de chat, que cuesta plata—
# leyera los avisos y mandara el pedido siguiente. Si el jefe no estaba
# delante, el equipo se quedaba OCHO HORAS parado con doce paneles ociosos.
# Después arreglamos eso repartiendo archivos .md de una pila escrita a mano,
# y el fallo se corrió de lugar: la pila se secaba (238 archivos, 215
# consumidos) y a los veinte minutos de arrancar estaban todos muertos otra
# vez. La lección: **la fuente de trabajo tiene que poder recargarse sin
# sentarse a la computadora.** De ahí el tablero (tablero.sh) y la pantalla
# del celu (celu.py), que es como se recarga.
#
# ORDEN DE PRIORIDAD para un panel libre:
#   1. Su COLA PERSONAL (scripts/colas.conf) — lo que le toca a él por tema.
#   2. El TABLERO — trabajo real sin dueño, recargable por voz desde el celu.
#   3. NADA. Y nada está bien.
#
# LAS TRES VÁLVULAS. Existen porque la versión sin ellas hacía exactamente lo
# que el dueño no quería: "que no moleste a los devs que ya terminaron todo, y
# constantemente estén inventándose trabajo porque alguien los molesta con un
# mensaje". Al llegar al final de la cola el índice DABA LA VUELTA y reenviaba
# trabajo ya cerrado; el panel, obediente, se inventaba algo que hacer.
#   1. GRACIA — un panel tiene que llevar un rato libre antes de que se lo
#      empuje. Un agente entre dos herramientas figura idle por segundos; si
#      se le habla ahí se le corta el hilo y encima se paga el prompt.
#   2. ESPERA — nunca dos empujones al mismo panel dentro de ESPERA segundos.
#      Techo duro de gasto por panel.
#   3. SILENCIO — cola hecha y tablero vacío = SE LO DEJA EN PAZ. Se avisa UNA
#      vez y no se lo vuelve a tocar. Un dev callado con todo hecho es el
#      estado correcto, no una falla que se corrija a mensajes.

# El repo se detecta desde la UBICACIÓN DEL SCRIPT, no desde el cwd de quien
# lo llama. `git rev-parse` a secas parece que funciona hasta que el vigilante
# lo lanza desde $HOME: ahí devuelve otro repo (o ninguno) y el autopiloto
# termina filtrando paneles de un proyecto que no es. Costó una hora de
# "¿por qué le habla al panel equivocado?".
_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="${AUTOPILOTO_REPO:-$(git -C "$_DIR" rev-parse --show-toplevel 2>/dev/null || dirname "$_DIR")}"
DIR="$_DIR"
# Dónde avisar cuando un panel MANUAL se quedó con el pedido tipeado y sin
# arrancar. Sin esto el fallo es mudo, que es como el dueño terminó
# encontrando dos Freebuff quietos y pegándoles el pedido a mano.
export HARNESS_AVISAR="$DIR/avisar-jefe.sh"
source "$DIR/harness.sh"

ESTADO="$REPO/.tmp/autopiloto.json"
COLAS_CONF="$REPO/scripts/colas.conf"
LOG="${AUTOPILOTO_LOG:-$HOME/.logs-vigilante/autopiloto.log}"
mkdir -p "$REPO/.tmp" "$(dirname "$LOG")"

# Válvulas en cero: los obreros son gratis e ilimitados y no hay a quién
# acosar. Ver la nota larga en latigo.sh. El anti-acoso que sí importa es el
# tope de intentos del tablero, que protege al ítem y no al panel.
GRACIA="${AUTOPILOTO_GRACIA:-0}"
ESPERA="${AUTOPILOTO_ESPERA:-0}"
# Enfriamiento aparte para los paneles MANUALES cuando el ritual no arranca.
# Hablarle a uno de esos le ROBA EL FOCO al dueño unos segundos: reintentar
# cada 45 s le haría saltar la pantalla toda la tarde. Diez minutos es
# suficiente para que un intento fallido no se vuelva una molestia, y bastante
# menos de lo que tardaba en enterarse antes, que era nunca.
ESPERA_MANUAL="${AUTOPILOTO_ESPERA_MANUAL:-600}"
SECO="${AUTOPILOTO_SECO:-0}"

escribir() { echo "$(date +%H:%M:%S) — $1" >> "$LOG"; }

# Un autopiloto por vez. Mandar un prompt tarda, y el vigilante relanza cada
# 20 s: sin candado, dos pasadas simultáneas le mandan el mismo pedido dos
# veces al mismo panel y se pisan el archivo de estado.
exec 9>"$REPO/.tmp/autopiloto.lock"
flock -n 9 || exit 0

# ── Colas personales. Formato de scripts/colas.conf, una por línea:
#      panel|pedido1.md|pedido2.md|...
#    Los .md viven en .logs/pedidos/. Las líneas vacías y las que empiezan con
#    # se ignoran. Si el archivo no existe, todos los paneles van al tablero.
COLAS=()
if [ -f "$COLAS_CONF" ]; then
  while IFS= read -r l; do
    case "$l" in ''|'#'*) continue ;; esac
    COLAS+=("$l")
  done < "$COLAS_CONF"
fi

# ── El harness caído NO es "cero paneles libres" ──────────────────────────
# Salir gritando y SIN TOCAR el estado. La versión que seguía de largo dejaba
# el archivo de estado vacío, o sea que el próximo intento bueno arrancaba
# todas las colas desde cero. Silencio + amnesia fue el modo de fallo que dejó
# al equipo parado media jornada mientras los logs decían "lanzado".
# Sólo los paneles de ESTE repo. En una misma sesión conviven paneles de
# varios proyectos; sin el filtro, el autopiloto de uno le manda su trabajo a
# los devs del otro. Con AUTOPILOTO_TODOS=1 se apaga el filtro (útil si el
# harness no informa directorio).
declare -A ESTADO_DE CLASE_DE
while IFS=$'\t' read -r pid st cwd clase; do
  [ -n "$pid" ] || continue
  CLASE_DE["$pid"]="${clase:-agente}"
  if [ "${AUTOPILOTO_TODOS:-0}" != "1" ] && [ -n "$cwd" ]; then
    case "$cwd" in "$REPO"|"$REPO"/*) ;; *) continue ;; esac
  fi
  ESTADO_DE["$pid"]="$st"
done < <(harness_list)
if [ ${#ESTADO_DE[@]} -eq 0 ]; then
  escribir "FATAL: el harness ($HARNESS) no devolvió paneles — no encadeno nada (PATH=$PATH)"
  exit 1
fi

# ── PANELES QUE NO SE REPARTEN ────────────────────────────────────────────
# El panel del jefe NO ES UN OBRERO. Es la conversación viva con el dueño, y
# meterle un ítem del tablero ahí no es una tarea delegada: es una
# interrupción en el medio de una charla. Pasó tal cual — el autopiloto le
# mandó un ítem al panel del jefe, el pedido le apareció al dueño en la
# pantalla, y terminó pegándoselo a mano a un Freebuff. Dos fallos en uno.
#
# Salen de dos lados, los dos legibles por un humano:
#   * docs/jefe.md — la tabla de quién es jefe y subjefe (la misma que ya lee
#     avisar-jefe.sh: una sola fuente para "quién manda", no dos que se
#     desincronizan).
#   * scripts/no-repartir.conf — un id por línea, para el resto: la sesión
#     interactiva del dueño, un panel prestado a otra cosa, lo que sea.
declare -A EXCLUIDO
if [ -f "$REPO/docs/jefe.md" ]; then
  while read -r pid; do
    [ -n "$pid" ] && EXCLUIDO["$pid"]=jefe
  done < <(grep -iE '^\|.*\*\*(Jefe|Subjefe)' "$REPO/docs/jefe.md" 2>/dev/null \
           | grep -oE '`w5:p[A-Za-z0-9]+`' | tr -d '`')
fi
# El pane del JEFE es dinamico: asegurar-jefe lo escribe en .logs/jefe.panel.
# Sin esta linea, un jefe recien creado recibia items como plebeyo (paso el
# 2026-08-28: el jefe degradado a peon por su propio latigo).
JP=$(cat "$REPO/.logs/jefe.panel" 2>/dev/null)
[ -n "$JP" ] && EXCLUIDO["$JP"]=jefe-dinamico

if [ -f "$REPO/scripts/no-repartir.conf" ]; then
  while IFS= read -r l; do
    l="${l%%#*}"; l="${l// /}"
    [ -n "$l" ] && EXCLUIDO["$l"]=conf
  done < "$REPO/scripts/no-repartir.conf"
fi

AHORA=$(date +%s)
declare -A IDX TS_ENVIO IDLE_DESDE AGOTADA
if [ -f "$ESTADO" ]; then
  while IFS='|' read -r panel idx ts idle agot; do
    [ -n "$panel" ] || continue
    IDX["$panel"]="${idx:-0}"; TS_ENVIO["$panel"]="${ts:-0}"
    IDLE_DESDE["$panel"]="${idle:-0}"; AGOTADA["$panel"]="${agot:-0}"
  done < "$ESTADO"
fi

# Paneles sin cola personal: también trabajan. Se los agrega con cola vacía
# para que caigan directo al tablero. Un panel que existe y nadie listó era,
# hasta hoy, un panel invisible que no trabajaba nunca.
for pid in "${!ESTADO_DE[@]}"; do
  encontrado=0
  for c in "${COLAS[@]}"; do [ "${c%%|*}" = "$pid" ] && { encontrado=1; break; }; done
  [ "$encontrado" = "0" ] && COLAS+=("$pid|")
done

NUEVO_ESTADO=""
for cola in "${COLAS[@]}"; do
  panel="${cola%%|*}"
  pedidos="${cola#*|}"
  lista=()
  [ -n "$pedidos" ] && IFS='|' read -r -a lista <<< "$pedidos"

  idx="${IDX[$panel]:-0}"; ts="${TS_ENVIO[$panel]:-0}"
  idle_desde="${IDLE_DESDE[$panel]:-0}"; agotada="${AGOTADA[$panel]:-0}"
  estado="${ESTADO_DE[$panel]:-}"
  guardar() { NUEVO_ESTADO="$NUEVO_ESTADO$panel|$idx|$ts|$idle_desde|$agotada"$'\n'; }

  # Excluido: se conserva su estado y no se lo toca NUNCA.
  if [ -n "${EXCLUIDO[$panel]:-}" ]; then guardar; continue; fi

  # Panel que ya no existe: se conserva su estado. Borrarlo haría que al
  # reaparecer arrancara la cola de cero.
  [ -z "$estado" ] && { guardar; continue; }

  # Trabajando: se le resetea el reloj de libre y NO SE LO TOCA.
  if [ "$estado" != "idle" ] && [ "$estado" != "done" ]; then
    idle_desde=0; guardar; continue
  fi
  # Válvula 1: gracia.
  if [ "$idle_desde" = "0" ]; then idle_desde=$AHORA; guardar; continue; fi
  [ $((AHORA - idle_desde)) -lt "$GRACIA" ] && { guardar; continue; }
  # Válvula 2: espera mínima entre empujones.
  [ $((AHORA - ts)) -lt "$ESPERA" ] && { guardar; continue; }

  mandar() { # $1=texto $2=etiqueta-para-el-log
    if [ "$SECO" = "1" ]; then escribir "[seco] mandaría a $panel: $2"; return 1; fi
    # EL SALUDO VA ANTES DEL PEDIDO. harness_prompt sabe si el texto ARRANCÓ,
    # pero no si del otro lado hay alguien: una ventana cerrada, un shell sin
    # dev adentro y un opencode que rechaza todo se ven los tres igual de
    # "mandados". Ver scripts/saludar-dev.sh y docs/SALUDAR-AL-DEV.md.
    bash "$DIR/saludar-dev.sh" "$panel" >/dev/null 2>&1
    case $? in
      0) : ;;
      2) escribir "AUTOPILOTO: $panel VENTANA CERRADA — no le mando $2"; return 1 ;;
      3) escribir "AUTOPILOTO: $panel ocupado con otra cosa — no es momento para $2"; return 1 ;;
      *) escribir "AUTOPILOTO: $panel no contesta ni con sesión nueva — no le mando $2"; return 1 ;;
    esac
    if harness_prompt "$panel" "$1"; then escribir "AUTOPILOTO: $panel arrancó con $2"; return 0; fi
    if [ "${CLASE_DE[$panel]:-agente}" = "manual" ]; then
      # ts hacia ADELANTE = enfriamiento: la válvula compara AHORA-ts, así que
      # con ts en el futuro el panel queda intocable hasta que el reloj lo
      # alcance. Se reusa el campo que ya existe en el archivo de estado en
      # lugar de inventar uno nuevo que después hay que migrar.
      ts=$((AHORA + ESPERA_MANUAL - ESPERA))
      escribir "AUTOPILOTO: $panel (MANUAL) quedó con el pedido tipeado, no arrancó — avisado, y no le vuelvo a robar el foco por ${ESPERA_MANUAL}s"
    else
      escribir "AUTOPILOTO: $panel NO arrancó con $2 (estaba $estado) — no insisto por ${ESPERA}s"
    fi
    return 1
  }

  # ── 1. Cola personal ────────────────────────────────────────────────────
  if [ "$agotada" != "1" ] && [ "$idx" -lt "${#lista[@]}" ]; then
    ped="${lista[$idx]}"
    if [ ! -f "$REPO/.logs/pedidos/$ped" ]; then
      escribir "SALTEO $panel: falta el pedido $ped"
      idx=$((idx + 1)); guardar; continue
    fi
    escribir "AUTOPILOTO: $panel libre hace $((AHORA - idle_desde))s -> $ped"
    mandar "ejecutá entero .logs/pedidos/$ped — AUTOPILOTO. Al cerrarlo avisá por scripts/avisar-jefe.sh. Si YA está hecho, no te inventes trabajo: contestá UNA línea diciendo que está cerrado y quedate quieto." "$ped"
    # El índice avanza SIEMPRE que se mandó, arranque o no. Si no avanzara, el
    # mismo pedido volvería en la próxima pasada — que es justo el acoso que
    # estamos sacando.
    idx=$((idx + 1)); ts=$AHORA; idle_desde=0
    guardar; continue
  fi

  # ── 2. El tablero ───────────────────────────────────────────────────────
  # `soltar` primero: un ítem que quedó tomado por un panel que ahora está
  # libre vuelve a la pila. Un panel que muere a mitad no se lleva el trabajo
  # a la tumba. Acá SÍ va `soltar`: a ese panel el pedido le llegó y no lo
  # cerró, así que el intento se cobra.
  bash "$DIR/tablero.sh" soltar "$panel" 2>/dev/null || true
  item="$(TABLERO_REPO="$REPO" bash "$DIR/tablero.sh" take "$panel" 2>/dev/null || true)"
  if [ -n "$item" ]; then
    agotada=0
    escribir "AUTOPILOTO: $panel cola agotada -> TABLERO: $item"
    if ! mandar "Tomá el ítem $item del tablero: leé .logs/tablero/$item.md y ejecutalo entero. Es trabajo REAL pedido por el dueño, no lo reinterpretes. Al cerrarlo: bash scripts/tablero.sh done $item && bash scripts/avisar-jefe.sh. Si al leerlo ves que YA está hecho, marcalo done igual y contestá UNA línea." "$item (tablero)"; then
      # No arrancó (o fue ensayo): el ítem se devuelve. Un ensayo no puede
      # consumir el tablero, y un envío fallido no puede tragarse un pendiente.
      # `devolver` y no `soltar`: el pedido nunca llegó, así que el ítem no
      # paga el intento que `take` ya le cobró. Tres ventanas cerradas
      # seguidas alcanzaban para marcar TRABADO a un ítem impecable.
      bash "$DIR/tablero.sh" devolver "$panel" 2>/dev/null || true
    fi
    ts=$AHORA; idle_desde=0; guardar; continue
  fi

  # ── 3. Silencio ─────────────────────────────────────────────────────────
  if [ "$agotada" != "1" ]; then
    agotada=1
    escribir "TABLERO VACÍO: $panel queda quieto — nadie lo va a molestar hasta que haya ítems"
    if [ ! -f "$REPO/.tmp/tablero-vacio-avisado" ]; then
      touch "$REPO/.tmp/tablero-vacio-avisado"
      bash "$DIR/avisar-jefe.sh" "TABLERO VACÍO — los paneles terminaron todo lo que había. Dictá pendientes desde el celu o agregá con scripts/tablero.sh add." 2>/dev/null || true
    fi
  fi
  guardar
done

printf '%s' "$NUEVO_ESTADO" > "$ESTADO"
