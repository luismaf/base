# ⚡ Cómo se trabaja con una cuadrilla de agentes

> **Un solo archivo.** Si sos un agente que arranca en un proyecto, leé esto y
> ya sabés cómo se juega. No hace falta nada más para empezar a producir.
>
> **Vale para todos, incluido el jefe.** Las reglas no son para los devs: son
> para cualquiera que toque el repo. El jefe se las aplica primero, porque es
> el que las repite.
>
> **Es agnóstico al proyecto a propósito.** No menciona tablas ni pantallas de
> nadie. Los ejemplos son casos reales de un sistema de gestión real
> —ahí están para que se entienda qué se rompía, que es lo que hace que una
> regla se recuerde— pero ninguna regla depende de ese dominio.

---

## Dos frenos que hay que soltar cuando los obreros son gratis

Los descubrimos con paneles parados y trabajo esperando al lado.

**Las válvulas del reparto están calibradas para obreros que se pagan.** La
gracia (esperar a que un panel lleve rato quieto) y el enfriamiento (no mandarle
dos veces seguidas) existen para no acosar y no gastar de más. Con obreros
gratis están al revés: un panel parado con treinta ítems en la cola no es
prudencia, es desperdicio. **Con obreros ilimitados, gracia y enfriamiento van a
cero.** Fue exactamente eso: tres paneles quietos con treinta y un ítems
esperando, y con las válvulas en cero salieron los tres en el mismo segundo.

**Y el reparto entrega de a poco por pasada**, así que una sola no alcanza. Hay
que barrer en bucle hasta que no quede nadie libre o se vacíe el tablero.

**El otro freno es el foco.** Mandarle un mensaje a un panel a veces necesita
enfocarlo, y eso le roba la pantalla a la persona que está trabajando en la suya
—incluso en otro espacio de trabajo. Antes de cada vuelta se anota quién tenía el
foco y al terminar se le devuelve. **Que la maquinaria ande no puede costarle la
pantalla al que la está usando.**

`scripts/motores.sh --loop` hace las tres cosas: barre corto, con las válvulas
en cero, y devuelve el foco.

## Y el ocio disfrazado de trabajo, que es peor que el ocio

Un panel apagado se ve. Un panel que corre tests cada dos minutos al pedo, o que
hace un cambio de una línea y compila otra vez, se ve **trabajando**: cuesta lo
mismo, ocupa la máquina, y no figura en ninguna lista de ociosos.

No es maldad del agente. Es lo que hace cualquiera cuando no sabe qué sigue, así
que **cuando lo veas, sospechá del ítem antes que del agente**: uno mal escrito o
ya terminado produce esto casi solo.

Se detecta **por salida, nunca por actividad**. El estado del panel miente —dice
"trabajando" tanto cuando escribe código como cuando mira el mismo error por
quinta vez—; lo que no miente es si los archivos de su zona cambiaron. Ventana
generosa, porque leer y pensar son trabajo y no dejan rastro: lo que se persigue
no es el minuto quieto, es la media hora sin una línea escrita.

Y hay que dejarle al agente una salida honesta, porque si no la tiene finge: si
el ítem está hecho, que lo cierre; si está mal escrito, que lo suelte; si no hay
nada, que lo diga en una línea. **"No tengo nada" es una respuesta correcta.**

`scripts/teatro.sh`.

## Política de empresa: el obrero es barato, el supervisor no

Antes que cualquier otra cosa de este documento, y vale para **todos los
proyectos**, los que existen y los que arranquen.

**Los obreros son agentes baratos; el supervisor es el caro.** Cuando además
corren sobre un modelo ilimitado y gratuito, la aritmética se da vuelta del todo:
un panel apagado no ahorra nada, sólo desperdicia.

1. **Ningún obrero ocioso, nunca.** No es una aspiración: es la política. Un
   obrero parado es la única forma segura de perder plata, y si hay paneles
   apagados ésa es la urgencia, antes que cualquier otra cosa.
2. **Si lo puede hacer un obrero, lo hace un obrero.** Compilar, correr tests,
   escribir código, buscar en el repo, arreglar errores de tipos. El supervisor
   entra sólo donde no hay reemplazo: estrategia, arquitectura, juzgar lo que
   volvió, y mantener la máquina andando.
3. **El proyecto en curso va primero, segundo y tercero.** Siempre hay algo que
   mejorar en el producto que se tiene entre manos. Otro repositorio es la
   últimísima instancia, y sólo para no dejar un panel apagado.
4. **El trabajo no puede depender de que alguien redacte.** Si el proyecto tiene
   un inventario de lo que falta, un script lo convierte en ítems solo. El jefe
   escribe los que requieren criterio; la máquina cubre el piso. Un tablero
   vacío por falta de prosa es un error de diseño, no mala suerte.

