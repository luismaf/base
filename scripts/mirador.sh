#!/usr/bin/env bash
# mirador.sh — la flota y la maquina en un panel, en vivo.
#
# Cuantos agentes hay, cuantos trabajan de verdad, cuanta RAM se comen y cuanto
# margen queda. Pensado para dejarlo abierto en un panel y mirarlo de reojo.
#
# ── LIVIANO, PORQUE MIRAR NO PUEDE COSTAR ──────────────────────────────────
#
# Un monitor que corre cada 5 segundos en una maquina que ya esta al limite de
# RAM tiene que ser barato o es parte del problema. Dos medidas:
#
#   * TODO el render es UN proceso de python por vuelta, leyendo /proc directo.
#     La version con un `awk` por PID costaba 0.17s en forks para leer 42
#     numeros; en python son 10 ms.
#
#   * El PSS de los devs NO se mide cada vuelta. Sacarlo cuesta ~1.6s con 42
#     procesos —casi todo tiempo de kernel recorriendo tablas de paginas— y a
#     5 segundos eso es un tercio de la maquina dedicado a mirarla. Se refresca
#     cada 60s y **la pantalla dice de cuando es el dato**, para que nadie lea
#     un numero viejo creyendo que es de ahora.
#
# ── TRES ESTADOS, NUNCA DOS ────────────────────────────────────────────────
#
# Si herdr no contesta, esto NO muestra "0 agentes": muestra SIN DATOS. Un
# monitor ciego que dibuja ceros se ve igual que una flota apagada, y la
# respuesta tranquilizadora es la peligrosa. Ver docs/DOCTRINA-DEL-JEFE.md §5.
#
# ── USO ────────────────────────────────────────────────────────────────────
#
#   bash scripts/mirador.sh              # en un panel, y lo dejas ahi
#   bash scripts/mirador.sh --una        # una sola foto y sale (para pegar)
#   MIRADOR_INTERVALO=10 bash scripts/mirador.sh
#   MIRADOR_REPOS="/ruta/a /ruta/b" bash scripts/mirador.sh
set -u

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INTERVALO="${MIRADOR_INTERVALO:-5}"
REPOS="${MIRADOR_REPOS:-/run/media/yo/A/rust/agp /run/media/yo/A/rust/ux /run/media/yo/A/rust/tuti}"
UNA=0
[ "${1:-}" = "--una" ] && UNA=1

export MIRADOR_REPOS_EFF="$REPOS"
export MIRADOR_UNA="$UNA"
export MIRADOR_INTERVALO_EFF="$INTERVALO"

exec python3 - <<'PY'
import json, os, re, subprocess, sys, time

REPOS = [r for r in os.environ["MIRADOR_REPOS_EFF"].split() if r]
UNA = os.environ["MIRADOR_UNA"] == "1"
INTERVALO = float(os.environ["MIRADOR_INTERVALO_EFF"])
LENTO = 60.0          # cada cuanto se paga la medicion cara

V, A, R, G, D, N = "\033[32m", "\033[33m", "\033[31m", "\033[90m", "\033[1m", "\033[0m"

def meminfo():
    d = {}
    with open("/proc/meminfo") as f:
        for l in f:
            k, _, v = l.partition(":")
            d[k] = int(v.split()[0])          # kB
    return d

def pids_opencode():
    out = []
    for e in os.listdir("/proc"):
        if not e.isdigit():
            continue
        try:
            with open("/proc/%s/comm" % e) as f:
                if f.read().strip() == "opencode":
                    out.append(e)
        except OSError:
            pass
    return out

