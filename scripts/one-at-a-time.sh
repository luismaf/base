#!/usr/bin/env bash
# one-at-a-time.sh - a global turn-taking gate for the whole fleet.
#
# ## Why this exists
#
# Twelve opencode panels share ONE working tree and ONE machine. Measured on
# 2026-08-24 while they were all busy:
#
#     total 62Gi | used 57Gi | available 5.2Gi | swap 15Gi of 15Gi USED
#     load average: 12.47
#
# Swap completely full, five gigabytes of headroom, and each panel about to
# decide on its own that now is a good time to run `cargo build`. One rustc
# link step is several gigabytes. Two at once on this machine is not slow, it
# is a freeze - and the owner is the one sitting in front of it.
#
# The same applies to commits for a different reason: all twelve panels commit
# into the SAME worktree. Concurrent `git commit` fights over `.git/index.lock`,
# and the loser either fails or - worse - commits a half-staged index that
# includes somebody else's in-flight files. That has already happened here;
# it is why commits keep showing up carrying another panel's WIP.
#
# ## Use
#
#     bash scripts/one-at-a-time.sh build  cargo check -p app-api
#     bash scripts/one-at-a-time.sh commit git commit -m "..."
#
# Lanes are independent: a commit does not wait behind a build. Within a lane
# it is strictly first-come-first-served, and waiting is the CORRECT outcome -
# a panel that waits 90 seconds costs nothing, a machine that swaps to death
# costs the afternoon.
#
# ## The memory guard
#
# The `build` lane additionally refuses to start while available memory is
# under the floor, even if the lock is free - because the memory pressure may
# come from something this script does not manage (the browser, the emulator,
# a Tauri build somebody started by hand). It waits, it does not kill.
set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOCKDIR="$RAIZ/.tmp"
mkdir -p "$LOCKDIR"

LANE="${1:?usage: one-at-a-time.sh <build|commit|lane-name> <command...>}"; shift
[ $# -gt 0 ] || { echo "one-at-a-time: no command given" >&2; exit 64; }

LOCK="$LOCKDIR/lane-$LANE.lock"
WAIT_MAX="${ONE_AT_A_TIME_WAIT:-1800}"     # seconds to wait for the turn
# The floor is a SECOND safety net, not the main one - the lock already
# guarantees a single build. It exists for pressure this script does not
# manage (the browser, the emulator, a Tauri build started by hand).
#
# Set from what the machine actually looks like, measured 2026-08-24 with all
# twelve panels up: 3.0 GB available, 900 MB free, swap 15/15 GB used. A floor
# of 6 GB on a box that idles at 3 GB does not protect anything - it just means
# nothing ever compiles and the whole fleet deadlocks waiting. 2.5 GB plus
# CARGO_BUILD_JOBS=4 plus strict serialisation is the combination that keeps
# the machine alive AND the work moving.
#
# The real problem is upstream and it is not solvable here: twelve opencode
# processes at ~1.6 GB each is ~19 GB before a single line is compiled. See
# INFRA-07 on the board - how many panels this machine actually sustains.
RAM_FLOOR_MB="${ONE_AT_A_TIME_RAM_MB:-2500}"
RAM_WAIT_MAX="${ONE_AT_A_TIME_RAM_WAIT:-900}"

# Re-entrancy: a script already holding this lane must not deadlock against
# itself when it calls a wrapped helper.
guard_var="ONE_AT_A_TIME_HELD_${LANE//[^A-Za-z0-9]/_}"
if [ "${!guard_var:-0}" = "1" ]; then
    exec "$@"
fi

available_mb() { awk '/^MemAvailable:/ {print int($2/1024)}' /proc/meminfo; }
swap_free_mb() { awk '/^SwapFree:/ {print int($2/1024)}' /proc/meminfo; }

# El comando se recorta: un `git commit -m "<treinta lineas>"` volcaba el
# mensaje entero al log y lo volvia ilegible.
log() { printf '%s one-at-a-time[%s] %s\n' "$(date '+%F %T')" "$LANE" "$(printf '%s' "$*" | tr '\n' ' ' | cut -c1-120)" >> "$RAIZ/.logs/one-at-a-time.log"; }

# ── ESPERAR LA MEMORIA **ANTES** DEL CANDADO ────────────────────────────────
# La primera version esperaba RAM CON EL CANDADO YA TOMADO. Eso convierte al
# que espera en un tapon: se queda quince minutos sin compilar nada y con el
# carril agarrado, y los otros once hacen cola detras de alguien que no esta
# haciendo absolutamente nada. Pasó a los diez minutos de existir el script —
# PID 964957, 281 segundos con el candado, cero procesos de cargo en la
# maquina, y otro panel encolado atras. Cambie un cuelgue por otro.
#
# Ahora la espera por memoria ocurre AFUERA del candado. El que no tiene aire
# espera solo, sin tapar a nadie, y recien cuando hay memoria pide el turno.
espera_memoria() {
    local waited=0
    while [ "$(available_mb)" -lt "$RAM_FLOOR_MB" ]; do
        if [ "$waited" -ge "$RAM_WAIT_MAX" ]; then
            echo "one-at-a-time: only $(available_mb)MB available (floor ${RAM_FLOOR_MB}MB) after ${waited}s - not starting." >&2
            log "ABORT low memory: $(available_mb)MB avail, $(swap_free_mb)MB swap free"
            return 1
        fi
        [ "$waited" = 0 ] && echo "one-at-a-time: waiting for memory ($(available_mb)MB available, need ${RAM_FLOOR_MB}MB)..." >&2
        sleep 15; waited=$((waited + 15))
    done
    return 0
}

if [ "$LANE" = "build" ]; then
    espera_memoria || exit 75
fi

exec 9>"$LOCK"
if ! flock -w "$WAIT_MAX" 9; then
    echo "one-at-a-time: lane '$LANE' still busy after ${WAIT_MAX}s - not starting." >&2
    log "TIMEOUT waiting for lane (pid $$)"
    exit 75   # EX_TEMPFAIL: try again, do not treat as a code error
fi

if [ "$LANE" = "build" ]; then
    # Segundo vistazo, ya con el turno en la mano: entre la espera y el
    # candado pudo entrar otra cosa que se comio el aire. Una sola pasada
    # corta — si no hay memoria, se suelta el turno y se reintenta despues,
    # que es exactamente lo contrario de quedarse tapando la fila.
    if [ "$(available_mb)" -lt "$RAM_FLOOR_MB" ]; then
        echo "one-at-a-time: memory dropped to $(available_mb)MB while waiting for the turn - releasing it, try again." >&2
        log "RELEASE turn, memory dropped to $(available_mb)MB"
        exit 75
    fi
    # Techo al build. Cargo sin limite lanza un rustc por core y cada uno es
    # caro; en una maquina asi de cargada, eso ES el problema.
    export CARGO_BUILD_JOBS="${CARGO_BUILD_JOBS:-4}"
fi

export "$guard_var=1"
log "START (pid $$, ${available_mb:+}$(available_mb)MB avail): $*"
"$@"
rc=$?
log "END rc=$rc: $*"
exit $rc
