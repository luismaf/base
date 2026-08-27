#!/usr/bin/env bash
# harness.sh — LA CAPA AGNÓSTICA. Se hace `source` de este archivo; no se ejecuta.
#
# Por qué existe: todo el mecanismo (autopiloto, tablero, la pantalla del celu)
# necesita EXACTAMENTE tres cosas de la herramienta que corre los agentes:
#
#     harness_list                 -> "panel<TAB>estado<TAB>directorio<TAB>clase"
#     harness_prompt <panel> <txt> -> le manda trabajo; 0 si arrancó
#     harness_read <panel> [n]     -> las últimas n líneas de su terminal
#
# Nada más. Mientras esas tres existan, da igual qué haya abajo. Hoy usamos
# herdr; mañana puede ser paseo, un harness de DeepSeek, o tmux pelado. El día
# que se cambie, se toca ESTE archivo y nada más — que es la diferencia entre
# migrar en una tarde y reescribir el mecanismo entero.
#
# El tercer campo, el directorio de trabajo del panel, no es un adorno: en una
# misma sesión conviven paneles de VARIOS repos. Sin ese dato, el autopiloto de
# un proyecto le manda su trabajo a los devs de otro — pasó, y el dev de al
# lado se encuentra ejecutando pedidos de un repo que no es el suyo.
#
# El cuarto campo es la CLASE de panel, y existe por algo que costó dos noches
# de paneles parados. No todo panel es un "agente" que el harness sepa manejar:
# algunos corren un TUI a secas (acá, Freebuff), y para el harness son una
# terminal común. Antes esos paneles NO APARECÍAN en la lista, así que el
# autopiloto nunca les daba trabajo y nadie notaba nada — el dueño encontró dos
# Freebuff quietos y tuvo que pegarles el pedido a mano. Un panel que el
# mecanismo no sabe manejar tiene que aparecer igual, marcado: invisible es la
# peor forma de estar roto.
#   agente  -> se le habla por la API de agentes; arranca solo.
#   manual  -> se le habla por teclado, con foco y ritual (ver _herdr_prompt_manual).
#
# Estados normalizados: working | idle | done | otro
#   * working = está haciendo algo, NO se lo toca.
#   * idle/done = puede recibir trabajo.
# Un backend que no sepa distinguirlos debe decir "otro": es preferible un
# panel que nadie empuja a uno al que se le pisa el trabajo a la mitad.
#
# Elección del backend: variable HARNESS, o el archivo .harness del repo.
# Valores: herdr (default) | tmux | custom

HARNESS="${HARNESS:-$(cat "${REPO:-.}/.harness" 2>/dev/null || echo herdr)}"
export PATH="$HOME/.local/bin:$PATH"

# ─────────────────────────────────────────────────────────────── herdr ──
# Los marcadores de que un panel manual está LIBRE. Son DOS, separados por "|",
# y confundir uno con los dos costó cuarenta minutos de paneles disponibles
# contados como ocupados:
#
#   "Press Enter to"      -> terminó y espera para abrir sesión NUEVA. Necesita
#                            el Enter de despertar antes de poder pegarle nada.
#   "Enter a coding task" -> el placeholder de la caja de entrada. Sólo se ve
#                            cuando la caja está VACÍA, o sea: sesión abierta y
#                            sin nada pendiente. Está listo para recibir, sin
#                            despertarlo.
#
# El segundo es el que faltaba. Un panel con la sesión abierta y la caja vacía
# es exactamente un panel libre, y el detector lo daba por ocupado para
# siempre: los dos Freebuff estuvieron disponibles toda una tarde y el
# autopiloto no les dio nada.
#
# Si la caja tiene texto, NO hay placeholder y el panel se cuenta ocupado. Eso
# es correcto y a propósito: puede estar trabajando, o puede tener un pedido
# tipeado esperando un Enter — en los dos casos, pegarle encima lo rompe.
#
# Los marcadores son CORTOS a propósito: el TUI dibuja en columnas con marcos y
# apretado queda "PressEnterto│Change│││continueinanew│model", con el texto del
# botón de al lado metido en el medio. Buscar la frase entera no matchea nunca.
HARNESS_MANUAL_LIBRE="${HARNESS_MANUAL_LIBRE:-Press Enter to|Enter a coding task}"

