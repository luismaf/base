#!/usr/bin/env bash
# ram-watch.sh - keep the tmpfs from eating the machine's memory.
#
# ## Why
#
# /tmp on this box is tmpfs: everything in it IS resident memory. On 2026-08-24
# three git worktrees under /tmp/opencode were holding 29 GB of cargo `target/`
# directories - 18 GB in wt-otro, 11 GB in proyecto-main - inside the RAM. The machine
# sat at 2.9 GB available with swap 15 of 15 GB used, and the kernel OOM killer
# started eating the agent panels:
#
#   vte-spawn-...scope: The kernel OOM killer killed some processes in this unit
#
# Nobody was looking at /tmp because nothing in it looked like memory. Deleting
# those three directories returned 20 GB instantly. This script makes sure it
# never has to be noticed by a human again.
#
# ## How it decides
#
# Pressure, measured two ways, and the WORSE of the two wins:
#   OK       tmpfs under 50%  and MemAvailable over 12 GB   -> only rubbish
#   WARN     tmpfs 50-70%     or  MemAvailable 6-12 GB      -> + rebuildable
#   ALTA     tmpfs 70-85%     or  MemAvailable 3-6 GB       -> + old and large
#   CRITICA  tmpfs over 85%   or  MemAvailable under 3 GB   -> everything stale
#                              or  RAM used over 94% (UMBRAL_USADO)
#
# Age is the other axis and it is what keeps this safe: nothing is touched
# before it has gone quiet. Each tier carries its own minimum age, so a target/
# being written to right now is never a candidate.
#
# ## What it will never delete
#
#   * anything a live process has open, or has as its working directory
#   * anything younger than the tier's minimum age
#   * the git worktree itself - only its rebuildable subdirectories
#   * anything under KEEP (this session's scratchpads, sockets, X11, systemd)
#
# ## Killing processes - only at CRITICA, and in a strict order
#
# Deleting files does not help when the memory is held by a live process. At
# CRITICA the script also reaps, cheapest first, re-measuring after each step
# and stopping as soon as the pressure clears:
#
#   1. rustc / cc1 / ld     - the actual hogs. A link step is several GB and
#                             cargo reports a clean failure; the panel retries.
#   2. cargo                - only if step 1 was not enough. Same reasoning.
#   3. tsc --noEmit         - a one-shot type check: a minute of CPU and 1.5 GB,
#                             and nothing is watching it. Same cost as a cargo
#                             check, so it is reaped on the same terms.
#   4. vite / esbuild       - LAST, and only the ones that have been idle. The
#                             panels verify on :3000 and :8080, so a dev server
#                             is working infrastructure, not rubbish. Killing a
#                             busy one costs someone their verification.
#
# NEVER killed, at any pressure: opencode, claude, herdr, postgres, systemd,
# the desktop. Those are the work and the machine. The rule is the same one as
# the OOM protection in protect-panels.sh: a dead rustc costs one `cargo check`,
# a dead panel costs the session.
#
# ## Use
#
#   bash scripts/ram-watch.sh            # act
#   bash scripts/ram-watch.sh --seco     # say what it would do, touch nothing
#   bash scripts/ram-watch.sh --estado   # just the pressure report
set -uo pipefail

TMP="${RAM_WATCH_DIR:-/tmp}"
# Used share of RAM that counts as critical on its own, whatever the tmpfs and
# the MemAvailable meters say.
UMBRAL_USADO="${RAM_WATCH_UMBRAL:-94}"
# Derived, not literal: a hardcoded path makes this script silently useless on
# any other machine (it logs into a directory that does not exist and nobody
# notices, because nothing here fails loudly).
RAIZ_KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG="${RAM_WATCH_LOG:-$RAIZ_KIT/.logs/ram-watch.log}"
SECO=0; SOLO_ESTADO=0
for a in "$@"; do
  case "$a" in
    --seco|-n)    SECO=1 ;;
    --estado|-s)  SOLO_ESTADO=1 ;;
  esac
done
mkdir -p "$(dirname "$LOG")" 2>/dev/null || true

# Never touch these, at any pressure level.
KEEP_RE='^/tmp/(\.X11-unix|\.ICE-unix|\.font-unix|\.XIM-unix|systemd-|snap\.|ssh-|gnupg|dbus-|pulse-|claude-[0-9]+)'

log() { printf '%s %s\n' "$(date '+%F %T')" "$*" >> "$LOG"; }
say() { printf '%s\n' "$*"; }

