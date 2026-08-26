# La flota distribuida

Hoy la flota vive en una máquina: un tablero en un archivo, un candado local,
paneles que comparten el mismo árbol de trabajo. Funciona, y tiene un techo
duro — la RAM de ese equipo. Este documento es cómo se rompe ese techo sin
romper lo que ya anda.

La idea en una línea: **el trabajo se publica en un lugar que todos ven, y
cualquier obrero, en cualquier locación, lo toma, lo resuelve y lo commitea.**

---

## 1. Qué cambia y qué no

Lo que **no** cambia es el modelo mental, y esa es la gracia: sigue habiendo un
tablero con ítems, alguien que los reparte, obreros que los toman y los cierran.
Un panel del VPS no sabe que es "remoto"; hace exactamente lo mismo que hace
uno local.

Lo que cambia son tres cosas, y las tres son consecuencia de una sola: **ya no
hay memoria compartida.**

| | una máquina | varias locaciones |
|---|---|---|
| dónde vive la cola | `.logs/tablero.tsv` | el repo (git) |
| cómo se reclama un ítem | `flock` sobre el archivo | un push que gana o pierde |
| cómo se sabe que un obrero murió | el panel no está en la lista | se le vence el arriendo |

`flock` no cruza la red. Un archivo TSV con un candado local es correcto en un
equipo y es una carrera perdida en cinco.

---

## 2. Git ES el bus, y no hace falta inventar otro

La tentación es montar una cola de mensajes. No hace falta, y sería una pieza
más que puede caerse: **todas las locaciones ya clonan el repo, ya sincronizan,
ya autentican y ya tienen historial**. Lo único que falta es usar el repo como
el lugar donde vive la cola, en vez de como el lugar donde vive sólo el código.

Y hay una propiedad de git que resuelve gratis el problema difícil: **la
actualización de una referencia es atómica y el servidor rechaza la que llega
segunda.** Eso es exactamente un candado distribuido, sin instalar nada.

### Reclamar un ítem

    git push origin HEAD:refs/claims/<id-del-item>

Si el push entra, el ítem es tuyo. Si el servidor lo rechaza porque la
referencia ya existe, otro lo tomó primero: no lo tomes, seguí con el
siguiente. **No hay ventana entre "miré" y "tomé"** — que es justo la ventana
por donde se cuelan dos obreros haciendo lo mismo.

Esto no es teórico: el 2026-08-26 tres obreros de la misma máquina escribieron
tres copias idénticas del mismo struct en el mismo archivo, porque ninguno
podía ver que los otros ya lo estaban haciendo. Con la cola en memoria
compartida eso ya pasa; entre locaciones pasaría más.

### Un ítem, un archivo

El TSV de una máquina se vuelve un directorio: `tablero/<id>.md`, uno por ítem.
No por prolijidad — **porque dos obreros que editan ítems distintos no chocan
al pushear.** Un archivo único garantiza conflicto en cada movimiento.

---

## 3. El arriendo: qué pasa cuando una locación se cae

Una reclama sin vencimiento es una fuga. Si el VPS se reinicia con tres ítems
tomados, esos ítems se ven ocupados y no los toma nadie más — para siempre.

Eso ya nos pasó **en una sola máquina**: tras un reinicio quedaron 115 ítems
reclamados por paneles que ya no existían. Se ven ocupados y nadie los agarra.
Distribuido es peor, porque no hay una lista de procesos vivos que consultar.

Entonces la reclama es un **arriendo con vencimiento**: el obrero renueva la
referencia cada pocos minutos mientras trabaja. Si deja de renovar —murió, se
cayó la red, se reinició la locación— el arriendo vence y **cualquiera puede
robarlo**:

    # sólo entra si la referencia sigue apuntando al arriendo vencido
    git push --force-with-lease=refs/claims/<id>:<sha-vencido> origin HEAD:refs/claims/<id>

