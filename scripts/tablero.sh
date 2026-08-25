#!/usr/bin/env bash
# tablero.sh — LA FUENTE DE TRABAJO. La única.
#
# Por qué existe (dueño 2026-08-22): el autopiloto repartía archivos .md
# escritos a mano de una pila FINITA. 238 archivos, 215 consumidos: a los veinte
# minutos de arrancar la pila estaba seca, todos los paneles decían "COLA
# AGOTADA" y el equipo quedaba parado hasta que el jefe —una sesión de chat que
# cuesta tokens— se sentaba a escribir 20 pedidos más. Ese eslabón humano es el
# que paraba todo.
#
# El tablero lo reemplaza: una lista de ítems REALES que se recarga desde
# cualquier lado (el celu por voz, un script, el jefe) y de la que cada panel
# libre TOMA uno solo, atómicamente. Nadie inventa trabajo: si el tablero está
# vacío, los paneles quedan callados y se avisa UNA vez al buzón.
#
# El repo se detecta desde la UBICACIÓN DEL SCRIPT, no desde el cwd de quien lo
# llama. `git rev-parse` a secas parece que funciona hasta que el vigilante lo
# lanza desde $HOME: ahí devuelve otro repo (o ninguno).
#
# Formato: .logs/tablero.tsv  ->  estado \t id \t ts \t origen \t panel \t titulo \t intentos
#          .logs/tablero/<id>.md  ->  el texto completo del pedido
# estado: pendiente | tomado | hecho | trabado
#
# ── POR QUÉ CADA ESCRITURA ES ATÓMICA (esto costó 379 ítems) ────────────────
# La primera versión hacía `open(tsv,'w')` sobre el archivo real. Eso TRUNCA
# primero y escribe después: si el proceso muere en el medio —un servicio
# reiniciado, un OOM, un Ctrl-C— el archivo queda VACÍO y se pierde el tablero
# entero. Pasó: quedó UNA fila de 379. Los .md sobrevivieron porque están
# aparte, que es la única razón por la que se pudo reconstruir.
#
# Ahora toda escritura es: archivo temporal → fsync → os.replace, que en el
# mismo sistema de archivos es atómico. O se ve el tablero viejo entero, o el
# nuevo entero; nunca la mitad. Y antes de reemplazar se guarda .bak.
#
# Encima va una GUARDA: ninguna operación de acá achica el tablero —todas
# cambian filas, ninguna las borra— así que si el resultado tiene menos filas
# que el original, se aborta y no se escribe nada. Eso ataja el fallo venga de
# donde venga, incluido un panel que decida "limpiar" el archivo a mano.
set -euo pipefail
_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="${TABLERO_REPO:-$(git -C "$_DIR" rev-parse --show-toplevel 2>/dev/null || dirname "$_DIR")}"
TSV="$REPO/.logs/tablero.tsv"
DIR="$REPO/.logs/tablero"
LOCK="$REPO/.tmp/tablero.lock"
mkdir -p "$DIR" "$REPO/.tmp"
touch "$TSV"

con_candado() { exec 7>"$LOCK"; flock 7; }

# El preámbulo que comparten todas las operaciones que escriben.
LIB='
import os, sys, tempfile
def leer(tsv):
    return [l.rstrip("\n").split("\t") for l in open(tsv, encoding="utf-8") if l.strip()]
def escribir(tsv, filas, antes):
    # La guarda: ninguna operación achica el tablero.
    if len(filas) < len(antes):
        sys.stderr.write("tablero: la operación intentó achicar el tablero (%d -> %d); NO se escribe\n"
                         % (len(antes), len(filas)))
        sys.exit(3)
    try:
        import shutil; shutil.copy2(tsv, tsv + ".bak")
    except Exception:
        pass
    d = os.path.dirname(tsv)
    # ── EL REEMPLAZO ATOMICO SE COMIA LOS PERMISOS (esto tiro abajo la cola) ──
    # mkstemp crea el temporal con 0600 y dueño = quien escribe, y os.replace
    # se lleva puesto el archivo viejo CON SUS PERMISOS. Alcanza con que UNA
    # operación del tablero corra como otro usuario —un panel con sudo, una
    # unidad de systemd— para que el tablero quede 0600 de root y a partir de
    # ahí NADIE pueda leerlo ni escribirlo. Pasó el 2026-08-24 11:54: doce
    # paneles con la cola caída y el error que se ve es "Permiso denegado",
    # que no dice en ningún lado que el archivo cambió de dueño.
    # Se preservan modo y dueño del archivo original antes de reemplazar.
    try:
        st = os.stat(tsv)
        modo, uid, gid = st.st_mode & 0o7777, st.st_uid, st.st_gid
    except FileNotFoundError:
        modo, uid, gid = 0o664, -1, -1
    fd, tmp = tempfile.mkstemp(dir=d, prefix=".tablero-", suffix=".tmp")
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        f.writelines("\t".join(x) + "\n" for x in filas)
        f.flush(); os.fsync(f.fileno())
    try:
        os.chmod(tmp, modo | 0o660)   # el dueño y el grupo siempre pueden escribir
        if uid != -1:
            os.chown(tmp, uid, gid)   # falla sin privilegios: no es fatal
    except (PermissionError, OSError):
        pass
    os.replace(tmp, tsv)