# El limpiador. Todo lo que se compara contra la pantalla de un TUI pasa por
# acá, y no es una comodidad: es la diferencia entre que el mecanismo funcione
# y que no.
#
# El TUI dibuja la caja de entrada con marcos, y al cortar una línea larga los
# bordes quedan METIDOS EN EL MEDIO del texto:
#
#     │  Tomá el ítem 20260822-214913-      │
#     │  0015287 del tablero: leé .logs/    │
#
# Sacando sólo los espacios queda "Tomáelítem20260822-214913-│0015287deltab…":
# cualquier fragmento de más de una línea lleva un │ adentro y NO MATCHEA
# NUNCA. Con eso, la verificación de "¿entró el texto?" daba siempre que no, el
# ritual abortaba antes de mandar el Enter, y el pedido quedaba tipeado — que
# es exactamente cómo el dueño encontró sus paneles. El bug se disfrazaba de
# "el Enter no funciona".
_h_limpio() {
  herdr pane read "$1" --source visible --lines "${2:-25}" --format text 2>/dev/null \
    | sed 's/[│┃╭╮╰╯─━┌┐└┘├┤┬┴┼║╔╗╚╝═▍▏▎▄▀]//g' | tr -d ' \t\n\r'
}
_h_limpiar_texto() { printf '%s' "$1" | sed 's/[│┃╭╮╰╯─━┌┐└┘├┤┬┴┼║╔╗╚╝═▍▏▎▄▀]//g' | tr -d ' \t\n\r'; }

# ¿Alguno de los marcadores está en la pantalla? Se compara sin espacios de los
# dos lados, porque el TUI corta las líneas donde le conviene.
_h_libre() {
  local pantalla marca
  pantalla=$(_h_limpio "$1" 25)
  [ -n "$pantalla" ] || return 1
  local viejo_ifs="$IFS"; IFS='|'
  for marca in $HARNESS_MANUAL_LIBRE; do
    [ -z "$marca" ] && continue
    if printf '%s' "$pantalla" | grep -qF "$(_h_limpiar_texto "$marca")"; then
      IFS="$viejo_ifs"; return 0
    fi
  done
  IFS="$viejo_ifs"; return 1
}

# Último recurso: el panel manual QUIETO.
#
# Un panel cuya caja tiene texto se cuenta ocupado, y está bien: puede estar
# trabajando. Pero también puede tener un pedido TIPEADO que nunca arrancó —
# que es justo el modo de fallo de todo esto. En ese estado no muestra ningún
# marcador de libre y quedaría ocupado PARA SIEMPRE: un solo ritual fallido
# dejaría el panel inservible hasta que pase un humano, que es exactamente lo
# que este mecanismo existe para no necesitar.
#
# Entonces: si no muestra marcador de libre PERO su pantalla no cambió en
# HARNESS_MANUAL_QUIETO segundos, no está trabajando — está trabado. El ritual
# vacía la caja con Ctrl-U antes de pegar, así que se recupera solo.
#
# Cinco minutos es a propósito generoso: un TUI que trabaja repinta seguido
# (spinners, contadores), y preferimos esperar de más antes que pisarle el
# trabajo a alguien.
HARNESS_MANUAL_QUIETO="${HARNESS_MANUAL_QUIETO:-300}"
_h_huellas="${TMPDIR:-/tmp}/harness-manual-$UID"

_h_quieto() {
  mkdir -p "$_h_huellas"
  local f="$_h_huellas/$(printf '%s' "$1" | tr ':.' '__')"
  local ahora nueva vieja ts
  ahora=$(date +%s)
  # Sólo las últimas líneas: ahí está la caja de entrada. Más arriba el TUI
  # rota BANNERS DE PUBLICIDAD cada pocos segundos, y con eso en la huella la
  # pantalla "cambia" siempre y nada se detecta nunca como quieto.
  nueva=$(_h_limpio "$1" 6 | md5sum | cut -c1-32)
  ts=0
  [ -f "$f" ] && { vieja=$(cut -d' ' -f1 "$f"); ts=$(cut -d' ' -f2 "$f"); }
  if [ "$nueva" != "${vieja:-}" ]; then echo "$nueva $ahora" > "$f"; return 1; fi
  [ $((ahora - ts)) -ge "$HARNESS_MANUAL_QUIETO" ]
}

