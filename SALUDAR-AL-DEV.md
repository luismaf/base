# Saludar al dev — por qué el látigo escribía en ventanas cerradas

*2026-08-26. Los proyectos que salen de este kit comparten estos scripts por
symlink: se arregla una vez y queda arreglado en todos.*

## El síntoma

El dueño lo dijo en una línea: **el látigo no se da cuenta si está escribiendo
en una ventana cerrada o no.**

Tenía razón, y era peor de lo que parecía. Los tres repartidores —`latigo.sh`,
`autopiloto.sh`, `nadie-ocioso.sh`— mandaban el pedido así:

```bash
herdr agent prompt "$p" "…cuarenta líneas de pedido…" >/dev/null 2>&1
herdr agent send-keys "$p" enter >/dev/null 2>&1
```

Ese `>/dev/null 2>&1` sin mirar el código de salida es todo el bug. El reparto
"salía bien" en cuatro situaciones distintas en las que no llegaba nada:

| lo que pasaba de verdad | lo que veía el repartidor |
|---|---|
| la ventana ya no existe | mandado ✅ |
| la ventana vive pero opencode adentro murió | mandado ✅ |
| opencode está rechazando todo con error de conexión | mandado ✅ |
| el texto quedó **tipeado** sin Enter | mandado ✅ |

## La prueba de que pasaba

`w5:p3C`, encontrado el 2026-08-26 con esto clavado en el título del terminal:

```
Freebuff: Tomá el ítem 20260824-110251-0172347 del tablero:…
```

Dos días parado. En esa ventana corría `freebuff` —un dev del dueño que herdr
no detecta como agente— y el autopiloto le escribió encima un pedido del
tablero que nadie iba a leer nunca.

Ese es también el origen de los **92 ítems** que hubo que rescatar a mano con
`tablero.sh huerfanos`: quedaron `tomado` por paneles que ya no existían.

## El agravante: el ítem pagaba el error del repartidor

`take` cuenta intentos, y a los tres el ítem queda `trabado`. Está bien cuando
el ítem rebota porque nadie puede cerrarlo —mal escrito, ya hecho, depende de
algo que no existe. Pero cuando el pedido **nunca llegó**, el ítem no hizo nada
malo: lo tomó un panel que no estaba. **Tres ventanas cerradas seguidas
alcanzaban para marcar TRABADO a un ítem impecable.**

Por eso ahora hay dos formas de devolver un ítem, y la diferencia importa:

```
soltar    el pedido LLEGÓ y el panel no lo cerró      -> cobra el intento
devolver  el pedido NO LLEGÓ                          -> no lo cobra
```

## La cura: el ritual

El dueño ya la había descubierto trabajando, y le puso nombre: **inicializar al
dev, saludar al dev.**

> Si hacés un `/new` y luego le ponés "hola", esperás la respuesta… luego
> siempre siempre funciona. En cambio cuando le tirás una chorrera inmensa
> apenas abrís el chat, se bloquea y no responde.

Eso ahora es `scripts/saludar-dev.sh`, y corre **antes** de cada pedido:

1. **¿existe la ventana?** Si no → el ítem vuelve con `devolver` y queda en el log.
2. **¿hay un dev corriendo adentro?** Si no → abre `opencode --auto` con
   `herdr agent start`, que además espera a que esté listo para recibir.
3. **¿la pantalla muestra un rechazo?** Si sí → `/new`, sesión limpia.
4. **Si hubo (2) o (3): "hola", y esperar la respuesta.** Con
   `herdr agent prompt --wait --until idle`. Esperar es el punto: mandar el
   saludo y seguir de largo no sirve, porque la chorrera llega igual con la
   ventana fría.
5. Recién ahí el repartidor manda el pedido de verdad — y **mira si llegó**.

### Cuándo no hace nada

Si el dev está vivo y la pantalla limpia, sale en 0 sin gastar un token. El
saludo es para ventana nueva o para panel que hay que revivir. A una
conversación que ya viene andando, saludarla cada vuelta es tirar plata.

### Códigos de salida

```
0  tibio y listo        -> mandale el pedido
1  no se pudo           -> devolvé el ítem, no le mandes nada
2  la ventana no existe -> devolvé el ítem y avisá al dueño
3  ocupado con otra cosa (vim, un build, sudo) -> no es momento
```

El 3 no es un fallo. Si en la ventana hay un `vim` abierto, escribirle un
pedido sería tipear adentro de lo que el dueño esté haciendo.

## Detectar el rechazo sin falsos positivos

El error que describe el dueño **no es que no llegue a la API: es que la
rechaza**. Las huellas viven en `scripts/errores-conexion.conf`, una expresión
regular por línea, para que agregar una nueva no sea tocar código.

La trampa está documentada ahí y vale repetirla: **la pantalla de un panel
tiene código, diffs y contadores.** Un patrón `429` a secas matchea

```
  429 |     let total = items.iter().sum::<i64>();
```

y manda a rescatar a un panel que está trabajando perfecto. Por eso los códigos
HTTP van siempre pegados a una palabra de error. Hay una batería de 17 casos
—9 que deben disparar, 8 de pantalla normal que no— y pasa entera.

## Uso a mano

```bash
bash scripts/saludar-dev.sh w5:p3C            # el ritual, lo que haga falta
bash scripts/saludar-dev.sh w5:p3C --forzar   # saludar aunque esté limpio
bash scripts/saludar-dev.sh --revisar         # informe de toda la flota
```

`--revisar` es el que conviene mirar cuando algo huele raro:

```
w5:p3Z	OCUPADO	sudo
w5:p2W	OK	claude
w5:p3C	OK	freebuff
w5:p20	OK	opencode
…
```

Perillas por variable de entorno: `SALUDO_ARRANCAR=0` (diagnosticar sin abrir
devs), `SALUDO_HOLA_MS`, `SALUDO_ARRANQUE_MS`, `SALUDO_KIND`, `SALUDO_CONF`.

## Qué NO toca

`freebuff` y `claude` cuentan como devs vivos. El script no los pisa, no los
cierra y no les abre un opencode encima. La regla del dueño sigue siendo la
misma: **a los paneles no se los cierra, se les manda instrucciones.**

## Archivos

| archivo | qué es |
|---|---|
| `scripts/saludar-dev.sh` | el ritual (nuevo) |
| `scripts/errores-conexion.conf` | las huellas del rechazo (nuevo) |
| `scripts/latigo.sh` | saluda antes de nombrar el ítem; `devolver` si falla |
| `scripts/autopiloto.sh` | saluda dentro de `mandar()`; `devolver` si falla |
| `scripts/mandar-a-panel.sh` | saluda antes del mensaje (`MANDAR_SIN_SALUDO=1` lo saltea) |
| `scripts/nadie-ocioso.sh` | lo hereda: manda por `mandar-a-panel.sh` |
| `scripts/tablero.sh` | subcomando `devolver` |

En los repos que salen del kit, los seis primeros son symlinks al repo
canónico. Un solo arreglo, todos los proyectos.

## No se pregunta permiso, se avanza (dueño, 2026-08-27)

Cuando el ítem del tablero ya dice qué hacer, **no se pregunta "¿avanzo?": se
avanza**. Un dev parado esperando permiso cuesta más que un camino subóptimo
commiteado y corregible. Preguntar es sólo para ambigüedad REAL que cambia el
resultado (dos caminos incompatibles entre sí); incluso ahí: elegí el más
simple, dejá la decisión anotada en el commit, y seguí. La pregunta que
bloquea un panel es la excepción absoluta, no la costumbre.