def pss_devs(pids):
    """Caro: el kernel recorre las tablas de paginas. Sólo cada LENTO segundos."""
    v = []
    for p in pids:
        try:
            with open("/proc/%s/smaps_rollup" % p) as f:
                for l in f:
                    if l.startswith("Pss:"):
                        v.append(int(l.split()[1]) // 1024)   # MB
                        break
        except OSError:
            pass
    v.sort()
    return v

def agentes():
    """None = no pude medir. Nunca una lista vacía disfrazada de flota apagada."""
    try:
        p = subprocess.run(["herdr", "agent", "list"], capture_output=True,
                           text=True, timeout=8)
        return json.loads(p.stdout)["result"]["agents"]
    except Exception:
        return None

def tablero(repo):
    c = {}
    try:
        with open(os.path.join(repo, ".logs/tablero.tsv"), encoding="utf-8", errors="replace") as f:
            for l in f:
                c[l.split("\t", 1)[0]] = c.get(l.split("\t", 1)[0], 0) + 1
    except OSError:
        return None
    return c

def commits(repo, minutos=60):
    try:
        p = subprocess.run(["git", "-C", repo, "log",
                            "--since=%d minutes ago" % minutos, "--oneline"],
                           capture_output=True, text=True, timeout=10)
        return len([x for x in p.stdout.split("\n") if x.strip()])
    except Exception:
        return None

def barra(usado, total, ancho=26):
    if not total:
        return "?" * ancho, G
    frac = max(0.0, min(1.0, usado / total))
    col = V if frac < 0.75 else (A if frac < 0.90 else R)
    lleno = int(round(frac * ancho))
    return col + "█" * lleno + G + "░" * (ancho - lleno) + N, col

def gb(kb): return kb / 1048576.0

lento_ts, pss_cache, tab_cache, com_cache = 0.0, [], {}, {}

while True:
    ahora = time.time()
    mi = meminfo()
    ags = agentes()
    pids = pids_opencode()

    if ahora - lento_ts >= LENTO or not pss_cache:
        pss_cache = pss_devs(pids)
        tab_cache = {r: tablero(r) for r in REPOS}
        com_cache = {r: commits(r) for r in REPOS}
        lento_ts = ahora
    edad = int(ahora - lento_ts)

    L = []
    L.append("%s FLOTA%s  %s        %s%s" % (D, N, time.strftime("%H:%M:%S"),
             G + " · ".join(os.path.basename(r) for r in REPOS), N))
    L.append(G + "─" * 74 + N)

    if ags is None:
        L.append(" %sAGENTES  SIN DATOS — herdr no contesta.%s" % (R, N))
        L.append("          %sNo es 'cero agentes'. Es que no puedo medir.%s" % (G, N))
    else:
        est, por = {}, {}
        for a in ags:
            est[a.get("agent_status", "?")] = est.get(a.get("agent_status", "?"), 0) + 1
            if a.get("agent") == "opencode":
                b = os.path.basename(os.path.realpath(a.get("cwd") or "/x"))
                por[b] = por.get(b, 0) + 1
        trab = est.get("working", 0)
        ocio = est.get("idle", 0) + est.get("done", 0)
        colo = V if ocio == 0 else A
        L.append(" %sAGENTES%s  %s%d%s total   %s%d trabajando%s   %s%d ociosos%s   %d trabados"
                 % (D, N, D, len(ags), N, V, trab, N, colo, ocio, N, est.get("blocked", 0)))
        L.append("          " + G + "   ".join("%s %d" % (k, v) for k, v in
                 sorted(por.items(), key=lambda x: -x[1])) + N)
    L.append("")

    tot, disp = mi.get("MemTotal", 0), mi.get("MemAvailable", 0)
    b, _ = barra(tot - disp, tot)
    L.append(" %sRAM%s      %s  %.1f / %.1f GB usada   %s%.1f GB libre%s"
             % (D, N, b, gb(tot - disp), gb(tot), D, gb(disp), N))

    stot = mi.get("SwapTotal", 0); slib = mi.get("SwapFree", 0)
    if stot:
        b2, c2 = barra(stot - slib, stot)
        aviso = ""
        if slib < stot * 0.10:
            aviso = "%s  ← AL LÍMITE: el kernel elige a quién matar%s" % (R, N)
        L.append(" %sSWAP%s     %s  %.1f / %.1f GB%s" % (D, N, b2, gb(stot - slib), gb(stot), aviso))

    if pss_cache:
        t = sum(pss_cache) / 1024.0
        med = pss_cache[len(pss_cache) // 2] / 1024.0
        p90 = pss_cache[min(len(pss_cache) - 1, int(len(pss_cache) * 0.9))] / 1024.0
        L.append(" %sDEVS%s     %.1f GB en %d devs · mediana %.2f · p90 %.2f  %s(hace %ds)%s"
                 % (D, N, t, len(pss_cache), med, p90, G, edad, N))
    else:
        L.append(" %sDEVS%s     %ssin medición de PSS todavía%s" % (D, N, G, N))
    L.append("")

    tl = []
    for r in REPOS:
        c = tab_cache.get(r)
        n = os.path.basename(r)
        tl.append("%s %s?" % (n, "") if c is None else
                  "%s %d%s/%d" % (n, c.get("pendiente", 0), G + "p" + N, c.get("tomado", 0)))
    L.append(" %sTABLERO%s  %s   %s(pendientes/tomados)%s" % (D, N, "   ".join(tl), G, N))

    cs = [(os.path.basename(r), com_cache.get(r)) for r in REPOS]
    tot_c = sum(v for _, v in cs if v is not None)
    det = " · ".join("%s %s" % (n, "?" if v is None else v) for n, v in cs)
    L.append(" %sSALIDA%s   %s%d commits%s en la última hora   %s(%s)%s"
             % (D, N, V if tot_c else A, tot_c, N, G, det, N))

    L.append(G + "─" * 74 + N)
    L.append(" %sctrl+c para salir · refresco %gs · lo caro cada %gs%s" % (G, INTERVALO, LENTO, N))

    sys.stdout.write("\033[H\033[J" + "\n".join(L) + "\n")
    sys.stdout.flush()
    if UNA:
        break
    try:
        time.sleep(INTERVALO)
    except KeyboardInterrupt:
        sys.stdout.write("\n")
        break
PY