`--force-with-lease` es la pieza: roba **sólo si nadie lo renovó mientras
tanto**. Un `--force` pelado le robaría el trabajo a un obrero vivo que estaba
lento.

**El intento no se le cobra al ítem.** Un panel que murió no es un ítem
imposible, y el que confunde las dos cosas termina marcando TRABADO trabajo
perfectamente bueno.

---

## 4. Las locaciones no son intercambiables

Un obrero del VPS ARM no puede producir un binario para el Windows de un
cliente. Uno sin GPU no puede correr el modelo local. Uno sin la base cargada
no puede probar una migración contra datos reales.

Por eso cada ítem declara qué necesita y cada locación qué ofrece:

    # tablero/20260826-0042.md
    ---
    necesita: [rust, postgis]
    ---

    # locaciones/vps-arm.conf
    ofrece: [rust, postgis, arm64, deploy]

Un obrero **no toma lo que no puede terminar**. Y —esto importa más de lo que
parece— si nadie ofrece lo que un ítem necesita, el ítem tiene que aparecer
como **bloqueado por falta de capacidad**, no quedarse pendiente para siempre
en silencio. Un ítem que nadie puede tomar y que nadie reporta es idéntico a
un ítem que a nadie le importa.

---

## 5. Lo que sigue siendo local, y por qué

**El carril de build es por máquina.** La RAM y los núcleos son locales: un
candado global de compilación entre cinco equipos serializaría cinco máquinas
para proteger a una. Cada locación tiene su carril y su piso de memoria.

**El foco del dueño es local.** Ninguna locación remota mueve la pantalla de
nadie.

**Las credenciales son locales.** Cada locación se autentica sola, con lo suyo.
No se copian claves entre máquinas: si una se ve comprometida, se revoca esa y
nada más.

---

## 6. El modo de falla que hay que diseñar primero

Un obrero que no puede llegar a la cola **tiene que gritar**, no quedarse
quieto. Es la lección más cara de toda esta maquinaria, y se repitió todo el
día del 2026-08-26 en cinco formas distintas:

- un verificador que miraba un crate de ocho y contestaba `check: OK`
- un guardia de fuerza bruta con el límite en 100.000 intentos, activo y
  registrando cada uno
- tres servicios `active (running)` que fallaban en CHDIR cada diez segundos
- un `/new` que se entregaba como mensaje y nunca se ejecutaba
- un `git checkout` que fallaba y dejaba el clon en el commit viejo, mientras
  el parche se aplicaba encima

**Todas fallaron devolviendo la respuesta buena.** Ninguna dio error. En un
sistema distribuido esto se multiplica, porque a la lista se le suman la red,
el reloj de cada máquina y la latencia.

La regla, entonces: **una locación silenciosa no es una locación tranquila.**
Cada una publica un latido; el que deja de latir se reporta caído aunque no
haya un solo error en ningún log. Y ninguna herramienta contesta "verde" sobre
algo que no pudo verificar — mejor un `NO PUDE MEDIR` ruidoso que un OK falso,
porque el OK falso lo cree todo el mundo y nadie va a mirar dos veces.

---

## 7. Por dónde empezar

No hace falta todo junto, y conviene no hacerlo junto:

1. **Una segunda locación que sólo compila.** Ya está: el VPS ARM verifica
   commits y árboles sucios, y su `cargo check` incremental tarda 1 segundo.
   No toca el tablero todavía — es un servicio, no un obrero.
2. **El tablero a git**, un archivo por ítem, sin reclamas remotas: sigue
   repartiendo la máquina principal. Esto solo ya destraba mirar el estado
   desde cualquier lado.
3. **Reclamas por referencia**, con arriendo. Recién acá la segunda locación
   toma trabajo por su cuenta.
4. **Capacidades**, cuando haya una tercera locación que no sepa hacer lo
   mismo que las otras dos.

El orden importa: cada paso es útil solo, y ninguno obliga al siguiente.