Corolario incómodo pero cierto: **un error de compilación no necesita a alguien
caro, necesita a alguien constante.** Por eso compila un obrero con ese rol
permanente y no el supervisor.

## Lo que este documento resuelve

Trabajás con varios agentes en paralelo. Cada uno es capaz. Y sin embargo el
proyecto no termina, hay paneles parados media hora, dos reportan avance con
números que no se pueden comparar, y nadie sabe qué pasó ayer.

Ninguno de esos es un problema de capacidad del modelo. **Los cuatro son
problemas de mecanismo**, y cada uno tiene una pieza acá.

| Síntoma | La pieza |
|---|---|
| "Todo avanza y nunca está listo" | §1.1 — dónde termina, y qué NO entra |
| Paneles parados esperando órdenes | §1.3 — el guardián, no la regla escrita |
| Un pedido vuelve flojo | §2 — las seis partes |
| Nadie sabe qué pasó ayer / se perdió con un `/clear` | §5 — tres archivos versionados |
| Dos números del mismo avance | §6.2 — un termómetro, un denominador |
| Tests verdes y bugs en producción | §7 — lo que calcula plata se testea |

---

## 0. Dónde estás parado

Antes de cualquier regla, una frase escrita: **cuál es la situación real del
proyecto**. La nuestra fue *"somos una startup quedándonos sin efectivo, con
competencia encima y un producto que todavía no le da de comer a nadie"*.

Eso no es color: es lo que decide cada elección del día. **Cuando dudes entre
dos caminos, gana el que acerca el producto a un cliente usándolo.** Sin esa
frase escrita, cada decisión se discute de cero.

---

## 1. Las tres cosas que hacen que un proyecto avance

### 1.1 Escribí dónde TERMINA, o vas a dar vueltas para siempre

El síntoma de que falta esto: cada semana entra una vertical nueva, todo
avanza, y nunca está listo. **La definición de "listo" se mueve hacia adelante
en vez de cerrarse hacia abajo.**

El antídoto es una **línea de corte** escrita en una frase, con sujeto y verbo:

> *"Un cliente real entra desde su casa, lo usa todos los días sin nosotros al
> lado, sus datos no se pierden, y le podemos cobrar."*

Y al lado, la lista de **lo que NO entra**. Esa lista es la mitad del valor:
sirve para decir que no sin volver a discutirlo cada vez. Todo lo que está ahí
es buena idea — el criterio no es si es buena, es si **hace que alguien pueda
usar el producto mañana**.

Cada bloque que sí entra lleva **criterio de terminado verificable**. Sin
criterio, un bloque no está listo: está *"casi"*, que es donde mueren los
proyectos.

- ❌ "Backups configurados" → ✅ **"Existe una restauración hecha, con fecha."**
  *Un backup que nunca se restauró no es un backup: es un archivo.*
- ❌ "Monitoreo listo" → ✅ **"Apagamos el servicio a propósito y llegó el aviso."**
- ❌ "Deploy funcionando" → ✅ **"Alguien que no somos nosotros abrió la URL y cargó un dato."**

### 1.2 El diagnóstico incómodo, dicho en voz alta

Cada tanto, parate y preguntá: *¿por qué esto no termina?* La respuesta suele
ser una frase que nadie quiere decir. La nuestra fue:

> **"Al producto no le faltan funciones: le falta existir en un servidor."**

Sesenta y ocho pantallas, asistente con voz, offline, multi-tenant auditado… y
ningún cliente podía usarlo porque sólo corría en el disco de una máquina.
Decirlo cambió el rumbo en una hora. **Buscá esa frase en tu proyecto.**

### 1.3 Nadie ocioso — y por qué la regla escrita NO alcanza

Un panel parado media hora cuesta más que cualquier cosa que vos escribas en
ese rato: ellos avanzan en paralelo, vos hacés una cosa a la vez. Por eso
**mirás quién está libre ANTES de ponerte a codear vos.**

Esto estuvo escrito desde el primer día y **se rompió igual**, porque dependía
de que alguien mirara. El día que el jefe se fue por límite de cuota, el
subjefe cerró su bloque, avisó, y quedó *"idle, a la orden"*; otros dos paneles
llevaban rato parados. Nadie estaba desobedeciendo: **el que tenía que mirar
era justo el que no estaba.**

La lección, portable a cualquier repo: **un aviso hacia arriba sin un empujón
hacia abajo deja a todos esperando.** Hacen falta las dos direcciones, y la de
abajo tiene que ser un proceso, no una intención:

| Dirección | Qué es | Cuándo corre |
|---|---|---|
| ⬆️ el que cierra avisa | `scripts/avisar-jefe.sh` | al terminar un bloque |
| ⬇️ el ocioso recibe órdenes | `scripts/nadie-ocioso.sh --demonio` | solo, cada 2 minutos |