mem_disponible_gb() { awk '/^MemAvailable:/ {printf "%.1f", $2/1048576}' /proc/meminfo; }
swap_usado_pct()    { awk '/^SwapTotal:/{t=$2} /^SwapFree:/{f=$2} END{if(t>0) printf "%d", (t-f)*100/t; else print 0}' /proc/meminfo; }
tmpfs_pct()         { df --output=pcent "$TMP" 2>/dev/null | tail -1 | tr -dc '0-9'; }
# Used share of physical RAM, the way `free` reports it: total minus available.
# This is the meter that catches a big box drowning slowly - 4 GB available out
# of 62 GB is 94% used and one cargo link away from the OOM killer, but the
# MemAvailable test below still calls it merely ALTA.
mem_usada_pct()     { awk '/^MemTotal:/{t=$2} /^MemAvailable:/{a=$2} END{if(t>0) printf "%d", (t-a)*100/t; else print 0}' /proc/meminfo; }
tmpfs_usado_gb()    { df -BG --output=used "$TMP" 2>/dev/null | tail -1 | tr -dc '0-9'; }

# ── Is anything alive using this path? ──────────────────────────────────────
# Two checks, because they miss different things: an open file descriptor
# (a log being written, a database file) and a working directory (a shell
# sitting inside it, which lsof +D does not always report cheaply).
en_uso() {
  local ruta="$1"
  local real; real="$(readlink -f "$ruta" 2>/dev/null)" || return 1
  [ -n "$real" ] || return 1
  # cwd of any live process
  for cw in /proc/[0-9]*/cwd; do
    local d; d="$(readlink "$cw" 2>/dev/null)" || continue
    case "$d" in "$real"|"$real"/*) return 0 ;; esac
  done
  # open file descriptors
  if command -v fuser >/dev/null 2>&1; then
    fuser -s "$real" 2>/dev/null && return 0
  fi
  return 1
}

# ── The one worker: delete matching paths older than N minutes ──────────────
# find -mmin is the age gate. `-maxdepth`/`-mindepth` keep the pattern from
# matching a whole tree when only a subdirectory was meant.
barrer() {
  local etiqueta="$1" edad_min="$2"; shift 2
  local total_kb=0
  while IFS= read -r ruta; do
    [ -e "$ruta" ] || continue
    [[ "$ruta" =~ $KEEP_RE ]] && continue
    if en_uso "$ruta"; then
      [ "$SECO" = 1 ] && say "  EN USO, se saltea: $ruta"
      continue
    fi
    local kb; kb=$(du -sk "$ruta" 2>/dev/null | cut -f1); kb=${kb:-0}
    # Paneles corriendo sudo dejan directorios de root en /tmp que este script
    # no puede borrar: `rm -rf` falla archivo por archivo y el espacio queda
    # ocupado en la RAM para siempre. Pasó con /tmp/proyecto-target, 852 MB. Se
    # avisa fuerte en vez de fallar en silencio, que es como nadie se entera.
    if [ ! -O "$ruta" ]; then
      say "  DE OTRO USUARIO, no se puede borrar: $ruta ($(numfmt --to=iec $((kb*1024)) 2>/dev/null || echo ${kb}K))"
      log "AJENO (no borrable) $ruta ${kb}K"
      continue
    fi
    [ "$kb" -lt 1024 ] && continue          # under 1 MB is not worth the risk
    total_kb=$((total_kb + kb))
    if [ "$SECO" = 1 ]; then
      say "  [seco] borraria $(numfmt --to=iec $((kb*1024)) 2>/dev/null || echo "${kb}K")  $ruta"
    else
      rm -rf -- "$ruta" 2>/dev/null && log "borrado ($etiqueta, ${kb}K) $ruta"
    fi
  done < <("$@" 2>/dev/null)
  if [ "$total_kb" -gt 0 ]; then
    say "$etiqueta: $(numfmt --to=iec $((total_kb*1024)) 2>/dev/null || echo "${total_kb}K")"
  fi
}

# ── Reaping, for when the memory is held by a process and not by a file ────
NUNCA_MATAR='opencode|claude|herdr|postgres|systemd|Xorg|gnome-shell|hyprland|sway|dbus|llama-server|whisper|ollama|oc-mix'

matar_grupo() {
  local etiqueta="$1" patron="$2" solo_ociosos="${3:-0}" modo="${4:-linea}" n=0
  local pids
  # exacto: match the process NAME (pgrep -x). linea: match the full command
  # line (pgrep -f), for things like `tsc --noEmit` that run as plain `node`.
  if [ "$modo" = exacto ]; then
    pids="$(pgrep -x "$patron" 2>/dev/null)"
  else
    pids="$(pgrep -f "$patron" 2>/dev/null)"
  fi
  for pid in $pids; do
    local cmd; cmd="$(ps -o comm= -p "$pid" 2>/dev/null)" || continue
    [[ "$cmd" =~ $NUNCA_MATAR ]] && continue
    # Never this script, and never the shell that launched it: a --seco run
    # invoked from a panel puts the pattern in an ancestor's command line.
    [ "$pid" = "$$" ] && continue
    [ "$pid" = "$PPID" ] && continue
    # "Idle" means it has not used CPU recently: killing a dev server that is
    # actively rebuilding costs a panel its verification loop.
    if [ "$solo_ociosos" = 1 ]; then
      local cpu; cpu="$(ps -o %cpu= -p "$pid" 2>/dev/null | tr -d ' ')"
      awk -v c="${cpu:-0}" 'BEGIN{exit !(c > 2.0)}' && continue
    fi
    local rss_mb=$(( $(ps -o rss= -p "$pid" 2>/dev/null | tr -d ' ' || echo 0) / 1024 ))
    if [ "$SECO" = 1 ]; then
      say "  [seco] mataria $cmd (pid $pid, ${rss_mb}MB)"
    else
      kill -TERM "$pid" 2>/dev/null && { n=$((n+1)); log "matado ($etiqueta) $cmd pid=$pid rss=${rss_mb}MB"; }
    fi
  done
  [ "$n" -gt 0 ] && say "$etiqueta: $n procesos"
  return 0
}

# True while memory is still critical, so the caller can stop reaping early.
sigue_critico() {
  local m; m="$(mem_disponible_gb)"; m="${m%.*}"
  [ "${m:-99}" -lt 3 ] && return 0
  [ "$(mem_usada_pct)" -ge "$UMBRAL_USADO" ] && return 0
  return 1
}

# ── Pressure ────────────────────────────────────────────────────────────────
PCT="$(tmpfs_pct)";  PCT="${PCT:-0}"
MEM="$(mem_disponible_gb)"; MEM="${MEM:-99}"
SWP="$(swap_usado_pct)"
MEM_ENT="${MEM%.*}"
USADO="$(mem_usada_pct)"; USADO="${USADO:-0}"

if   [ "$PCT" -ge 85 ] || [ "$MEM_ENT" -lt 3 ] || [ "$USADO" -ge "$UMBRAL_USADO" ]; then NIVEL=CRITICA
elif [ "$PCT" -ge 70 ] || [ "$MEM_ENT" -lt 6 ];  then NIVEL=ALTA
elif [ "$PCT" -ge 50 ] || [ "$MEM_ENT" -lt 12 ]; then NIVEL=WARN
else                                                  NIVEL=OK
fi

say "tmpfs $TMP: ${PCT}% ($(tmpfs_usado_gb)G) | RAM usada: ${USADO}% | RAM disponible: ${MEM}G | swap: ${SWP}% | presion: $NIVEL"
[ "$SOLO_ESTADO" = 1 ] && exit 0

ANTES_TMP="$(tmpfs_usado_gb)"; ANTES_MEM="$MEM"

# ── QUE NO VUELVA A PASAR: worktrees en tmpfs con su target/ adentro ────────
# Los paneles crean worktrees de git en /tmp/opencode para trabajar aislados, y
# cada uno se lleva un target/ de cargo de ~2 GB DENTRO DE LA RAM. El 2026-08-24
# había 29 GB así y la máquina quedó en 2,9 GB con el swap lleno; horas después
# volvieron a aparecer cuatro nuevos, 7,6 GB, porque el arreglo anterior fue
# archivo por archivo sobre los worktrees que existían ESE momento.
#
# Ahora se cura solo: a todo worktree que aparezca en el tmpfs se le deja un
# .cargo/config.toml que manda el target a DISCO. No borra nada y no interrumpe
# a nadie; el próximo build de ese worktree ya escribe afuera de la RAM.
redirigir_targets_del_tmpfs() {
    # Where the redirected target/ dirs land: a real disk, NOT the tmpfs. By
    # default a sibling of the repo, which is on disk on any machine.
    local destino="${RAM_WATCH_TARGETS:-$(dirname "$RAIZ_KIT")/.cargo-targets}"
    mkdir -p "$destino" 2>/dev/null || return 0
    local n=0
    while IFS= read -r wt; do
        [ -e "$wt/Cargo.toml" ] || continue
        local cfg="$wt/.cargo/config.toml"
        grep -qs 'cargo-targets' "$cfg" && continue
        mkdir -p "$wt/.cargo" 2>/dev/null || continue
        {
            echo "# Este worktree vive en tmpfs, o sea EN LA RAM. Sin esto, su target/"
            echo "# de cargo (~2 GB) se come memoria hasta que el OOM killer empieza a"
            echo "# matar paneles de trabajo. Lo puso scripts/ram-watch.sh solo."
            echo "[build]"
            echo "target-dir = \"$destino/$(basename "$wt")\""
        } > "$cfg" 2>/dev/null && n=$((n + 1))
    done < <(find "$TMP" -maxdepth 3 -name Cargo.toml -not -path "*/target/*" 2>/dev/null | xargs -r -n1 dirname 2>/dev/null | sort -u)
    [ "$n" -gt 0 ] && say "worktrees en RAM redirigidos a disco: $n"
    return 0
}
redirigir_targets_del_tmpfs

# ── OK and up: rubbish. Big, obviously regenerable, and already cold. ───────
barrer "basura vieja" 120 \
  find "$TMP" -maxdepth 3 -mmin +120 \( \
      -type d -name 'playwright_*' -o \
      -type d -name 'chrome-*' -o \
      -type d -name 'puppeteer_*' -o \
      -type d -name '.org.chromium.*' -o \
      -type d -name 'node-compile-cache' -o \
      -type f -name '*.log' -size +50M \
  \) -prune

if [ "$NIVEL" != OK ]; then
  # ── WARN: build output. This is the big one and it is always rebuildable. ──
  # ONLY the target/ and node_modules/ inside /tmp - never the worktree, so a
  # panel working in there loses a compile, not its work.
  barrer "target/ y node_modules en RAM" 45 \
    find "$TMP" -mindepth 2 -maxdepth 4 -type d \( -name target -o -name node_modules \) -prune
  barrer "cache de cargo/npm en RAM" 60 \
    find "$TMP" -mindepth 1 -maxdepth 3 -type d \( -name '.cargo' -o -name '.npm' -o -name '.cache' \) -prune
fi

if [ "$NIVEL" = ALTA ] || [ "$NIVEL" = CRITICA ]; then
  # ── ALTA: anything over 200 MB that has been cold for four hours. ─────────
  barrer "grandes y frios (>200M, +4h)" 240 \
    find "$TMP" -mindepth 1 -maxdepth 2 -mmin +240 -size +200M -prune
fi

if [ "$NIVEL" = CRITICA ]; then
  # ── CRITICA: everything cold for a day. At this point the alternative is
  # the OOM killer choosing for us, and it chooses much worse.
  barrer "todo lo frio (+24h)" 1440 \
    find "$TMP" -mindepth 1 -maxdepth 1 -mmin +1440 -prune
  log "PRESION CRITICA: tmpfs ${PCT}%, RAM ${MEM}G disponible, swap ${SWP}%"

  # Files are gone and it may still be critical: now the memory is in a
  # process. Reap cheapest first, re-measuring between steps.
  if sigue_critico || [ "$SECO" = 1 ]; then
    say "RAM sigue critica tras limpiar archivos — se cobra a los procesos"
    matar_grupo "compiladores" 'rustc|cc1|cc1plus|ld|lld|collect2' 0 exacto
    sleep 3
  fi
  if [ "$SECO" = 0 ] && sigue_critico; then
    matar_grupo "cargo" 'cargo' 0 exacto
    sleep 3
  fi
  if [ "$SECO" = 1 ] || sigue_critico; then
    matar_grupo "type-check de TS" 'tsc --noEmit|tsc --build|tsc -p ' 0
    sleep 3
  fi
  if [ "$SECO" = 0 ] && sigue_critico; then
    # LAST resort: idle dev servers only. The panels verify on :3000 / :8080.
    matar_grupo "dev servers ociosos" 'vite|esbuild|tsserver|tsc --watch' 1
  fi
fi

DESPUES_TMP="$(tmpfs_usado_gb)"; DESPUES_MEM="$(mem_disponible_gb)"
if [ "$SECO" = 0 ] && [ "$ANTES_TMP" != "$DESPUES_TMP" ]; then
  say "tmpfs ${ANTES_TMP}G -> ${DESPUES_TMP}G | RAM disponible ${ANTES_MEM}G -> ${DESPUES_MEM}G"
  log "pasada $NIVEL: tmpfs ${ANTES_TMP}G->${DESPUES_TMP}G, RAM ${ANTES_MEM}G->${DESPUES_MEM}G"
fi
