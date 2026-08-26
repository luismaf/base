#!/usr/bin/env bash
# herdr-entorno.sh - hace que la maquinaria vea la flota desde fuera de un panel.
#
# ## Por que existe
#
# `latigo` solo funciona dentro de una sesion de Herdr: fuera, contesta
# "not inside a Herdr session (HERDR_ENV != 1)". Los bucles corren bajo systemd,
# que no hereda ese entorno, y todas las llamadas iban con `2>/dev/null || true`.
# Resultado: tres servicios en verde, `is-active` diciendo `active`, y los tres
# girando en el vacio sin ver un solo panel.
#
# Peor todavia, el vacio se leia como calma: `latigo roster | wc -l` daba 0
# obreros, y con cero obreros la condicion "hay menos items que gente" es falsa,
# asi que el jefe concluia que no habia urgencia de reponer. La flota entera
# parada, y el reloj que existe para evitarlo confirmando que todo estaba bien.
#
#   herdr-entorno.sh --guardar   desde DENTRO de un panel, persiste el entorno
#   . herdr-entorno.sh           desde un bucle, lo carga (o falla ruidosamente)
set -uo pipefail
ARCHIVO="${HERDR_ENV_FILE:-$HOME/.config/herdr.env}"

if [ "${1:-}" = --guardar ]; then
  [ "${HERDR_ENV:-0}" = 1 ] || { echo "herdr-entorno: no estoy dentro de una sesion Herdr, no hay nada que guardar" >&2; exit 1; }
  mkdir -p "$(dirname "$ARCHIVO")"
  # PANE_ID y TAB_ID no van: son del panel que guarda, y un bucle que los
  # heredara creeria estar parado donde no esta.
  env | grep -E '^HERDR_(ENV|SOCKET_PATH|BIN_PATH|WORKSPACE_ID)=' > "$ARCHIVO"
  echo "XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}" >> "$ARCHIVO"
  chmod 600 "$ARCHIVO"
  echo "herdr-entorno: guardado en $ARCHIVO ($(wc -l < "$ARCHIVO") variables)"
  exit 0
fi

# Modo carga. Se usa con `.` desde los bucles.
if [ "${HERDR_ENV:-0}" != 1 ] && [ -r "$ARCHIVO" ]; then
  set -a; . "$ARCHIVO"; set +a
fi

# Y el control que faltaba: comprobar que DE VERDAD vemos la flota. No alcanza
# con que las variables esten: el socket puede haber cambiado si Herdr
# reinicio. Un bucle que no ve paneles no debe seguir como si nada — tiene que
# fallar ruidosamente, porque su silencio es indistinguible del exito.
herdr_ve_la_flota() {
  local n
  n=$(latigo roster 2>/dev/null | grep -c 'opencode' || true)
  [ "${n:-0}" -gt 0 ]
}