Tres decisiones de diseño del guardián, que son las que lo hacen sobrevivir:

1. **Manda órdenes permanentes, no la tarea concreta.** *"Sos el panel X =
   devN, tu cola es tal sección, tomá el próximo ítem y arrancá."* Un
   despachador que elige el ítem se desincroniza con la cola en dos días y
   termina mandando trabajo ya hecho. El panel sabe leer su cola y su
   historial; lo único que le faltaba era el empujón. **Estado mínimo = menos
   para que se pudra.**
2. **Tiene válvula.** Si un panel vuelve a ocioso tres veces seguidas, escala a
   un humano y lo deja en paz. Insistirle a un panel sin cola gasta más que
   dejarlo quieto.
3. **Filtra por repo, resolviendo enlaces simbólicos.** Si en la misma
   herramienta de coordinación viven paneles de otros proyectos, no son tuyos
   para mandar. Y el mismo repo se alcanza por más de un camino: comparar el
   TEXTO del path hace que un panel entrado por el otro camino quede invisible
   — y **un panel invisible es un panel ocioso que nadie empuja**, justo el bug
   que el guardián vino a matar.
4. **No le cree al estado que reporta la herramienta.** Este es el que más caro
   sale y el menos evidente. La herramienta de coordinación **saltea la
   detección de pantalla en algunos agentes**, así que su estado se queda
   PEGADO en "trabajando" aunque el agente haya terminado hace media hora: el
   evento de cambio nunca llega. El log del guardián decía "0 ociosos" durante
   veinte minutos mientras un panel estaba en el prompt vacío, y lo terminó
   reiniciando el dueño a mano.

   **El desempate es la pantalla, no el estado.** Cada pasada saca un hash de
   lo que se ve en el panel; si no cambió en N pasadas seguidas, se lo trata
   como ocioso encubierto y se lo empuja. Y —clave— **no se interpreta la
   interfaz de ningún agente** buscando su prompt: eso se pudre con la próxima
   versión de la herramienta. Sólo se pregunta si la pantalla cambió. **Un
   agente que trabaja escribe algo; uno que terminó muestra lo mismo pase tras
   pase.** Por si el umbral se queda corto, el mensaje aclara que si estaba en
   el medio de algo lo ignore y siga.

   La forma general de la lección, que sirve para cualquier semáforo que no
   escribiste vos: **un estado que sólo se actualiza por eventos miente cuando
   el evento se pierde, y miente en la dirección cómoda** — dice "todo bien"—,
   que es la que nadie va a ir a revisar.

**Corolario para vos, el que cierra: avisar NO es el final de tu turno.**
Cerrás, avisás, y en el MISMO turno agarrás el ítem siguiente. Quedarse
esperando la respuesta al aviso es la misma ociosidad con mejor excusa.

---

## 2. Cómo se delega para que no vuelva flojo

Un pedido vago vuelve vago. Uno bueno tiene **seis partes**:

1. **El territorio**, con el "no toques" al lado. Dos agentes en el mismo
   archivo se pisan y se pierde trabajo.
2. **El porqué, con el caso real.** No *"arreglá los enums"* sino *"la página
   filtraba `type === 'income'` y el backend manda `sale`: mostraba $0 de
   ingresos habiendo $5.324.250 en ventas"*. **El que entiende qué se rompe
   encuentra los primos del bug; el que sigue una lista, no.**
3. **Los números reales** con los que se comprueba. *"Una tarifa de $400 por
   unidad terminó costando $16.000 — el total debe ser tarifa × cantidad."*
4. **Cómo se sabe que está bien**: el comando exacto y el número que tiene que
   dar.
5. **Qué hacer si no encuentra nada**: decirlo. *"Revisé 60 consultas y ninguna
   pierde filas"* es un resultado excelente. **Inventar hallazgos para llenar
   una tabla es el peor resultado posible.**
6. **Las reglas fijas** del repo (commits, verificación, qué no tocar).

**Y el pedido tiene que durar horas, no minutos.** Una cola larga y ordenada —
"cuando termines esto seguís con aquello, y no vuelvas a pedir trabajo"— vale
diez veces más que mandar tareas de a una.

### Saludar antes de pedir — el primer mensaje es "hola"

Un agente recién abierto que recibe como **primer** mensaje un pedido largo
responde mal: se pierde, contesta a medias o directamente no arranca. El mismo
agente, saludado primero con una sola palabra y esperado unos segundos, después
acepta el pedido de cuarenta líneas sin problema.

**Entonces: ventana nueva → "hola" → esperar unos segundos → recién ahí el
pedido.** `scripts/saludar-agentes.sh` lo hace por toda la flota.

