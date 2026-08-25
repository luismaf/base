# DESIGN.md — el diseño no se discute, se consulta

> **Antes de tocar una pantalla, se lee esto.** No es una guía de estilo: es un
> contrato. Cada regla está acá porque se pagó — alguien la rompió, el dueño lo
> vio, y costó una vuelta entera arreglarlo.
>
> **Si vas a hacer algo distinto de lo que dice acá, no lo hagas: preguntá.**
> Una pantalla que se sale de esto no es "una variante": es el frankenstein que
> venimos peleando desde el día uno.

**Fuente única.** Este documento manda. `exportar/SISTEMA.md` es la versión
para llevarse a otro proyecto y dice lo mismo; si alguna vez difieren, gana
éste y hay que corregir el otro.

---

## 0. La regla madre

> **Si algo aparece dos veces, es del sistema, y se arregla en la pieza — no en
> la pantalla.**

Arreglar una pantalla y no la pieza deja la app **peor que antes**: donde había
una forma mediocre quedan dos formas distintas. Así nacieron los dos sistemas
de filtros, los tres comportamientos del botón "+", y las dos formas de cargar
un pedido. Todos costaron una vuelta.

Antes de resolver algo, la pregunta es: **¿esto es de esta pantalla o del
sistema?**

**Y la forma positiva de la misma regla: se arranca del ESQUELETO GLOBAL,
siempre que se pueda.** No se escribe una pantalla y después se busca qué
unificar — se parte de la pieza que ya existe y la pantalla decide únicamente
QUÉ dice, nunca cómo se ve. `PageShell` para la distancia, `FilaPlegable` para
cualquier bloque, `ListaDeFichas` para cualquier lista, `CUADRO` para cualquier
caja, `GRILLA_*` para cualquier grilla, `ExpandableForm` para cualquier alta.

El motivo es lo que pasa si no: **queda un Frankenstein.** Cada pantalla nace
apenas distinta —un padding propio, un borde a mano, otro lugar para el botón—
y el conjunto deja de parecer un producto para parecer diez personas trabajando
sin hablarse. Nadie decide eso; se llega solo, una pantalla por vez, y para
cuando se nota hay que rehacer todo. Por eso la pregunta al empezar una
pantalla no es "¿cómo la hago?" sino **"¿de qué esqueleto sale?"**, y por eso
la tabla de piezas de §2 tiene una columna "Nunca": lo que ahí figura no es un
estilo desaconsejado, es la vía por la que entra el Frankenstein.

