# Levantar una locación nueva

Receta probada el 2026-08-26 sobre un Oracle Cloud free tier (Ampere ARM, 2
núcleos, 12 GB, 200 GB). Sirve para cualquier VPS Linux.

Una locación es un equipo que **compila y trabaja** por su cuenta, sin gastarle
memoria a la máquina de nadie. Lo que sigue es el orden exacto, y cada paso
está donde está por una razón que se explica.

---

## 0. Antes que nada: qué NO se copia

**Credenciales, nunca.** Cada locación autentica sola. Si una se ve
comprometida se revoca esa y nada más. Copiar un `auth.json` de una máquina a
otra convierte dos servidores en un solo punto de falla.

Resultó que tampoco hace falta: **opencode Zen da modelos gratis sin
credencial**. Cero configuración.

---

## 1. Base del sistema

    sudo apt-get update -qq
    sudo apt-get install -y build-essential pkg-config libssl-dev git curl jq rsync tmux

**Swap, aunque haya RAM de sobra.** Con 12 GB alcanza para el rustc de 6 GB,
pero sin margen un pico inesperado *mata* el build en vez de hacerlo lento. El
disco sobra:

    sudo fallocate -l 8G /swapfile && sudo chmod 600 /swapfile
    sudo mkswap /swapfile && sudo swapon /swapfile
    echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab

**Rust:**

    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal
    . "$HOME/.cargo/env"

**Las bibliotecas de sistema del proyecto.** Si no, el build falla a los 47
segundos con `glib-2.0 not found` y parece un problema de Rust:

    sudo apt-get install -y libglib2.0-dev libgtk-3-dev libwebkit2gtk-4.1-dev \
      libsoup-3.0-dev libjavascriptcoregtk-4.1-dev librsvg2-dev patchelf \
      libayatana-appindicator3-dev

---

## 2. Postgres con PostGIS

Los macros de sqlx verifican las consultas **contra una base viva en tiempo de
compilación**. Sin base, el build muere con `Connection refused` en cada
query — 54 errores que no tienen nada que ver con el código.

    sudo apt-get install -y postgresql postgresql-contrib postgis postgresql-14-postgis-3
    sudo systemctl enable --now postgresql
    sudo -u postgres psql -c "CREATE ROLE agp LOGIN PASSWORD '<del entorno>'"
    for db in agp ux; do
      sudo -u postgres createdb -O agp $db
      sudo -u postgres psql -d $db -c "CREATE EXTENSION IF NOT EXISTS postgis"
    done

Verificar que escucha **sólo en localhost** (`ss -tlnp | grep 5432` → `127.0.0.1`).

> Con caché offline de sqlx (`.sqlx/` en el repo) alcanza `SQLX_OFFLINE=true` y
> la base no hace falta para compilar. **agp la tiene; ux no.** Por eso
> conviene la base igual: es la diferencia entre "compila" y "no compila".

---

## 3. Acceso al repo: deploy keys, una por repo

**Una deploy key sirve para UN repo.** GitHub rechaza la misma clave en un
segundo repo con `key is already in use`. Entonces una clave por repo más
alias de host:

    ssh-keygen -t ed25519 -N "" -f ~/.ssh/id_agp
    ssh-keygen -t ed25519 -N "" -f ~/.ssh/id_ux
    ssh-keyscan -t ed25519 github.com >> ~/.ssh/known_hosts

    cat > ~/.ssh/config <<'EOF'
    Host github-agp
      HostName github.com
      User git
      IdentityFile ~/.ssh/id_agp
      IdentitiesOnly yes
    Host github-ux
      HostName github.com
      User git
      IdentityFile ~/.ssh/id_ux
      IdentitiesOnly yes
    EOF
    chmod 600 ~/.ssh/config

Se registran **de sólo lectura** (una locación de build no necesita empujar):

    gh api -X POST repos/<org>/<repo>/keys -f title='VPS' -f key="$(cat ~/.ssh/id_agp.pub)" -F read_only=true

