# Migrar un sistema viejo

Cómo arrancamos cuando el proyecto no es una idea nueva sino el reemplazo de algo
que ya funciona — o cuando nos inspiramos en un software ajeno para hacer el
nuestro.

La regla que ordena todo lo demás: **el sistema viejo es la especificación, y es
la única que hay.** Nadie escribió lo que hace. Está en sus pantallas, en sus
tablas y en su código, y se lee. No se pregunta, no se supone, no se reinventa.

Y su gemela, igual de importante: **el sistema viejo es especificación de *qué*,
nunca de *cómo*.** Tomamos la función y el vocabulario. No tomamos su desgaste.

---

## Las seis etapas

### 1. Inventario — qué hay, medido

Antes de opinar, contar. Sin números la discusión es estética.

```
archivos por extensión · tamaño por directorio · duplicados
programas · pantallas · reportes · tablas
líneas de código · funciones · densidad de comentario muerto
```

Casi siempre aparece lo mismo: **el árbol canónico es uno y el resto son copias
fechadas**. Un directorio con `back`, `BACK20190123`, `Copia (2) de X` y `Nueva
carpeta` no tiene cuatro versiones: tiene una, y tres fotos de miedo. Identificar
cuál es la viva es la primera decisión y se toma con evidencia, no por la fecha.

### 2. Extracción — el código y los esquemas, nunca los datos

**Los datos reales no entran al repositorio. Nunca.** Un sistema en producción
guarda datos de personas reales, y una filtración no es un bug: es un incidente
declarable, y lo publicado se da por comprometido para siempre aunque se borre a
los dos minutos.

Lo que sí se extrae:

- **El código fuente**, completo, a un espejo local. El disco del cliente es
  lento y encima es evidencia: se lee la copia.
- **Los esquemas**, leyendo únicamente las cabeceras de las tablas. Nombres de
  campo y tipos son públicos; los valores no.
- **Las pantallas y los reportes**, si el formato lo permite. En muchos sistemas
  viejos los formularios y los informes son tablas: se abren y adentro están las
  etiquetas, los campos y los botones. Eso es la mejor especificación disponible,
  porque **las etiquetas son lo que el usuario lee**.

Se escribe un extractor propio y se guarda en el repo. Va a hacer falta otra vez.

### 3. Veredicto — qué está vivo y qué es escombro

La parte que más ahorra y la que casi nadie hace.

Un sistema de veinte años tiene pantallas que ya nadie abre, tablas que nadie
escribe y programas que quedaron a mitad de camino. Portarlos es trabajo puro
tirado, y peor: arrastra decisiones viejas a un producto nuevo.

**La fecha del archivo no alcanza para decidirlo, y engaña.** Alguien copia todo
antes de un cambio riesgoso y las fechas quedan iguales; alguien toca un archivo
muerto por error y queda con fecha de ayer.

**Lo que decide es el grafo de llamadas.** Una pantalla que ningún programa
invoca está muerta, tenga la fecha que tenga. Una que se invoca cuarenta y nueve
veces está viva aunque sea de hace quince años.

Se cruzan tres señales, en este orden de peso:

1. **Referencias desde el código** — quién la llama y cuántas veces.
2. **Pertenencia al build** — si el proyecto compilado la incluye.
3. **Fecha de modificación** — sólo para desempatar entre variantes vivas.

Sale una lista con veredicto por pantalla. Se publica. Si alguien reclama una que
quedó afuera, se revisa el veredicto — pero **no se porta por las dudas**, porque
"por las dudas" es como se importa la basura.

### 4. Evaluación — honesta, con evidencia

Escribir qué tan bien o mal está hecho, con números y sin diplomacia ni desprecio.

Los indicadores que casi siempre dicen la verdad:

| Señal | Qué significa |
|---|---|
| Pantallas duplicadas con variantes | Se parchó copiando en vez de cambiando. Nadie sabía cuál estaba viva |
| Muchas formas de esquema en una misma tabla | Migraciones que nadie pudo terminar |
| El log de errores del propio sistema | Si registra caídas, dejá de discutir si "andaba bien" |
| Manejo de errores desactivado | Se suprimía lo que se podía y se moría con el resto |
| Evaluación de cadenas en runtime | Reglas de negocio que no se podían testear ni cambiar sin miedo |
| Porcentaje de código comentado | Intentos abandonados dejados en el lugar |
| Tablas al lado de las vivas con nombres tipo `x.no`, `x_backup` | Alguien copió antes de un cambio y no volvió |

Y el equilibrio que hay que mantener: **casi siempre está gastado, no mal
hecho**. Alguien escribió reglas que funcionan y con las que un negocio vivió
años. Ese conocimiento no lo tenemos y no lo podemos inventar. Por eso se lee el
viejo con respeto, y por eso mismo no se copia su desgaste.

### 5. Diseño — de cero a todo, mapeado

El documento central es un inventario con casilleros, no una visión. Cada
funcionalidad con su identificador, la pantalla vieja de la que sale, y un
criterio de terminado **que cualquiera pueda verificar sin preguntar**.