'

cmd="${1:-list}"; shift || true

case "$cmd" in
  add)
    # tablero.sh add "<texto completo>" [origen]
    texto="${1:?falta el texto}"; origen="${2:-jefe}"
    id="$(date +%Y%m%d-%H%M%S)-$RANDOM"
    titulo=$(printf '%s' "$texto" | head -1 | cut -c1-110 | tr '\t\n' '  ' | sed 's/^#* *//')
    printf '%s\n' "$texto" > "$DIR/$id.md"
    con_candado
    printf 'pendiente\t%s\t%s\t%s\t-\t%s\t0\n' "$id" "$(date +%s)" "$origen" "$titulo" >> "$TSV"
    # Hay trabajo otra vez: se levanta la bandera de "tablero vacío".
    rm -f "$REPO/.tmp/tablero-vacio-avisado"
    echo "$id"
    ;;

  bulk)
    # tablero.sh bulk <archivo> [origen] — ítems separados por una línea con %%
    # Cargar 350 ítems con `add` son 350 flocks y 350 procesos: tarda minutos y
    # deja el tablero a medio llenar si algo se corta. Esto es un solo append.
    archivo="${1:?falta el archivo}"; origen="${2:-jefe}"
    con_candado
    python3 -c "$LIB"'
import time, random, os, sys
tsv, d, archivo, origen = sys.argv[1:5]
items = [t.strip() for t in open(archivo, encoding="utf-8").read().split("\n%%\n") if t.strip()]
lineas = []
for i, texto in enumerate(items):
    iid = "%s-%04d%d" % (time.strftime("%Y%m%d-%H%M%S"), i, random.randint(100, 999))
    open(os.path.join(d, iid + ".md"), "w", encoding="utf-8").write(texto + "\n")
    titulo = texto.splitlines()[0][:110].replace("\t", " ").lstrip("# ")
    lineas.append("pendiente\t%s\t%d\t%s\t-\t%s\t0\n" % (iid, int(time.time()), origen, titulo))
with open(tsv, "a", encoding="utf-8") as f:
    f.writelines(lineas); f.flush(); os.fsync(f.fileno())
print(len(lineas))
' "$TSV" "$DIR" "$archivo" "$origen"
    rm -f "$REPO/.tmp/tablero-vacio-avisado"
    ;;

  take)
    # tablero.sh take <panel> -> imprime el <id> del ítem tomado, o nada.
    #
    # Cuenta INTENTOS. Un ítem repartido que volvió a la pila tres veces sin
    # que nadie lo cerrara queda TRABADO y deja de repartirse. Sin el tope, un
    # ítem que ningún panel puede cerrar (mal escrito, ya hecho, depende de algo
    # que no existe) rebota para siempre: el panel lo toma, contesta, queda
    # libre, se lo mandan de nuevo. Eso es el acoso que esto viene a evitar, y
    # encima se paga un prompt cada vuelta. Pasó con w5:p2C, dos veces en dos
    # minutos.
    panel="${1:?falta el panel}"
    con_candado
    python3 -c "$LIB"'
import sys
tsv, panel, tope = sys.argv[1], sys.argv[2], int(sys.argv[3])
filas = leer(tsv); antes = list(filas)
elegido = None

# ── POR QUÉ NO SE REPARTE DESDE ARRIBA (esto quemó 29 ítems en 15 minutos) ──
# La versión anterior escaneaba desde la primera fila y entregaba el primer
# pendiente. Con doce paneles pidiendo trabajo, la CABEZA de la cola se vuelve
# una picadora: el mismo ítem se entrega una y otra vez —un panel lo toma, lo
# interrumpen o contesta sin cerrarlo, vuelve a pendiente, y vuelve a salir
# primero— hasta que agota el tope y queda TRABADO sin que nadie lo haya
# trabajado de verdad. El 2026-08-24 se trabaron así GAP-1.08 a GAP-1.30,
# consecutivos: no era la calidad de los pedidos, era su POSICIÓN. Mientras
# tanto los otros 800 ítems del tablero no se tocaban nunca.
#
# Ahora se elige el pendiente con MENOS intentos, y a igualdad, el más viejo.
# Eso reparte el desgaste solo: un ítem que ya rebotó se va al fondo de la
# preferencia y otro fresco sale antes, así que ninguno se quema por estar
# arriba y la cola entera se recorre en vez de moler los primeros veinte.
candidatos = []
for i, f in enumerate(filas):
    if len(f) < 6 or f[0] != "pendiente":
        continue
    while len(f) < 7: f.append("0")
    try:
        n = int(f[6] or 0)
    except ValueError:
        n = 0
    if n >= tope:
        # Ya agotó el tope sin que nadie lo cerrara: se marca y no se reparte.
        f[0] = "trabado"; f[4] = "-"
        continue
    candidatos.append((n, i, f))

