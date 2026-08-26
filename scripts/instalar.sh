#!/usr/bin/env bash
# instalar.sh — deja el mecanismo andando en otro repo en un solo comando.
#
#   bash export/scripts/instalar.sh /ruta/al/repo [puerto-celu]
#
# Qué hace y por qué en este orden:
#   1. Copia los scripts (harness, tablero, autopiloto, celu, avisar, mandar).
#   2. Crea .logs/pedidos, .logs/tablero y .tmp.
#   3. Deja scripts/colas.conf VACÍO con el formato explicado. Vacío es un
#      estado válido: sin colas personales, todos los paneles comen del
#      tablero, que es el modo más simple y el que menos se rompe.
#   4. Escribe el .service de usuario de la pantalla del celu con un puerto
#      propio, para que convivan varios proyectos en la misma máquina.
#   5. NO arranca nada: el que instala decide cuándo. Un demonio que arranca
#      solo en medio de una instalación a medio hacer manda prompts a paneles
#      que todavía no son de nadie.
set -euo pipefail

DESTINO="${1:?uso: instalar.sh /ruta/al/repo [puerto-celu]}"
PUERTO="${2:-8443}"
ORIGEN="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NOMBRE="$(basename "$(cd "$DESTINO" && pwd)")"

[ -d "$DESTINO" ] || { echo "no existe $DESTINO" >&2; exit 1; }
mkdir -p "$DESTINO/scripts" "$DESTINO/.logs/pedidos" "$DESTINO/.logs/tablero" "$DESTINO/.tmp"

# El kit completo. Las cuatro últimas se agregaron el 2026-08-24 y son las que
# más se extrañan en una máquina nueva: sin one-at-a-time.sh doce paneles
# deciden compilar a la vez y la máquina se congela; sin latigo.sh un panel que
# queda ocioso sin avisar no lo levanta nadie.
#
# Los seis últimos son los que hacen que el proyecto arranque solo:
#   arrancar.sh      un comando, de repo instalado a flota trabajando
#   poblar-flota.sh  abre tantos obreros como la RAM aguante, ni uno más
#   motores.sh       reparte con las válvulas en cero, nadie parado
#   jefe.sh          el reloj del jefe y la escalera de mejora
#   foco.sh          devuelve el foco que la maquinaria le saca a la persona
#   saludar-agentes.sh  el primer mensaje a una ventana nueva es "hola"
for f in harness.sh tablero.sh autopiloto.sh celu.py avisar-jefe.sh mandar-a-panel.sh \
         nadie-ocioso.sh latigo.sh one-at-a-time.sh vigilar-paneles.sh wait-panel.sh \
         arrancar.sh poblar-flota.sh motores.sh jefe.sh foco.sh saludar-agentes.sh \
         autoservicio.sh; do
  # No se pisa lo que el repo ya tiene propio: avisar-jefe.sh suele estar
  # adaptado a los paneles de ese equipo, y pisarlo deja los avisos mudos.
  if [ -e "$DESTINO/scripts/$f" ] && [ "${FORZAR:-0}" != "1" ]; then
    echo "  = $f ya existe, no lo piso (FORZAR=1 para pisarlo)"
  else
    cp "$ORIGEN/$f" "$DESTINO/scripts/$f"; chmod +x "$DESTINO/scripts/$f"
    echo "  + $f"
  fi
done

