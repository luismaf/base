#!/usr/bin/env python3
"""celu.py — la sala de máquinas en el bolsillo.

Portable: detecta el repo solo (git rev-parse), habla con el harness a través
de harness.sh y guarda token y certificado por nombre de repo, así conviven
varias instancias en la misma máquina (una por proyecto, un puerto cada una).

Por qué existe (dueño 2026-08-22): "estoy internado en la compu hace semanas y
necesito algo mobile". Con ZeroTier el celu y la PC ya se ven; lo único que
faltaba era una pantalla. Esta es esa pantalla, y sobre todo es la BOCA: el
dueño dicta un pendiente por voz desde la cama y cae en el tablero
(scripts/tablero.sh), que es de donde los paneles libres sacan trabajo real.
Sin esto, recargar el tablero exige sentarse a escribir .md — que es
exactamente el eslabón que dejaba al equipo parado durante horas.

Tres decisiones que importan:

1. **La transcripción la hace el CELULAR, no un modelo pago.** Chrome en
   Android trae `webkitSpeechRecognition` (es-AR) gratis y sin cuota. Dictar
   un pendiente cuesta CERO tokens. El texto sólo se convierte en gasto
   cuando un panel efectivamente lo ejecuta. Si el navegador no la tiene, se
   graba el audio, se guarda en .logs/celu-audio/ y se transcribe con whisper
   local si está instalado; si tampoco, se avisa y se escribe a mano.

2. **HTTPS con certificado propio.** No es paranoia: `getUserMedia` y la API
   de voz sólo existen en contexto seguro. Sobre http:// plano el botón del
   micrófono no funciona y no hay forma de saber por qué. El certificado se
   genera solo la primera vez; en el celu se acepta una vez y listo.

3. **Sin dependencias.** Sólo stdlib. Un servidor que se cae porque faltó un
   pip en la madrugada no sirve para esto.

Uso:  python3 scripts/celu.py                     (CELU_PORT, default 8443)
      https://<ip-vpn>:<puerto>/?t=<token>       desde el celu
El token se guarda en ~/.celu-token-<repo> y se imprime al arrancar.
"""

import http.server, socketserver, ssl, json, subprocess, os, secrets, shutil, html
from urllib.parse import urlparse, parse_qs

_DIRSC = os.path.dirname(os.path.abspath(__file__))
# Desde la ubicación del script, nunca desde el cwd: arrancado por systemd el
# cwd puede ser cualquier cosa y el celu terminaría mostrando otro proyecto.
REPO = os.environ.get("CELU_REPO") or subprocess.run(
    ["git", "-C", _DIRSC, "rev-parse", "--show-toplevel"], capture_output=True, text=True
).stdout.strip() or os.path.dirname(_DIRSC)
NOMBRE = os.environ.get("CELU_NOMBRE") or os.path.basename(REPO)
DIRSC = _DIRSC
HOME = os.path.expanduser("~")
PORT = int(os.environ.get("CELU_PORT", "8443"))
CERT = os.path.join(HOME, f".celu-cert-{NOMBRE}.pem")
TOKFILE = os.path.join(HOME, f".celu-token-{NOMBRE}")
AUDIO = os.path.join(REPO, ".logs", "celu-audio")
os.makedirs(AUDIO, exist_ok=True)
os.environ["PATH"] = os.path.join(HOME, ".local/bin") + ":" + os.environ.get("PATH", "")

if os.path.exists(TOKFILE):
    TOKEN = open(TOKFILE).read().strip()
else:
    TOKEN = secrets.token_urlsafe(9)
    open(TOKFILE, "w").write(TOKEN)
    os.chmod(TOKFILE, 0o600)


def sh(args, timeout=25):
    try:
        return subprocess.run(args, capture_output=True, text=True, timeout=timeout).stdout
    except Exception as e:
        return f"[error: {e}]"


def _harness(fn, *args):
    """Todo lo que toca al harness pasa por harness.sh — la capa que hace que
    cambiar de herdr a paseo (o a lo que venga) sea tocar UN archivo."""
    cmd = f'source "{DIRSC}/harness.sh"; {fn} ' + " ".join(f'"{a}"' for a in args)
    return sh(["bash", "-c", cmd])


def paneles():
    """Sólo los paneles de ESTE repo — el celu de un proyecto no muestra (ni
    deja mandarle trabajo a) los devs de otro."""
    r = []
    for l in _harness("harness_list").splitlines():
        p = l.split("\t")
        if len(p) < 2:
            continue
        cwd = p[2] if len(p) > 2 else ""
        if cwd and not (cwd == REPO or cwd.startswith(REPO + "/")):
            continue
        r.append({"id": p[0], "estado": p[1].strip(),
                  "clase": p[3] if len(p) > 3 else "agente"})
    return r


