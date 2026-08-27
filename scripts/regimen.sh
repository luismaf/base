#!/usr/bin/env bash
# regimen.sh - ¿el modelo que usa la flota es gratis o se paga?
#
# De esto depende cómo se trabaja, y hasta hoy dependía de que alguien se
# acordara de cambiarlo a mano — o sea, de nada.
#
#   GRATIS  el único límite es la RAM. Nunca ocioso: si el proyecto se quedó
#           sin trabajo, se genera trabajo de negocio y hasta se le pide
#           prestado al vecino. Un panel esperando es capacidad tirada.
#
#   PAGO    cada pedido sale plata. Un proyecto que terminó DETIENE sus devs,
#           y eso es un resultado, no una falla. No se inventa trabajo, no se
#           le pide prestado a nadie, y el látigo insiste menos.
#
# Cómo se decide, en orden:
#
#   1. REGIMEN forzado por entorno, para poder probar sin tocar la config.
#   2. El proveedor del modelo configurado:
#        opencode-go/*  -> ocmix, que rutea a cuentas propias  -> PAGO
#        */*-free       -> el pozo gratuito del proveedor       -> GRATIS
#        el resto       -> PAGO, porque ante la duda se gasta menos.
#
# El default ante la duda es PAGO a propósito. Equivocarse hacia GRATIS
# gasta plata que nadie autorizó; equivocarse hacia PAGO sólo deja un panel
# quieto, que es reversible y visible.
set -u

CONF="${OPENCODE_CONF:-$HOME/.config/opencode/opencode.jsonc}"

modelo_actual() {
  [ -r "$CONF" ] || return 1
  # El .jsonc tiene comentarios, así que no se parsea como JSON puro: se busca
  # la primera línea "model" que NO esté comentada.
  grep -E '^[[:space:]]*"model"[[:space:]]*:' "$CONF" 2>/dev/null \
    | grep -v '^[[:space:]]*//' \
    | head -1 \
    | sed -E 's/.*"model"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/'
}

INTERRUPTOR="${FLOTA_MODO_FILE:-$HOME/.config/flota/modo}"

regimen() {
  # Prioridad: env explicito > interruptor en disco > heuristica -free > PAGO.
  # PAGO POR DEFECTO (dueño, 2026-08-27): sin señal explicita el regimen es
  # pago. La heuristica por nombre queda SOLO para detectar gratis (sufijo
  # -free); modelo desconocido o config ilegible = pago. Equivocarse hacia
  # gratis regala saludos de aceite y trabajo inventado con plata.
  case "${FLOTA_MODO:-${REGIMEN:-}}" in gratis|pago) echo "${FLOTA_MODO:-$REGIMEN}"; return 0 ;; esac
  if [ -r "$INTERRUPTOR" ]; then
    case "$(tr -d '[:space:]' < "$INTERRUPTOR")" in
      gratis) echo gratis; return 0 ;;
      pago)   echo pago;   return 0 ;;
    esac
  fi
  local m; m="$(modelo_actual)"
  case "$m" in *-free) echo gratis ;; *) echo pago ;; esac
}

case "${1:-}" in
  --modelo) modelo_actual ;;
  --gratis) [ "$(regimen)" = gratis ] ;;
  --pago)   [ "$(regimen)" = pago ] ;;
  --ver)    printf 'modelo: %s\nregimen: %s\n' "$(modelo_actual || echo '(no pude leerlo)')" "$(regimen)" ;;
  *)        regimen ;;
esac