Y **dos clones**, no uno:

    git clone git@github-agp:<org>/<repo>.git ~/repos-agp   # el carril de build
    git clone git@github-agp:<org>/<repo>.git ~/work-agp    # los obreros

Separados a propósito: el carril hace `git reset --hard` en cada corrida y
**le borraría el trabajo sin commitear a los obreros**.

---

## 4. opencode y el modelo

    curl -fsSL https://opencode.ai/install | bash
    mkdir -p ~/.config/opencode
    cat > ~/.config/opencode/opencode.json <<'EOF'
    {
      "$schema": "https://opencode.ai/config.json",
      "model": "opencode/x-preview-f-free",
      "autoupdate": false
    }
    EOF

### El nombre de ox-alpha, que hace perder una tarde

**En opencode Zen, ox-alpha se llama `x-preview-f-free`.** No aparece como
"ox-alpha" en `opencode models` y da toda la impresión de no existir.

Y `opencode-go` **no** es un proveedor remoto: es el router `ocmix` en
`127.0.0.1:8099` de la máquina principal. En una locación nueva no está y no
puede estar, salvo que se monte ocmix ahí con sus propias cuentas.

`opencode models` lista los 7 gratuitos de Zen. No hace falta autenticar.

---

## 5. herdr en ARM

El binario de herdr es específico de arquitectura; `npm i -g herdr` instala un
paquete vacío. Las builds reales están publicadas:

    URL=$(curl -s https://herdr.dev/latest.json | jq -r .assets."linux-aarch64")
    SHA=$(curl -s https://herdr.dev/latest.json | jq -r .sha256."linux-aarch64")
    curl -fsSL "$URL" -o /tmp/herdr.dl
    [ "$(sha256sum /tmp/herdr.dl | cut -d' ' -f1)" = "$SHA" ] || { echo "SHA NO COINCIDE"; exit 1; }
    install -m755 /tmp/herdr.dl ~/.local/bin/herdr

Hay `linux-x86_64`, `linux-aarch64`, `macos-x86_64`, `macos-aarch64` y
`windows-x86_64`. **Verificar el sha siempre**: un binario que se baja de
internet y se corre sin chequear es la definición del problema.

Como servicio, para que vuelva si muere:

    # ~/.config/systemd/user/herdr.service   → Restart=always
    systemctl --user enable --now herdr
    sudo loginctl enable-linger $USER   # sin esto muere al cerrar la sesión SSH

---

## 6. Los obreros, y el saludo que no es cortesía

**Una ventana recién abierta que recibe un pedido largo como primer mensaje se
traba y no contesta nunca más.** Se saluda, se ESPERA la respuesta, y recién
ahí se manda el trabajo.

Medido el 2026-08-26: el mismo modelo rechazó **seis `opencode run` seguidos**
con `UnknownError` y contestó al primer "hola" dentro de la TUI en 1,2
segundos. No era falta de credenciales ni de cuota: era el arranque en frío.

    herdr agent start dev-w1-p1 --kind opencode --pane w1:p1 --timeout 90000 -- --auto
    herdr agent prompt w1:p1 "hola" --wait --until idle --timeout 90000
    herdr pane send-keys w1:p1 enter        # el submit a veces sólo TIPEA
    herdr agent read w1:p1                  # ¿contestó? si no, no le mandes trabajo

Si no contesta, **sesión nueva y de nuevo**, hasta tres veces:

    herdr pane send-text w1:p1 "/new"       # send-text al PANEL
    herdr pane send-keys w1:p1 enter

> `/new` va con **`pane send-text`**, nunca con `agent prompt`. Mandado como
> mensaje, el modelo lo **lee** en vez de ejecutarlo: contesta con toda
> naturalidad y sigue en la misma sesión trabada, con su contexto intacto.
> Medido: 920 k de contexto sin moverse después de tres "sesiones nuevas".

### Cuántos obreros entran

    obreros = (MemAvailable - reserva_de_build) / 750 MB

La reserva **no se negocia**: un rustc del crate grande pica en 6,2 GB, medido.
En 12 GB eso deja 2 o 3 obreros. Poner más es elegir entre trabajar y compilar.

---

## 7. Que se reinicie solo si se tilda

    sudo apt-get install -y earlyoom
    # /etc/default/earlyoom
    EARLYOOM_ARGS="-r 3600 -m 8,4 -n \
      --avoid '^(systemd|sshd|herdr|postgres)$' \
      --prefer '^(rustc|cc1|opencode|node)$'"

**`--avoid` es para lo que no se puede reponer solo**, no para lo que más
memoria usa. Un guardia con prohibido tocar la causa del problema informa
"activo" para siempre y no evita un solo cuelgue: si `opencode` está en
`--avoid` y son los obreros los que llenan la RAM, earlyoom no tiene a quién
matar y la máquina se traba igual. Perder un obrero es recuperable; perder la
locación entera, no.

Y para el cuelgue duro, donde ni earlyoom llega a correr:

    # /etc/sysctl.d/99-watchdog.conf
    kernel.panic = 10               # reiniciar 10 s después de un pánico
    kernel.panic_on_oops = 1
    kernel.hung_task_panic = 1      # una tarea trabada 5 min ES un cuelgue
    kernel.hung_task_timeout_secs = 300

Sin esto, un cuelgue deja el servidor muerto hasta que alguien lo note — que
en una locación remota puede ser mañana.

---

## 8. Endurecer, sin quedarse afuera

Lo que ya viene bien en Oracle Ubuntu: `PasswordAuthentication no` y ningún
usuario con contraseña utilizable. **Una contraseña fuerte no agrega nada
cuando no hay por dónde usarla.**

Lo que hay que agregar:

    sudo sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
    sudo sshd -t && sudo systemctl reload ssh

    sudo apt-get install -y fail2ban
    # /etc/fail2ban/jail.d/sshd.local  →  backend = systemd (sin esto la jaula
    # arranca y muere en silencio en Ubuntu 22.04)

78 intentos de login fallidos **en la primera hora** de vida del servidor. No
es paranoia, es el ruido de fondo de internet.

Si se usa ZeroTier, **aceptar por interfaz**:

    sudo iptables -I INPUT 4 -i ztXXXXXXXX -j ACCEPT
    sudo netfilter-persistent save

Sin esa regla la red se ve "conectada" y no pasa un paquete. Y no es abrir un
puerto al mundo: sólo entra lo que llega por la red privada.

**El 22 se deja abierto** hasta comprobar que se entra por ZeroTier. Cerrarlo
antes es cómo uno se queda afuera de su propio servidor.

> Y en Oracle Cloud hay **dos** cortafuegos: el *Security List* de la consola y
> el `iptables` de la Ubuntu. Abrir uno solo da el síntoma más confuso posible
> — el DNS resuelve perfecto y nada contesta.

---

## 9. Comprobar que sirve

    bash scripts/compilar-en-vps.sh agp --sucio

Tiene que dar un commit, un tiempo y errores reales. Referencia de la primera
locación: **1-2 segundos** el check incremental del workspace completo, con el
árbol sucio incluido.

Y las cuatro guardas del carril, cada una nacida de una falla real:

| si… | pasa esto |
|---|---|
| el VPS no contesta | aborta — un `0` con la red caída le dice a 46 paneles que su código compila |
| el commit base no está allá | aborta — el checkout falla, git se queda en el commit viejo y el parche se aplica encima |
| el checkout no quedó donde se pidió | aborta |
| el parche dejó marcadores `<<<<<<<` | aborta — `--3way` no falla al no fusionar, deja el conflicto adentro del archivo |

**Las cuatro devolvían verde antes de existir.** Ése es el modo de falla a
buscar primero en cualquier locación nueva: no el error ruidoso, sino la
respuesta buena que nadie va a mirar dos veces.
