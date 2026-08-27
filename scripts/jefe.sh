#!/usr/bin/env bash
# jefe.sh - el reloj del jefe.
#
# ## El problema que resuelve
#
# Un agente no se detiene por falta de ganas. Se detiene porque termina su turno
# y nada lo vuelve a despertar. Escribirle en un documento que sea incansable no
# sirve: la constancia no es una propiedad del agente, es una propiedad del
# sistema que lo despierta.
#
# El autopiloto despierta a los obreros. Al jefe lo excluye a proposito, porque
# el jefe no toma items del tablero. Ese es exactamente el agujero: el unico
# mecanismo que reinicia a alguien no le apunta al que tiene que reponer el
# trabajo de todos los demas. Este script es ese mecanismo, apuntado al jefe.
#
# ## Como decide que decirle
#
# Nunca le pregunta "que queres hacer". Le da la siguiente accion ya decidida,
# segun el estado del tablero:
#
#   pendientes < obreros   -> reponer, y le dice de donde sacar el trabajo
#   pendientes >= obreros  -> subir un escalon de la escalera de mejora
#
# La escalera rota y no se termina nunca. Cuando da la vuelta, el producto
# cambio y hay cosas nuevas en cada escalon. Esa es la condicion de salida
# imposible, y es a proposito.
#
# ## Configuracion
#
# Los escalones son de este proyecto: se editan en ESCALONES, abajo. Cada uno
# tiene que apuntar a un DOCUMENTO o a una MEDICION, nunca a la imaginacion del
# jefe. Un item inventado es peor que un tablero vacio.
#
#   jefe.sh          una vuelta
#   jefe.sh --loop   se queda, que es como se usa
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
RAIZ="$(cd "$DIR/.." && pwd)"
. "$DIR/harness.sh"
TABLERO="$DIR/tablero.sh"
# El pane del jefe es DINAMICO: lo escribe asegurar-jefe.sh en .logs/jefe.panel
# cada vez que lo (re)crea. Un id hardcodeado en un unit de systemd es una
# mentira a futuro: los panes se renumeran.
JEFE="${JEFE_PANEL:-$(cat "$RAIZ/.logs/jefe.panel" 2>/dev/null || echo jefe)}"
# El estado vive con el resto del mecanismo, en .logs/.
ESTADO="$RAIZ/.logs/jefe.escalon"
INTERVALO="${JEFE_INTERVALO:-180}"
UMBRAL_RAM_MB="${JEFE_RAM_MIN:-1500}"

# --- La escalera. Editable por proyecto. TITULO|que mirar y que produce -------
ESCALONES=(
"INTERFAZ|Recorré las pantallas ya construidas contra DESIGN.md. Buscá lo que se aparta del canon: un color escrito a mano, un boton de mas, un selector que quedo como pantalla, una navegacion por cursor que sobrevivio, un estado vacio sin accion. Cada desvio es un item."
"SEGURIDAD|Revisá una superficie por vez: un endpoint sin control de rol, un dato personal que llega a un log, un limite que falta en lo publico, un mensaje de error que filtra si algo existe. Cada hallazgo es un item."
"RENDIMIENTO|Compará contra el presupuesto de respuesta que el proyecto declaro. Lo que no entra necesita un indice o una consulta distinta. Medilo con datos del tamano mas grande que soportamos, no del mas chico."
"CALIDAD|Mirá los huecos que el proyecto mide con su propio marcador. Cada grupo de huecos es un item."
"COBERTURA|Abrí el inventario de lo que hay que lograr y buscá lo que todavia no tiene item ni implementacion. Nada del inventario se descarta en silencio."
"DOCUMENTACION|Verificá que las specs sigan coincidiendo con lo construido. Una funcionalidad cerrada que no esta hecha, o hecha y no marcada, es un item. Un documento que quedo viejo tambien."
"VENTA|Pensá como se vende esto mejor: que le falta a la demo, que numero convence a quien firma, que hace falta para que un cliente diga que si en una reunion. Lo que no esta medido, medirlo es un item."
"WEB|Que tarea principal del usuario todavia no se resuelve en una pantalla, que se pide dos veces, que no entra en un telefono. Cada una es un item."
)

# ── Escalones EXPLORATORIOS: cerrados hasta lograr el objetivo ──────────
# Valen mucho, y son la forma mas facil de no terminar nunca. Se abren cuando
# ./scripts/objetivo.sh dice que la puerta esta abierta, y ni un minuto antes.
EXPLORATORIOS=(
"COMPETENCIA|Estudia como resuelven esto los mejores del pais y del mundo. Que hacen mejor, que hacen peor, que se les puede robar. Cada hallazgo aplicable es un item, con el porque y a que pantalla nuestra afecta."
"VENTA|Que le falta a la demo, que numero convence a quien firma, que hace falta para que un cliente diga que si. Lo que no esta medido, medirlo es un item."
"MARKETING|Como se cuenta esto afuera: a quien, con que argumento, con que prueba. Cada pieza que falte es un item."
"IDEAS PRESTADAS|Productos de OTROS rubros que resuelven bien algo que nosotros resolvemos mal. Lo mejor casi nunca viene del competidor directo."
)