# ── Las plantillas de docs/ ────────────────────────────────────────────────
# Sin docs/jefe.md, avisar-jefe.sh no tiene a quién leer y todo aviso se
# escala al vacío en silencio. El instalador lo pedía por pantalla y no lo
# creaba, que es la peor combinación: parece hecho y no está.
PLANTILLAS="$(cd "$ORIGEN/../plantillas" 2>/dev/null && pwd)"
if [ -n "$PLANTILLAS" ]; then
  mkdir -p "$DESTINO/docs"
  for t in "$PLANTILLAS"/*.md; do
    [ -e "$t" ] || continue
    d="$DESTINO/docs/$(basename "$t")"
    if [ -e "$d" ]; then echo "  = docs/$(basename "$t") ya existe, no lo piso"
    else cp "$t" "$d"; echo "  + docs/$(basename "$t")"; fi
  done
fi

if [ ! -f "$DESTINO/scripts/colas.conf" ]; then
  cat > "$DESTINO/scripts/colas.conf" <<'CONF'
# Colas personales, una línea por panel:
#     panel|pedido1.md|pedido2.md|...
# Los .md viven en .logs/pedidos/. Un panel que no figure acá igual trabaja:
# va directo al tablero. Empezar VACÍO está bien y es lo recomendado — las
# colas personales sólo valen cuando un dev es dueño de un área y el orden
# importa.
CONF
  echo "  + scripts/colas.conf (vacío)"
fi

if [ ! -f "$DESTINO/scripts/no-repartir.conf" ]; then
  cat > "$DESTINO/scripts/no-repartir.conf" <<'NOREP'
# Paneles que el autopiloto NO debe tocar nunca. Un id por línea.
#
# El panel del jefe no es un obrero: es la conversación viva con el dueño.
# Mandarle un ítem del tablero no es delegar, es interrumpir una charla.
# (Los paneles marcados como jefe/subjefe en docs/jefe.md ya se excluyen solos;
# esto es para el resto: la sesión interactiva del dueño, un panel prestado.)
#
# ⚠️ El id de la sesión del dueño CAMBIA cada vez que abre una sesión nueva.
# Si al jefe le empiezan a llegar ítems del tablero, es esta línea la que
# quedó vieja.
NOREP
  echo "  + scripts/no-repartir.conf"
fi

# El harness elegido queda escrito en el repo, no en la cabeza de nadie.
[ -f "$DESTINO/.harness" ] || { echo "${HARNESS:-herdr}" > "$DESTINO/.harness"; echo "  + .harness (${HARNESS:-herdr})"; }

UNIT="$HOME/.config/systemd/user/celu-$NOMBRE.service"
mkdir -p "$(dirname "$UNIT")"
cat > "$UNIT" <<UNITEOF
[Unit]
Description=La cuadrilla en el celu — $NOMBRE
After=network-online.target

[Service]
Type=simple
Environment=PATH=%h/.local/bin:/usr/local/bin:/usr/bin:/bin
Environment=CELU_PORT=$PUERTO
Environment=CELU_REPO=$(cd "$DESTINO" && pwd)
Environment=CELU_NOMBRE=$NOMBRE
WorkingDirectory=$(cd "$DESTINO" && pwd)
ExecStart=/usr/bin/python3 $(cd "$DESTINO" && pwd)/scripts/celu.py
Restart=always
RestartSec=5

[Install]
WantedBy=default.target
UNITEOF
echo "  + systemd --user: celu-$NOMBRE (puerto $PUERTO)"

# El reloj del autopiloto. Se instala como servicio propio y no como un
# `while` suelto en una terminal: un bucle lanzado a mano muere con el SIGHUP
# de la sesión que lo lanzó, y el equipo se queda parado sin que nadie se
# entere. Esto se relanza solo.
LOOP="$HOME/.config/systemd/user/autopiloto-$NOMBRE.service"
cat > "$LOOP" <<LOOPEOF
[Unit]
Description=Autopiloto — nadie ocioso con trabajo pendiente ($NOMBRE)
After=network-online.target

[Service]
Type=simple
Environment=PATH=%h/.local/bin:/usr/local/bin:/usr/bin:/bin
Environment=AUTOPILOTO_LOG=%h/.logs-vigilante/autopiloto-$NOMBRE.log
WorkingDirectory=$(cd "$DESTINO" && pwd)
ExecStart=/usr/bin/bash -c 'while true; do bash $(cd "$DESTINO" && pwd)/scripts/autopiloto.sh; sleep \${AUTOPILOTO_INTERVALO:-20}; done'
Restart=always
RestartSec=10

[Install]
WantedBy=default.target
LOOPEOF
echo "  + systemd --user: autopiloto-$NOMBRE (cada 20 s)"

# ── El látigo: por repo, igual que el autopiloto ────────────────────────────
# Un bucle `while true` a mano fue el que quedó apuntando a un latigo.sh
# borrado y falló en silencio 240 s por vez durante horas. Una unidad de
# systemd deja rastro en el journal cuando el ExecStart no existe.
WHIP="$HOME/.config/systemd/user/latigo-$NOMBRE.service"
cat > "$WHIP" <<WHIPEOF
[Unit]
Description=Latigo ($NOMBRE) - levanta paneles ociosos que no avisaron

[Service]
Type=simple
WorkingDirectory=$DESTINO
ExecStart=/bin/bash -c 'while true; do timeout -k 20 240 bash $DESTINO/scripts/latigo.sh --una; sleep 120; done'
Restart=always
RestartSec=10

[Install]
WantedBy=default.target
WHIPEOF
echo "  + systemd --user: latigo-$NOMBRE (barrido cada 120 s)"

# ── Lo que va UNA VEZ POR MÁQUINA, no por repo ─────────────────────────────
# ram-watch y protect-panels cuidan la máquina entera, no un proyecto. Sin
# ellos, en una máquina nueva el OOM killer se come los paneles (que es el
# trabajo) y deja vivos los compiladores (que causaron la escasez).
MAQUINA="$(cd "$ORIGEN/../maquina" 2>/dev/null && pwd)"
if [ -n "$MAQUINA" ] && [ -d "$MAQUINA" ]; then
  if [ -f /etc/systemd/system/ram-watch.service ]; then
    echo "  = cuidado de máquina ya instalado (ram-watch), no lo toco"
  else
    KIT_MAQ="$HOME/.local/share/flota"
    mkdir -p "$KIT_MAQ"
    cp "$MAQUINA"/*.sh "$KIT_MAQ"/ && chmod +x "$KIT_MAQ"/*.sh
    for u in ram-watch protect-panels; do
      for e in service timer; do
        [ -f "$MAQUINA/$u.$e" ] || continue
        sed -e "s#@@KIT@@#$KIT_MAQ#g" -e "s#@@USUARIO@@#$USER#g" -e "s#@@REPO@@#$DESTINO#g" \
            "$MAQUINA/$u.$e" > "/tmp/$u.$e"
      done
    done
    echo "  + cuidado de máquina preparado en $KIT_MAQ y /tmp/*.service|timer"
    echo "    instalalo con:  sudo cp /tmp/{ram-watch,protect-panels}.{service,timer} /etc/systemd/system/ &&"
    echo "                    sudo systemctl daemon-reload &&"
    echo "                    sudo systemctl enable --now ram-watch.timer protect-panels.timer"
  fi
fi

cat <<FIN

Listo. Falta que vos hagas tres cosas:

  1. Abrir el puerto SÓLO en la VPN (nunca a la LAN ni a internet):
       sudo ufw allow from <subred-vpn> to any port $PUERTO proto tcp

  2. Arrancar la pantalla del celu:
       systemctl --user enable --now celu-$NOMBRE
       systemctl --user status celu-$NOMBRE     # ahí sale la URL con el token

  3. Arrancar el autopiloto y el látigo:
       systemctl --user enable --now autopiloto-$NOMBRE latigo-$NOMBRE
       tail -f ~/.logs-vigilante/autopiloto-$NOMBRE.log

  4. Si es una máquina nueva, el cuidado de RAM y OOM (una vez por máquina,
     no por repo) — el instalador ya te dejó los comandos arriba.

Y una decisión de contenido: completá docs/jefe.md con quién recibe los
avisos. Un jefe por proyecto; el archivo es la fuente única y ningún script
hardcodea el panel, porque los ids cambian cada vez que se recrea uno.

Probá primero en seco, que no manda nada y te dice qué haría:
     AUTOPILOTO_SECO=1 bash $DESTINO/scripts/autopiloto.sh && tail ~/.logs-vigilante/autopiloto.log
FIN