def items(n=25):
    tsv = os.path.join(REPO, ".logs", "tablero.tsv")
    if not os.path.exists(tsv):
        return []
    filas = []
    for l in open(tsv, encoding="utf-8"):
        f = l.rstrip("\n").split("\t")
        if len(f) >= 6:
            filas.append({"estado": f[0], "id": f[1], "origen": f[3], "panel": f[4], "titulo": f[5]})
    pend = [x for x in filas if x["estado"] == "pendiente"]
    otros = [x for x in filas if x["estado"] != "pendiente"]
    return (pend + otros[::-1])[:n]


def transcribir(path):
    """Whisper local si está; si no, vacío. Nunca manda el audio afuera:
    mandarlo a una nube sería sacar la voz del dueño del ZeroTier sin que
    nadie lo haya pedido."""
    for bin_ in ("whisper-cli", "whisper"):
        if shutil.which(bin_):
            wav = path + ".wav"
            sh(["ffmpeg", "-y", "-i", path, "-ar", "16000", "-ac", "1", wav], timeout=90)
            modelo = os.path.join(HOME, ".cache", "whisper", "ggml-small.bin")
            args = [bin_, "-m", modelo, "-l", "es", "-nt", "-f", wav] if bin_ == "whisper-cli" \
                else [bin_, "--language", "es", "--output_format", "txt", wav]
            return sh(args, timeout=180).strip()
    return ""


