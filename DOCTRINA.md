# DOCTRINA — cómo trabajamos, con qué, y por qué

> Escrito 2026-08-28 por el jefe-supervisor con el dueño, después de la noche
> de la horda (40 concurrentes), la muerte de la cuota gratis y el rebaraje.
> Este archivo vive en `base` y se re-registra con el mismo nombre en cada
> proyecto. Si algo choca con una costumbre, gana este documento.

---

## 1. Los dos regímenes — y el interruptor eterno

La flota opera en uno de dos modos, y **los dos son ciudadanos de primera**:

| | METRALLETA (`gratis`) | FRANCOTIRADOR (`pago`) |
|---|---|---|
| Cuándo | Apareció un modelo gratis usable (otro ox-alpha) | Se paga por token (estado normal) |
| Límite | **RAM, target 90 %** de uso | **Presupuesto**: tope de devs concurrentes + USD/día |
| Saludo de aceite ("hola") | SÍ — calienta la ventana | NO — cada mensaje cuesta |
| Reapertura | Agresiva: se cierra uno, se abre otro | Sólo hasta el tope; sesión nueva a ~50k tokens salvo tarea compleja |
| Tablero | Se llena mecánicamente (autoservicio, escalera) | Curado: ítems grandes, bien especificados, verificables |
| Espíritu | Volumen: 40 cañones empujando | Precisión: pocos tiros, todos al MVP |

- Interruptor: `~/.config/flota/modo` (`pago`/`gratis`). **Pago por defecto**:
  sin señal explícita, config ilegible o modelo desconocido = pago.
  Equivocarse hacia gratis regala plata.
- La era metralleta (ox-alpha, 2026-08) **funcionó de maravilla** y queda
  documentada como capacidad, no como nostalgia: si vuelve la oportunidad, es
  UN comando y la maquinaria de volumen revive entera.

## 2. Medir todo, decidir por USD-por-resultado

- La métrica que decide es **USD por ítem cerrado** (y su hermana ítems/hora),
  no el precio de lista del token. `medir-modelo.sh informe` es la fuente.
- Hipótesis vivas se prueban con protocolo, no con fe: mismo lote de ítems,
  dos modelos, comparar USD/ítem y calidad de cierre. Hipótesis abierta del
  dueño: *GLM 5.3 Flash parece caro pero quizá resuelve más por dólar que
  MiMo 2.5*. MiMo anda muy bien; el motor de freebuff vuela. Se mide, no se
  discute.
- El jefe necesita ver estos números (hoy no los ve — pidió exactamente esto).
  El Contador de rodeo (§4) se los sirve.

## 3. Las reglas de conducta que pagamos con sangre

1. **No se pregunta permiso, se avanza.** Un dev parado esperando confirmación
   cuesta más que un camino subóptimo commiteado y corregible.
2. **Un ítem, un tablero.** Duplicar tableros = pagar el mismo trabajo 2-3
   veces (pasó: dólar pizarra × 3).
3. **Commitear seguido, por archivo nombrado.** La cuota muere sin avisar y el
   árbol compartido con curas sin commitear tuvo al CI rojo 8 horas — dos veces.
4. **Tres resultados, nunca dos**: SÍ / NO / NO PUDO MEDIRSE. La falla muda es
   el enemigo número uno (backups que "están", checks que miran 1 de 8 crates,
   "verificado con grep" sobre columnas que se siguen leyendo).
5. **La pantalla es la evidencia final** sobre el estado de un agente: el
   estado que reporta el harness miente en las dos direcciones.
6. **Quien compila manda**: una máquina, un compilador; en la máquina de CI el
   build apaga la flota y la revive al terminar (mecanismo, no regla escrita).
7. **Ningún commit vive en una sola máquina.** Rescate diario de clones que no
   pueden pushear.