siguiente_escalon() {
  local n=0
  [ -f "$ESTADO" ] && n=$(cat "$ESTADO" 2>/dev/null || echo 0)
  n=$(( (n + 1) % ${#ESCALONES[@]} ))
  mkdir -p "$(dirname "$ESTADO")"; echo "$n" > "$ESTADO"
  echo "$n"
}

obreros() { harness_list 2>/dev/null | awk -F'\t' -v j="$JEFE" '$1!=j && ($4=="obrero"||$4=="agente")' | wc -l; }

# El panel del jefe existe de verdad, o no se le habla. docs/jefe.md envejece:
# los ids cambian cada vez que se recrea un panel, y hablarle a un id muerto es
# la forma silenciosa de que la escalera no suba nunca.
jefe_vivo() { harness_list 2>/dev/null | cut -f1 | grep -qx "$JEFE"; }
ram_mb()  { awk '/MemAvailable/ {printf "%d", $2/1024}' /proc/meminfo; }

una_vuelta() {
  local pend n ram
  pend=$("$TABLERO" count 2>/dev/null || echo 0)
  n=$(obreros); [ "$n" -eq 0 ] && n=1
  ram=$(ram_mb)

  if [ "$pend" -lt "$n" ]; then
    # ── PRIMERO LA MAQUINA, DESPUES EL CARO ────────────────────────────────
    # La regla de la casa es que si algo lo puede hacer un obrero lo hace un
    # obrero; aca se estira un escalon mas: si lo puede hacer un SCRIPT, lo
    # hace un script. nunca-ocioso.sh repone sin redaccion y sin un token.
    # Al jefe se lo despierta solo si despues de eso el tablero sigue corto,
    # que es cuando de verdad falta criterio y no manos.
    if [ -x "$DIR/nunca-ocioso.sh" ]; then
      MINIMO="$n" bash "$DIR/nunca-ocioso.sh" >/dev/null 2>&1 || true
      pend=$("$TABLERO" count 2>/dev/null || echo 0)
      if [ "$pend" -ge "$n" ]; then
        echo "$(date +%H:%M) repuesto por la escalera, sin molestar al jefe: pend=$pend"
        return
      fi
    fi
    jefe_vivo || { echo "$(date +%H:%M) reponer: pend=$pend<$n y el panel del jefe ($JEFE) no existe"; return; }
    harness_prompt "$JEFE" "El tablero tiene $pend pendientes y hay $n obreros. Esta por debajo, y eso significa paneles apagandose.

Reponelo AHORA hasta pasar los $n. No inventes trabajo: sacalo de las fuentes que el proyecto ya tiene, en orden, y la primera que tenga entradas gana. El inventario de lo que falta, el marcador de huecos, los informes de cierre de los obreros (donde dice que les falto) y las specs.

Una zona exclusiva por item, en rutas. El contexto completo adentro del item: el obrero no ve tu pantalla. Cuando termines, decime cuantos escribiste." >/dev/null 2>&1 || true
    echo "$(date +%H:%M) reponer: $pend<$n"
    return
  fi

  # La compuerta. Sin ella el equipo se dispersa justo cuando falta poco.
  local puerta="CERRADA"
  ./scripts/objetivo.sh --puerta >/dev/null 2>&1 && puerta="ABIERTA"
  [ "$puerta" = ABIERTA ] && ESCALONES+=("${EXPLORATORIOS[@]}")

  local i titulo cuerpo
  i=$(siguiente_escalon)
  titulo="${ESCALONES[$i]%%|*}"
  cuerpo="${ESCALONES[$i]#*|}"
  # ── SIN PANEL DE JEFE, EL ESCALON NO SE PIERDE: SE VUELVE ITEM ─────────
  # Cuando el jefe es una sesion de terminal y no un panel de la flota, no hay
  # a quien mandarle el prompt. Dejar caer el escalon seria apagar la escalera
  # justo cuando el tablero esta sano. El escalon entra al tablero y lo agarra
  # un obrero, que ademas es mas barato que despertar al jefe.
  if ! jefe_vivo; then
    printf '%s\n' "$cuerpo

Esto no es relleno ni es opcional: el producto nunca esta terminado. Si este escalon esta genuinamente limpio, decilo en una linea y cerra el item — decir 'esto esta bien' es una respuesta correcta; inventar trabajo no.
Cada desvio o hueco que encuentres va como ITEM NUEVO al tablero: bash scripts/tablero.sh add \"...\". Al cerrar deci cuantos escribiste." \
      | "$TABLERO" add "ESCALON-$titulo: subir un escalon de la escalera de mejora" >/dev/null 2>&1 || true
    echo "$(date +%H:%M) escalon $titulo -> al tablero (sin panel de jefe)"
    [ "$ram" -lt "$UMBRAL_RAM_MB" ] && echo "$(date +%H:%M) AVISO: RAM disponible ${ram} MB, por debajo de ${UMBRAL_RAM_MB}"
    return 0
  fi

  harness_prompt "$JEFE" "El tablero esta con $pend pendientes para $n obreros, asi que no hay urgencia de reponer. Turno de mejorar: **$titulo**.

$cuerpo

Esto no es relleno ni es opcional: el producto nunca esta terminado y tu trabajo tampoco. Si este escalon esta genuinamente limpio, decilo en una linea y pasa al siguiente — decir 'esto esta bien' es una respuesta correcta; inventar un item no.

Escribi los que salgan y avisame cuantos. RAM disponible: ${ram} MB." >/dev/null 2>&1 || true
  echo "$(date +%H:%M) escalon: $titulo (pend=$pend)"

  [ "$ram" -lt "$UMBRAL_RAM_MB" ] && echo "$(date +%H:%M) AVISO: RAM disponible ${ram} MB, por debajo de ${UMBRAL_RAM_MB}"
  return 0
}

case "${1:-}" in
  --loop) while true; do una_vuelta; sleep "$INTERVALO"; done ;;
  *)      una_vuelta ;;
esac
