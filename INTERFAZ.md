# La interfaz, en concreto

`DESIGN.md` explica el porqué con los casos que lo motivaron. Esto es la forma
exacta, sin ejemplos de ningún proyecto en particular, para que se pueda copiar
tal cual al que empieza.

No es una guía de estilo: es una lista cerrada. Se cambia acá, para todas las
pantallas, nunca en una sola.

## Por qué es cerrada

Un Frankenstein no lo decide nadie. Se arma solo, una pantalla por vez, cada vez
que alguien resuelve un problema en su pantalla en lugar de resolverlo en la
pieza compartida. Donde había una manera mediocre ahora hay dos, y la próxima
persona elige mal porque las dos existen.

**Todo lo que aparece dos veces vive en una sola pieza.** La pantalla decide
*qué* dice, nunca cómo se ve. Cuando algo falta, se agrega a la pieza compartida;
nunca se resuelve local "por esta vez".

La prueba de que se respetó: **el usuario cambia de módulo y no aprende nada
nuevo.** El menú donde estaba, el buscador donde estaba, los botones donde
estaban y del mismo color.

## El menú

**Una definición, un componente.** La estructura vive en un solo archivo de datos
y la consume un solo componente. No hay un árbol para el teléfono y otro para
escritorio: el daño de tener dos está medido — el usuario pierde el modelo mental
al cambiar de dispositivo porque el menú aparece de otro lado y en otro orden.

**Va a la derecha.** En el teléfono son dos rayitas; en escritorio, la barra de
título.

**Las dos rayitas se convierten en cruz, y son UNA pieza compartida.** Cerrada,
dos rayas; abierta, giradas 45° y −45°. La misma pieza la usan el menú, el
gatillo de filtros y el formulario abierto. Dos animaciones que hoy coinciden
mañana divergen, porque alguien tocó una y no se acordó de la otra.

**En el teléfono el menú es un overlay de pantalla completa**, pero arranca
**debajo de la barra de título**, nunca desde el borde superior. Si tapara la
barra, la cruz que lo cierra quedaría invisible e intocable, y es la única
salida.

**Dos niveles, y el segundo se abre en el lugar.** Un ítem es un grupo: tiene
destino propio y, opcionalmente, submenús.

- **En escritorio** los submenús cuelgan verticalmente del grupo, en la barra.
- **En el teléfono** el grupo se toca y **se expande dentro del mismo overlay**,
  sin abrir otra pantalla. Eso es lo que lo hace usable con el pulgar, y se rompe
  apenas alguien decide que un submenú merece pantalla propia.
- Qué va visible en la barra lo decide **la frecuencia de uso real**, no la
  simetría del organigrama.
- Si no entran, hay un **"Más"** que expande hacia abajo — pero es la última
  salida. **Antes de recurrir a "Más" se agrupa en submenús**: una barra que
  necesita "Más" casi siempre está mal agrupada.

## Los formularios

**Cada formulario es una página con su propia URL.** No un overlay ni una hoja
que sube desde abajo: una ruta. Se puede compartir el enlace, volver con el botón
atrás, recargar sin perder dónde estabas y enlazar desde una notificación.

Lo que se conserva del patrón de panel:

- **Se ancla arriba, pegado a la barra de título**, y **oculta las pestañas** o
  lo que hubiera antes. No compite con nada.
- **La barra de título dice lo que se está cargando, en vivo.** Mientras se
  escribe el nombre, la cumbrera lo muestra. Es el mismo mecanismo con el que
  cualquier ficha publica su título, no un caso especial.
- **Al abrir un alta o edición, las dos rayitas se vuelven cruz**, igual que con
  el menú, y esa cruz cancela el formulario. Un solo control con dos trabajos
  según haya o no formulario abierto. **Nunca una cruz extra al lado.**
- **Abrir y cerrar son simétricos**: al cerrar se vuelve exactamente a donde se
  estaba, no al principio de la lista.

En el teléfono, sin marco alrededor de los campos. De tablet para arriba, vuelve.

## Los botones

**Como máximo dos, y son Guardar y Cancelar.** Siempre los mismos, siempre en el
mismo lugar, siempre con la misma forma. Distintivos entre sí: el que confirma
tiene peso visual, el que cancela no.

- Un tercer botón casi siempre significa que la pantalla hace dos trabajos y hay
  que partirla. Un cuarto, seguro.
- Las acciones secundarias no son botones: son ítems del menú de la fila o de la
  ficha.
- **El destructivo nunca al lado del constructivo**, y pide confirmación que
  nombra lo que se va a perder.
- En el teléfono van al pie, donde llega el pulgar.

## Los filtros

**La misma forma en toda colección**, y una pantalla propia con su ruta — no una
hoja. Al pie, "Ver N resultados" y "Limpiar". La cierra la misma cruz del menú,
no una cruz propia.

**Recordar los filtros** es opcional y explícito. Un filtro que sobrevive sin que
el usuario lo haya pedido es la causa número uno de "no aparece lo que busco".

## El buscador

**Siempre en el mismo lugar**: arriba de la colección, ancho completo en el
teléfono. Tolerante a acentos, mayúsculas y palabras dadas vuelta.

Y **un selector es un campo con autocompletado, nunca una pantalla.** Los
sistemas viejos suelen tener una pantalla por cada "elegir cuál"; todas
desaparecen.

## Los colores

**Sólo fichas semánticas.** Un color escrito a mano dentro de una pantalla es un
error, no una decisión de diseño. Claro y oscuro se definen una vez, arriba, y
ninguna pantalla los redefine.

El color significa siempre lo mismo en todo el sistema. Un verde que en una
pantalla es "cobrado" y en otra es "activo" ya rompió el sistema.

## Las piezas compartidas

Ninguna pantalla construye estas cosas: las usa.

| Pieza | Qué resuelve |
|---|---|
| Barra de título | Cumbrera, título en vivo, las dos rayitas / cruz |
| Menú | Una definición, dos niveles, overlay en mobile |
| Colección | Buscador arriba, filtros, lista, vacío, error, cargando |
| Ficha | Encabezado, datos, acciones |
| Formulario | Página con URL propia, anclado arriba, Guardar/Cancelar al pie |
| Filtros | Página propia, "Ver N" y "Limpiar" |
| Autocompletado | Reemplaza todo selector |
| Importe | Alineado en la coma, con la fecha a la que está calculado |
| Estados | Vacío, cargando, error, sin conexión, demasiados datos |
| Confirmación | Nombra lo que se va a perder |

Si falta algo acá y hace falta en dos pantallas, **se agrega a esta tabla**. No se
resuelve en la pantalla.

## Cómo se verifica sin discutir

Un documento se ignora; un build rojo no. Lo mecánico se chequea solo, recorriendo
todas las rutas:

- Sin desborde horizontal a 360 px de ancho.
- Todo blanco interactivo de al menos 44 × 44.
- Ningún color literal fuera de la definición de fichas.
- Exactamente una acción primaria por pantalla.
- Todo control de formulario con su etiqueta programática.
- Contraste AA en claro y en oscuro.
- Foco siempre visible y nunca atrapado.
- Ninguna cadena de texto visible escrita fuera del catálogo de traducción.

Lo que una herramienta no puede: recorrer los dos flujos más importantes **sólo
con el teclado** y anotar dónde se vuelve inusable.