if candidatos:
    candidatos.sort(key=lambda c: (c[0], c[1]))
    _, _, f = candidatos[0]
    f[6] = str(int(f[6] or 0) + 1)
    f[0] = "tomado"; f[4] = panel
    elegido = f[1]

escribir(tsv, filas, antes)
if elegido: print(elegido)
' "$TSV" "$panel" "${TABLERO_MAX_INTENTOS:-3}"
    ;;

  done)
    id="${1:?falta el id}"
    con_candado
    python3 -c "$LIB"'
import sys
tsv, iid = sys.argv[1], sys.argv[2]
filas = leer(tsv); antes = list(filas)
for f in filas:
    if len(f) >= 6 and f[1] == iid: f[0] = "hecho"
escribir(tsv, filas, antes)
' "$TSV" "$id"
    ;;

  # Un ítem tomado por un panel que quedó libre sin cerrarlo vuelve a la pila.
  # Sin esto, un panel que muere a mitad se lleva el trabajo a la tumba.
  soltar)
    panel="${1:?falta el panel}"
    con_candado
    python3 -c "$LIB"'
import sys
tsv, panel = sys.argv[1], sys.argv[2]
filas = leer(tsv); antes = list(filas)
for f in filas:
    if len(f) >= 6 and f[0] == "tomado" and f[4] == panel:
        f[0] = "pendiente"; f[4] = "-"
escribir(tsv, filas, antes)
' "$TSV" "$panel"
    ;;

  # Un trabado se revive a mano, después de arreglar lo que lo trababa.
  revivir)
    id="${1:?falta el id}"
    con_candado
    python3 -c "$LIB"'
import sys
tsv, iid = sys.argv[1], sys.argv[2]
filas = leer(tsv); antes = list(filas)
for f in filas:
    if len(f) >= 6 and f[1] == iid and f[0] == "trabado":
        f[0] = "pendiente"
        if len(f) >= 7: f[6] = "0"
escribir(tsv, filas, antes)
' "$TSV" "$id"
    ;;

  # Reconstruye el índice desde los .md, que son la fuente real. Existe porque
  # el índice ya se perdió una vez: los textos estaban intactos y no había cómo
  # volver a armarlo. Respeta lo que el índice actual ya sabe (hecho, trabado,
  # intentos) y agrega como pendiente todo .md que no figure.
  reconstruir)
    con_candado
    python3 -c "$LIB"'
import sys, os, glob, time
tsv, d, origen = sys.argv[1], sys.argv[2], sys.argv[3]
conocidas = {}
for f in leer(tsv):
    if len(f) >= 6: conocidas[f[1]] = f
filas, nuevos = [], 0
for ruta in sorted(glob.glob(os.path.join(d, "*.md"))):
    iid = os.path.basename(ruta)[:-3]
    if iid in conocidas:
        filas.append(conocidas[iid]); continue
    try: titulo = open(ruta, encoding="utf-8").readline().strip().lstrip("# ")[:110]
    except Exception: titulo = iid
    filas.append(["pendiente", iid, str(int(os.path.getmtime(ruta))), origen, "-", titulo, "0"])
    nuevos += 1
escribir(tsv, filas, [])
print("%d filas (%d reconstruidas desde los .md)" % (len(filas), nuevos))
' "$TSV" "$DIR" "${1:-reconstruido}"
    ;;

  count)    grep -cP "^pendiente\t" "$TSV" 2>/dev/null || true ;;
  trabados) grep -P '^trabado\t' "$TSV" 2>/dev/null | cut -f2,6 || true ;;
  texto)    cat "$DIR/${1:?falta el id}.md" ;;
  list)
    awk -F'\t' '{printf "%-10s %-22s %2s %-14s %s\n", $1, $2, ($7==""?0:$7), $4, $6}' "$TSV" | tail -"${1:-40}"
    ;;
  *) echo "uso: tablero.sh add|bulk|take|done|soltar|revivir|reconstruir|count|trabados|texto|list" >&2; exit 2 ;;
esac