PAGINA = """<!doctype html><html lang=es><head>
<meta charset=utf-8><meta name=viewport content="width=device-width,initial-scale=1,viewport-fit=cover">
<title>__NOMBRE__</title><style>
:root{--bg:#0e1013;--card:#171a1f;--line:#262b33;--fg:#e7eaf0;--dim:#8b94a3;
--ok:#3ddc84;--work:#ffb020;--off:#5a6270;--acc:#4c8dff}
*{box-sizing:border-box;-webkit-tap-highlight-color:transparent}
body{margin:0;background:var(--bg);color:var(--fg);font:16px/1.45 system-ui,sans-serif;
padding:env(safe-area-inset-top) 12px calc(96px + env(safe-area-inset-bottom))}
h1{font-size:15px;color:var(--dim);font-weight:600;margin:14px 2px 8px;letter-spacing:.04em;text-transform:uppercase}
.card{background:var(--card);border:1px solid var(--line);border-radius:14px;padding:12px;margin-bottom:8px}
.row{display:flex;align-items:center;gap:10px}
.dot{width:9px;height:9px;border-radius:50%;flex:0 0 9px}
.working .dot{background:var(--work);box-shadow:0 0 8px var(--work)}
.idle .dot{background:var(--ok)} .otro .dot{background:var(--off)}
.pid{font:600 15px ui-monospace,monospace} .sub{color:var(--dim);font-size:13px;margin-left:auto}
pre{white-space:pre-wrap;word-break:break-word;font:12px/1.35 ui-monospace,monospace;
color:var(--dim);margin:10px 0 0;max-height:45vh;overflow:auto}
.item{border-left:3px solid var(--off);padding-left:10px;margin:9px 0;font-size:14px}
.item.pendiente{border-color:var(--acc)} .item.tomado{border-color:var(--work)}
.item.hecho{border-color:var(--off);opacity:.45;text-decoration:line-through}
.meta{color:var(--dim);font-size:11px}
#barra{position:fixed;left:0;right:0;bottom:0;background:#12151a;border-top:1px solid var(--line);
padding:10px 12px calc(10px + env(safe-area-inset-bottom));display:flex;gap:10px;align-items:flex-end}
textarea{flex:1;background:#0b0d10;color:var(--fg);border:1px solid var(--line);border-radius:12px;
padding:11px;font:15px/1.4 system-ui;resize:none;min-height:48px;max-height:34vh}
button{border:0;border-radius:12px;font:600 15px system-ui;padding:12px 15px;color:#fff;background:#2b323d}
#mic{background:var(--acc);min-width:56px;font-size:22px;padding:11px 14px}
#mic.rec{background:#e5484d;animation:p 1s infinite} @keyframes p{50%{opacity:.55}}
.envios{display:flex;gap:8px;margin:8px 0 0;flex-wrap:wrap}
.envios button{background:#232a34;font-size:13px;padding:9px 12px}
.envios button.pri{background:var(--acc)}
.man{font-size:11px;background:var(--work);color:#1a1200;border-radius:6px;padding:2px 6px;font-weight:700}
#toast{position:fixed;left:12px;right:12px;bottom:100px;background:#1d2530;border:1px solid var(--acc);
border-radius:12px;padding:11px;font-size:14px;display:none}
</style></head><body>

<h1>Tablero — <span id=np>·</span> pendientes</h1>
<div class=card id=tab></div>

<h1>La cuadrilla — __NOMBRE__</h1>
<div id=pan></div>

<div id=toast></div>
<div id=barra>
  <button id=mic>&#127908;</button>
  <textarea id=txt placeholder=""></textarea>
</div>
<div class=envios style="position:fixed;bottom:74px;left:12px;right:12px;display:none" id=env>
  <button class=pri onclick="mandar('tablero')">Al tablero</button>
  <button onclick="mandarPanel()">A un panel…</button>
  <button onclick="document.getElementById('txt').value='';ui()">Borrar</button>
</div>

<script>
const T=new URLSearchParams(location.search).get('t')||'';
const $=i=>document.getElementById(i);
function toast(m){$('toast').textContent=m;$('toast').style.display='block';
  clearTimeout(window._t);window._t=setTimeout(()=>$('toast').style.display='none',3200);}
function ui(){$('env').style.display=$('txt').value.trim()?'flex':'none';}
$('txt').addEventListener('input',ui);

async function refrescar(){
  const r=await fetch('/api/estado?t='+T); if(!r.ok){toast('token malo');return;}
  const d=await r.json();
  $('np').textContent=d.items.filter(i=>i.estado==='pendiente').length;
  $('tab').innerHTML=d.items.map(i=>`<div class="item ${i.estado}">${i.titulo}
    <div class=meta>${i.estado}${i.panel!=='-'?' · '+i.panel:''} · ${i.origen}</div></div>`).join('')
    ||'<div class=meta>vacío — dictá algo</div>';
  $('pan').innerHTML=d.paneles.map(p=>{
    const c=p.estado==='working'?'working':(p.estado==='idle'?'idle':'otro');
    // Los paneles MANUALES se marcan. No arrancan solos: a veces hay que
    // apretarles Enter con la pestaña en pantalla. Verlos desde el celu es la
    // diferencia entre enterarse y encontrarlos quietos de casualidad.
    const man=p.clase==='manual'?' <span class=man>a mano</span>':'';
    return `<div class="card ${c}" onclick="ver('${p.id}',this)"><div class=row>
      <span class=dot></span><span class=pid>${p.id}</span>${man}
      <span class=sub>${p.estado}</span></div></div>`;}).join('');
}
async function ver(id,el){
  if(el.querySelector('pre')){el.querySelector('pre').remove();return;}
  const r=await fetch('/api/pane?t='+T+'&id='+encodeURIComponent(id));
  const p=document.createElement('pre'); p.textContent=await r.text(); el.appendChild(p);
}
async function mandar(destino,panel){
  const texto=$('txt').value.trim(); if(!texto)return;
  const r=await fetch('/api/'+destino+'?t='+T,{method:'POST',
    headers:{'content-type':'application/json'},body:JSON.stringify({texto,panel})});
  toast(await r.text()); $('txt').value=''; ui(); refrescar();
}
function mandarPanel(){
  const libres=[...document.querySelectorAll('.card.idle .pid')].map(e=>e.textContent);
  const p=prompt('¿A qué panel? libres: '+libres.join(' '),libres[0]||'');
  if(p) mandar('panel',p);
}

// ── Voz. La hace el celular: gratis, sin cuota, cero tokens. ──────────────
const SR=window.SpeechRecognition||window.webkitSpeechRecognition;
let rec=null, grab=null, chunks=[];
$('mic').onclick=()=>{
  if(SR){
    if(rec){rec.stop();return;}
    rec=new SR(); rec.lang='es-AR'; rec.continuous=true; rec.interimResults=true;
    const base=$('txt').value?$('txt').value+' ':'';
    rec.onresult=e=>{let s='';for(let i=0;i<e.results.length;i++)s+=e.results[i][0].transcript;
      $('txt').value=base+s; ui();};
    rec.onend=()=>{rec=null;$('mic').classList.remove('rec');};
    rec.onerror=e=>toast('voz: '+e.error);
    rec.start(); $('mic').classList.add('rec'); toast('escuchando… tocá otra vez para cortar');
  } else { audio(); }
};
async function audio(){   // fallback: se sube el .webm y lo transcribe whisper local
  if(grab&&grab.state==='recording'){grab.stop();return;}
  const s=await navigator.mediaDevices.getUserMedia({audio:true});
  grab=new MediaRecorder(s); chunks=[];
  grab.ondataavailable=e=>chunks.push(e.data);
  grab.onstop=async()=>{$('mic').classList.remove('rec');toast('transcribiendo…');
    const r=await fetch('/api/audio?t='+T,{method:'POST',body:new Blob(chunks)});
    const j=await r.json(); if(j.texto){$('txt').value+=j.texto;ui();}else toast(j.aviso||'sin texto');};
  grab.start(); $('mic').classList.add('rec'); toast('grabando… tocá para cortar');
}
refrescar(); setInterval(refrescar,15000);
</script></body></html>"""


