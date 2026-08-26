#!/usr/bin/env bash
# teatro.sh - detectar al panel que parece trabajar y no produce.
#
# ## El problema, que es peor que el ocio
#
# Un panel apagado se ve. Un panel que corre tests cada dos minutos al pedo, o
# que hace un cambio de una linea y compila otra vez, y otra vez, se ve
# TRABAJANDO. Cuesta lo mismo que el trabajo de verdad, ocupa la maquina, y
# encima no aparece en ninguna lista de ociosos.
#
# Y no es maldad del agente: es lo que hace cualquiera cuando no sabe que sigue.
# Un item mal escrito o ya terminado produce esto de forma casi automatica.
#
# ## Como se detecta, que es la parte que importa
#
# **Por salida, nunca por actividad.** El estado del panel miente: dice
# "working" tanto cuando escribe codigo como cuando mira el mismo error por
# quinta vez. Lo que no miente es si los archivos de su zona cambiaron.
#
#   panel ocupado + su zona sin cambiar hace rato  ->  teatro
#   panel ocupado + su zona cambiando              ->  trabajo
#
# Un panel puede estar legitimamente leyendo o pensando: por eso la ventana es
# generosa. Lo que se persigue no es el minuto quieto, es la media hora sin una
# linea escrita.
#
#   teatro.sh            informar
#   teatro.sh --actuar   informar y sacudir al que lleva demasiado
set -euo pipefail
cd "$(dirname "$0")/.."
VENTANA_MIN="${TEATRO_VENTANA:-25}"   # minutos sin tocar un archivo = sospecha

# Cuanto se produjo en la ventana. La verdad la dice git, no el reloj del
# disco.
#
# La primera version media con `find -newermt` y eso funciona en un disco comun
# y MIENTE en otros: sobre un montaje ntfs3 devuelve cero archivos mientras
# `git log` muestra veinte commits en la misma ventana. Un detector que mide con
# una regla rota reporta teatro en TODA la flota y manda a rescatar paneles que
# estaban trabajando — que es peor que no tener detector, porque interrumpe a
# los que producen.
#
# Por eso git primero, y el reloj del disco solo como respaldo cuando no hay
# repositorio.
produccion() {
  if git rev-parse --git-dir >/dev/null 2>&1; then
    local c a
    c=$(git log --since="${VENTANA_MIN} minutes ago" --oneline 2>/dev/null | wc -l)
    a=$(git status --porcelain 2>/dev/null | wc -l)
    echo $(( c + a ))
  else
    find . -type f \
      \( -name '*.rs' -o -name '*.ts' -o -name '*.tsx' -o -name '*.sql' -o -name '*.md' -o -name '*.sh' -o -name '*.py' \) \
      -not -path './.git/*' -not -path '*/node_modules/*' -not -path '*/target/*' \
      -newermt "-${VENTANA_MIN} minutes" 2>/dev/null | wc -l
  fi
}

sospechosos=(); ok=()
while read -r nombre pane kind estado resto; do
  [ "$kind" = opencode ] || continue
  [ "$estado" = working ] || continue
  # Un panel que trabaja mientras el arbol entero no cambia hace media hora es
  # el sintoma; con varios paneles no se puede atribuir a uno solo sin mirar su
  # zona, asi que el informe apunta al conjunto y el humano decide.
  ok+=("$nombre")
done < <(latigo roster 2>/dev/null)

cambios=$(produccion)
echo "paneles trabajando: ${#ok[@]}"
echo "commits + archivos sin commitear en los ultimos ${VENTANA_MIN} min: $cambios"

# ── Autocontrol: el instrumento se mide a si mismo ──────────────────────────
#
# Un detector que dice que TODOS estan haciendo teatro mientras el repo
# commitea no descubrio una flota vaga: se rompio el. Y como el sintoma de un
# instrumento roto se ve identico al del problema que busca, sin este control
# la unica forma de enterarse es que alguien mire y sospeche.
#
# Mayoria y no unanimidad, a proposito: la primera prueba con el instrumento
# roto a proposito marco 14 de 24 con 23 commits en la ventana, y eso ya es
# imposible. Pidiendo unanimidad, ese caso pasaba.
if [ "${#ok[@]}" -gt 0 ] && [ "$cambios" -gt 0 ]; then
  : # hay produccion y hay paneles: todo normal, no hay nada que revisar