Es barato y evita el caso caro: un pedido largo que hay que reescribir y
reenviar porque la ventana estaba fría.

**Y es el rescate del panel trabado.** Cuando uno no contesta, tiene un error que
no importa, o ya se le insistió tres veces, lo que funciona **no** es un cuarto
recordatorio: es `--nuevo`, que abre sesión limpia y saluda. Insistirle a un
panel que no contesta es la forma más cara de no lograr nada.

Si la conversación con ese panel ya viene andando, el saludo no hace falta. Es
para ventana nueva o para revivir.

### Anti-pereza (esto es lo que más falla)

Ponerlo literal en el pedido:

- **"Si compila no significa que ande."** Verificá con datos reales: una
  consulta contra la base, un mensaje de verdad, la pantalla abierta.
- **"No ajustes el test para que pase."** Un test nuevo que falla contra el
  código de hoy es un bug encontrado, no un test roto.
- **"No abandones por una dependencia sin nombrarla."** Si falta un paquete,
  decí cuál y con qué comando se instala.
- **"Los builds largos se dejan correr."** No lo mates a los cinco minutos y
  digas que no se pudo.
- **"Diez cosas que prueban algo real valen más que cien triviales."**

### Cómo avisa un panel que terminó (sin quedarse mudo)

Un panel que termina y queda ocioso sin avisar es **trabajo terminado que nadie
sabe que terminó** — el "nadie ocioso" al revés. Cuatro trampas que el
mecanismo tiene que resolver, y las cuatro nos mordieron:

1. **"El que está a cargo" rota** (jefe ausente → subjefe). Nunca se hardcodea
   el panel: vive en un archivo (`jefe.md`) que es la única fuente de quién es
   quién, y se actualiza al rotar.
2. **La confirmación es la recepción, no una herramienta externa.** No se
   consulta cuota ni estado de salud: se manda el mensaje y se verifica que el
   panel **pasó a "trabajando"**. Si procesó, recibió.
3. **Mandar el texto NO es mandarlo.** En la mayoría de estas herramientas, el
   prompt queda TIPEADO en el panel y el agente sigue ocioso hasta que llega un
   Enter aparte. Se pierden horas creyendo que hay cuatro agentes trabajando
   cuando hay cuatro esperando que alguien apriete Enter. **Después de cada
   envío: Enter, y verificar que pasó a "trabajando".**
4. **El aviso tiene que estar firmado.** Si el mecanismo depende de una
   variable que nadie exporta, todos los avisos llegan como *"panel ?"*: el
   jefe lee "cerré tal cosa" sin saber quién lo cerró y tiene que ir a
   adivinarlo panel por panel. Usá el identificador que la herramienta ya
   exporta en cada panel. **Un reporte de estado anónimo es medio reporte.**

**El canal también es regla: el aviso se manda por la herramienta de
coordinación, no se pega en la conversación propia.** Un aviso escrito en el
chat del panel que termina lo ve sólo quien abra ese chat, y no pasa por la
verificación de recepción: el destinatario queda ocioso y el aviso muere en un
cuadro de texto.

**Si no procesa, el aviso escala solo:** jefe → subjefe → archivo de estado con
fecha (contrato "archivo presente = terminó"). Si el que termina **es** el
destinatario, no se avisa a sí mismo: salta al siguiente. El caso "ya estaba
trabajando en otra cosa" NO escala: el aviso queda en su cola y se considera
recibido.

### La trampa del shell en los pedidos

Si el texto del pedido lleva `$(comando)` o backticks, **el shell del panel los
ejecuta** en vez de pasárselos al agente. Ya pasó: un pedido con `TOKEN=$(curl
...)` adentro terminó en "permiso denegado" y el agente nunca vio la tarea.
Escribí los comandos de verificación sin sustitución, en prosa o partidos en
pasos.

---

## 3. Territorios: por qué existen

Varios agentes editando los mismos archivos se pisan y se pierde trabajo. Cada
uno tiene su zona y **no sale de ahí**. Si necesita un cambio en zona ajena, lo
pide; no lo hace.

Regla que ya se rompió una vez y costó caro: **nunca `git add -A`.** Se agregan
los archivos por nombre. Un `add -A` se lleva al commit el trabajo a medias de
los otros cuatro agentes.

---

## 4. Las reglas que hacen a un agente autónomo

Estas son las que más se rompen, y cada una costó tiempo real:

1. **Nadie pide permiso para seguir.** Terminaste un ítem → agarrás el próximo
   de tu cola.
2. **Bloqueado ≠ parado.** Si falta una clave, una cuenta o un permiso que sólo
   puede dar el dueño: escribís **una línea** con el nombre exacto de lo que
   falta y **seguís con el ítem siguiente**. Quedarse esperando es la forma más
   cara de no trabajar.
