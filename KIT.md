# 📦 Kit de trabajo — metodología, diseño y stack, portable a cualquier repo

Esto es lo que aprendimos haciendo funcionar una cuadrilla de agentes en
paralelo sobre un producto real. **Nada de acá depende de nuestro dominio.**
Copiá la carpeta a otro repo y sigue valiendo.

## Qué hay

| Archivo | Qué contesta |
|---|---|
| **`JEFE-LEEME.md`** | **Si sos el jefe, empezá acá.** Qué cambió en tu trabajo: dejaste de repartir y pasaste a llenar el tablero. Con los dos fracasos que lo motivaron. |
| **`METODOLOGIA.md`** | Cómo se trabaja: dónde termina el proyecto, cómo se delega, cómo no queda nadie ocioso, qué se testea. **Empezá por acá.** |
| **`MIGRACION_LEGACY.md`** | **Si el proyecto reemplaza un sistema que ya funciona, empezá acá.** Las seis etapas, cómo se decide qué está vivo y qué es escombro, y el puente que hace barata la segunda migración. |
| **`INTERFAZ.md`** | La forma exacta: menú, formularios con URL propia, dos botones, filtros, buscador, colores y las piezas compartidas. Se copia tal cual. |
| **`DESIGN.md`** | **El canon vivo del diseño.** Las reglas de interfaz que sobreviven al proyecto, con los bugs reales que las motivaron. Antes de tocar una pantalla, se lee esto. |
| `DESIGN_SYSTEM.md` | Los tokens y componentes concretos. Se lee DESPUÉS de `DESIGN.md`, que es el que manda. |
| **`STACK.md`** | Qué tecnología y por qué — incluida la lista de **lo que NO está instalado**, que es la que evita que alguien importe algo que no existe. |
| `scripts/` | Los scripts que hacen que el mecanismo sea un proceso y no una intención. |
| `plantillas/` | Los archivos que el equipo necesita el día uno. |

## Instalarlo en un repo nuevo

```bash
bash export/scripts/instalar.sh /ruta/al/repo 8444
```

Un comando. Copia los scripts sin pisar lo que el repo ya tenga propio, crea
las carpetas, deja `scripts/colas.conf` vacío (que es un estado válido y el
más simple: sin colas personales, todos los paneles comen del tablero) y
escribe dos servicios de usuario con puerto propio, para que convivan varios
proyectos en la misma máquina. **No arranca nada**: un demonio que arranca en
medio de una instalación a medio hacer le manda prompts a paneles que todavía
no son de nadie.

Después, lo que el instalador te dice: abrir el puerto **sólo en la VPN**,
`systemctl --user enable --now celu-<repo> autopiloto-<repo>`, y probar en
seco con `AUTOPILOTO_SECO=1`, que no manda nada y te dice qué haría.

Y una sola decisión de contenido: **completá `docs/jefe.md`** (quién recibe los
avisos). Las colas personales son opcionales.

## Los scripts

| Script | Qué hace |
|---|---|
| **`harness.sh`** | **La capa agnóstica.** Aísla las únicas tres cosas que el mecanismo necesita de la herramienta que corre los agentes. Cambiar de herramienta es tocar este archivo y ninguno más. |
| **`tablero.sh`** | La fuente de trabajo. `add` / `bulk` / `take` (atómico) / `done` / `soltar` / `devolver` / `huerfanos` / `trabados` / `revivir`. `soltar` cobra el intento —el pedido llegó y el panel no lo cerró—; `devolver` no —el pedido nunca llegó—. |
| **`autopiloto.sh`** | Reparte: cola personal → tablero → silencio. Con las tres válvulas anti-acoso. |
| **`celu.py`** | La pantalla y la boca en el celular, por VPN. Se dicta un pendiente y cae en el tablero. |
| **`saludar-dev.sh`** | **El ritual, antes de cada pedido.** ¿Existe la ventana? ¿Hay un dev corriendo adentro —o abro `opencode --auto`? ¿La pantalla muestra un rechazo —o hago `/new`? Y entonces **"hola", esperando la respuesta**. Sin esto los repartidores escriben a ventanas cerradas y el ítem se muere tomado por un panel que no existe. `--revisar` da el informe de toda la flota. Ver [SALUDAR-AL-DEV.md](SALUDAR-AL-DEV.md). |
| **`saludar-agentes.sh`** | El mismo saludo pero en lote, a mano: a todos los ociosos, o a los que le nombres. Con `--nuevo` es el rescate del panel trabado. |
| **`jefe.sh`** | **El reloj del jefe.** Lo despierta cada tanto con la siguiente acción ya decidida: reponer si el tablero está bajo, o subir un escalón de la escalera de mejora. Es lo que hace que no se detenga. |
| `avisar-jefe.sh` | El panel que cierra un bloque avisa, con escalado jefe → subjefe → disco. |
| `mandar-a-panel.sh` | Mandar un mensaje a un panel: saluda al dev, envía, aprieta Enter y **verifica que arrancó**. |
| `instalar.sh` | Todo lo anterior andando en otro repo, en un comando. |

