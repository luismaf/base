# Cómo trabajamos

Esto no es una lista de buenas intenciones. Es lo que quedó después de romper
cosas y medirlas, y cada regla dice **por qué** existe, porque una regla sin su
razón se descarta la primera vez que estorba.

Si sos nuevo — persona o agente — leé esto entero antes de tocar nada. Está
escrito para que puedas replicar el sistema completo sin preguntarle nada a
nadie.

---

## 1. La idea de fondo

Un equipo de agentes trabajando en paralelo sobre los mismos repos, sin parar,
con una persona que carga trabajo y no tiene que repartirlo. Tres piezas:

| pieza | qué hace |
|---|---|
| **el tablero** | la cola de trabajo: ítems pendientes, tomados, hechos |
| **el látigo** | reparte: busca el que está ocioso y le da lo siguiente |
| **el jefe** | mira el conjunto, destraba, decide, no reparte |

El dueño llena el tablero. Todo lo demás se mueve solo.

---

## 2. El principio que ordena todo lo demás

> **Una regla que hay que acordarse de cumplir no es una regla, es una
> sugerencia.**

Cada vez que algo salió mal, la causa fue la misma: existía la regla, estaba
escrita en el pedido, y alguien no la aplicó. La respuesta nunca es escribirla
más grande. Es hacerla **estructural**.

- ¿"Un build a la vez"? → un shim de `cargo` que toma el turno **quiera o no**.
- ¿"No compiles en la máquina de los paneles"? → el shim redirige al servidor.
- ¿"Bajá el límite de fuerza bruta en producción"? → el default **depende del
  build**: permisivo en debug, seguro en release.

El patrón: **lo que pasa cuando nadie decide nada tiene que ser lo correcto.**

---

## 3. La falla muda: lo que hay que buscar primero

Es el error más caro y el más frecuente. Un componente que, **al fallar,
devuelve una respuesta plausible en vez de un error.** Y siempre —siempre— la
plausible es la buena: "no hay deuda", "no hay diferencias", "tiene permiso",
"compila".

Ejemplos reales, todos de un mismo día:

| lo que se veía | lo que pasaba |
|---|---|
| `check: OK` en 0,20 s | miraba **un crate de ocho**; los otros siete jamás se compilaron |
| guard anti fuerza bruta activo, contando, registrando | su límite por defecto eran **100.000 intentos** en 15 min |
| tres servicios `active (running)` | fallaban en CHDIR y systemd los reiniciaba cada 10 s |
| el panel contestaba el saludo con naturalidad | el `/new` nunca se ejecutó; seguía con sus 920 k de contexto |
| `git checkout` sin ruido | falló, git quedó en el commit viejo, y el parche se aplicó **encima** |

Ninguno dio error. Todos devolvieron la respuesta buena.

**Las reglas que salen de esto:**

1. **Tres resultados, nunca dos.** `HAY PROBLEMA` / `NO HAY PROBLEMA` /
   `NO PUEDO MEDIR`. El tercero es el que falta siempre, y es el que evita que
   un instrumento roto se lea como buenas noticias.
2. **Un instrumento roto nunca abre una compuerta.** Si no se pudo medir, no se
   avanza: no se recicla el panel, no se marca verde, no se despliega.
3. **Se verifica con dos sensores que fallen por razones distintas.** Un
   detector de actividad y un contador de commits; el screen y la base de
   datos. Si los dos coinciden, es verdad.
4. **Medí el efecto, no la acción.** "Mandé el `/new`" no es "el contexto
   bajó". Un reciclado que no baja el contexto **no pasó**, y sin comprobarlo
   se ve idéntico a uno exitoso — y se repite para siempre.
5. **Nunca uses un pico como medida de estado.** Un máximo histórico no baja
   nunca: "sigue por encima del umbral" y "el arreglo no hizo nada" dan la
   misma lectura.

---

## 4. Las reglas fijas del trabajo

**PROHIBIDO correr suites de tests.** Se verifica compilando, leyendo el código
o usando la app. Cuarenta paneles corriendo tests tumban la máquina, y un test
verde sobre un crate que no se compila no dice nada.

**Un build a la vez, por máquina.** La RAM es local. Está implementado con un
candado global (`one-at-a-time.sh`) más un shim de `cargo`, no con un pedido.

