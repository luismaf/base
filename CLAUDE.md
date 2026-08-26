# La bitácora compartida

Este archivo se carga solo cuando una sesión de Claude trabaja en cualquier
repositorio que tenga el kit. **Es la memoria común de todas las sesiones**: lo
último que se descubrió, lo último que se rompió y lo último que se arregló.

Una sesión se muere y lo que sabía se va con ella. Lo que está acá, no.

**Si acabás de arrancar sin memoria**, leé
[`DESPUES-DE-UN-REINICIO.md`](DESPUES-DE-UN-REINICIO.md): te devuelve el
criterio en cinco minutos.

## Cómo se usa

**Cuando descubrís algo, lo escribís acá en el momento** — no "después", porque
después es tu próximo reinicio. Una línea con la fecha, qué pasó y dónde quedó
el arreglo. Lo viejo se poda: esto es la mesa de trabajo, no el archivo
histórico. El porqué largo va a los documentos que correspondan.

Y lo mismo al revés: **antes de encarar algo grande, leé las últimas entradas.**
Es muy probable que otra sesión ya lo haya pisado.

## El patrón que más caro salió

Casi todas las fallas que nos costaron horas tienen la misma forma:

> **Un componente que ante su propia falla devuelve un valor plausible en vez de
> un error, y siempre disfrazado de la respuesta BUENA** — "todo bien", "cero",
> "100%", "no hay nada que hacer". Nunca de la mala.

Uno que falla diciendo "hay problema" se descubre en cinco minutos. Uno que
falla diciendo "todo bien" vive meses, y se replica sin resistencia porque nadie
lo cuestiona.

Las seis reglas que salieron de ahí están en `DESPUES-DE-UN-REINICIO.md`. La más
corta y la que más sirve: **¿cómo se ve esto cuando el instrumento está roto?**
Si la respuesta es "igual que cuando todo está bien", falta un control.

## Bitácora

### 2026-08-26 — Ocho fallas silenciosas en una noche, entre tres sesiones

Filtro por clase de panel que no matcheaba (contaba cero obreros siempre, en
cinco scripts). Búsqueda por substring que daba medio inventario por cubierto.
`find -newermt` devolviendo cero en montajes ntfs3 mientras git mostraba veinte
commits. Denominador en cero leído como 100% — **y ése abría la compuerta del
objetivo**. `[ cond ] && acción` matando un bucle bajo `set -e`. `x=$(cmd |
grep)` muriendo con `pipefail` cuando el grep no matchea. Un endpoint sin
control de rol, indistinguible de uno que lo pasó. Una regla escrita sólo en un
comentario y nunca implementada.

Arreglos en `base/scripts/` y la lección en `skills/flota/SKILL.md`.

### 2026-08-26 — La memoria de los agentes: medida, no supuesta

Un agente nace en **279 MB** y llega a **780** con horas encima. No es fuga: es
contexto. `/compact` recupera **83 MB** (un octavo); reiniciar recupera los ~500
pero se lleva el contexto puesto.

Y la señal para decidir **no es el tamaño, es el contexto por ítem cerrado**: un
panel con 828K y 53 ítems cerrados es residuo y se recicla; uno con 828K y cero
ítems está peleando algo difícil y reciclarlo **garantiza que ese ítem no se
resuelva nunca**. Se ven igual desde afuera.

`base/scripts/guardia-ram.sh`.

### 2026-08-26 — El lugar para compilar se aparta al abrir

Una compilación grande puede pedir casi toda la máquina y cuánto pide es
incierto. Pelear ese lugar después obliga a sacar gente justo cuando todos
trabajan. Se aparta en `poblar-flota.sh` al crear la flota; sacar gente queda
como último recurso. **Un recurso que nunca está disponible no es un recurso: es
un bloqueo permanente.**

### 2026-08-26 — La compuerta contra la dispersión

`objetivo.sh` mide condiciones y parte la escalera de mejora en dos: los
escalones que convergen están siempre; los que exploran —competencia, venta,
marketing— **quedan cerrados con llave hasta que los números digan que el
objetivo está logrado**. No se pide disciplina, que se gasta: se pone una
compuerta que se mide sola.

Al escribir condiciones: si no se puede medir no es una condición, es un deseo.
Y los umbrales van altos — la mitad de los productos que no se terminan estaban
en 85%.

### 2026-08-26 — Por qué un jefe se detiene

No por falta de ganas: termina su turno y nada lo despierta. **La constancia no
es propiedad del agente, es propiedad del sistema que lo despierta.** El látigo
despierta a los obreros y saltea al jefe, o sea que el único que repone el
trabajo de todos es el único al que nada reinicia. `jefe.sh` es ese reloj.

### 2026-08-26 — El primer mensaje a una ventana nueva es "hola"

Un agente frío que recibe cuarenta líneas responde mal. Saludado y esperado unos
segundos, acepta lo mismo. Y a un panel que no contesta no se le insiste una
cuarta vez: sesión nueva y "hola". `saludar-agentes.sh`.