## Cambiar de herramienta de agentes

Todo lo que toca la herramienta pasa por `harness.sh`, que expone exactamente
tres funciones y nada más:

```
harness_list                 -> "panel<TAB>estado<TAB>directorio" por línea
harness_prompt <panel> <txt> -> le manda trabajo; sale 0 si ARRANCÓ
harness_read   <panel> [n]   -> las últimas n líneas de su terminal
```

Vienen tres backends: **herdr** (el que usamos), **tmux** pelado (sirve para
probar el kit en cualquier máquina, sin instalar nada) y **custom**, que son
tres variables de entorno con los comandos de la herramienta que sea. Se elige
con la variable `HARNESS` o con el archivo `.harness` del repo.

El cuarto campo de `harness_list` es la **clase** de panel, y existe por algo
que costó dos noches de paneles parados. No todo panel es un agente que la
herramienta sepa manejar: algunos corren un TUI a secas y para el harness son
una terminal común — aparecen en la lista de panes pero no en la de agentes.
Todo lo que se apoyaba en la lista de agentes **no los veía**, así que nunca
recibían trabajo y nadie se enteraba; el dueño encontró dos quietos de
casualidad y les pegó el pedido a mano.

| Clase | Qué es | Cómo se le habla |
|---|---|---|
| `agente` | El caso normal: la herramienta lo maneja | Arranca solo |
| `manual` | Un TUI que el harness no maneja | Por teclado, con foco y ritual |

A un panel manual hay que **enfocarlo, despertarlo con un Enter, pegarle el
texto y mandarlo con otro Enter**, verificando por lectura entre paso y paso —
y devolverle el foco al dueño. Si aun así no arranca, el texto queda puesto y
se avisa (`HARNESS_AVISAR`): un fallo se cuenta, no se calla. El detalle
completo, con las cinco formas en que esto falla en silencio, está en la
sección de paneles manuales de `harness.sh`.

**Un panel que el mecanismo no sabe manejar tiene que aparecer igual, marcado.
Invisible es la peor forma de estar roto**, porque no hay ni un error que
buscar.

Dos detalles más del contrato que parecen menores y no lo son:

- **`harness_prompt` devuelve si arrancó, no si se mandó.** En estas
  herramientas el texto queda TIPEADO en el panel y el agente sigue ocioso
  hasta que llega un Enter aparte. Se pierden horas creyendo que hay cuatro
  agentes trabajando cuando hay cuatro esperando que alguien apriete Enter.
- **El directorio de trabajo va en la lista.** En una misma sesión conviven
  paneles de varios repos. Sin ese dato, el autopiloto de un proyecto le manda
  su trabajo a los devs de otro. Nos pasó.

## La trampa que te va a morder el primer día

**Mandar el texto NO es mandarlo.** En estas herramientas el prompt queda
TIPEADO en el panel y el agente sigue ocioso hasta que llega un Enter aparte.
Se pierden horas creyendo que hay cuatro agentes trabajando cuando hay cuatro
esperando que alguien apriete Enter.

Por eso los scripts hacen siempre lo mismo: **mandar → Enter → verificar que el
panel pasó a "trabajando"**. Si sigue ocioso, reintentan el Enter.

## El tablero, en tres líneas

Un panel libre busca trabajo en su cola personal; si no tiene, en el tablero;
si el tablero está vacío, **se queda quieto y nadie lo molesta**. El tablero se
llena dictándole al celular. Un ítem que se repartió tres veces sin cerrarse
queda trabado y deja de repartirse, porque un ítem que rebota es un ítem mal
escrito, no un panel vago.

## Si leés un solo párrafo, que sea este

Escribí dónde termina el proyecto y qué NO entra. No dejes a nadie ocioso —con
un guardián, no con una regla escrita, porque la regla depende de que alguien
mire y el día que no mira nadie se rompe—. Arreglá en vez de documentar. Medí
con un solo termómetro. Y testeá lo que calcula dinero o cantidades que
deciden: **un test que falla es un bug encontrado, no un incordio.**