# ¿Está esperando el Enter que abre una sesión nueva? Sólo en ese caso hay que
# despertarlo; si ya tiene la caja abierta, ese Enter sobra.
_h_dormido() { _h_limpio "$1" 25 | grep -qF "PressEnterto"; }

_herdr_list() {
  # UNA sola llamada: `pane list` ya trae agent, agent_status, cwd y tab_id.
  # Antes se llamaba a `agent list`, que por definición no puede ver los
  # paneles que no son agentes — o sea, justamente los que se perdían.
  local crudo; crudo=$(herdr pane list 2>/dev/null) || return 1
  echo "$crudo" | python3 -c "
import json,sys
try: d=json.load(sys.stdin)
except Exception: sys.exit(1)
ps=d.get('result',{}).get('panes',[])
if not ps: sys.exit(1)
for p in ps:
    pid=p.get('pane_id',''); cwd=p.get('cwd','') or ''
    if p.get('agent'):
        e=p.get('agent_status','') or 'otro'
        print(pid, e if e in ('working','idle','done') else 'otro', cwd, 'agente', sep='\t')
    else:
        print(pid, 'PENDIENTE', cwd, 'manual', sep='\t')
" | while IFS=$'\t' read -r pid est cwd clase; do
      # ── EL "WORKING" DE HERDR NO ES EVIDENCIA (2026-08-27) ────────────────
      # herdr adivina el estado del agente y miente en las dos direcciones
      # (default_known_agent_idle_fallback). El caso caro: un dev que TERMINO
      # su item queda "working" para siempre, el repartidor le cree, y el
      # panel no recibe latigazo nunca — "libres:0" con obreros ociosos.
      # La evidencia real es la pantalla: un agente cuya pantalla no cambio
      # en HARNESS_AGENTE_QUIETO segundos (180 por defecto; un modelo
      # trabajando ESCRIBE) no esta trabajando, diga lo que diga herdr.
      if [ "$clase" = "agente" ] && [ "$est" = "working" ]; then
        if HARNESS_MANUAL_QUIETO="${HARNESS_AGENTE_QUIETO:-180}" _h_quieto "$pid"; then est=idle; fi
      fi
      if [ "$est" = "PENDIENTE" ]; then
        # Ante la duda, OCUPADO. Equivocarse hacia "está trabajando" cuesta
        # esperar una vuelta; equivocarse hacia "está libre" le pisa el
        # trabajo a la mitad y encima se paga el prompt.
        if _h_libre "$pid"; then est=idle
        elif _h_quieto "$pid"; then est=idle   # trabado, no trabajando
        else est=working; fi
      fi
      printf '%s\t%s\t%s\t%s\n' "$pid" "$est" "$cwd" "$clase"
    done
}

_herdr_clase() {
  herdr pane list 2>/dev/null | python3 -c "
import json,sys
for p in json.load(sys.stdin).get('result',{}).get('panes',[]):
    if p.get('pane_id')=='$1':
        print('agente' if p.get('agent') else 'manual'); break
"
}

_herdr_prompt() {
  # Un panel que no es agente no entiende `agent prompt`: contesta
  # "No agent is running in pane" y el pedido se pierde en silencio.
  if [ "$(_herdr_clase "$1")" = "manual" ]; then _herdr_prompt_manual "$1" "$2"; return $?; fi
  # --wait --until working es lo que convierte "mandé el texto" en "arrancó".
  # Sin eso el prompt queda TIPEADO en el panel y el agente sigue ocioso: es
  # la trampa que hace creer que hay cuatro agentes trabajando cuando hay
  # cuatro esperando un Enter.
  herdr agent prompt "$1" "$2" --wait --until working 2>&1 | grep -q '"agent_status":"working"'
}
# ── El ritual del panel manual (Freebuff) ─────────────────────────────────
# Escrito después de que el dueño encontrara dos Freebuff parados y tuviera
# que pegarles el pedido a mano (2026-08-22). Son TRES pulsaciones, no una, y
# el orden importa:
#
#   1. ENTER para ARRANCAR. Cuando el TUI termina lo suyo queda mostrando
#      "Press Enter to continue in a new session". En ese estado NO hay caja de
#      texto: pegar ahí no hace nada. Este Enter es el que faltaba en la receta
#      vieja, y es la razón por la que los dos paneles quedaron quietos.
#   2. PEGAR el texto — con `pane run`, que es el único camino que mete texto
#      en un pane que no es agente (`send-text` sin foco no llega y no falla).
#   3. ENTER para MANDAR. Sin este, el pedido queda TIPEADO y el panel ocioso.
#      Es la misma trampa de siempre: parece delegado y no lo está.
#
# Y todo eso SÓLO con el pane enfocado: sin foco las teclas no llegan y no dan
# error, que es la peor forma de fallar. Por eso el ritual roba el foco, hace
# lo suyo y lo DEVUELVE — al dueño se le mueve la pantalla un segundo, que es
# el precio de que el panel no quede parado toda la noche.
#
# Con HARNESS_FOCO=0 no se roba el foco: se deja el texto puesto y se devuelve
# fracaso, para que quien llame avise en vez de creer que arrancó.
HARNESS_FOCO="${HARNESS_FOCO:-1}"