fi
if [ "${#ok[@]}" -ge 3 ] && [ "$cambios" -ge 3 ]; then
  echo
  echo "(control: ${#ok[@]} paneles ocupados y $cambios de produccion — coherente)"
fi

if [ "${#ok[@]}" -gt 0 ] && [ "$cambios" -eq 0 ]; then
  echo
  echo "SOSPECHA DE TEATRO: ${#ok[@]} paneles dicen estar trabajando y en"
  echo "${VENTANA_MIN} minutos no se produjo nada: ni un commit ni un archivo modificado."
  echo "Causas tipicas, en orden: items ya terminados que nadie cerro, items mal"
  echo "escritos que no se pueden hacer, o agentes compilando en circulos."
  # ── El autocontrol necesita un SEGUNDO instrumento, no el mismo ──────────
  #
  # La primera version se controlaba con su propia medicion: "si marco a todos
  # PERO veo produccion, el roto soy yo". Lo probe rompiendola a proposito y no
  # sirvio — porque cuando la medicion se rompe devuelve CERO, y con cero el
  # control nunca se dispara. Un instrumento no puede auditarse con el mismo
  # sensor que se le rompio.
  #
  # Hace falta una segunda medicion que falle DISTINTO. git y el reloj del
  # disco se rompen por motivos que no se solapan: git falla si no hay repo o
  # el rango esta mal; los mtimes fallan en ciertos montajes. Que las dos den
  # cero a la vez es raro; que una de las dos vea algo mientras la otra no,
  # significa que la que no ve esta rota.
  segunda=""
  segunda=$(find crates web/src desktop/src docs scripts -type f \
              \( -name '*.rs' -o -name '*.ts' -o -name '*.tsx' -o -name '*.md' -o -name '*.sh' \) \
              -newermt "-${VENTANA_MIN} minutes" 2>/dev/null | wc -l)
  if [ "$cambios" -gt 0 ] || [ "${segunda:-0}" -gt 0 ]; then
    echo
    echo "NO ME CREAS — marco ${#ok[@]} paneles como teatro, pero la segunda"
    echo "medicion ve $segunda archivos tocados (la primera vio $cambios)."
    echo "Cuando las dos no coinciden, el roto es el instrumento y no la flota."
    echo "Revisa como mido antes de ir a sacudir a nadie."
    exit 2
  fi
  if [ "${1:-}" = --actuar ]; then
    for a in "${ok[@]}"; do
      latigo send "$a" "Pregunta directa: en los ultimos ${VENTANA_MIN} minutos no se produjo nada en el repo —ni un commit ni un archivo modificado— y tu panel figura trabajando.

Si tu item ya esta hecho, cerralo: latigo board done <id>
Si tu item esta mal escrito o no se puede hacer, decilo y soltalo: latigo board release <id>
Si estas compilando o corriendo tests en circulos, pará. Una compilacion no es progreso y una corrida de tests tampoco. Nadie paga por ejercitar un compilador.
Si de verdad no tenes nada, decilo en una linea. Es una respuesta valida.

Lo que no sirve es seguir pareciendo ocupado." >/dev/null 2>&1 || true
    done
    echo "sacudidos: ${#ok[@]}"
  fi
elif [ "${#ok[@]}" -eq 0 ]; then
  # Cero paneles ocupados no es una flota sana: es que no vi ninguno. Puede ser
  # verdad (todos libres) o puede ser que el roster no contesto. Se dicen las
  # dos, porque "sin sospecha" aca seria mentir con la misma frase que se usa
  # cuando todo anda — que es el error que este script existe para no cometer.
  if [ "$cambios" -eq 0 ]; then
    echo
    echo "NO PUEDO MEDIR — cero paneles ocupados y cero produccion."
    echo "O la flota esta entera libre, o no estoy viendo nada. Verificá con"
    echo "'latigo roster' antes de sacar conclusiones: un instrumento que no ve"
    echo "nada se parece demasiado a un mundo donde no pasa nada."
    exit 3
  fi
  echo "sin paneles ocupados, pero hay produccion ($cambios) — alguien commiteo y solto"
else
  echo "sin sospecha: $cambios de produccion con ${#ok[@]} paneles ocupados"
fi