8. **Un backup sin restore probado no es backup.**
9. **`.logs` es el contrato.** La deriva "un dev implementó colas en vez de
   .logs" pasó porque la regla estaba escrita pero no verificada: todo
   proyecto nuevo corre el verificador del kit (`instalar-flota` chequea la
   estructura) antes del primer ítem.
10. **Sin jerga de campo en las herramientas.** Pausa se llama pausa.

## 4. Las herramientas: hoy, y hacia dónde

**Hoy (shell, funciona pero frágil):** tablero.sh (fuente de trabajo, formato
probado y atómico), autopiloto/látigo (reparto), jefe.sh + reloj (reposición),
asegurar-jefe (si no hay jefe se crea solo), vigia-local (aprieta los Enter de
sesiones agotadas sin gastar tokens), harness.sh (la capa que habla con los
panes, con la guardia: **jamás tipear a un bash pelado**, marcador de ocupado,
detección de devs por proceso→descendientes→pantalla, parametrizable con
`DEVS_RE` / `DEVS_PANTALLA_RE` para cualquier app nueva).

**Hacia dónde — RODEO (demonio Rust) + caras múltiples.** La lógica frágil
(parsear pantallas, estado disperso, sin noción de presupuesto) se reemplaza
por un binario con estado propio y API. Decisión de arquitectura: **híbrido** —
rodeo es el cerebro, y las caras se enchufan a su API:

- **Registro de devs**: pane, proceso, modelo, sesión, tokens, costo, estado
  verificado por evidencia.
- **Reparto por protocolo**: verifica TUI viva antes de entregar, maneja
  "Press Enter to continue", confirma recepción. Nunca texto a ciegas.
- **Pausa** (así se llama): global o por dev, un comando y un botón. Y
  **corte automático**: N fallos seguidos de un modelo → ese frente se pausa
  solo y avisa UNA vez — nunca más la lluvia de mensajes imposible de frenar.
- **Contador de presupuesto**: tope de devs, USD/día, sesión fresca a ~50k
  tokens, cierre del dev que engorda, y el informe USD-por-resultado servido
  al jefe y al dueño.
- **Ciclo de vida**: si deben ser N y hay N-1, abre uno (`opencode --auto`
  verificado después de arrancar); freebuff agotado recibe su Enter; muerto →
  renace. En régimen gratis, N lo pone la RAM (90 %); en pago, el presupuesto.
- **API chica (HTTP/socket)** para las caras: **paseo** (seguimiento desde el
  celular) como cara primera; la visión de **dos apps Tauri** conectadas por
  API (nuestro stack de siempre); y **tuti** (voz) para hablar con el jefe y
  que el jefe conteste — la conversación natural con el dev jefe como
  interfaz. Evaluar antes de construir cada pieza: si un harness existente
  (el que el dueño llama "el de DeepSeek" — identificar cuál es) ya resuelve
  algo de esto, se adopta o se copia con cita.
- Los scripts actuales quedan como fallback documentado; rodeo se los come de
  a uno, reparto primero (donde más sangra).

## 5. Multi-proyecto y la sinergia que vende

Cada proyecto trabaja **separado** (su tablero, su jefe, su flota) pero los
jefes **pueden hablar entre sí** — como conectar dos Claude, y mejor. Casos
que son producto, no capricho técnico:

- **AGP ⇄ UX (contable)**: el productor carga en AGP; su contador ve todo en
  UX. La contabilidad viaja sola: el productor no llama, el contador no
  transcribe.
- **Sueldos**: el dueño del negocio anota "Pedro no vino hoy" (sistema o
  WhatsApp); el contador recibe novedades, liquida 931 e impuestos; el dueño
  ve qué transferir a cada empleado. Cero teléfono.
- **Seguros/ART**: el lote ya está geolocalizado en AGP — el broker no busca
  el campo en Google Earth: asegura EXACTAMENTE ese polígono. Menos fraude,
  menos error, todos tranquilos.