3. **Encontrás algo roto → lo arreglás y lo commiteás.** No lo documentás, no lo
   anotás para después, no abrís una auditoría. **Única excepción: un bug de
   vida o muerte** — fuga de datos entre clientes, pérdida de plata o de
   cantidades que deciden, o riesgo de seguridad — se trata EN EL ACTO, con
   prioridad sobre lo que estés haciendo. Pero igual se arregla; nunca se
   audita nomás.
4. **Verificá con datos reales.** Que compile no es que ande. Los números que
   verificaste van en el mensaje del commit.
5. **No ajustes un test para que pase.** Si un test nuevo falla contra el
   código de hoy, **encontraste un bug**: arreglá el código, o dejá el test
   marcado como ignorado explicando qué bug encontró y quién lo va a arreglar.
6. **Un commit por idea, con el POR QUÉ.** Qué se rompía antes y por qué esto
   lo arregla — el diff ya está en el diff. Archivos por nombre.
7. **99% código, 1% prosa.**

---

## 5. Que sobreviva a un `/clear`

Toda la memoria del proyecto vive en **tres archivos versionados**, y el
archivo que el agente lee al arrancar apunta a ellos:

| Archivo | Qué contesta |
|---|---|
| **Roadmap** | Qué falta para terminar, con dueño y criterio. Y **qué NO entra**. |
| **Colas** | Qué hace cada uno, en orden, y qué hacer cuando se le acaba. |
| **Handoff** | Qué pasó ayer y cuál es el próximo paso concreto. Cinco líneas por bloque. |

Nada de esto va en un directorio que no se versiona. Si se pierde con un
`clean`, no era memoria: era una nota.

### Cuándo conviene un `/clear`

**Al cerrar un bloque, nunca en el medio de uno.** Y conviene de verdad, no es
higiene: un contexto lleno hace dos daños a la vez — el agente empeora (lo
importante queda enterrado entre mil vueltas viejas) y cada llamada cuesta más,
porque se re-envía todo el historial. **Un panel al 90% de contexto es más caro
y más tonto que el mismo panel recién arrancado.**

La secuencia segura es siempre la misma: **commiteás, dejás tus cinco líneas en
el handoff, y recién ahí se limpia.**

**Quién lo hace: el jefe.** No es tarea del dueño andar mirando el porcentaje
de contexto de cada panel. Y la contracara, que evita perder trabajo: **nunca
se limpia un panel con el árbol sucio.** Un `/clear` sobre trabajo sin
commitear no borra el archivo, pero borra al único que sabía qué estaba
haciendo con él.

---

## 6. Medir

### 6.1 El ritual antes de commitear

El que sea de tu stack, pero **siempre el mismo y siempre completo**: tipos,
tests (el número **no puede bajar**), build, y los chequeos propios del repo.
Verde antes de commitear, sin excepciones.

Y una que sólo aparece cuando trabajan varios a la vez: **el árbol roto
permanente es veneno**. Si nadie puede distinguir su error del ajeno, la
verificación deja de significar algo y todos empiezan a ignorarla. Cuando pase,
alguien tiene que parar y ordenarlo — es más urgente que cualquier función.

### 6.2 Un objetivo, un termómetro, un denominador

Si el objetivo es un número ("el 99% de la app corre sin señal"), **ese número
lo da un script, no la cuenta de cada uno.** Dos cosas que pasaron el mismo día
y que valen para cualquier proyecto:

- **Dos denominadores es no tener ninguno.** Un panel reportó "38 de ~46" y
  otro "40 de 82" sobre el mismo objetivo, en la misma mañana. No había forma
  de saber cuál iba mejor. El de ~46 salía de un número escrito a mano en otro
  documento. Se borra el número a mano; queda el script.
- **Un termómetro que no ve el trabajo termina discutido en vez de creído.**
  El script contaba sólo una carpeta. Alguien dejó el asistente funcionando sin
  señal —trabajo real del objetivo— y el número no se movió ni un punto, porque
  ese código vivía en otra carpeta. Si el criterio de terminado se mide mal, el
  criterio deja de significar algo.

**Antes de creerle a una medición, asegurate de que el instrumento andaba.** Un
barrido corrido mientras el backend se reiniciaba marcó tres páginas sanas como
rotas; desde entonces el barrido hace ping y se niega a correr si no contesta.

---

## 7. Los tests que valen (y los que no)

**La prioridad: lo que calcula dinero o cantidades que deciden se testea; lo que
sólo pinta, no.** Diez tests que prueban algo real valen más que cien que
verifican que un componente renderiza. La pregunta que separa uno del otro:
*¿si esto se rompe, el usuario toma una decisión mala con un número que parece
bien?* Si la respuesta es sí, va el test.

Tres patrones que se pagan solos:

