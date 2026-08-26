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

# Ultimo cambio real en el arbol, en minutos. Se ignora lo generado.
edad_ultimo_cambio() {
  local m
  m=$(find crates web/src desktop/src migrations docs scripts -type f \
        \( -name '*.rs' -o -name '*.ts' -o -name '*.tsx' -o -name '*.sql' -o -name '*.md' -o -name '*.sh' \) \
        -newermt "-${VENTANA_MIN} minutes" 2>/dev/null | wc -l)
  echo "$m"
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

cambios=$(edad_ultimo_cambio)
echo "paneles trabajando: ${#ok[@]}"
echo "archivos tocados en los ultimos ${VENTANA_MIN} min: $cambios"

if [ "${#ok[@]}" -gt 0 ] && [ "$cambios" -eq 0 ]; then
  echo
  echo "SOSPECHA DE TEATRO: ${#ok[@]} paneles dicen estar trabajando y en"
  echo "${VENTANA_MIN} minutos no cambio un solo archivo del proyecto."
  echo "Causas tipicas, en orden: items ya terminados que nadie cerro, items mal"
  echo "escritos que no se pueden hacer, o agentes compilando en circulos."
  if [ "${1:-}" = --actuar ]; then
    for a in "${ok[@]}"; do
      latigo send "$a" "Pregunta directa: en los ultimos ${VENTANA_MIN} minutos no cambio un solo archivo del proyecto y tu panel figura trabajando.

Si tu item ya esta hecho, cerralo: latigo board done <id>
Si tu item esta mal escrito o no se puede hacer, decilo y soltalo: latigo board release <id>
Si estas compilando o corriendo tests en circulos, pará. Una compilacion no es progreso y una corrida de tests tampoco. Nadie paga por ejercitar un compilador.
Si de verdad no tenes nada, decilo en una linea. Es una respuesta valida.

Lo que no sirve es seguir pareciendo ocupado." >/dev/null 2>&1 || true
    done
    echo "sacudidos: ${#ok[@]}"
  fi
else
  echo "sin sospecha: hay produccion"
fi