class H(http.server.BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def _ok(self, cuerpo, tipo="text/plain; charset=utf-8", code=200):
        b = cuerpo.encode() if isinstance(cuerpo, str) else cuerpo
        self.send_response(code)
        self.send_header("Content-Type", tipo)
        self.send_header("Content-Length", str(len(b)))
        self.end_headers()
        self.wfile.write(b)

    def _auth(self, q):
        # ZeroTier ya es la puerta; el token evita que un dispositivo cualquiera
        # de la red mande prompts a los paneles.
        if q.get("t", [""])[0] != TOKEN:
            self._ok("token", code=403)
            return False
        return True

    def log_message(self, *a):
        pass

    def do_GET(self):
        u = urlparse(self.path)
        q = parse_qs(u.query)
        if u.path == "/":
            return self._ok(PAGINA.replace("__NOMBRE__", NOMBRE), "text/html; charset=utf-8")
        if not self._auth(q):
            return
        if u.path == "/api/estado":
            return self._ok(json.dumps({"paneles": paneles(), "items": items()}),
                            "application/json")
        if u.path == "/api/pane":
            pid = q.get("id", [""])[0]
            return self._ok(_harness("harness_read", pid, "45") or "(sin salida)")
        self._ok("no", code=404)

    def do_POST(self):
        u = urlparse(self.path)
        q = parse_qs(u.query)
        if not self._auth(q):
            return
        n = int(self.headers.get("Content-Length", 0))
        cuerpo = self.rfile.read(n)

        if u.path == "/api/tablero":
            texto = json.loads(cuerpo).get("texto", "").strip()
            if not texto:
                return self._ok("vacío")
            iid = sh(["bash", os.path.join(REPO, "scripts/tablero.sh"), "add", texto, "celu"]).strip()
            return self._ok(f"al tablero ({iid.split('-')[-1]}) — lo toma el próximo panel libre")

        if u.path == "/api/panel":
            d = json.loads(cuerpo)
            panel, texto = d.get("panel", ""), d.get("texto", "").strip()
            if not panel or not texto:
                return self._ok("faltan datos")
            _harness("harness_prompt", panel, texto.replace('"', "'"))
            return self._ok(f"mandado a {panel}")

        if u.path == "/api/audio":
            import time
            p = os.path.join(AUDIO, f"{int(time.time())}.webm")
            open(p, "wb").write(cuerpo)
            t = transcribir(p)
            aviso = "" if t else ("sin whisper local: instalá whisper.cpp o dictá con "
                                  "Chrome, que transcribe solo")
            return self._ok(json.dumps({"texto": t, "aviso": aviso}), "application/json")

        self._ok("no", code=404)


def cert():
    if not os.path.exists(CERT):
        subprocess.run(["openssl", "req", "-x509", "-newkey", "rsa:2048", "-nodes",
                        "-keyout", CERT, "-out", CERT, "-days", "3650",
                        "-subj", "/CN=cuadrilla"], check=True, capture_output=True)
        os.chmod(CERT, 0o600)
    c = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    c.load_cert_chain(CERT)
    return c


class S(socketserver.ThreadingTCPServer):
    allow_reuse_address = True
    daemon_threads = True


if __name__ == "__main__":
    srv = S(("0.0.0.0", PORT), H)
    srv.socket = cert().wrap_socket(srv.socket, server_side=True)
    ips = [l.split()[3].split("/")[0] for l in
           subprocess.run(["ip", "-4", "-o", "addr"], capture_output=True, text=True)
           .stdout.splitlines() if " zt" in l]
    print("token:", TOKEN)
    for ip in ips:
        print(f"  https://{ip}:{PORT}/?t={TOKEN}")
    srv.serve_forever()