**1. El test que congela una REGLA, no una función.** La regla se escribe en el
nombre y en el doc-comment, con el caso real que la motivó. Los primos de
cualquier dominio:

- *"la sincronización no pisa el cambio local pendiente"* — un sync en el medio
  pisaba lo recién cargado con el dato viejo.
- *"una tarifa POR UNIDAD no se confunde con el TOTAL"* — la pantalla decía un
  número chico donde el contrato dice el grande (precio × cantidad), y el
  margen salía inflado.
- *"una entidad nueva nace con su configuración mínima"* — el segundo cliente
  no podía operar el primer día y nadie se enteraba.
- *"sin datos se muestra una raya, nunca un cero"* — un `$0` o un "Al día"
  donde no bajó el dato le dice al usuario que no debe nada. **Un cero
  inventado es peor que un error.**

**2. El test que ENCUENTRA el bug.** Un test nuevo que falla contra el código de
hoy no es un test roto: **es un bug descubierto.** Se arregla el código, o se
deja el test ignorado explicando qué bug encontró y quién lo va a arreglar.
Acomodarlo para que dé verde es esconder el problema.

**3. El test que PARECE trabajo (el que hay que matar).** Un test que se repite
igual N veces cambiando un nombre **no prueba N cosas: prueba una, N veces.**
Es la forma más cara de parecer diligente: sube el número de la suite, llena el
commit, se ve bien en el reporte — y no agrega una sola garantía nueva.

Nos pasó con todas las letras. Una regla decía *"cada pantalla cubierta congela
las 4 reglas en un test"*. A las 45 pantallas eran **181 tests en `pages/`**,
todos el mismo test con otro nombre, y faltaban 37 pantallas: ~150 más de lo
mismo. El dueño lo cortó con la frase justa: **"es una forma de parecer que
hacemos cuando no hacemos, y gastamos tokens y tiempo que no abundan."**

La regla que queda: **si la regla es una sola, el test es uno solo** — contra el
patrón compartido (el hook, el helper, la función), no contra cada consumidor.
Y si de verdad querés cubrir los consumidores, se hace **al final, en una
tanda**, no bloqueando cada avance.

El olfato para distinguirlos: *¿este test puede fallar por un motivo que otro
test no cubra ya?* Si la respuesta es no, es ceremonia.

**4. El número que no puede bajar.** La suite tiene un piso conocido y
documentado ("hoy N, no puede bajar"). Cada tanda sube el número; nadie puede
bajarlo. Es el termómetro de "algo se rompió".

Y el detalle que caza lo que el compilador no ve: **el tipo de la base
importa.** Un `NUMERIC` leído como entero, un `INT4` como `i64`, un booleano que
viaja como 0/1 en JSON — cada uno produce un **cero silencioso** que parece
dato. Por eso el test mira los NÚMEROS, no el exit code: un test que pasa con
"0" donde debería haber "13.400" no pasó, **mintió**.

### Los tests de un sistema con LLM

Si el producto tiene un LLM (asistente, agente, copiloto), hay DOS niveles de
tests, y confundirlos arruina ambos:

**Nivel 1 — el determinístico (el que corre en CI, el que nunca flakea).** El
LLM decide la intención, pero el CÓDIGO ejecuta: cada acción que el LLM puede
disparar es una función con entrada y salida propias. Ese contrato se testea
**sin LLM**: se siembran datos reales, se invoca la función con un input
representativo, y se congela la respuesta. Las reglas que se congelan:

- el número correcto **con su signo** ("se deben 20.625", nunca "a favor");
- el número por la **unidad** correcta (por pieza, no por lote completo);
- la **respuesta honesta cuando no hay datos** ("no hay X" + adónde cargarlos),
  nunca un total inventado ni un cero que parezca real;
- el **orden** correcto cuando hay muchos (vencidos primero).

Si el LLM mañana cambia de proveedor, estos tests siguen validando que la
herramienta que él invoca no miente.

**Nivel 2 — la medición de calidad con el LLM real (el número, no la opinión).**
El modelo no se testea en CI (es lento, caro y no determinístico): se MIDE por
tanda, con un guion fijo de preguntas reales, repetidas N veces (p. ej. 20
preguntas × 3). El resultado es una tabla: por pregunta, cuántas de las N
respuestas fueron correctas. Eso convierte *"el asistente anda"* —una opinión—
en *"19/20 al 66-100%, 14/20 al 100%, y la única falla es X"* —un número
accionable. Cada falla baja a una descripción de herramienta o a un bug real.

**La regla que une los dos niveles: la intención la decide el modelo; la verdad
la decide el código.** Sin el nivel 1, la medición mide humo; sin el nivel 2, el
determinístico valida herramientas que nadie invoca.

### Y la regla de oro del asistente: el LLM decide, el código valida