**El canal de venta es el contador.** El mercado ya validó el modelo:
[Xubio](https://xubio.com/ar/contadores) construyó 50.000+ empresas cliente
sobre 6.000 estudios contables como canal, y [Colppy](https://colppy.com/contadores)
compite igual. Nuestra jugada: al contador se le regala o se le da precio de
canal (decisión del dueño abierta: gratis / conveniente / un mes gratis por
cliente recomendado), y cada contador trae N productores. La competencia agro
directa — [Albor](https://alboragro.com/software-lider-gestion-agropecuario/)
(30+ años, cotización a medida), Auravant, FieldView,
**VISUAL Gestión Agro (VGA — exactamente el sistema cuya paridad venimos
construyendo ítem por ítem)**, GestionPlay — no tiene esta integración
contador⇄productor⇄sueldos⇄seguros. Ésa es la diferencia que vende: sinergia,
no features sueltas.

## 6. Nevera → etapas (nunca freezer)

Los ítems que no entran en la etapa actual **no se archivan a morir**: se
clasifican con evidencia (contra el código, no a ojo) y se **asignan a una
etapa futura del roadmap** en el mismo acto. Lo bueno y corto se hace ya —
"si es bueno y sale en un ratito, se hace, no se congela". El análisis no se
patea para adelante: la clasificación ES el análisis.

## 7. La herramienta, decidida (2026-08-28): climax es la base

Investigado [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness)
(dsh): 200k estrellas, MIT, todo-es-plugin, CLI+Web UI. Veredicto: es un
**runtime de UN agente** (con subagentes), en developer preview — no tiene
tablero, ni presupuesto, ni pausa, ni ciclo de vida de N devs. Lo que nos
falta es exactamente la capa que dsh no tiene. No se forkea ni se tuerce la
trayectoria; se re-evalúa a futuro como runtime de devs o escribiendo un
dsh-plugin que exponga los nuestros.

**La base es [climax](../climax)** — ya maduro, empaquetado (instalador,
systemd opt-in), habla herdr, y su función original ES una de las pedidas:
vigilar la ventana de cuota por el statusLine oficial (sin scrapear pantallas)
y **reactivar agentes cuando la ventana reabre**, delegando tareas pendientes
antes de morir. Fácil de arrancar, fácil de detener, entendible. Sobre esa
base se agregan, en orden: `climax pause/resume` (global y por agente — lo
primero), el contador de presupuesto (tope de devs, USD/día, sesión fresca a
~50k, informe USD-por-resultado), el ciclo de vida de N devs, y el reparto por
protocolo. **rodeo** ya existe como la cara móvil (server sobre el socket de
herdr → app de bolsillo): queda como UI de climax, no como proyecto aparte.
El nombre final no importa ahora. **idge (ia-bridge)** — los jefes de
proyectos distintos hablándose — nace después como módulo de esta misma base
(Etapa 3). Abierta: la key de Claude directa en opencode vs la interfaz de
Claude Code — medir qué se gana/pierde (contexto, herramientas, costo).

**Devs locales primero, nube switcheable**: la flota corre local (el 13700K);
el VPS es espejo y refugio (corte de luz programado = seguir desde la nube).
El objetivo: cambiar local⇄nube con un comando.

## 8. El canal profesional y el costo por usuario

- **Se entra por el profesional**: contador, abogado, ingeniero agrónomo,
  veterinario — tienen la cartera de clientes y el dolor administrativo.
  Acopios/consignatarios: quizá no como canal (se sientan sobre el dinero,
  demasiados intereses) pero sí como usuarios. **ESTUDIAR cómo lo hacen los
  demás, local e internacional** (Xubio/Colppy acá; QuickBooks ProAdvisor,
  Xero Partner Program afuera) antes de definir el nuestro.
- **Se vende el dolor aliviado, no el sistema**: para cada tipo de usuario,
  qué le morigeramos. Lo que hace el software es irrelevante en la venta.
- **Costo por usuario, medido**: un contador con 50 clientes o un acopio
  pueden costarnos mucho más (DB, disco) que un productor chico. Antes de
  regalar nada: saber el costo. "Lo gratis nunca es valorado" — si se regala,
  es gasto de publicidad consciente, no generosidad ciega.
- **Programa de benchmark permanente** (fanatismo por performance y costo):
  auditoría continua de qué impacto tiene cada cosa en performance,
  escalabilidad, disco y RAM. Medir cuánto rinde el hosting actual (12 GB /
  2 ARM) y derivar la unidad económica: **usuarios por núcleo A1 + 1 GB RAM +
  disco**, proyectado a 2 años de datos acumulados. Ese número define
  precios, planes y qué se puede regalar.

## 9. El futuro sinérgico (registrado para no perderse)

La visión completa, con los pies del presente: un club con punto de venta de
café y comidas; la oficina registra compras y gastos; la contabilidad le
LLEGA al contador sin que nadie mande un archivo; el cliente ve los VEP a
pagar en la misma app; notificación al encargado: "hoy vence el 931 —
¿pagar?" → la API del banco ejecuta el pago. Contador, sueldos, seguros
geolocalizados, pagos: el mismo patrón — **la información viaja sola entre
las partes que hoy se persiguen por teléfono**. Es Etapa 3+ del roadmap; se
construye cuando el presente esté redondo.

## 10. La cara del taller — visión de UI (para futuro, no YA)

Registrado 2026-08-28 del dueño, para construir DESPUÉS del demonio (climax).
La versión alfa puede hardcodear; el diseño se piensa así desde ahora:

- **El jefe siempre visible**: un panel fijo (ocultable) del jefe — por
  defecto a la izquierda — y N paneles agrupables de workers al lado.
  Orientación vertical/horizontal como setting, no como destino.
- **Botones [1] [2] [3] junto al panel del jefe**: eligen cuántos workers se
  muestran en el resto de la pantalla (jefe + 1, jefe + 2, jefe + 3…).
- **Barra inferior de workers** (estilo "20 background workers" de Claude):
  todos los devs con su título; click → o un selector, o salir del zoom a
  pantalla dividida jefe+workers.
- **Usabilidad que hoy duele en herdr**: cerrar un panel PIDE CONFIRMACIÓN
  (está al lado de zoom y se toca por error); un click en un panel = zoom;
  atajos simples: ALT+1/2/3… (ALT+F1… si son muchos).
- **Detección de ventanas MODULAR, sin recompilar**: si hoy el dev se llama
  freebuff y pide Enter, y mañana se llama rifuff y pide Escape, eso se
  agrega por CONFIGURACIÓN (perfiles de app: nombre de proceso, firma de
  pantalla, tecla de reactivación) — nunca tocando código. Es la
  generalización de lo que ya hacen `DEVS_RE`/`DEVS_PANTALLA_RE` en el
  harness de shell: el demonio la hereda como principio de diseño desde el
  día uno, aunque la alfa traiga los perfiles hardcodeados.
- **El ruidito, silenciable y APAGADO por defecto**: ¿a quién le importa el
  sonido de un worker terminando una tarea? Notificación sonora opt-in.
- **El control del layout en dos estados**, tal cual lo dibujó el dueño:
  visible `[-][1][2][3]` / oculto `Oculto: [+][1][2][3]` — el [-]/[+]
  colapsa o expande el bloque de workers, los números eligen cuántos.
- **La vara**: apuntar a empresa grande — user-centric, que ENTREGA VALOR.
  Cada decisión de esta cara se juzga con esa vara, no con la comodidad
  del que la programa.
- **¿Web, Tauri o fork de herdr?** Decisión para cuando el demonio exista y
  la API mande: herdr está bien hoy; una web quizá sea mejor, quizá no; un
  fork de herdr con este layout es candidato. La API del demonio hace que la
  elección de cara sea barata y reversible.