**Un commit a la vez, y se stagean los archivos propios por nombre.** `git add
-A` con cuarenta paneles sobre el mismo árbol se lleva el trabajo de otros.

**Código y comentarios nuevos en inglés.** El español sólo en textos de
interfaz e i18n. Es un proyecto internacional.

**Sin coautorías en los mensajes de commit.**

**Nunca se cierra ni se mata un panel.** Se le mandan instrucciones. Un panel
que parece ocioso puede estar pensando.

**La clave nunca en el código, ni en un commit, ni en un documento.** Se nombra
la variable, jamás el contenido. Y sin valor por defecto: si falta, el proceso
**aborta con instrucciones** en vez de arrancar con una puerta abierta.

---

## 5. La aritmética de la RAM

Es lo que decide cuántos agentes entran, y no es opinable:

```
agentes = (RAM_total − sistema − reserva_de_build − margen) / costo_p90
```

Medido en una máquina de 62 GB con 46 paneles:

| | |
|---|---|
| panel recién nacido | 590 MB |
| panel mediano | 1.191 MB |
| **panel p90** | **1.702 MB** |
| el más gordo visto | 2.015 MB |
| **pico de compilar** | **6.245 MB — y es UN SOLO rustc** |

**Se presupuesta por el p90, no por la mediana.** Con la mediana, la mitad de
la flota pesa de más y el error se acumula panel a panel hasta que no queda con
qué compilar.

**Los paneles engordan**: de 590 a 2.015 MB, más del triple. Ningún techo
sobrevive a eso solo — hay que **rejuvenecerlos**.

Y dos cosas que se aprendieron midiendo, contra la intuición:

- **`/new` no libera RAM.** Baja el contexto del modelo; el proceso conserva su
  heap entero. Medido: 756 → 752 MB. Para recuperar memoria hay que **cerrar y
  reabrir** (916 → 775 MB, con PID nuevo).
- **El rejuvenecimiento va en el momento del reparto, no en un reloj.** Un
  panel que cierra su ítem recibe el siguiente antes de que ningún temporizador
  lo mire: arranca con sus 400 k puestos. La carrera la gana siempre el
  repartidor.

---

## 6. El saludo, que no es cortesía

> **Se saluda. Se ESPERA la respuesta. Recién ahí se manda el trabajo.**

Una ventana recién abierta que recibe un pedido largo como primer mensaje **se
traba y no contesta nunca más**. Medido: el mismo modelo rechazó seis pedidos
seguidos y contestó al primer "hola" en 1,2 segundos.

El ritual completo, en orden:

1. ¿Existe la ventana? Si no, no hay a quién escribirle.
2. ¿Hay un dev adentro, o es un shell pelado? Si es un shell, el pedido se
   ejecuta como comando y escupe "command not found" cuarenta veces.
3. ¿Está rechazando? (los errores de conexión típicos) → sesión nueva.
4. Saludar y **exigir la respuesta**. Un panel que no contesta es un zombi:
   parece disponible y no lo es.
5. Si no contesta ni con sesión nueva: **no se le manda el ítem**, y el ítem
   se devuelve al tablero **sin cobrarle el intento** — el ítem no tiene la
   culpa de que el panel esté muerto.

Detalle que cuesta una tarde: **`/new` va con `send-text` al PANEL**, nunca
como mensaje al agente. Mandado como mensaje, el modelo lo **lee** en vez de
ejecutarlo: contesta con toda naturalidad y sigue en la misma sesión trabada.

---

## 7. Dónde se compila

**En el servidor, no en la máquina de los paneles.** Un `rustc` de 6,2 GB
compitiendo con 46 paneles por la memoria terminó en dos reinicios y 46 paneles
perdidos en una hora.

El carril remoto manda el **diff del árbol de trabajo** sobre el commit base,
así que no hay que commitear para saber si compila. Cuesta 1-2 segundos.

Y tiene cuatro guardas, cada una nacida de una falla real:

| si… | aborta, porque… |
|---|---|
| el servidor no contesta | un `0` con la red caída le dice a 46 paneles que su código compila |
| el commit base no existe allá | el checkout falla y git se queda donde estaba |
| el checkout no quedó donde se pidió | se verificaría otro código |
| el parche dejó marcadores `<<<<<<<` | `--3way` no falla al no fusionar: deja el conflicto adentro del archivo |