**Nunca hardcodear frases ni regex para interpretar la intención del usuario.**
Un `if` que secuestra la conversación y actúa sin pensar es un bug, no una
optimización. Los `contains()`, los `extract_*`, los arranques determinísticos
y los guards de "número suelto" se borran y no vuelven.

El corolario práctico, que cuesta descubrir: **cuando el asistente se equivoca
de intención, el arreglo va en la DESCRIPCIÓN de la herramienta, no en un
`if`.** Caso real: el usuario escribió *"creo que me están afanando gasoil"* y
el asistente ofreció reportar un problema del sistema — porque la descripción
de esa herramienta decía "usala ante datos que no cierran o cualquier señal de
insatisfacción", que no distingue *"el sistema me miente"* de *"me están
robando"*. Y detrás había un agujero más grande: **no existía ninguna
herramienta de combustible, así que el modelo usó la única que le quedaba.**
Un asistente sin la herramienta correcta no se queda callado: elige mal.

---

## 8. Lo que NO se hace (y ya costó días)

- ❌ **Auditorías y barridos.** Encontrás algo, lo arreglás. Un documento de
  hallazgos sólo existe si el dueño lo pidió por su nombre.
- ❌ **Prosa que nadie lee.** El porqué va en el mensaje del commit y en el
  doc-comment del código —ahí sí, completo—, porque es donde el próximo lo va a
  encontrar cuando abra ese archivo. Un documento aparte se pudre en una semana.
- ❌ **Documento de diseño previo** cuando el diseño ya está decidido. Si falta
  decidir algo, se pregunta en una línea.
- ❌ **Dos backlogs** (ni dos tablas de lo mismo). Se desincronizan en una semana
  y después nadie sabe cuál manda. Una sola fuente, y las demás apuntan a ella.
- ❌ **Empezar algo de la lista de "no entra".** Cuando sobra tiempo, se cierra
  lo abierto.

---

## 9. El tono

Directo, sin adornos y sin condescendencia. Si una idea del dueño no es viable,
se dice **con los números por los que no lo es** y se ofrece la alternativa que
resuelve el mismo problema. Si es buena, se hace.

Perseguimos la perfección; eso significa **decir la verdad incómoda temprano, no
tener razón después**.

---

## 10. Lo que se aprendió a los golpes

| Qué pasó | Qué dejó |
|---|---|
| El disco llegó a 100% y **truncó un archivo fuente en mitad de una escritura**. El error hablaba de sintaxis, no de disco. | Chequeo de espacio antes de compilar. **Un disco lleno no falla como un disco lleno: falla como un archivo corrupto.** |
| Alguien corrió el script de reset y **se llevó la base entera** en el medio de la sesión. | Ahora exige `--yes`. Para aplicar una migración no hace falta borrar nada. |
| Un barrido corrido con el backend reiniciándose marcó **3 páginas sanas como rotas**. | El instrumento hace ping y se niega a correr si no contesta. |
| Tres tareas lanzadas en background murieron por timeout **sin commitear nada**. | Todo va por paneles que se ven. |
| `git add -A` de un agente. | Nunca más: archivos por nombre. |
| Dos tablas de "qué panel es cada dev", desincronizadas. | Una sola, y es la que lee el script. |
| Todos los avisos llegaban firmados "panel ?". | El identificador sale de la variable que la herramienta ya exporta. |
| El guardián decía "0 ociosos" 20 minutos mientras un panel estaba parado: la herramienta reportaba "trabajando" con el evento de cambio congelado. | **Un semáforo que no escribiste vos puede estar pegado.** Se corrobora con una señal independiente — acá, si la pantalla cambió. |
| Un termómetro contaba sólo una carpeta y hacía desaparecer trabajo real hecho en otra. | Si el criterio de terminado se mide mal, el criterio deja de significar algo. |

---

**Resumen en una línea:** escribí dónde termina, no dejes a nadie ocioso —con
un guardián, no con una regla—, arreglá en vez de documentar, medí con un solo
termómetro, y testeá lo que calcula dinero o cantidades que deciden: un test
que falla es un bug, no un incordio.

> Todo esto, completo y con el chip de jefe humano, está en
> [DOCTRINA-DEL-JEFE.md](DOCTRINA-DEL-JEFE.md). Los scripts
> `poblar-flota.sh` y `nunca-ocioso.sh` son el músculo que hace que se cumpla
> sin depender de que alguien se acuerde.

## grep dentro de `$( )` con `set -euo pipefail` mata el bucle

`x=$(cmd | grep ...)` no es una lectura: es una bomba con temporizador puesto
en el caso "no encontro nada". grep devuelve 1 cuando no hay coincidencias,
`pipefail` lo propaga y `set -e` mata el script entero. Y `grep -c` es peor
todavia — imprime `0` por stdout, que es la respuesta correcta, y devuelve 1
igual.