Y el mapeo campo por campo. **Ningún campo del sistema viejo se descarta en
silencio**: donde no va, la tabla dice por qué. Los campos sin etiqueta, esos que
el sistema viejo nunca documentó, son exactamente donde se pierde algo — se
marcan como "hay que leer el fuente" en vez de adivinarlos.

Tres patrones aparecen en casi todo sistema viejo y valen como punto de partida:

- **Pantallas que existen sólo para elegir algo.** Suelen ser un cuarto del total
  y todas desaparecen: un selector es un campo con autocompletado, no una
  pantalla.
- **Un formulario que son cuatro entidades con un solo abrigo.** Se parte, con
  revelado progresivo.
- **Navegación por cursor de registros** — primero, anterior, siguiente, último.
  Es una interfaz de base de datos de 1990 y la reemplaza la búsqueda.

### 6. Migración — sin un mes malo

El sistema viejo sigue facturando mientras se construye el nuevo, así que la
importación **no es una migración de una sola vez**: es una capacidad permanente.

1. **Reconocimiento** sin escribir nada, y se le entrega al cliente el estado
   real de sus datos **antes de firmar**. Duplicados, huérfanos, cosas que no
   concilian. Eso es una conversación previa, no un reclamo posterior.
2. **Corrida en paralelo**: los dos sistemas emiten el mismo período y se comparan
   registro por registro. El viejo sigue siendo el que manda. Se corta cuando dos
   períodos seguidos cierran con toda diferencia explicada.
3. **Cambio** en una tarde, reimportando el delta.
4. **Primer período supervisado**, con vista previa y reversión.
5. **La reimportación queda**, para siempre.

Lo que la hace segura, técnicamente:

- `upsert` sobre la clave natural del sistema viejo, guardada como tal.
- Un manifiesto con hash por archivo: lo que no cambió no se reprocesa.
- Nada se borra sin pedirlo explícitamente, y avisando antes qué se borraría.
- Lectores que mapean por **nombre** de campo, toleran variantes de esquema y
  fallan ruidosamente con archivo, fila y campo en vez de perder una columna en
  silencio.
- El sistema viejo es de sólo lectura. Jamás se lo trunca ni se lo "arregla".

Y lo que se deja atrás, **visiblemente y nunca en silencio**: duplicados
detectados y propuestos con fusión reversible, tablas abandonadas conciliadas y
reportadas, pantallas muertas no portadas, y registros huérfanos cargados y
marcados — nunca descartados, porque descartarlos cambia lo que alguien debe.

---

## El puente que hace barata la segunda migración

Si cada cliente nuevo llega con su propio sistema viejo y cada uno obliga a
escribir un importador, el negocio no escala.

Por eso el importador **no se escribe: se declara**. Tres espacios en la base:

```
  crudo          →     mapeo          →     el modelo
  tal cual vino        qué es qué           limpio y con reglas
```

- **Crudo**: una tabla por tabla de origen, todo como texto, sin restricciones,
  más de qué archivo y qué fila salió. Sirve para reproducir una discusión seis
  meses después, para reprocesar sin volver al disco del cliente, y como
  evidencia de las variantes de esquema.
- **Mapeo**: filas, no código. Sistema de origen, tabla → entidad, columna →
  campo, transformaciones nombradas, mapa de valores, reglas de descarte con su
  motivo.
- **El modelo**: el esquema real, con sus restricciones puestas.

Migrar un sistema viejo distinto es **cargar filas en el mapeo**. El código que
las interpreta ya está escrito y es el mismo para todos. Eso convierte la segunda
migración en una fracción de la primera.

---

## Lo que no se hereda nunca

- **El desgaste.** Pantallas duplicadas, cadenas evaluadas en runtime, redondeos
  absorbidos en silencio, manejo de errores apagado. Reproducirlo es el único
  resultado imperdonable.
- **La estructura de menús del sistema viejo**, si estaba organizada por el
  organigrama de la empresa en vez de por lo que la persona quiere hacer.
- **Los datos reales**, en ningún momento, en ninguna forma, ni siquiera como
  ejemplo en un comentario.

## Lo que se hereda siempre

- **El vocabulario.** Las palabras que el usuario viene leyendo hace veinte años
  se quedan exactamente como están. Cambiamos cómo funciona y cómo se ve; no le
  renombramos el mundo.
- **Las reglas de negocio**, leídas del fuente y no supuestas, sobre todo las
  raras: son raras porque alguna vez alguien las necesitó así.
- **Los formularios legales.** Un informe que un organismo acepta no es lugar
  para creatividad. Mismo orden de columnas, mismos textos, mismos totales.
- **Los atajos y los gestos.** Si el operador escanea un código de barras hace
  quince años, el lector sigue funcionando igual y sin cambiar de modo.

## La vara

El sistema viejo ya funciona. Reemplazarlo sólo vale la pena si el reemplazo es
mejor en algo que una persona pueda sentir, y eso se mide contra la pantalla que
reemplaza, no contra una hoja en blanco:

- **Menos tecleos** para el mismo resultado. Más es una regresión y vuelve.
- **Menos pasos**: una pantalla donde antes había tres.
- **Nada destructivo sin vista previa**, y reversible mientras se pueda.
- **Y que dé ganas de usarlo**: que alguien obligado a pasar diez horas ahí
  adentro no quiera el viejo de vuelta.