---

## 8. El despliegue

CI/CD propio, en la misma máquina que despliega — **misma arquitectura, mismas
bibliotecas, misma base**: lo que pasó el check es exactamente lo que va a
correr.

Cinco etapas, y el orden importa: `traer → chequear → construir → migrar →
publicar`. El check cuesta segundos y el build minutos: fallar primero en el
barato es enterarse en 10 segundos en vez de en 10 minutos.

**Publicar es mover un symlink** — una operación atómica: no existe el instante
en que apunta a medias. Volver atrás es moverlo de vuelta, y como el build
anterior sigue en disco, cuesta un segundo.

**Después de publicar se le PREGUNTA a la app.** Un servicio que arranca y se
muere a los dos segundos deja systemd en `activating` y el despliegue
"exitoso". Si no contesta, se revierte solo. Un despliegue que no se verifica
no es un despliegue, es una esperanza.

**Las migraciones van ANTES de publicar.** Un binario nuevo contra un esquema
viejo falla en la primera consulta de un usuario real, no en el deploy.

---

## 9. Seguridad

**Fallar cerrando.** Ante la duda, el permiso se niega, el flag se apaga, el
proceso no arranca. Los dos errores no cuestan lo mismo.

**Los defaults son la seguridad.** Nadie setea variables el día del deploy. Si
el valor seguro depende de que alguien se acuerde, no es seguro. Se hace
depender del build: permisivo en debug, seguro en release.

**Ninguna credencial cruza máquinas.** Cada locación autentica sola. Si una se
compromete, se revoca esa y nada más.

**Un usuario llamado `admin` regala la mitad del par de credenciales.**

**Y buscá la puerta, no el cartel.** Esconder la pista de las credenciales en
producción no sirve de nada si **la cuenta existe**: el que prueba
`demo/admin123` no necesita que se lo digan.

---

## 10. Los roles

**El jefe** hace lo estratégico, lo difícil y lo peligroso. No compila, no
corre tests, no arregla errores de tipos. Está para los problemas gordos, para
destrabar, para decidir, y para empujar. Es caro: sus tokens se ahorran, los de
los obreros se gastan sin culpa.

**Los obreros** son gratis e ilimitados; el único límite es la RAM. Nunca
ociosos: si no hay trabajo del proyecto propio, se busca en otro — priorizando
muchísimo el propio, pero **antes de dejar un dev libre, se le da otra cosa.**

**Contexto caro vs. contexto barato.** Al jefe se lo **compacta**, nunca se lo
reinicia: su contexto es la memoria del proyecto. A un obrero que cerró su ítem
se lo recicla y cuesta casi nada.

**Nadie recicla a quien está trabajando.** Nunca, por ninguna cifra. Y el
estado se lee **dos veces separadas por segundos**: un panel puede figurar
`done` al elegirlo y `working` un segundo después.

---

## 11. Cómo se escribe

**El código en inglés; los comentarios explican POR QUÉ, no qué.**

El qué ya está en la línea de abajo. Lo que se pierde es la razón: qué se
probó, qué falló, qué medición llevó a esa decisión. Un comentario que dice
*"el default era 100.000 y eso son 111 intentos por segundo"* evita que alguien
lo "simplifique" dentro de seis meses.

**Los mensajes de commit cuentan la historia**: qué estaba mal, cómo se
descubrió, qué se midió, qué se decidió y qué se descartó.

**Al reportar, primero lo que importa.** Sin preámbulos, sin recapitular lo que
el otro ya sabe. Los números medidos, no adjetivos. Y **si algo salió mal o fue
un error propio, se dice en la primera línea**, no enterrado al final.

---

## 12. Replicarlo desde cero

1. `docs/LOCACION-NUEVA.md` — levantar una máquina nueva de cero: sistema,
   Rust, Postgres+PostGIS, deploy keys, opencode, herdr, obreros, watchdog y
   endurecimiento. Probado paso a paso.
2. `scripts/instalar.sh` — el kit en cualquier repo (symlinks, no copias: se
   arregla una vez y se arregla en todos).
3. `ci/pipeline.sh` + `ci/vigilante.sh` — el despliegue.
4. `docs/FLOTA-DISTRIBUIDA.md` — cuando haya más de una locación.

**El orden importa**: cada paso sirve solo y ninguno obliga al siguiente.