_h_pane_enfocado() { herdr pane list 2>/dev/null | python3 -c "
import json,sys
for p in json.load(sys.stdin).get('result',{}).get('panes',[]):
    if p.get('focused'): print(p['pane_id']); break
"; }
_h_tab_de() { herdr pane list 2>/dev/null | python3 -c "
import json,sys
for p in json.load(sys.stdin).get('result',{}).get('panes',[]):
    if p.get('pane_id')=='$1': print(p.get('tab_id','')); break
"; }
_h_tab_enfocado() { herdr tab list 2>/dev/null | python3 -c "
import json,sys
for t in json.load(sys.stdin).get('result',{}).get('tabs',[]):
    if t.get('focused'): print(t['tab_id']); break
"; }

# Caminar hasta un pane. `herdr pane focus` sólo sabe moverse a un VECINO por
# dirección: no hay "enfocá este id". La primera versión caminaba siempre hacia
# la derecha y funcionaba… hasta que el destino estaba a la izquierda: desde
# w5:p2M nunca llegaba a w5:p2K, se quedaba pegado al borde dando doce vueltas
# sin moverse, y el panel quedaba sin trabajo igual que antes. Ahora es una
# búsqueda de verdad: en cada paso prueba las cuatro direcciones y toma la
# primera que lleve a un pane donde no estuvo. Sin la lista de visitados, dos
# panes vecinos se rebotan el foco para siempre.
_h_enfocar() {
  local objetivo="$1" visitados=" " actual dir movio pasos=0
  herdr tab focus "$(_h_tab_de "$objetivo")" >/dev/null 2>&1
  while [ $pasos -lt 40 ]; do
    actual=$(_h_pane_enfocado)
    [ "$actual" = "$objetivo" ] && return 0
    [ -z "$actual" ] && return 1
    visitados="$visitados$actual "
    movio=0
    for dir in right down left up; do
      herdr pane focus --direction "$dir" >/dev/null 2>&1 || continue
      actual=$(_h_pane_enfocado)
      [ "$actual" = "$objetivo" ] && return 0
      case "$visitados" in *" $actual "*) ;; *) movio=1; break ;; esac
    done
    [ "$movio" = "0" ] && return 1
    pasos=$((pasos + 1))
  done
  return 1
}

# Se avisa desde los DOS caminos por los que el texto puede quedar tipeado:
# el que no roba el foco por configuración y el que lo intentó y no pudo. La
# primera versión sólo avisaba en el segundo, así que con HARNESS_FOCO=0 el
# fallo volvía a ser mudo — que es el problema entero que esto viene a
# resolver.
_h_avisar_tipeado() {
  [ -n "$HARNESS_AVISAR" ] || return 0
  bash "$HARNESS_AVISAR" "PANEL MANUAL $1: el pedido está TIPEADO pero no arrancó — enfocá ese panel y apretá Enter. El texto está puesto, no lo reescribas." >/dev/null 2>&1 || true
}

# Traza paso a paso. Con HARNESS_DEBUG=1 cada etapa dice qué vio, porque este
# ritual falla en silencio por naturaleza y deducir desde afuera cuál de los
# seis pasos se cayó cuesta más que instrumentarlo.
_h_dbg() { [ -n "${HARNESS_DEBUG:-}" ] && echo "  [ritual] $*" >&2; return 0; }

_herdr_prompt_manual() {
  # El ritual, con los primitivos que de verdad hacen lo que dicen. La receta
  # anterior estaba construida sobre dos suposiciones equivocadas, y las dos se
  # cayeron mirando la caja después de cada tecla en vez de deducirlas:
  #
  #   * `pane run` NO deja el texto puesto: SUBMITEA. Se lo usaba como "pegar",
  #     y lo que hacía era mandar lo que hubiera en la caja — una vez arrancó un
  #     panel con el pedido VIEJO que había quedado tipeado.
  #   * Ctrl-U NO vacía la caja. Tampoco Ctrl-K ni Escape. Lo único que la
  #     vacía es BACKSPACE repetido.
  #
  # Lo que sí funciona, verificado paso por paso con el pane enfocado:
  #   send-text  -> el texto entra y NO se manda
  #   send-keys enter -> lo manda
  local pane="$1" texto="$2"

  # ── GUARDIA (2026-08-27): NUNCA tipearle trabajo a un bash pelado ────────
  # Un pane cuyo agente murió (OOM, kill, crash) sigue existiendo como shell.
  # El clasificador lo ve "manual", este ritual le tipeaba el prompt a BASH
  # —una linea por renglon, "command not found" por pantalla, el pedido
  # perdido y la terminal del dueño llena de basura. Paso el 2026-08-27 con
  # siete panes a la vez.
  # La unica prueba de que del otro lado hay una TUI esperando texto es el
  # marcador en pantalla (HARNESS_MANUAL_LIBRE). Sin marcador NO SE TIPEA:
  # se avisa y el pane queda para que poblar-flota lo reclame con un agente
  # nuevo. Tres resultados, nunca dos: tipeado / NO tipeo (pane muerto) /
  # no pude mirar.
  if ! _h_libre "$pane"; then
    echo "harness: $pane no muestra una TUI esperando texto (agente muerto o bash pelado): NO le tipeo el pedido" >&2
    return 2
  fi

  # La huella sale de la COLA del texto, no del principio. El prompt del
  # autopiloto tiene trescientos y pico de caracteres: la caja hace scroll y
  # los primeros se van FUERA DE VISTA. Buscando el arranque, la verificación
  # de "¿entró el texto?" fallaba siempre con los pedidos largos —o sea, con
  # los de verdad— y el ritual abortaba antes de mandar el Enter. Con los
  # cortos de prueba andaba, que es lo que lo hizo difícil de ver.
  # El final del texto siempre queda visible: es donde está el cursor.
  local huella; huella=$(_h_limpiar_texto "$texto" | rev | cut -c1-24 | rev)

  if [ "$HARNESS_FOCO" != "1" ]; then
    _h_avisar_tipeado "$pane"
    return 1
  fi

  local tab_orig; tab_orig=$(_h_tab_enfocado)
  local volver; volver() { [ -n "$tab_orig" ] && herdr tab focus "$tab_orig" >/dev/null 2>&1; }

  # Sin foco no se manda NADA: mejor no hacer nada que dejar el texto tipeado
  # en el panel equivocado, que además se lo lleva puesto el próximo Enter.
  if ! _h_enfocar "$pane"; then _h_dbg "foco: FALLÓ"; volver; return 1; fi
  _h_dbg "foco: ok"

  # 1. Enter para abrir sesión nueva, SÓLO si está esperando eso. Cuando el TUI
  # termina queda en "Press Enter to continue in a new session" y ahí no hay
  # caja: pegar no hace nada. Ésta era la pulsación que faltaba en la receta
  # vieja y la razón por la que los paneles quedaban quietos.
  if _h_dormido "$pane"; then
    _h_dbg "dormido: mando Enter de sesión nueva"
    herdr pane send-keys "$pane" enter >/dev/null 2>&1
    sleep 3
  fi

  # 2. Vaciar la caja. Si un intento anterior dejó texto —es justo el modo de
  # fallo de esto— escribir encima concatena dos pedidos y el panel recibe un
  # mamarracho. Van todos los backspaces en UNA llamada: 300 llamadas sueltas
  # tardan más que todo el resto del ritual junto.
  local bs; bs=$(for _ in $(seq 1 "${HARNESS_BORRAR:-300}"); do printf 'backspace '; done)
  herdr pane send-keys "$pane" $bs >/dev/null 2>&1 || _h_dbg "backspaces: la llamada falló"
  sleep 1
  _h_dbg "caja vaciada"

  # 3. El texto, y se VERIFICA que entró antes de mandar nada.
  local intento
  for intento in 1 2; do
    herdr pane send-text "$pane" "$texto" >/dev/null 2>&1
    sleep 2
    if _h_limpio "$pane" 30 | grep -qF "$huella"; then _h_dbg "texto: entró (intento $intento)"; break; fi
    _h_dbg "texto: NO lo veo (intento $intento) — huella=[$huella]"
    [ "$intento" = "2" ] && { volver; _h_avisar_tipeado "$pane"; return 1; }
  done

  # 4. Enter, insistiendo y verificando por lectura entre intento e intento.
  # Verificar leyendo es lo único que distingue MANDADO de TIPEADO, y
  # confundirlos es lo que deja un panel ocioso toda la noche pareciendo
  # ocupado. Se miran las últimas líneas, que es donde está la caja: el texto
  # sigue existiendo más arriba, en el historial, y eso está bien.
  local arranco=0 espera=3
  for intento in 1 2 3; do
    _h_enfocar "$pane" >/dev/null 2>&1 || break
    herdr pane send-keys "$pane" enter >/dev/null 2>&1
    sleep "$espera"
    # Mandado = la caja quedó VACÍA, y eso se ve por el placeholder que el TUI
    # vuelve a mostrar. Es una señal positiva y distintiva; "ya no encuentro mi
    # texto" es negativa y se confunde con el mismo texto pasando al historial
    # justo arriba de la caja. Se aceptan las dos, la positiva primero.
    if _h_limpio "$pane" 6 | grep -qF "$(_h_limpiar_texto "${HARNESS_MANUAL_VACIA:-Enter a coding task}")"; then _h_dbg "enter $intento: caja vacía -> MANDADO"; arranco=1; break; fi
    if ! _h_limpio "$pane" 8 | grep -qF "$huella"; then _h_dbg "enter $intento: la huella ya no está -> MANDADO"; arranco=1; break; fi
    _h_dbg "enter $intento: sigue tipeado"
    espera=$((espera + 3))
  done

  volver
  # Si no arrancó, el texto QUEDA PUESTO y se avisa. Es la diferencia entre que
  # el dueño encuentre dos paneles quietos por casualidad —como pasó— y que le
  # llegue "hay un pedido esperando un Enter en w5:p2K".
  [ "$arranco" = "0" ] && { _h_avisar_tipeado "$pane"; return 1; }
  return 0
}

_herdr_read() { herdr pane read "$1" --source recent --lines "${2:-45}" --format text 2>/dev/null; }

# ──────────────────────────────────────────────────────────────── tmux ──
# Backend sin ninguna herramienta de agentes: sirve para probar el kit en
# cualquier máquina. "working" se deduce de que la pantalla del panel haya
# CAMBIADO en los últimos HARNESS_TMUX_QUIETO segundos. Es una heurística, no
# un estado real — por eso el default es generoso (90 s): equivocarse hacia
# "está ocupado" sólo cuesta esperar; equivocarse hacia "está libre" le pisa
# el trabajo a un agente a mitad de camino.
HARNESS_TMUX_QUIETO="${HARNESS_TMUX_QUIETO:-90}"
_tmux_huella_dir="${TMPDIR:-/tmp}/harness-tmux-$UID"
_tmux_list() {
  command -v tmux >/dev/null || return 1
  mkdir -p "$_tmux_huella_dir"
  local ahora; ahora=$(date +%s)
  tmux list-panes -a -F '#{session_name}:#{window_index}.#{pane_index}\t#{pane_current_path}' 2>/dev/null | while IFS=$'\t' read -r p cwd; do
    local f="$_tmux_huella_dir/$(echo "$p" | tr ':.' '__')"
    local nueva; nueva=$(tmux capture-pane -p -t "$p" 2>/dev/null | md5sum | cut -c1-32)
    local vieja=""; local ts=0
    [ -f "$f" ] && { vieja=$(cut -d' ' -f1 "$f"); ts=$(cut -d' ' -f2 "$f"); }
    if [ "$nueva" != "$vieja" ]; then ts=$ahora; echo "$nueva $ahora" > "$f"; fi
    if [ $((ahora - ts)) -lt "$HARNESS_TMUX_QUIETO" ]; then printf '%s\tworking\t%s\n' "$p" "$cwd"
    else printf '%s\tidle\t%s\n' "$p" "$cwd"; fi
  done
}
_tmux_prompt() {
  tmux send-keys -t "$1" "$2" 2>/dev/null || return 1
  tmux send-keys -t "$1" Enter 2>/dev/null || return 1
  sleep 2
  # Se declara arrancado sólo si la pantalla se movió: mandar no es arrancar.
  local f="$_tmux_huella_dir/$(echo "$1" | tr ':.' '__')"
  local antes=""; [ -f "$f" ] && antes=$(cut -d' ' -f1 "$f")
  [ "$(tmux capture-pane -p -t "$1" 2>/dev/null | md5sum | cut -c1-32)" != "$antes" ]
}
_tmux_read() { tmux capture-pane -p -t "$1" 2>/dev/null | tail -"${2:-45}"; }

# ────────────────────────────────────────────────────────────── custom ──
# Para un harness que todavía no tiene backend acá (paseo, DeepSeek, lo que
# venga). Se definen tres comandos por variable de entorno y listo:
#   HARNESS_LIST_CMD   debe imprimir "panel<TAB>estado<TAB>directorio" (el
#                      directorio puede ir vacío si el harness no lo sabe: en
#                      ese caso el panel se considera de cualquier repo)
#   HARNESS_PROMPT_CMD recibe $1=panel $2=texto; sale 0 si arrancó
#   HARNESS_READ_CMD   recibe $1=panel $2=líneas
_custom_list()   { eval "${HARNESS_LIST_CMD:?definí HARNESS_LIST_CMD}"; }
_custom_prompt() { eval "${HARNESS_PROMPT_CMD:?definí HARNESS_PROMPT_CMD}" "$(printf '%q %q' "$1" "$2")"; }
_custom_read()   { eval "${HARNESS_READ_CMD:?definí HARNESS_READ_CMD}" "$(printf '%q %q' "$1" "${2:-45}")"; }

# ── Arrancar un obrero nuevo ────────────────────────────────────────────
# Cuarta primitiva. Recibe $1=nombre $2=clase-de-agente y el resto de
# argumentos para el agente. Sale 0 si quedo andando.
#
# No todo harness puede crear paneles: si no puede, devuelve 1 y quien llama se
# entera. Devolver 0 sin haber creado nada es la clase de mentira que deja la
# maquina llena de obreros imaginarios.
_herdr_start() {
  local nombre="$1" clase="$2"; shift 2
  local pane
  pane=$(herdr pane new 2>/dev/null | grep -oE 'w[0-9]+:p[0-9A-Za-z]+' | head -1)
  [ -z "$pane" ] && return 1
  herdr agent start "$nombre" --kind "$clase" --pane "$pane" -- "$@" >/dev/null 2>&1
}
_tmux_start() {
  local nombre="$1" clase="$2"; shift 2
  tmux new-window -d -n "$nombre" "$clase $*" >/dev/null 2>&1
}
_custom_start() {
  [ -n "${HARNESS_START_CMD:-}" ] || return 1
  eval "$HARNESS_START_CMD" "$(printf '%q %q' "$1" "$2")"
}

# ── La clase de panel: una sola palabra, y no cambiarla ────────────────
#
# CLASE DE PANEL. El cuarto campo de harness_list dice que ES ese panel, y el
# valor canonico es "agente". Se acepta tambien "obrero" por compatibilidad,
# pero al escribir un filtro nuevo aceptá LAS DOS.
#
# Por que este comentario existe: cinco scripts filtraron por "obrero" cuando el
# harness emitia "agente". No fallaron — contaron CERO obreros siempre, y con
# cero el umbral de reposicion es 1, asi que un tablero con un solo item para
# veinte paneles leia como sano. Un filtro que no matchea nunca no se queja: se
# lleva la flota puesta en silencio.

# ───────────────────────────────────────────────────────── el contrato ──
harness_list()   { "_${HARNESS}_list"; }
harness_prompt() { "_${HARNESS}_prompt" "$1" "$2"; }
harness_read()   { "_${HARNESS}_read" "$1" "${2:-45}"; }
harness_start()  { "_${HARNESS}_start" "$@"; }

# Un harness que no contesta NO es "cero paneles libres": es un harness caído.
# Confundirlos fue el bug más caro que tuvimos — el autopiloto veía la lista
# vacía, no empujaba a nadie, no escribía una línea de log, y el equipo entero
# quedaba parado horas mientras todo "corría bien".
harness_vivo() { [ -n "$(harness_list 2>/dev/null | head -1)" ]; }
