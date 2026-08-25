#!/usr/bin/env bash
# protect-panels.sh - stop the OOM killer from eating the agent panels first.
#
# ## What was happening
#
# Every opencode panel on this machine carried `oom_score_adj = 200`, giving it
# an OOM score of 807 out of 1000 - the highest of anything running. So every
# time memory ran short, the kernel killed the WORK, and left the transient
# compiler processes that actually caused the shortage untouched. The journal
# has it three times in one day:
#
#   vte-spawn-...scope: The kernel OOM killer killed some processes in this unit
#
# On top of that, earlyoom is configured with
#   --prefer '^(rustc|cc1|cc1plus|ld|lld|rust-analyzer|node)$'
# and opencode is a node/bun binary, while `--avoid` never mentions it. So both
# killers were aiming at the same target: the panels.
#
# And panels had started fighting back with sudo - `systemctl stop earlyoom`,
# `pkill -TERM earlyoom` - which only swaps a careful userspace killer for the
# kernel's blunt one. That is worse, not better.
#
# ## What this does
#
# Inverts the priority so the right thing dies first:
#   opencode panels ......... adj  -100  (protected: this is the work)
#   herdr / the supervisor ... adj  -200  (protected: this is the control plane)
#   rustc / cc1 / ld ........ adj  +500  (killed first: transient, restartable)
#
# A dead rustc costs one `cargo check`. A dead panel costs the session, its
# context and whatever it had not committed yet.
#
# Lowering oom_score_adj needs CAP_SYS_RESOURCE, so this runs under sudo.
# Raising it (the compilers) works unprivileged.
set -uo pipefail

ajustar() {
    local patron="$1" valor="$2" n=0
    for pid in $(pgrep -f "$patron" 2>/dev/null); do
        if echo "$valor" > "/proc/$pid/oom_score_adj" 2>/dev/null; then
            n=$((n + 1))
        fi
    done
    printf '%-38s adj=%-6s ajustados=%d\n' "$patron" "$valor" "$n"
}

ajustar '^opencode'                    -100
ajustar 'herdr'                        -200
ajustar '^(rustc|cc1|cc1plus|ld|lld)$'  500
ajustar 'rust-analyzer'                 400