**El canon es ejecutable** (dueño, 2026-08-18: *"que no haya margen para
hacer las cosas de otra forma"*): `homogeneidad.test.ts`
(`frontend/src/lib/__tests__/`) destila este documento a checklist —
PageShell, `ListaDeFichas` y no `DataView`, `EmptyState` con CTA, cero
Dialog de dominio, cero color crudo — contra CADA página del sitio. Si tu
página pasa `homogeneidad.test`, cumple; si no pasa, no se mergea. Un doc
se ignora; una suite que pone en rojo la página desviada, no.

---

## 0.05 Lo que el dueño MATÓ el 2026-08-20 (mirando /grupos en el teléfono)

Tres piezas que eran canon dejaron de serlo. Si las ves en una pantalla, es
código viejo y se saca; si las ves en un doc (HANDOFF §0 del 19/08,
GRUPO_INGRESOS §12/§18), ese doc quedó atrás de éste:

1. **Los chips verdes con contador — `Ingresos (1) · Actividades · Egresos` —
   NO SE USAN MÁS.** Ni en grupos ni en ningún listado. La fila es limpia
   como la de /lots; al clickear se abre la ficha con su tab de Actividad, y
   ahí ingresos/egresos son FILTROS de la lista, no chips.
2. **KPI cards / mini-cards / StatCards: "esos cards pedorros no los quiero
   en NINGÚN lado"** (dueño, textual). Ni al abrir grupos, ni en home, ni en
   colecciones. La información agregada irá el día de mañana a un informe
   dinámico (estilo Power BI) en Reportes — no a tarjetitas arriba de una
   lista. En mobile el home tampoco lleva boxes.
3. **Dos filas de pestañas en una sección: NO.** Una sola fila corta, como
   Ventas (`Pedidos · Campañas · Tareas · Mercado`). Las tabs de toda
   sección y de toda ficha se parecen a las de /lots.

4. **El "+" en la fila de tabs (y en barras de título de colecciones): NO VA
   MÁS.** Toda alta se da como en /lots: **la PRIMERA fila de la lista es el
   alta** ("+ Crear Pedido"), clickeable, que abre el `ExpandableForm` pegado
   a la barra.
5. **"Manga en vivo" muere como página.** Registrar en la manga ES una
   pesada: una actividad de la grupo, dentro de su ficha. (En la demo de
   WinCampo la manga sólo se nombra al pasar — no es una feature central.)
6. **LA CLASE (la orden estructural del día):** *"todo debe ser heredado de
   una clase; el día que cambie el diseño no puedo ir pantalla por pantalla
   — eso es INACEPTABLE"*. Toda página de colección se construye con
   **`PaginaDeColeccion`** (`components/shared/`), extraída de /lots, y las
   pantallas sólo la parametrizan. Ensamblar a mano PageShell + lista +
   filtros en una página nueva es un bug de arquitectura, aunque se vea
   igual. `homogeneidad.test.ts` lo vigila.
7b. **Los ACORDEONES mueren (al menos en mobile)** (dueño, 2026-08-20,
   viendo la tab Tareas del pedido): clickear una tarea/actividad NO expande
   una fila — **abre el registro a PÁGINA COMPLETA en modo lectura**, con
   el camino a editar (lápiz→tacho). La expansión inline `abierto &&
   detalle` de las filas es patrón muerto en mobile.
7c. **Los botones "+" REDONDOS (FAB flotante) no van más.** El alta es la
   primera fila de la lista, con su "+" textual — nunca un círculo
   flotante. La pieza `AddButton` y todo `rounded-full` con Plus se
   retiran. (Y reiterado: el "+" tampoco va en las tabs.)
7d. **Un botón/campo de búsqueda viejo es la SEÑAL de que esa página se
   REHACE entera** con el sistema nuevo — no se parcha la lupa: se migra la
   página a la clase.
7e. **TODA página que pueda tener algo COMO una lista, se ve como /lots.**
   No sólo colecciones: fichas, tabs, pickers — si lista algo, es el
   esqueleto. La ficha consume el MISMO esqueleto en modo embebido (misma
   cabecera Filtrar+Buscar, misma fila): "si cambio el ícono de filtrar se
   cambia en TODAS; si dejo un espacio más arriba, en TODAS."
7f. **Las OPCIONES de un "+ Crear X" se muestran como la misma lista** —
   uno por línea, la fila canon, elegido sube arriba con vuelta atrás.
   Nunca cards, nunca un dropdown propio.
7g. **Nombres en INGLÉS — el español está PROHIBIDO en el código** (dueño,
   2026-08-20; detalle y salvaguarda de contratos en CLAUDE.md §i18n).
   `PaginaDeColeccion` pasa a **`CollectionPage`** (alias temporal mientras
   los paneles migran); toda pieza nueva nace en inglés.
7h. **UNA clase de BOTONES para toda la app** (dueño: "los botones son
   siempre iguales — blanco la acción principal, usualmente Guardar, y
   Cancelar; en filtros también"). La pieza es una sola (`FormActions`,
   ex-AccionesFormulario): acción principal blanca + Cancelar, mismos
   estilos, misma posición, en formularios Y en la pantalla de filtros.
   Un botón armado a mano en una pantalla es un bug.
7i. **Los formularios se DESPLAZAN cuando no entran en la pantalla** —
   nunca un form cortado sin scroll. Es propiedad del esqueleto del form,
   no de cada pantalla.
> El principio detrás de 6-7i, del dueño textual: **"UNA SOLA forma de
> hacer las cosas. Un esqueleto que se repite en todos lados — es la única
> forma de tener código mantenible."** Clase de lista, clase de botones,
> clase de form: las pantallas sólo configuran.
7. **El esqueleto se configura con DATOS, no con JSX** (dueño: *"cada
   pantalla tiene sus filtros, en un JSON o algo así, que hereda; un
   esqueleto que se pueda usar"*): cada pantalla declara filtros, fila y
   alta en un objeto de configuración tipado. Y las **tabs son concisas,
   como pedidos: `Actividad · Campañas · Tareas · Mapas · Mercado`** — en
   muchos casos una tab (Campañas, Grupos) no es una página: es un FILTRO
   predefinido sobre la lista de Actividad. **Taller lleva las mismas
   tabs; producción es taller nerfeado (comparte casi todo); servicios se
   arma en función de eso.**

Y dos reafirmaciones del mismo día: **el filtro (botón Filtrar) + búsqueda de
/lots van tal cual en toda colección**, y **las URLs van en inglés, siempre**
— lo que se lee en la barra de direcciones es parte del diseño. Detalle del
Filtrar (corregido por el dueño en vivo, se rompió una vez): **el ícono del
botón Filtrar NO cambia nunca** — queda el de filtros de siempre. Lo que
pasa al ABRIR los filtros es lo mismo que al abrir un formulario: **el ☰ del
MENÚ se convierte en la cruz** con su animación existente (mecanismo
`cancelarFormulario`/`titulo-contexto`) y esa cruz cierra los filtros.
Jamás dibujarle rayitas nuevas al botón Filtrar.

---

## 0.1 Un pixel en mobile = 1 gramo de oro

> El lema, textual del dueño (2026-08-15): *"no hay que desperdiciar pixeles,
> **un pixel en mobile = 1 gr de oro** debería ser nuestro lema"*.

La app se usa en el campo, en un teléfono, con el sol de frente. Cada renglón
que no cambia una decisión empuja hacia abajo el que sí. En concreto, y todo
esto ya se pagó:

| Se prohíbe | Qué va en su lugar |
|---|---|
| Tarjeta adentro de tarjeta (recuadro sobre recuadro) | Adentro de un bloque, **renglones**: `RenglonDeDetalle` |
| Un bloque que repite lo que dice el de arriba | Un solo bloque; el desglose, plegado |
| Botón adentro de algo que ya se toca entero ("Abrir", "Ver", "Ver el mercado") | El renglón entero lleva; el `›` es la pista, no el control |
| Párrafos de salvedades en cada ficha | Un `?` con los motivos en `title` (`PorQueEstimado`) |
| Alto reservado "por las dudas" (`min-h` en paneles que no lo piden) | El alto lo pone el contenido; el que necesita piso lo pide |
| Renglón de ayuda que ocupa alto para no decir nada | La ayuda aparece **cuando hay algo que decir** |
| Cuadro de texto con un ejemplo adentro ("Ej: Soja", "llegaron 54 bichos el 03") | El rótulo dice qué va; la aclaración, en `ayuda` de `Campo` |
| Dos campos cortos (nombre + capacidad, nombre + superficie), cada uno en su propia línea completa | Comparten renglón — una grilla de 2 o 3 columnas, nunca una fila por campo |

La última tiene su propia frase del dueño: *"no quiero ningún cuadro de texto
con sugerencias, son un peligro a la profesionalidad de la aplicación"*.
Sobreviven los `placeholder` de los desplegables ("Seleccionar categoría"), los de
búsqueda y los que son el ÚNICO rótulo de un campo en una grilla compacta.

### El tachito de borrar: SIEMPRE al lado del primer campo

> El dueño (2026-08-14, sobre "Editar pedido", la referencia): *"¡no! El mismo
> sistema que para cambiar de nombre un pedido. ¡Eso para todo!"* — y
> (2026-08-18), extendiéndolo a cualquier formulario que edita algo que ya
> existe: *"el tachito de basura, siempre a la altura y en línea con el
> primer textbox, es una regla"*.

Editar algo que ya existe (un pedido, un tanque, un maestro) NUNCA usa un
grabber ni una hoja aparte para borrar: el mismo formulario de alta,
precargado, gana un tachito rojo (`DeleteButton variant="icon"`, con
`useUndoableDelete`) **en el primer renglón, pegado al primer campo** —
no al segundo, no al final del formulario, no como texto ("Borrar Pedido").
El ejemplo canónico es `HojaDelNombre`: el nombre y el tachito comparten
la primera línea, a la misma altura; todo lo demás (superficie, estado)
va abajo.

```
  NOMBRE *
  [ Pedido Norte              ] 🗑   ← el tachito, acá, siempre
  SUPERFICIE (HA)
  [ 120.5                    ]
```

Un formulario de alta se convierte en el de edición agregando **sólo**
esto: los valores llegan precargados y el tachito aparece porque ahora
hay algo que borrar. Nunca dos componentes distintos para la misma
conversación ("dar de alta" / "editar") — es el mandamiento 2 aplicado a
formularios: si el alta y la edición se ven distinto, el productor
aprende dos veces lo mismo.

### Los avisos son en línea, nunca un banner de pared a pared

El dueño (2026-08-17), viendo una fila de cuenta con un renglón propio para
"⚠️ Diferencia de US$15.000 vs. lo cargado — actividad sin registrar o sin
conciliar": *"todo ese warning gigante debería ser un simple simbolito al
lado: Movim: USD 343434 | ⚠️ Dif: USD 344343 ❯ — y si acercás el mouse al
warning, un popup que te explica; si clickeás, debe entrar para cargarlo.
TODOS los warnings así los quiero"*.

Es la misma regla de la tabla de arriba, aplicada a los avisos: la pieza es
`AvisoEnLinea` (`components/shared/Ayuda.tsx`) — el triangulito ámbar + el
dato corto, **en la MISMA línea** del dato al que se refiere, nunca en su
propio renglón ni con fondo ámbar de pared a pared.

| Gesto | Qué hace |
|---|---|
| Reposo | Símbolo + texto corto ("Dif: US$15.000"), nada más |
| Hover / mantener apretado (`title` nativo) | La explicación completa, la misma frase que antes ocupaba el banner |
| Click / tap | Entra a resolverlo — cargar el movimiento que falta, conciliar |

Reusa el mecanismo de `Cifra`/`Ayuda`: `title` nativo para la explicación (no
depende de JavaScript, lo anuncian los lectores de pantalla, se lee en el
celular manteniendo apretado). Lo que `Ayuda` no tenía es el click: un aviso
de plata casi siempre tiene una acción que lo resuelve, así que
`AvisoEnLinea` navega.

**Un banner de línea entera queda prohibido salvo bloqueo duro de página
completa** (un error de carga, un formulario que no puede guardar todavía).
Cualquier otra cosa —una diferencia de saldo, una alerta de service, un stock
por debajo del mínimo— es un `AvisoEnLinea` metido en el `resumen` o el
`alDerecha` de la ficha, no un cartel aparte.

---

## 1. La ropa es de Geist. El comportamiento es de Apple.

Cómo se VE lo decide Geist (Vercel): paleta neutra, sin acento, radios chicos.
Cómo se SIENTE lo decide iOS: hojas desde abajo, gestos, áreas táctiles. Lo que
delata a una web disfrazada de app no es la paleta, es el comportamiento.

### Colores

| Regla | Por qué |
|---|---|
| **La acción primaria es el INVERSO del fondo** (`bg-foreground text-background`) | Blanco sobre negro en oscuro, negro sobre blanco en claro |
| **El color de marca NO va en botones** | Queda para estados y el logo. Cuando todo grita, nada avisa |
| **Rojo sólo para destruir** | Es lo único que tiene que frenar el dedo |
| **Filtros y tags sin relleno**: borde y texto | Un semáforo permanente enseña a ignorar los colores justo cuando aparece uno que importaba |
| **Lo elegido se INVIERTE** | Sólo el borde es demasiado sutil entre opciones hermanas |
| **La pestaña activa lleva el color de marca** (3px) | No es un botón, es un ESTADO —dónde estás parado—, que es para lo que el sistema reserva el color. Es el único de la fila |

### Medidas

| Elemento | Medida |
|---|---|
| Botón de acción | alto 36-40px · radio 8px · texto 14px peso medio |
| Botón chico de encabezado | alto 32px · texto 13px |
| Botón de ícono que se toca en la calle | **44px de ÁREA**, aunque se vea de 32 (`.toque-44`) |
| Agarradera de una hoja | 48 × 4px · blanco 50% · **apoyada SOBRE** la hoja, entera |
| Radio | 8px general · 16px tarjetas · **12px hojas** |

Los 44px son el mínimo táctil de la HIG. Un control puede **verse** de 32 y
tener 44 de área: es lo que hace iOS y resuelve la contradicción entre
elegancia y dedo.

### El ancho: nada se estira más de lo que necesita

> **Un elemento nunca ocupa más ancho del que necesita para leerse.** En el
> teléfono va al ancho completo. Cuando el contenedor da para DOS cómodos, se
> parte en columnas — no se estira uno solo.

El dueño (2026-08-13): *"al tener más ancho se deben convertir a grid, si no es
una tira larga, horrible queda. ¿Hay alguna regla para que cuando a algo le
quede más del 30% libre achicarlo?"*.

Un renglón de pedido estirado a 1.200px para decir "El 12 · tipo A · 45 u" se lee
PEOR que en el teléfono: el ojo cruza la pantalla entera para juntar el nombre
con el dato de la derecha.

**No hace falta medir el 30% con JavaScript**: `auto-fill` hace exactamente eso
—mete otra columna apenas entra una más— y lo resuelve el navegador, sin un
`ResizeObserver` que se desincronice. Los mínimos están en `lib/grillas.ts` y
son cuatro, no hay un quinto:

| Grilla | Mínimo | Para |
|---|---|---|
| `GRILLA_LISTA` | 28rem | Renglones de una lista (pedidos, grupos) |
| `GRILLA_BLOQUES` | 18rem | Bloques de 2-3 renglones (el inicio) |
| `GRILLA_TARJETAS` | 20rem | Tarjeta con datos y acciones |
| `GRILLA_CAMPOS` | 14rem | Los campos de un formulario |

### UN SOLO BLOQUE para todo: `FilaPlegable`

> *"Quiero que sean EL MISMO ELEMENTO: la lista de tareas, el clima, el home,
> la lista de pedidos. Que sean lo mismo en su diseño y se comporten igual, con
> botones en lugares similares, que tengan acciones similares."* — el dueño,
> 2026-08-13

**No hay un bloque de pedido, otro de tarea y otro de clima.** Hay uno, y cada
pantalla decide QUÉ dice — nunca cómo se ve:

| Ranura | Qué va | Ejemplos |
|---|---|---|
| `title` | El nombre, chico y en mayúsculas | "EL CLIMA", "El 12", "Norte" |
| `resumen` | La información, **visible siempre** | "6° · Chubascos", "tipo A · 45 u" |
| `alDerecha` | Un valor corto, alineado al borde | "faltan 20-35 días", "$186k" |
| `barra` | Progreso al pie, 0-100 | El ciclo del categoría |
| `children` | Lo que aparece al abrirlo | Las acciones, el pronóstico, los pedidos del grupo |

### UNA sola flecha: el glifo de entrar, al costado

Acá estuvo escrita la regla de los dos chevrones —`>` para irse, `⌄` para
abrir—, la de los Ajustes de iOS. **El dueño frenó las dos** (2026-08-13: *"no
quiero esas flechitas, hay tantas que marean"*, *"las flechas no van"*), probé
con el nombre del bloque haciendo de puerta, y el 2026-08-14 él trajo la
solución: *"para entrar, ¿la flechita glifo? al costado de cada uno. Algo
sutil, como el botón de +"*.

Lo que quedó, y es lo que rige:

| Dónde tocás | Qué pasa |
|---|---|
| **Cualquier parte del bloque** | Se abre acá, hacia abajo, sin perder de vista dónde estás |
| **El glifo `›` del costado** | Vas a la ficha completa |
| Un bloque **sin nada adentro** | Todo el bloque va a la ficha, y no hay glifo |

La flecha que se fue es la de ABRIR: sobraba, porque el bloque entero ya se
toca y con veinte pedidos eran veinte dibujos diciendo lo mismo. La que quedó es
la de IRSE, que era la única que hacía falta — no hay otra forma de anunciar
"esto te saca de la pantalla".

**Sutil, como el `+` del tirador**: `text-muted-foreground/50` en reposo, que
sube a `text-foreground` con el dedo o el mouse encima. Se ve si lo buscás y no
compite con el nombre si no. Centrado verticalmente: el resto de la fila se
alinea arriba —el valor de la derecha va a la altura del nombre— pero el glifo
no acompaña a ningún texto, es la puerta del bloque entero, y pegado al techo
se lee como si fuera del título.

Lleva el nombre del bloque como etiqueta accesible. Una flecha sin destino es
una flecha que no se puede usar sin ver la pantalla.

> **El bloque entero abre, y eso no es negociable.** Cuando el toque quedó en
> un botón interno que cubría sólo el renglón del resumen, medio bloque se
> murió de forma invisible: se veía igual y respondía distinto según dónde
> cayera el dedo. Los gestos van en la `<section>`; lo de adentro —las
> acciones, la historia, el tirador— frena el burbujeo para no abrir y cerrar
> de un saque. Está cubierto por `FilaPlegable.test.tsx`.

### Si entra, se muestra

> *"Quiero que las opciones sean todas las que entren en el cuadro."* — el dueño

Esconder dos botones detrás de un chevron es cobrarle un toque al productor
para mostrarle algo que entraba. Las acciones que entran van en la ranura
`acciones`, **debajo del resumen y a la vista**, en el mismo lugar en todos los
bloques.

El `⌄` queda para lo que de verdad no entra: el pronóstico hora por hora, doce
cotizaciones, los pedidos de un grupo. Y cuando el contenido es grande,
`detalleAmplio` le da el renglón entero y un alto mínimo — un mercado abierto
en una columna de 28rem es una palabra por renglón.

**Y el acordeón es para lo que NO se puede mostrar siempre**, no para esconder
lo que entraba. En un pedido lo que se abre es **lo que se le hizo** —cada
actividad con su fecha, y tocando una se va a SU detalle—, porque eso es una
lista larga que cerrada sería una tira. Lo que se ve cerrado es el resumen en
orden de ocurrencia: *40 u | Preparación | Categoría B | Preparación (2) |
Fumigación*.

**Un bloque no se mira para ejecutar una acción, se mira para saber cómo
viene.** Los botones de acceso directo al alta —"dar de alta", "cerrar"— se
sacaron por eso: la acción está a un toque adentro, que es donde se carga con
todos sus datos.

### Hasta dónde se abre acá, y cuándo se va a la pantalla

El acordeón sirve para **ver de qué se trata**, no para reemplazar una
pantalla. La línea es simple:

| Se abre acá | Se va a la pantalla |
|---|---|
| Una lista de lo que pasó | El detalle completo de UNA cosa |
| Dos o tres datos | Un registro con diez campos |
| Algo que se lee | Algo que se edita |

Una alta tiene categoría, variedad, densidad, superficie, insumos y costos:
meterla en un acordeón adentro de otro acordeón, dentro de una columna de
22rem, es mostrarla **peor** de lo que se puede. En la lista se ve QUÉ se hizo
y CUÁNDO; el resto es una pantalla.

### Anidado: `plano`, no una tarjeta adentro de otra

Un bloque adentro de otro bloque va **plano**: sin borde, sin fondo y sin alto
mínimo, separado del de arriba por una línea finita. Con su propia caja se lee
como una tarjeta suelta que se cayó adentro de otra, y el alto mínimo —que
existe para emparejar los bloques de una GRILLA— ahí no empareja nada: sólo
estira renglones que dicen tres palabras.

Plano conserva **todo** el comportamiento: el toque, los dos chevrones, uno
abierto por vez. Lo único que cambia es que es un renglón del cuadro que lo
contiene.

### El resto del comportamiento, igual en todos

**Todo el bloque es el blanco del toque** (no el chevron), **cerrados todos
miden lo mismo**, y hay **uno abierto por vez** (`AcordeonGrupo`).

Un elemento nuevo que "se parece" a éste es un bug. Si necesita algo que no
tiene, se le agrega una ranura acá — como pasó con `alDerecha` y `barra`, que
nacieron el día que los pedidos dejaron de tener bloque propio.

### Cada ítem en su caja, y los grupos como carpetas

Una lista es una grilla de **cajas**, no renglones separados por una línea
dentro de un marco común: con cada uno en su caja la grilla sale sola y el
bloque es el mismo objeto que se arrastra para agrupar.

**Un grupo es UN objeto de la grilla**, del mismo tamaño que un ítem suelto, y
al abrirlo muestra lo que tiene adentro **compartiendo el perímetro** — la
carpeta de iOS y macOS. Adentro vuelven a ser renglones, porque ahí sí son
partes de un conjunto. Y no existe una carpeta "sin grupo": sería una carpeta
para lo que justamente no está en ninguna.

**Esto es para el agrupamiento LIBRE** (arrastrar uno sobre otro, ponerle
nombre) — no para una **dimensión de clasificación** que el ítem ya trae
(zona, grupo-carpeta-de-grupo, lo que venga). Esas se muestran como un
**segmento más del renglón** (`FilaPedido`, `FilaGrupo`: texto plano
separado por `|`, el mismo color y tamaño que sus vecinos — nunca pastilla,
nunca borde, nunca fondo) y se filtran en `Filtros` con su chip por negativa
(`Sin zona`, `Sin grupo`) para encontrar los olvidados — **nunca** como
encabezado de sección ni bucket anidado.

El dueño (2026-08-17), viendo la zona agrupada en carpetas con un bucket
ámbar "Sin zona": *"no me convence lo de la zona así, vamos achicando todo
mucho y queda una mamushka. La zona debería ser simplemente un tag más. Como
alquilado, propio"*. Se probó dos veces y las dos se revirtió: primero la
carpeta (`c3f0f851`/`543dabb5`), después una pastilla tipo `StatusPill`
—*"quedó horrible lo de pedido propio alquilado con botones! no era así! era
un link simplemente"*— hasta el mockup final, textual: *"235 has · Propio ·
La Cañada… en reposo tiene que verse texto plano idéntico al resto"*, con el
separador `|` de siempre (*"así, no puntitos"*). Si dudás entre carpeta,
pastilla o texto plano para una dimensión de clasificación: texto plano,
segmento del renglón, cursor-pointer y subrayado sólo al pasar el mouse —
en reposo, indistinguible del resto de la línea.

### La distancia (`PageShell`)

| Qué | Cuánto |
|---|---|
| Aire al borde | 16px en el teléfono, 20px de ahí para arriba (`p-4 sm:p-5`) |
| **Entre bloques** | **16px** (`gap-4`) — el único salto entre una cosa y otra |
| Entre campos del mismo bloque | 8-12px (`gap-2`/`gap-3`) — son del mismo tema |
| Ancho máximo del contenido | `max-w-7xl` — de borde a borde en un monitor de 27 no se lee |

**La distancia vive en `PageShell`, no en cada pantalla.** Por eso ninguna se ve
corrida respecto de la de al lado. Si una necesita otra distancia, la pregunta
no es qué clase ponerle: **es por qué esa pantalla es distinta**.

Y un encabezado que no dice nada —título oculto, sin migas ni pestañas ni
bajada— **no se lleva un renglón**.

---

## 2. Las piezas. Se usan, no se reinventan.

| Necesito… | La pieza | Nunca |
|---|---|---|
| **Una lista de cosas** | `ListaDeFichas` + `FichaEnLista` | Una grilla con tarjetas propias |
| **Una caja** | `CUADRO` · `CUADRO_LISO` · `CUADRO_TENUE` · `VACIO` · `AVISO` (`lib/superficies`) | **`rounded-xl border bg-card p-4` a mano** |
| Un rótulo de sección | `ROTULO` (`lib/superficies`) | `text-[0.7rem] font-bold uppercase…` a mano |
| Carpetas en una lista | `repartirEnCarpetas` (`lib/carpetas`) | Repetir el reparto en cada página |
| Filtrar una lista | `Filtros` | Escribir chips a mano |
| Una fila de pestañas | `Pestanas` / `SubTabs` | Links a otra pantalla |
| Una grilla | `GRILLA_LISTA` · `GRILLA_BLOQUES` · `GRILLA_TARJETAS` · `GRILLA_CAMPOS` | `sm:grid-cols-2` a dedo |
| Dar de alta o editar una entidad | `ExpandableForm` con `backdrop` (§2, "El formulario pegado a la barra") | `HojaEdicion` en pantallas nuevas, o un panel embutido en la página |
| Un menú de acciones | `ActionSheet` | Un dropdown desde arriba |
| Cancelar / Guardar | `AccionesFormulario` | Dos botones escritos a mano |
| **Cualquier botón** | `components/ui/button` | **Clases escritas a mano** |
| Elegir entre pocas opciones | `SegmentedControl` | Tarjetas gigantes con emoji |
| Adjuntar en el chat | `MenuAdjuntar` | Otro "+" con otro comportamiento |
| Borrar | Papelera + Deshacer, o `BorrarConNombre` | "¿Está seguro?" |

### El menú — UNA definición, dos niveles

**La estructura vive en un solo archivo** (`components/layout/nav-items.ts`) y
la consume **un solo componente** (`TopNav`). No se negocia, y el motivo es un
daño medido: antes vivía embebida en `Sidebar.tsx`, que renderizaba **dos
árboles distintos con el mismo contenido escrito dos veces** — un overlay a la
izquierda en el teléfono y un panel fijado a la derecha en escritorio. El
usuario perdía el modelo mental al cambiar de dispositivo: el menú aparecía de
otro lado y en otro orden. Con una definición única, el orden y los destinos
son idénticos en todos los anchos.

**Las dos rayitas se convierten en cruz, y son UNA pieza compartida.**
`IconoMenuCruz` (`abierto=false` dos rayas, `abierto=true` giradas 45°/-45°)
la usa el ☰ del menú **y** el gatillo de "Filtrar". El dueño (2026-08-20) no
pidió "una animación parecida" sino la misma pieza: dos animaciones que hoy
coinciden mañana divergen porque alguien tocó una sin acordarse de la otra.

**Dos niveles, y el segundo se abre en el lugar — como en una Mac.** Un ítem
es un grupo (`main`, el destino de tocar el título) con sus `submenus`
opcionales:

| Campo | Qué decide |
|---|---|
| `primary: true` | Va **siempre visible** en la barra. El resto entra en "Más". |
| `main` | A dónde lleva tocar el título del grupo. |
| `submenus` | Los accesos que se **sacaron de la barra** para no contaminarla. |
| `tabKey` | El nombre de la PÁGINA cuando no coincide con el del rubro. |
| `module` | El grupo depende de un módulo contratado (ver abajo). |

- **Qué va en `primary`**: frecuencia de uso real, no simetría del
  organigrama. Pedidos y Depósitos se tocan todos los días; Configuración, una
  vez por temporada.
- **Qué va en `submenus`** (dueño, 2026-08-11): compras, mediciones, plantillas,
  depósitos, insumos, cheques. Viven **dentro de su grupo**, no sueltos
  compitiendo con los destinos del trabajo diario. **En el teléfono el grupo
  se toca y se expande en el mismo overlay, sin abrir otra pantalla** — que es
  la parte que lo hace usable con el pulgar y la que se rompe apenas alguien
  decide que un submenú "merece" su propia pantalla.
- **El menú dice el rubro, la pestaña dice la pantalla.** El menú dice VENTAS y
  la primera pestaña dice LOTES (`tabKey`). Sin eso la fila arranca repitiendo
  el nombre de la sección en la que ya estás: **una pestaña dice a dónde vas,
  no dónde estás parado.** Sólo se pone donde el rubro y la pantalla se llaman
  distinto; donde coinciden (Contactos, Equipos) se omite.
- **Reportes NO es un ítem propio.** Un reporte no se consulta en abstracto:
  se consulta desde el negocio del que uno está hablando. Por eso hay
  "Producción → Reportes" y "Finanzas → Reportes", cada uno entrando a su
  pestaña de `/reports` vía `?vista=`. Suelto arriba obliga a entrar y recién
  ahí elegir de qué negocio: un paso de más, y una decisión que el usuario ya
  tomó al abrir el menú.
- **Los `path` son siempre la ruta canónica en inglés.** Las viejas en español
  existen sólo como redirect y no aparecen acá.
- **Un grupo con `module` se esconde si el usuario no lo tiene, pero falla
  ABIERTO.** Se muestra la intersección de lo que la empresa habilita y lo que
  el usuario tiene autorizado; si ese dato **no llegó** (sin sesión, query
  caída, backend viejo) se muestra igual. Esconder un módulo entero por un
  fetch que falló es peor que mostrar de más — el mismo criterio que el resto
  de la app: **nunca inventar un estado más restrictivo que "no sé".**

### Botones — hay UNA forma

> *"Los botones son grandes, deberían ser standard, como los de guardar. Ya hay
> una forma de hacer botones, no se puede usar otra."* — el dueño

`components/ui/button`, siempre. Las variantes ya están decididas y no se
inventan otras:

| Variante | Cuándo |
|---|---|
| `default` | La acción principal — el inverso del fondo |
| `outline` | Las otras acciones del mismo grupo |
| `secondary` | Acciones de menor peso |
| `ghost` | Íconos de encabezado |
| `destructive` | Sólo borrar |

Y el tamaño: `sm` adentro de un renglón de lista, `default` en un formulario o
una pantalla, `icon` para los de ícono. **Un botón con `className` de tamaño o
color propio es un bug.**

**36px de alto, no 48.** El área táctil de 44px se consigue con `.toque-44`,
que agranda el BLANCO sin agrandar el dibujo — es exactamente para eso. Un
formulario con todos los controles de 48px se lee burdo: la pantalla parece
hecha para otra cosa.

### Filtros — las reglas

- **Un filtro es un GRUPO con sus opciones**, no una opción suelta. Con
  opciones sueltas cada toque pisa al anterior y no se puede combinar.
- **Se despliega AL LADO** al tocarlo, en la misma fila, donde estaba el dedo.
- **Se combinan.** "Sembrados + Arrendados + Zona norte" es lo normal.
- **El chip dice QUÉ está filtrando** ("Estado · Sembrados"), no sólo cómo se
  llama el grupo. Un filtro puesto que no se ve es la forma más rápida de que
  alguien crea que perdió datos.
- **Todos los grupos se ven SIEMPRE**, en cualquier ancho (dueño, 2026-08-17:
  *"los chips de filtro se muestran SIEMPRE todos"*). `secundario` sigue
  existiendo pero es sólo de ORDEN —van después de los principales—, nunca de
  visibilidad. Antes vivían detrás de un "+" hasta tocarlo.
- **Volver a tocar la opción elegida la apaga.** Sin eso no hay salida.
- Y **si dos filtros mezclan preguntas distintas, son dos grupos**, no uno
  (ver Contactos: "qué es para mí" y "de qué").

### El chat — píldora abajo, se abre a la izquierda, se amplía hacia arriba

Tres estados, y el usuario los maneja con el dedo. **Vale igual en mobile y en
escritorio**: es la misma pieza, no dos.

1. **Píldora abajo a la derecha.** Es el estado de "estoy adentro de una
   página": el chat **no le come un renglón entero al contenido** cuando el
   productor vino a mirar otra cosa.
2. **Tocarla la despliega HACIA LA IZQUIERDA**, a todo el ancho, con la altura
   del cuadro de texto nomás. Alcanza para escribir sin tapar la pantalla.
3. **Arrastrarla hacia arriba la abre a pantalla completa**; hacia abajo,
   vuelve.

Las reglas que lo sostienen:

- **Pointer events, no touch events**, así el gesto anda igual con dedo, mouse
  o lápiz — y se puede probar en escritorio sin emular touch.
- **El eje se decide ANTES de actuar.** Se fija recién cuando el movimiento
  pasa los 8px, y si sale más horizontal que vertical el gesto **se cancela
  entero**: el pulgar resbalando al costado no puede abrir el chat por error.
- **El textarea se excluye del gesto sólo EXPANDIDO.** Colapsada, la píldora
  es casi enteramente el textbox: excluirlo ahí deja al gesto sin dónde
  agarrarse y "no se puede abrir arrastrando". Expandida sí se excluye —
  un arrastre accidental mientras se tipea no puede cerrar el chat de golpe.
- **`touch-action` tiene que estar puesto ANTES de que empiece el toque.**
  Ponerlo al arrancar el gesto no sirve: el navegador decide en el
  `touchstart` si el toque es suyo mirando el valor de **ese** instante, y si
  se lo queda manda `pointercancel` y no hay arrastre. Es un bug que en
  escritorio no se ve, porque con mouse no hay arbitraje.
- **El scroll NO cierra nada, en ningún estado.** Ni el expandido se cierra ni
  la píldora se encoge sola: el chat lo guarda el usuario. Un gesto hecho para
  mirar la página no puede decidir por él.

### La voz — UN mecanismo, el de WhatsApp

**Se graba apretando la píldora. No hay un segundo modo de grabar en toda la
app**, y el gesto es el que el productor ya sabe:

| Gesto | Qué hace |
|---|---|
| **Tap corto** (<250ms) | Despliega el chat a lo ancho. No graba. |
| **Mantener** | Empieza a grabar directo, sin abrir nada. |
| **Deslizar al costado** | Cancela el envío. |
| **Deslizar hacia arriba** | **Bloquea**: sigue grabando con el dedo suelto. |
| Bloqueado: tocar el micrófono | Detiene y **envía**. |
| Bloqueado: el tacho | **Borra** el mensaje. |

- **250ms separa "toqué" de "mantuve".** Más corto y un tap normal arranca a
  grabar sin querer; más largo y el que quiere grabar cree que no funcionó.
- **Manda el eje DOMINANTE, no el primero que cruza el umbral.** Subiendo en
  diagonal siempre hay algo de horizontal: sin comparar los dos, el audio se
  cancela justo cuando el productor lo quería dejar grabando.
- **El bloqueo SIEMPRE tiene salida.** Sin las dos acciones (tacho y
  micrófono) soltar el dedo no toca nada, el micrófono queda prendido para
  siempre y el candado rojo se queda en pantalla sin ningún control que lo
  saque: *"tiré para arriba y quedó así, no hay cómo pararlo ni sacarlo de esa
  situación"*. Un estado sin salida es un bug, no un estado.

### La onda vive en el input, y es la misma para los dos

La onda de audio se muestra **sólo dentro del cuadro de texto**, nunca en el
botón: **roja cuando grabás vos, verde cuando habla el bot**, en el **mismo
lugar** para ambos. Se mueve al ritmo del audio real.

Un solo lugar para las dos voces es lo que hace que se lea como una
conversación y no como dos aparatos distintos. El botón no se anima: sólo
cambia de color y de ícono según el estado.

### El "+" — UNO, y se convierte en la ✕ que lo cierra

Tenía **tres comportamientos para el mismo botón** (cuadrito con opciones en
el chat abierto, desplegar la persiana en la píldora, abrir el explorador de
archivos en el inicio). Ahora es una pieza en los tres lugares, y como el
arreglo vive en la pieza, el próximo "+" ya sale bien.

- **Se abre hacia ARRIBA.** El "+" vive abajo, al alcance del pulgar; un menú
  que cae hacia abajo se sale de la pantalla y de la zona del dedo.
- **Rota 45° al abrirse**: el "+" se convierte en la ✕ que lo cierra, así no
  hacen falta dos controles. Misma idea que ☰→✕.
- **Ícono Y palabra** en cada ítem. Un ícono suelto se entiende sólo cuando el
  destino es obvio, y "reportar un problema" no lo es.
- **Sin color de marca**: el color se guarda para lo que exige atención, y acá
  no hay nada urgente. **44px** de área por ítem. Cierra al tocar afuera y con
  Escape.

### El cuadro de búsqueda va AL LADO de los filtros

- **Desplegado si entra; si no, la lupa** (dueño, 2026-08-15: *"el botón
  buscar debería tener el cuadro de texto, salvo que no tenga lugar"*).
- **Se MIDE, no se decide por breakpoint.** Un breakpoint no sabe qué hay en
  la fila: con pantalla ancha y "Estado" desplegado el campo entraba a la
  fuerza y empujaba todo abajo; con pantalla angosta y un solo chip sobraba
  lugar y aparecía la lupa igual. Se mide el hueco desde el **último chip**
  hasta el borde derecho: si entran las 15rem, va desplegado.
- **El último chip, no la suma de anchos**: los chips envuelven, así que
  importa cuánto sobra en el renglón donde terminaron. Y no puede pestañear —
  los chips van antes que el buscador en el orden de envoltura, o sea que
  medir no cambia lo que se mide.

### La pantalla de filtros — completa, y la cierra el ☰

`PaginaDeFiltros`, para cualquier colección (dueño, 2026-08-20: *"te pedí una
pantalla de filtros como tiene MercadoLibre"*).

- **Ruta propia, no una hoja.** "Ver X" / "Limpiar" al pie, donde llega el
  pulgar. "Recordar estos filtros" opcional.
- **La cierra el ☰ del menú convertido en ✕, no una cruz propia.** El dueño
  frenó en vivo el primer intento (2026-08-20): *"el símbolo del botón Filtrar
  NO SE TOCA... el ☰ del menú se convierte en la cruz con su animación
  existente, y esa cruz cierra"*. La pantalla publica su título y
  `cancelarFormulario` en la cumbrera y **es `TopNav` quien hace el cambio** —
  el mismo mecanismo que el alta de pedido, no una pieza nueva.
- **Por eso arranca en `top-14`, no `inset-0`:** tapar la barra dejaría el
  ☰/✕ sin ser visible ni tocable, que es lo único que cierra.
- **El pie es `FormActions`**, no un par propio: es el mismo Guardar/Cancelar
  de cualquier formulario, sólo que Guardar dice "Ver X". Sin color de marca —
  le pone una recomendación a una decisión que es del productor.

### Pestañas

- El **título de la pantalla ES la primera pestaña**: no se escribe dos veces.
- **La primera pestaña dice la PÁGINA, no el rubro**: el menú dice VENTAS, la
  pestaña dice LOTES. Una pestaña dice **a dónde vas**, no dónde estás.
- **Ni bajada ni flecha de volver** donde hay pestañas.
- **La última es un `+`**, al fondo a la derecha, separado.
- **Si no entran, son demasiadas.** La pregunta no es cómo mostrarlas todas
  sino **cuáles comparten formulario**.

### Hojas

- Oscurecen todo (negro 70%). Tocar el fondo cancela.
- **Agarradera arriba, arrastrable de verdad.** Dibujada y muerta es peor que
  no tenerla.
- **Sin cruz de cerrar**: ya hay tres salidas (fondo, agarradera, Escape).
- Guardar y Cancelar **anchos y apilados**, del mismo tamaño. Achicar Cancelar
  es decidir por el otro.
- El teclado se mide con `visualViewport`: con el teclado abierto `bottom: 0`
  es el borde de la ventana y queda tapado.

**Esta pieza (`HojaEdicion`/`HojaDelNombre`, la hoja que sube de abajo con
agarradera) es la que se está retirando** — ver la sección siguiente. Hoy
sigue viva donde todavía no se migró (`EquipmentDetailPage`,
`WarehouseDetailPage`), pero no es la que se copia en una pantalla nueva.

### El formulario pegado a la barra — `ExpandableForm backdrop`

> El dueño (2026-08-19), sobre "Crear pedido" y extendiéndolo a **todo el
> sitio**: *"todos los formularios... van pegaditos a tope a la barra de
> título y opacan el fondo completo, para tener máxima concentración en lo
> que se está haciendo... así deberían ser todos los formularios del
> sitio"*. Y sobre la grupo, el mismo día, viendo la hoja vieja: *"dejar de
> usar el grabber, cambiarlo por lo que hicimos hermoso en pedidos"*.

Es el reemplazo de la `Hoja` (arriba) para dar de alta o editar: **no sube
desde abajo, se ancla arriba, pegado a la barra de título**, con el fondo
casi opaco detrás. El dueño lo pidió por partes y esto es como quedó, junto:

```
┌ Ventas › Pedidos › Norte    [✕] ┐   ← la barra publica el título EN VIVO
│░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░│   ← fondo negro 80%, no 70% — "se
│  ┌──────────────────────────────────┐   │      seguía viendo todo por debajo,
│  │ NOMBRE *                         │   │      distrae" (dueño, 2026-08-19)
│  │ [ Norte              ] 🗑  │   │
│  │ SUPERFICIE (HA)                  │   │   ← SIN caja en mobile (dueño,
│  │ [ 120.5                     ]    │   │      2026-08-20: "que no tenga
│  └──────────────────────────────────┘   │      box, más minimalista") — de
│         [       Guardar        ]         │      sm: para arriba sí hay marco
│         [       Cancelar       ]         │
└───────────────────────────────────────────┘
```

**Las cuatro piezas del gesto, y por qué son una sola cosa:**

1. **Fondo opaco (`backdrop`)** — `fixed inset-x-0 bottom-0 top-14 z-30
   bg-black/80`. 80%, no 50%: con menos se sigue leyendo la pantalla de
   atrás y distrae en vez de concentrar. No cierra al tocarlo (a
   diferencia de la `Hoja`) — es un paréntesis de verdad, no un modal que
   se descarta solo.
2. **La barra de título dice lo que se está cargando, EN VIVO** —
   `useTituloContexto` con el `titulo` derivado del campo que se está
   tipeando (`datosPedido.nombre.trim() || t('pedidos.create')`): "Pedido ›
   [lo que vas escribiendo]". Es el mismo mecanismo con el que la ficha
   ya publica su cumbrera, así que no es un caso especial: es CÓMO se
   publica un título mientras se edita algo.
3. **El ☰ se vuelve ✕** — `cancelarFormulario` en el mismo
   `useTituloContexto`: mientras hay un alta con `backdrop` abierta, el
   botón de menú dos-rayitas de `TopNav` gira 45° y ES la cruz que cierra
   ese formulario, no el menú. *"Al clickear la edición las rayitas se
   forman en cruz"* (dueño, 2026-08-19). Un solo control, dos trabajos
   según haya o no un alta abierta — nunca un ✕ de más al lado.
4. **Abrir y cerrar son simétricos** — al abrir, la página baja hasta el
   panel (`scrollIntoView`); al cerrar, vuelve exactamente a donde estaba
   (`scrollAlAbrir` en `ExpandableForm.tsx`). Sin esto el productor queda
   "tirado en el medio de la lista, sin encabezado" (dueño, 2026-08-11,
   el bug original de la versión sin `backdrop`).

**La receta, siempre las mismas props:**

```tsx
<ExpandableForm
  open={formAbierto}          // estado controlado, SIEMPRE — nunca defaultOpen acá
  onOpenChange={setFormAbierto}
  hideTrigger                 // si algo MÁS abre el form (tocar el nombre, un "+" propio)
  backdrop                    // el fondo opaco — sin esto es el alta inline chica de siempre
  triggerLabel={t('...')}
  title={t('...')}            // lo que dice la barra si no hay título en vivo propio
>
  {(close) => (
    <MiForm onCancelar={close} onSuccess={() => { close(); refrescar(); }} />
  )}
</ExpandableForm>
```

Y en la cumbrera de la página (`useTituloContexto`, junto al resto):

```tsx
cancelarFormulario: formAbierto ? () => setFormAbierto(false) : undefined,
```

**`hideTrigger` sí, `hideTrigger` no** — la única decisión real:

| Quién abre el form | `hideTrigger` |
|---|---|
| Tocar el NOMBRE en la barra (editar algo que ya existe) | `true` — el trigger propio no tiene sentido, ya hay un gesto |
| Un "+" que vive en la fila de pestañas o el header de una lista (`ActivityPicker`, `HistoryPanel action`) | `true` — el "+" ya existe, es OTRO botón el que decide abrir |
| Nada más lo abre — es la ÚNICA forma de dar de alta en esa pantalla | `false` — `ExpandableForm` dibuja su propio "+" |

**Guardar es DOBLE a propósito, no un bug**: el `<AccionesFormulario>` que
`ExpandableForm` pone al pie (`Guardar`/`Cancelar`, fijo, siempre en el
mismo lugar) busca `button[type="submit"], button[data-app-submit]`
**dentro del panel** y lo clickea — no reimplementa el guardado. Si el
formulario hijo ya tiene su propio botón de submit (`ProduccionActivityForm`,
`ControlForm`, `MantenimientoDepositoForm`…), los dos conviven: el de adentro,
más chico y en su lugar de siempre; el de `ExpandableForm`, abajo del todo,
ancho, el que se usa el 90% de las veces. **Si el botón interno no tiene
`type="submit"` de forma explícita** (un `<Button onClick={...}>` sin
`type`, que es lo más común en formularios viejos armados sin `<form>`),
agregale `data-app-submit` — si no, el "Guardar" de abajo no encuentra nada
para clickear y no hace nada.

**Dónde ya está** (agosto 2026, la lista crece — si tocás una pantalla que
todavía usa el patrón viejo, es candidata): Crear/Editar Pedido
(`PedidosPage`, `PedidoDetailPage`), el alta de actividad del pedido (alta,
cierre, labores), Editar Grupo y su alta de actividad (`GrupoDetailPage`),
el alta de actividad del depósito (`DepositoDetailPage`), las cuatro altas del
taller (`TallerPage`: medición, unidad, comprobante, análisis), Crear Equipo
(`EquipmentPage`) y el alta de servicio (`EquipmentDetailPage`), Crear
Almacén (`DepositosPage`) y el alta de stock/herramienta
(`WarehouseDetailPage`).

**Cuándo NO lleva `backdrop`**: un alta chica, de un campo o dos, que vive
al lado de lo que crea (`SelectWithInlineCreate`, un maestro) sigue siendo
la versión SIN `backdrop` de `ExpandableForm` — ésa nunca tapó la pantalla
y no tiene por qué empezar ahora. `backdrop` es para el alta/edición de una
ENTIDAD (un registro con nombre propio, varios campos), no para cualquier
`ExpandableForm`.

**Cuándo NO es esto, aunque se le parezca**: si la pantalla no tiene un
alta de UN registro sino un panel propio con su historial adentro (el
seguro del pedido, `PedidoSeguroPanel`; el movimiento de una grupo,
`MoverGrupoADeposito` + `DividirGrupo` + `EtiquetasDeGrupo` juntos) — eso
sigue en línea, sin `backdrop`, porque disfrazarlo de "Agregar X" mentiría
sobre qué es: no es un alta, es gestión.

---

## 3. Formularios

- **Se piden los datos QUE SE PUEDEN TENER EN ESE MOMENTO.** Un formulario que
  pide algo que nadie sabe todavía enseña a inventarlo. (La cierre se parte en
  tres momentos: el campo, el detalle, la venta.)
- **Salir guarda.** Si falta algo importante, se guarda un borrador y se avisa.
  Guardar automático **por tiempo** no: un reloj no sabe si terminaste.
- **"Limpiar" no existe.** Nadie quiere vaciar los campos; quiere irse.
- **Todos los campos son columnas de la misma grilla** (`GRILLA_CAMPOS`). Los
  anchos a mano hacen el zigzag y el borde derecho serrucho.
- **CRUD de tipos adentro del formulario**: todo selector de "tipo" cierra con
  "+ Agregar…". Mandar a otra pantalla es la forma más barata de que todo se
  cargue como "Otro".
- **El alta ES la compra**: dar de alta animales, insumos o un equipo registra
  la compra en el mismo acto, con el precio **opcional**.

---

## 3.1 El alta en el renglón — LA forma de cargar sin salir del formulario

> El dueño (2026-08-15), sobre el alta de variedad: *"me encantó cómo
> resolviste lo de variedad, quiero que lo implementes en cada rincón del sitio
> que tenga un alta que se pueda hacer inline"*. Y sobre el selector de
> orígenes: *"**esta es la forma de hacer las cosas**, implementalo en cierre,
> en fumigación…"*.

Hay **dos piezas** y ninguna otra. Si estás por escribir un panel, un diálogo o
una tarjeta para dar de alta algo desde adentro de un formulario, es una de
estas dos.

### a) Un maestro que es SÓLO UN NOMBRE → `SelectWithInlineCreate` + `onCreate`

Variedad, categoría, proveedor, tipo de animal, cliente. El `+` **convierte el
campo en el alta**:

```
  Variedad            →   NUEVA VARIEDAD          ← el rótulo es el título
  [ sadf        ▾][+]     [ DM 4670    ] [✕][✓]   ← ✕ roja, ✓ verde
```

- Enter guarda, Escape cancela.
- Si la mutation falla, **el nombre escrito no se pierde**.
- Lo recién creado **queda elegido** aunque el `refetch` no haya vuelto.
- El llamador escribe UNA mutation (`onCreate`) y nada más.

`renderCreateForm` (el panel de abajo) sobrevive **sólo** para maestros que no
son un nombre: un insumo necesita tipo y unidad.

Un maestro de **dos** campos (un depósito: nombre + capacidad) NO baja al panel:
`SelectWithInlineCreate` se extiende con `campoExtra` y el segundo campo se
dibuja en el mismo alta en línea, debajo del nombre.

### a.1) Una acción ADENTRO del cuadro de texto → `CampoConAccion`

> El dueño (2026-08-17), sobre el alta de depósito y el trío unidades/machos/
> hembras: *"si lo ponés adentro del textbox, esa será nuestra forma de hacer
> las cosas y va en todos lados así"*.

Un `Input` con una acción chica de texto (`"Todos"`, `"Total"`) flotando
adentro, a la derecha — no un botón aparte al lado. La usa `campoExtra` (el
botón **Total** que completa la capacidad del depósito con las unidades de la
grupo) y el trío unidades/tipo A/tipo B (el botón **Todos** de Tipo A/Tipo B).
Sigue siendo editable después: el proceso es opcional, el resultado no se
bloquea.

### a.2) La flechita EDITA, NO navega → `onEditar`/`renderEditForm`

> El dueño (2026-08-18), aprobando el diseño tal cual: *"la flechita › dentro
> de un form abre la EDICIÓN del maestro en línea... guardar vuelve al form
> intacto porque nunca te fuiste"*.

**Prohibido**: una flechita `›` dentro de un formulario que navega a la
ficha completa del maestro. Eso saca al productor del formulario grande que
la estaba usando —y con él, todo lo que ya había tipeado— para arreglar un
typo en el nombre del proveedor.

`SelectWithInlineCreate` y `CampoContacto` resuelven esto con el mismo par
que ya usa el alta:

- **`onEditar(id, nuevoNombre)`** — el caso simple, un rename EN el
  renglón. Mismo `Input` + `CruzYTilde` que `onCreate`, pre-cargado con el
  nombre actual.
- **`renderEditForm(id, onSuccess, onCancel)`** — varios campos (un
  proveedor con teléfono y email, un depósito con capacidad), en el mismo
  panel que `renderCreateForm`.

"No perder lo tipeado" no es una feature aparte: es la CONSECUENCIA de que
nunca hay `navigate()` — el formulario padre nunca se desmonta. Lo que no
entra en la edición rápida (cuenta corriente, historial de un contacto)
sigue en la ficha completa; esto es para el arreglo sin abandonar el
formulario, no un reemplazo de Contactos/Depósitos.

`rutaDe` sigue viva como respaldo para el maestro que todavía no tiene
`onEditar`/`renderEditForm` — migrar es agregar una de las dos props, no
reescribir la pieza.

#### El estándar del CRUD en línea (dueño, 2026-08-19)

> *"Debería tener un lapicito para editar, a la izquierda del + para
> agregar. Al clickearlo aparece el cestito para eliminar. Durante la
> edición hay 3 botones: textbox, delete, greencheck, redcross. Al
> clickear delete, el clásico botón de confirmar se desplaza ocupando
> todo el espacio del textbox y la cruz de cancelar. Esto es estándar
> desde ahora para todos los CRUD en línea de la app."*

Es la forma FINAL, sin excepciones, de `SelectWithInlineCreate` (y de
cualquier pieza nueva que resuelva el mismo problema):

```
  reposo:     [ Elegido       ▾ ] [✎] [+]        ← el tacho NO vive acá
  editando:   [ Nombre nuevo    ] [🗑] [✓] [✕]    ← 3 botones, en ESE orden
  armado:     [       Confirmar        ] [✕]      ← el tacho se comió todo
```

- **El tacho vive DENTRO de la edición**, no suelto al lado del `▾` en
  reposo. Un tacho visible sin haber tocado el lápiz es una amenaza sin
  contexto — recién tiene sentido cuando ya se está mirando ESE renglón
  para corregirlo.
- **Armar el borrado (`DeleteButton`) hace desaparecer el textbox y el
  tilde** — el mismo criterio que ya usaba el borrado del maestro elegido
  en reposo (`className={armado ? 'flex-1 justify-between' : 'shrink-0'}`):
  mientras pregunta, la pregunta ES el renglón entero.
- Guardar el formulario grande sin haber tocado el ✓ de una edición en
  curso **también la confirma** (`lib/pendientes-inline.tsx` — el mismo
  registro que ya cubre `onCreate`): "estoy escribiendo un nombre nuevo y
  toco Guardar abajo" tiene que guardar los dos, sea alta o edición.

### b) Elegir de una lista, con cantidad y con alta → `ElegirEnFila`

De dónde sale / a dónde va: el origen de la insumo, el destino de la cierre,
el depósito del insumo, el tanque del combustible.

```
  Depósito ACA - Rosario            12.500 kg  ›   ← tocar ELIGE, la flecha ENTRA
  Depósito
  ─────────────────────────────────────────────
  Estante Propio                    [ 300 ] kg [✕][✓]   ← elegido: pide la cantidad
  Estante
  ─────────────────────────────────────────────
  [ Depósito ACA - Rosario      ]         [✕][✓]   ← el alta es un renglón más
  (Depósito)(Estante)(Depósito)                          ← los tipos, donde va el sub
  ─────────────────────────────────────────────
  + Nuevo origen
```

Las cuatro reglas:

1. **El renglón es la unidad.** Elegir, escribir cuánto, crear y entrar a la
   ficha pasan todos en un renglón de la misma altura.
2. **Tocar el renglón ELIGE; la flechita ENTRA** a la ficha para cargar el
   resto. Dos destinos, dos blancos, nunca el mismo.
3. **El alta es un renglón más**, no un panel: cuadro de texto donde va el
   nombre, los tipos donde va el subtítulo, `CruzYTilde` al final.
4. **Entra todo, sin barra de scroll** (*"no quiero que haya barras de scroll,
   debería entrar siempre todo"*). Por eso son renglones y no tarjetas: en el
   alto de tres tarjetas entran ocho renglones.

### La cruz y el tilde son UNA pieza: `CruzYTilde`

Íconos y no palabras (en una grilla de dos columnas "Cancelar" y "Crear"
aplastan el cuadro de texto), **teñidos** y no rellenos (`--success` en oscuro
es un verde claro donde el blanco no contrasta), y el tilde se convierte en la
ruedita mientras guarda: un segundo toque crea dos filas.

### Lo que se carga puede quedar A MEDIAS

*"Todo se debe poder cargar al ritmo del usuario."* Falta el origen de 200 de
los 300 kg: **se guarda igual**, queda pendiente visible y todo número que
dependa de eso se muestra **ámbar** (`Cifra`) hasta que se complete. El
proceso es opcional; el resultado, obligatorio.

**El ámbar es la ÚNICA señal de un número estimado — SIN el símbolo `≈`
adelante** (el dueño, 2026-08-17, sacándolo de `Cifra`: *"el ámbar ya indica
que es una estimación"*). Antes convivían dos marcas para el mismo hecho —el
`≈` y el color— y era una de más: el ámbar solo alcanza, y el motivo de la
estimación sigue disponible en el `?`/popover de siempre (`title`, se lee
manteniendo apretado en el celular), nunca se pierde información. Un aviso en
texto (`"revisar pesadas"`) también usa el ámbar, por la misma regla. Y **el
rojo jamás es ámbar disfrazado**: rojo es una mala noticia CONFIRMADA
(mortandad, deuda, retiro); si el número todavía depende de una estimación,
no es rojo, es ámbar.

### Y la explicación va en el `?`

Nada de carteles de letra chica explicando qué es un origen: `Ayuda`, el signo
de pregunta, al lado del rótulo o del botón. Ver §0.1.

### 3.2 La moneda clickeable — ARS ⇄ USD ⇄ QQS (`Cifra`, 0292)

*"Al clickear la moneda, te cambia la moneda… el combustible sale 2000 ARS,
clickeás en ARS y te lo pasa a dólares, clickeás de nuevo, a QQS unidades de
tipo A, y luego a ARS de nuevo. Sirve para ingresar un valor o para ver."* — el
dueño, "es súper importante que esto funcione bien". QQM de maíz no entra
("creo que no se usa").

Es **contrato desde acá**, no una guía de estilo: se implementa en LA PIEZA
(`Cifra`), nunca pantalla por pantalla.

**Las reglas, en el orden en que se rompen:**

1. **La verdad guardada es el ARS original.** La conversión es sólo
   presentación e ingreso; nunca se re-guarda un valor convertido pisando el
   original.
2. **Toda conversión parte SIEMPRE del ARS original**, nunca del valor ya
   convertido que está en pantalla — `lib/conversion-moneda.ts` es el único
   lugar con la aritmética, y sus tests son el candado: el ciclo
   ARS→USD→QQS→ARS tiene que devolver EXACTAMENTE el número inicial. Encadenar
   conversiones acumula el redondeo de presentación como si fuera dato.
3. **Redondeo sólo al presentar** (ARS sin decimales, USD con 2, QQS con 1),
   nunca en el dato — `formatearEnUnidad`.
4. **La tasa viaja con su fecha, visible** (tooltip: "al dólar del 16/08 ·
   $1.320"). Tasa vieja (>48 h), no exacta, o el valor todavía no pasó (sin
   `fecha`: una proyección — grano sin vender) ⇒ el número se pinta **ámbar
   `Cifra`**. Sin la tasa que hace falta, esa unidad no se dibuja con un
   número inventado: `Cifra` cae a ARS para ese número puntual y dice por qué.
5. **Preferencia GLOBAL persistida** (`useUnidadMoneda`, `app.unidad-moneda` en
   `localStorage`, sincronizada entre pestañas): tocar CUALQUIER número
   cambia la moneda de presentación de TODA la app. El rótulo es el botón.
6. **Para ingresar**, el modelo es: se guarda el importe en la moneda que se
   eligió (valor + moneda + fecha, tal cual se tipeó) y la cuenta se hace al
   calcular — nunca se re-convierte al guardar. La puerta de entrada es
   `MovimientoDeDinero`; el monto en pesos muestra una conversión de
   CORTESÍA a US$/qq (con la tasa de HOY, informativa, no se guarda).
7. **La regla de la fecha**: lo que YA PASÓ se convierte a la tasa de SU
   fecha (si no, la devaluación reescribe la historia); lo que NO PASÓ
   todavía (grano sin vender, proyecciones) va a la tasa de HOY y queda
   SIEMPRE ámbar.

**Cómo se usa:**

```tsx
// Antes (número fijo, sin conversión):
<Cifra valor={margen}>{fmtMoney(margen)}</Cifra>

// Ahora (la pieza hace la conversión y el click):
<Cifra ars={margen} fecha={fechaDelMovimiento} />   // pasado: tasa de esa fecha
<Cifra ars={proyectado} />                          // sin fecha = hoy, siempre ámbar
<Cifra ars={margen} motivos={[...]} />              // se pueden combinar los dos
```

Sin `ars`, `Cifra` sigue funcionando exactamente como antes (`valor`/
`children`/`motivos`, para porcentajes y números que no son plata) — la
prop es aditiva, no rompe ningún uso existente.

**Deuda relevada al construir esto (2026-08-16, no se cazó una por una en este
pedido — pedido explícito del jefe):** 36 usos de `<Cifra` contra 191 llamadas
a `fmtMoney(...)` en 31 archivos que muestran plata SIN pasar por `Cifra` —
`AccountingMovementsPage`, `ChecksPage`, `ClientStatementPage`,
`CommissionsPage`, `ContactDetailPage`, `DashboardPage`,
`EquipmentDetailPage`, `EquipmentServicesPage`, `FeedingPage`,
`FinancesPageNew`, `FuelBookPage`, `HoteleriaReportePage`, `TareaForm`,
`LeaseDetailPage`, `PaymentTermsPage`, `AltaForm`, `RankingFormulasPage`,
`SalesPage`, `ServiceBillingPage`, `TaskOrderDetailPage`, `ZonasPage`,
`PedidoSeguroPanel`, `taller/FormComprobante`, `ventas/FormVenta`,
`servicios/GastosDelDeposito`, `equipos/FilaEquipo`, `produccion/FilaContrato`,
`produccion/FilaPlantilla`, `produccion/FilaControl`, `shared/Contact360`,
`trabajos/FilaTaskOrder`. Migrarlos es reemplazar `fmtMoney(x)` por
`<Cifra ars={x} fecha={...} />` uno por uno — mecánico, pero no gratis.
`FinanzasDelPedido.tsx` (el P&L de pedido) ya usa `useUnidadMoneda` pero convierte
del lado del backend (`lotFinances`, con USD todavía sin soportar): es un
segundo camino de conversión que este pedido no tocó.

---

## 4. Listas — UN SOLO MÓDULO, no un patrón a imitar

> *"Homogeneizalo con una única clase o un conjunto de clases o similar, para
> que no exista posibilidad de que quede un frankenstein."* — el dueño,
> 2026-08-14

La diferencia importa: un *patrón* se copia y cada copia se edita por su lado
—así la tarjeta de grupos y la de equipos empezaron iguales y terminaron
distintas—. Un *módulo* se usa, y cuando cambia, cambian todas.

Una pantalla que muestra una colección se arma con **estas cuatro piezas y
ninguna más**:

```
PageShell( nombre + contador · "+" )
  Filtros                    ← arriba de lo que filtran, siempre
  ListaDeFichas              ← grilla, carpetas, acordeón, vacío y pie
    FichaEnLista             ← el renglón
```

| Pieza | Dónde |
|---|---|
| `ListaDeFichas` | `components/shared/ListaDeFichas.tsx` |
| `FichaEnLista` | `components/shared/FichaEnLista.tsx` |
| `Filtros` | `components/shared/Filtros.tsx` |
| Las 5 superficies | `lib/superficies.ts` |
| El reparto en carpetas | `lib/carpetas.ts` |

**Una página no escribe la grilla, ni el acordeón, ni el cartel de vacío, ni el
pie.** `ListaDeFichas` no acepta `className` para la grilla ni una ranura para
meter un `<div>` propio entre las fichas, y es a propósito: la puerta por la que
entra el frankenstein es siempre la excepción razonable de una sola pantalla. Si
una lista necesita algo que no está, **se le agrega una ranura a la pieza** y lo
heredan las 90 restantes.

### Qué dice cada renglón

Debajo del nombre, una línea con lo que se mira para decidir, separada por `|`:

```
40 u | Preparación | Categoría B | Control (2)     ← pedido
120 u | Producto | 320 kg | 0,95 kg/día          ← grupo
Equipo 6110 | 1.240 h | $32/h | Depósito norte    ← máquina
96 / 200 · 48% | 70% T-14 · 30% T-9 | Zona norte    ← depósito
```

Y a la derecha, **el "cuánto falta"**: los días a cierre, los días al peso
objetivo, las horas al service, "casi lleno". Siempre en el mismo lugar, para
que se lea sin buscarlo.

### Las reglas que no cambian

- **Un renglón por cosa**, ancho completo en el teléfono; grilla cuando sobra
  ancho (`GRILLA_LISTA`, 22rem de mínimo).
- **Al tocarlo, ACCIONES o historia, no un informe.** Un informe no se lee en
  la camioneta.
- **Sin flechitas.** El nombre lleva a la ficha, el cuerpo abre (§1).
- **Filtros arriba**, antes de lo que filtran.
- **El total al pie**, como el explorador de archivos.
- **Arrastrar no es tocar** (`tap-seguro`); arrastrar uno sobre otro los agrupa,
  y la carpeta se ve.
- **Lo que estaría vacío no se dibuja.** Un dato que no existe se dice `—`,
  nunca `0`: un cero con cara de dato es peor que la ausencia.

### Cuándo NO es una lista

> Si el objeto tiene nombre propio, algo que le pasa y algo que se le puede
> cargar → `FichaEnLista`. Si es una fila de números que sólo existe dentro de
> un total (un asiento contable, un cheque, una cotización) → **tabla**, con
> `CUADRO_LISO` y los mismos `Filtros`. No hay una tercera opción.

El barrido de las 91 pantallas, con el veredicto de cada una:
`docs/BARRIDO_LISTAS.md`.

---

## 5. Lo que se muestra tiene que EXISTIR

La regla más cara de todas. Cada una de estas fue un botón dibujado sin
conectar que llegó al dueño:

- El `+` del inicio abría el explorador de archivos y **el adjunto no viajaba**.
- El enviar de la píldora llamaba a un callback que **nadie pasaba**.
- El menú de la barra tenía tres ítems que **sólo se cerraban a sí mismos**.
- Se ofrecía adjuntar imágenes con **un modelo que no las lee**.

> **Un control que se toca y no pasa nada es peor que no tener el control.**

Y su corolario: **si no hay con qué hacerlo, no se ofrece.** Se dice con
palabras qué falta, no se contesta como si se hubiera podido.

---

## 6. Minimalismo: qué significa acá

> **Si no se hace casi todos los días, no va en el menú.**

- **Un reporte no es una sección de cada área.** Contesta "¿cuánto ganamos?",
  que es de plata: vive en Finanzas.
- **Los tipos no tienen menú.** Se crean con el "+ Agregar…" del selector.
- **Un alta no es una página del menú.**
- **Menos botones**: un botón es una decisión que le pasás al usuario. Antes de
  agregar uno: *¿esto se resuelve con algo que ya va a tocar igual?*

| Se fue | Ahora es |
|---|---|
| Guardar (en edición inline) | Salir guarda |
| Cerrar / Volver | El gesto y el nombre de la sección en la barra |
| "+ Nuevo pedido" | Un `+`, última pestaña de la fila |
| Editar / Borrar | Tocar el nombre |
| `<Select>` de filtros | Grupos que se tocan |
| "Ver ficha" | La fila entera |
| "¿Está seguro?" | Papelera + Deshacer |

---

## 7. El texto

- **De vos**, en toda la app (rioplatense). El "usted" sólo si el usuario lo
  pidió explícitamente.
- **Vocabulario del campo**: grupo, detalle, depósito, rendimiento, unidades.
- **Sin `truncate` en nada que haya que entender**: dos renglones antes que una
  frase cortada.
- **Se dice qué es cada número.** Si es de referencia, se dice.
- **El sistema no narra lo que hace por dentro.** "Quedó guardado el trato" no
  significa nada para el productor: "el trato" es una palabra nuestra.

---

## 8. Lo que NO se toca sin permiso del dueño

1. **La fuente de los datos de clima y satelital NO se muestra en la interfaz.**
   Es el moat. (Cotizaciones y tasas son la excepción: ahí la fuente da
   credibilidad.)
2. **No hay exportadores a CSV.** Ninguno, en ninguna pantalla.
3. **El dataset del negocio no se expone crudo**: cocinado siempre.
4. **No se promete lo que no existe** (si no hay app de iOS, no se lista iOS).
5. **No se predice el rendimiento** con un modelo entrenado: con dos campañas es una
   adivinanza con cara de ciencia.
6. **Los commits no llevan trailer de coautoría.**