Lo caro no es el error: es **cuando** se dispara. El bucle de la flota moria
en `grep -oE 'WHIP …'` exactamente cuando no habia latigazos que dar, o sea
cuando el tablero estaba vacio — justo el momento en que mas falta hacia que
siguiera vivo para barrer al llegar trabajo nuevo. Y como corria bajo systemd
con `Restart=always`, el suicidio se disfrazaba de `activating`: el servicio
figuraba arrancando, no caido. Trece obreros parados cuatro horas.

Es el patron de siempre en su forma de sistema: **un componente que al fallar
devuelve algo plausible en vez de un error, y siempre disfrazado de la buena
noticia** — aca, "el servicio esta arrancando".

Regla: toda sustitucion que termine en `grep`, `head`, `cut` o `tr` lleva
`|| true` (o `|| echo <valor neutro>`) pegado. No es defensivo de mas: es que
el shell no distingue "no habia nada que contar" de "se rompio".

Y el corolario para systemd: `Restart=always` no prueba que algo funcione.
Antes de darlo por vivo, `systemctl --user is-active` tiene que decir `active`
y no `activating`, y conviene mirar el uptime — un servicio que se reinicia
cada 15 segundos esta muerto, solo que ruidosamente.

## Un bucle bajo systemd no ve la flota, y el vacio se lee como calma

`latigo` solo funciona dentro de una sesion de Herdr: fuera contesta
"not inside a Herdr session (HERDR_ENV != 1)". systemd no hereda ese entorno
—ni siquiera `~/.local/bin` en el PATH— y como todas las llamadas iban con
`2>/dev/null || true`, el resultado era tres servicios en verde, `is-active`
diciendo `active`, y los tres girando en el vacio sin ver un solo panel.

Lo caro no fue eso: fue **como se leyo el vacio**. `latigo roster | wc -l` daba
cero obreros, y con cero obreros la condicion "hay menos items que gente" es
falsa, asi que el reloj del jefe concluia que **no habia urgencia de reponer** y
lo mandaba a escribir documentacion. El mensaje literal era: "el tablero esta
con 0 pendientes para 16 obreros, asi que no hay urgencia de reponer". La flota
entera parada, y el mecanismo que existe para evitarlo confirmando que todo
estaba bien.

Cero nunca significa calma. Cero obreros significa **no puedo medir**; cero
items con gente libre significa **la urgencia maxima**.

El arreglo tiene dos mitades y hacen falta las dos:

1. `scripts/herdr-entorno.sh --guardar` persiste el entorno desde un panel, y
   los bucles lo cargan al arrancar. Los units llevan `Environment=PATH=` con
   `~/.local/bin` adelante.
2. **El guard.** Cada bucle comprueba que de verdad ve paneles y, si no,
   **sale con error**. Que systemd lo marque caido es muchisimo mejor que
   quedar verde sin hacer nada: un bucle que falla se arregla en cinco minutos,
   uno que gira en el vacio vive semanas.

Y la regla general detras: **si un componente puede quedarse sin su
dependencia, tiene que notarlo y gritar.** Un `|| true` sobre una llamada que
es la razon de ser del proceso no es robustez, es un silenciador.

## Un estado que se vuelve a medir no se registra como algo "ya tomado"

Hay dos clases de trabajo y se parecen lo suficiente como para confundirlas:

- **Lo que se hace una vez**: portar la pantalla 47, escribir el manual. Se
  registra que ya se tomo, y no se vuelve a emitir.
- **Lo que es un ESTADO y se vuelve a medir**: un error de compilacion, un test
  que falla, una consulta lenta. No se "toma": se mide de nuevo en cada parte.

Tratar lo segundo como lo primero deja huerfano todo lo que no quedo arreglado.
Nos paso: 126 ids de error registrados como tomados, cero items abiertos, y 133
errores vivos que ningun mecanismo podia volver a repartir — con catorce
obreros libres y el tablero en cero. Cada error cerrado sin arreglar salia del
sistema para siempre.

Para un estado, el criterio es el PRESENTE y no el pasado: se saltea solo si
hay un item ABIERTO para eso ahora mismo. Si la medicion lo sigue viendo y
nadie lo esta trabajando, es trabajo nuevo, aunque tenga un item cerrado atras.

Y el corolario al exportar: **un script que depende de herramientas que el otro
repo no tiene no se copia.** Pise el `autoservicio.sh` de este repo con la
version de un proyecto Rust, que llama a `cargo` y lee `docs/SPECS.md`. Con
todo bajo `|| true`, no habria fallado: habria devuelto cero items en silencio.
Lo especifico se queda en su repo; lo que viaja es la regla.
