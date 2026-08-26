---
name: flota
description: Poner a trabajar una flota de agentes en paneles de terminal y que no se pare nunca — desplegar según la RAM, cargar el tablero solo, repartir sin frenos, despertar al jefe y devolverle el foco a la persona. Usar cuando haya que arrancar, conducir o destrabar un equipo de agentes en cualquier proyecto, o cuando aparezcan paneles parados.
---

# Conducir una flota de agentes

Una flota de agentes en paneles de terminal se para sola. No por falta de ganas
ni de trabajo: por mecanismo. Esta skill es lo que aprendimos parándola muchas
veces, y sobre todo **dónde mirar primero cuando se para**.

La regla que ordena todo lo demás: **cada vez que la flota se detiene, la causa
está en el mecanismo, no en los agentes.** Empujarlos es tratar el síntoma.

## El comando

Con el kit instalado (ver la skill `base`), un solo comando lleva un repo a una
flota trabajando:

```bash
bash scripts/arrancar.sh          # poblar, saludar, cargar, encender
bash scripts/arrancar.sh --estado # qué está andando
bash scripts/arrancar.sh --parar  # apagar los motores (los obreros siguen)
```

Si algo hay que arrancarlo aparte después, es un bug de ese script: **lo que uno
se olvida de encender es exactamente lo que aparece apagado a las tres horas.**

## Los cinco pasos, y por qué cada uno

**1. Verificar que el harness conteste.** Un harness mudo **no es "cero paneles
libres": es que no hay con quién hablar.** Confundir las dos cosas fue el bug más
caro: el repartidor veía la lista vacía, no empujaba a nadie, no escribía una
línea de log, y el equipo entero quedaba parado horas mientras todo "corría
bien".

**2. Poblar según la RAM, y no según la memoria libre.** Dos trampas:

- **Un agente no pesa lo que pesa recién nacido.** Arranca en ~230 MB y con horas
  encima llega a 1,6 GB. Se presupuesta por el **percentil 90 del PSS**, no por
  la mediana: la mediana planifica para el mejor caso.
- **El crecimiento es diferido.** Si se crean ocho midiendo después de cada uno,
  ninguna medición miente y aun así la máquina se hunde. Se **descuenta el costo
  completo apenas se crea** el obrero, sin esperar a medirlo.

**3. Saludar antes de pedir.** El primer mensaje a una ventana nueva es `hola`,
nunca el pedido. Un agente frío que recibe cuarenta líneas responde mal — se
pierde, contesta a medias o no arranca. Saludado y esperado unos segundos, acepta
lo mismo sin problema. Y cuando uno no contesta, tiene un error que no importa o
ya se le insistió tres veces, **no va un cuarto recordatorio: va sesión nueva y
`hola`.** Insistirle a un panel mudo es la forma más cara de no lograr nada.

**4. Cargar el tablero sin que nadie redacte.** Si el tablero sólo se llena
cuando alguien escribe, se vacía — y cuando se vacía, la flota espera a que esa
persona conteste. El trabajo ya está escrito en algún lado (un inventario de
funcionalidades, una lista de pantallas, la salida de un script que mide huecos):
convertirlo en ítems tiene que ser mecánico. El jefe sigue escribiendo los que
requieren criterio; la máquina cubre el piso.

**5. Encender los motores y dejarlos.** Tres bucles que se cubren entre ellos.

## Los tres motores

| Motor | Qué resuelve |
|---|---|
| `motores.sh` | Reparte con las válvulas en cero y barre hasta que no queda nadie libre |
| `jefe.sh` | Despierta al jefe con la próxima acción **ya decidida**, nunca una pregunta |
| `foco.sh` | Devuelve el foco que la maquinaria le saca a la persona |

**Las válvulas del reparto están calibradas para obreros que se pagan.** La
gracia (esperar a que un panel lleve rato quieto) y el enfriamiento (no empujarlo
dos veces seguidas) existen para no acosar. Con obreros gratis están al revés: un
panel parado con treinta ítems en la cola no es prudencia, es desperdicio. **Van
a cero.** Lo que NO va a cero es el tope de intentos de un ítem: eso protege al
*ítem* de rebotar para siempre, no al panel de recibir trabajo. Son dos cosas
distintas y sólo una sobra.

**Y el reparto entrega de a poco por pasada**, así que quien se libera a mitad de
la vuelta espera el intervalo entero. Hay que barrer en bucle.

## Por qué el jefe se detiene

**Un agente no se detiene por falta de ganas: termina su turno y nada lo vuelve a
despertar.** La constancia no es una propiedad del agente, es una propiedad del
sistema que lo despierta.

El repartidor despierta a los obreros y saltea al jefe a propósito, porque el
jefe no toma ítems. Ése es exactamente el agujero: **el único que repone el
trabajo de todos es el único al que nada reinicia.** Por eso el jefe necesita su
propio reloj, que le entregue la próxima acción ya decidida.

Y cuando el tablero está lleno todavía hay trabajo: **la escalera de mejora**
—interfaz, seguridad, rendimiento, calidad de datos, cobertura, documentación,
cómo se vende, la web— que rota y no se completa nunca, porque para cuando vuelve
a dar la vuelta el producto cambió. La condición de salida es imposible a
propósito.

La barandilla que evita que se vuelva relleno: **cada escalón apunta a un
documento o a una medición**, nunca a la imaginación del jefe. "Este escalón está
limpio" es una respuesta correcta; inventar un ítem no, porque un ítem que no
acerca al objetivo es peor que un tablero vacío — cuesta plata, ocupa un obrero y
produce algo que alguien después tiene que revisar y probablemente revertir.

## El foco es de la persona

Mandarle un mensaje a un panel a veces necesita enfocarlo, y eso le roba la
pantalla a quien está trabajando en la suya, incluso desde otro espacio de
trabajo.

Devolverlo siempre sería peor: si la persona se movió a propósito, se lo estarías
peleando. **Lo que lo hace preciso es distinguir quién lo movió:** nuestra
automatización sólo enfoca paneles de obreros, así que si el foco quedó en uno de
ésos se lo sacamos nosotros y hay que devolverlo; si quedó en uno humano, se
movió la persona y no se toca.

## Quién compila

**Uno solo, y es un obrero con ese rol permanente**, sacado de la rotación del
tablero para que no se lo lleven a otra cosa. Corre el chequeo en bucle, agrupa
los errores por módulo, le manda a cada dueño su lista con archivo y línea,
arregla él los triviales que no son de nadie, y vuelve a empezar cada vez que se
cierra un ítem — los demás no pueden ver que rompieron algo.

**Un error de compilación no necesita a alguien caro, necesita a alguien
constante.** Y una máquina, un compilador a la vez: varios en paralelo no es más
lento, es un cuelgue, y hay alguien sentado adelante.

## El ocio disfrazado de trabajo

Hay algo peor que un panel apagado, porque el apagado al menos se ve: **el panel
que parece trabajar y no produce.** Corre tests cada dos minutos al pedo, hace un
cambio de una línea y compila otra vez, y otra vez. Cuesta lo mismo que el
trabajo real, ocupa la máquina, y no aparece en ninguna lista de ociosos.

No es maldad del agente: es lo que hace cualquiera cuando no sabe qué sigue. **Un
ítem mal escrito, o uno ya terminado que nadie cerró, produce esto casi
automáticamente.** Así que cuando lo veas, sospechá del ítem antes que del
agente.

Las tres formas que toma:

- **Compilar en círculos** — cambio mínimo, build, mirar, repetir. Si no sabés
  qué cambiar, no lo vas a averiguar compilando: leé el código.
- **Tests de relleno** — un test que comprueba que un tipo existe o que un
  constructor construye **no puede fallar, y por lo tanto no es un test**. La
  vara: nombrá en una oración la regla que protege. Si no se puede, no hay test
  que escribir ahí.
- **Refactor que nadie pidió**, fuera de la zona propia.

**La detección va por salida, nunca por actividad.** El estado de un panel
miente: dice "trabajando" tanto cuando escribe código como cuando mira el mismo
error por quinta vez. Lo que no miente es si los archivos de su zona cambiaron.

```
panel ocupado + su zona sin cambiar hace rato  ->  teatro
panel ocupado + su zona cambiando              ->  trabajo
```

La ventana tiene que ser generosa —media hora, no un minuto— porque leer y
pensar son trabajo legítimo y no dejan rastro en el disco. Lo que se persigue no
es el minuto quieto: es la media hora sin una línea escrita. `scripts/teatro.sh`.

Y la salida honesta que hay que dejarle abierta al agente, porque si no la tiene
va a fingir: **si el ítem ya está hecho, cerralo; si está mal escrito, soltalo;
si de verdad no hay nada, decilo en una línea.** "No tengo nada" es una respuesta
correcta. Lo único que no sirve es seguir pareciendo ocupado.

Ojo con una trampa que nos metimos solos: cuando el inventario se agota y se
recurre a "cubrir con tests" como fuente de trabajo, **eso es exactamente la
excusa perfecta para el teatro**. Si vas a generar ítems de test, exigí en el
ítem que cada uno nombre la regla que protege y que el informe diga qué encontró
roto. Tres tests que encontraron algo valen más que veinte que no.

## Los instrumentos que mienten en silencio

El patrón que más nos costó, y apareció cuatro veces en una noche entre dos
equipos: **una medición rota devuelve un valor plausible en vez de un error.**

| Lo que se rompió | Cómo se veía | Qué era en realidad |
|---|---|---|
| Filtro por clase de panel que no matchea | "cero obreros" | El harness decía otra palabra |
| Búsqueda por substring que matchea de más | "inventario cubierto" | Un ítem mencionaba un rango |
| `find -newermt` en ciertos montajes | "cero archivos tocados" | git mostraba veinte commits |
| Condición del objetivo que no se puede medir | Una puerta con cuatro llaves | Una de las llaves era decorativa |

Ninguno se queja. Y como no se quejan, **se replican sin resistencia**: el del
filtro por clase lo copié yo a cinco scripts sin notarlo.

**La pregunta que hay que hacerle a toda medición nueva:** *¿cómo se ve esto
cuando el instrumento está roto?* Si la respuesta es "igual que cuando todo está
bien", falta un control.

**Y el corolario práctico:** antes de confiar en un número, **rompé el
instrumento a propósito y mirá qué imprime.** Si imprime lo mismo que cuando
anda, todavía no está terminado.

### El autocontrol necesita un segundo sensor, no el mismo

Ésta la aprendimos aplicando el corolario, y es la parte fina.

Un detector se puede auditar solo: *"si marco a la mayoría como sospechosos
mientras el repositorio commitea, el roto soy yo y no la flota"*. Suena bien y
funciona — **pero sólo si el control usa una medición distinta de la que falló.**

Nuestro primer intento se controlaba con su propia medición. Al romperla a
propósito, devolvió cero, el control comparaba contra ese mismo cero, nunca se
disparó, y el detector salió a acusar a quince paneles que estaban trabajando.
**Un instrumento no puede auditarse con el sensor que se le rompió.**

La forma correcta es tener dos mediciones que **fallen por motivos que no se
solapan** — por ejemplo git y el reloj del disco: git falla si no hay repo o el
rango está mal, los mtimes fallan en ciertos montajes. Que las dos den cero a la
vez es raro; que una vea algo mientras la otra no, significa que la que no ve
está rota. Si discrepan, el detector se acusa a sí mismo y **no toca a nadie**.

Umbral de mayoría y no de unanimidad, además: en una prueba real el instrumento
roto marcó 14 de 24 paneles con 23 commits en la ventana, y eso ya es imposible.
Pidiendo unanimidad, ese caso pasaba.

## Los cuatro modos de falla

Cuando la flota está parada, mirá en este orden.

**1. Las válvulas.** Es el primero porque es el más común y el más invisible. Si
hay paneles quietos con el tablero lleno, es el enfriamiento. En un caso real
estaba en 900 segundos: un panel que cerraba en dos minutos esperaba quince con
treinta ítems al lado.

**2. Un panel con varias reclamas.** El repartidor le asignó ítems mientras
parecía ocioso entre dos llamadas a herramientas. Un panel hace una cosa por vez;
el resto queda trabado e invisible, y el tablero parece ocupado mientras nada se
mueve. Se diagnostica cruzando los ítems tomados contra **qué directorios
cambiaron de verdad en el disco**: una zona reclamada donde no se escribió una
línea es una reclama muerta. Se liberan.

**3. Una detección por substring que sale positiva de más.** Nuestro generador
buscaba el id de una funcionalidad dentro del texto de los ítems para no
repetirla, y varios ítems mencionan **rangos**. Uno solo con un rango amplio daba
por cubierto medio inventario. Lo peor del bug es su forma: **un match parcial
que sale positivo de más no falla ruidosamente, apaga la flota en silencio.**
Registro explícito, campo entero, sin regex que pueda interpretar el contenido.

**4. Un panel sin cuota.** El proveedor lo dice en pantalla, a veces con un
reintento medido en horas. No está ocioso ni roto: dejalo y no gastes ítems en
él. Si se caen varios a la vez, es problema de cuentas y va al dueño.

Y el que no es de la flota sino del repo: **si el trabajo no está commiteado ni
pusheado, desde afuera el proyecto parece muerto.** Nos pasó — otra sesión vio el
repo con un commit y montó una segunda flota encima.

## La compuerta: no dispersarse antes de terminar

Queremos un equipo fanático de mejorar — que mire a la competencia, que le robe
lo mejor a los mejores del mundo, que piense cómo se vende. Todo eso vale.

**Y todo eso es, exactamente, la forma más fácil de no terminar nunca.**
Investigar es cómodo, se siente productivo, no tiene final claro y no lo audita
nadie. Un equipo que estudia competidores con el producto a medio hacer no está
mejorando: se está escapando de terminar. El riesgo no es la pereza, es lo
contrario — gente entusiasta yéndose por las ramas justo cuando falta poco.

**La solución no es pedir disciplina.** La disciplina se gasta y nadie se da
cuenta de cuándo se gastó. Es una **compuerta que se mide sola**: la escalera de
mejora se parte en dos, y la mitad exploratoria está cerrada con llave hasta que
los números digan que el objetivo está logrado.

| Siempre disponibles (convergen) | Cerrados hasta terminar (exploran) |
|---|---|
| Interfaz, seguridad, rendimiento | Competencia |
| Calidad de datos, cobertura | Venta |
| Documentación, lo que está roto | Marketing, ideas prestadas |

Dos reglas al escribir las condiciones del objetivo:

1. **Si una condición no se puede medir, no es una condición: es un deseo.**
   "Que la interfaz esté linda" no va. "Cero violaciones del contrato de diseño
   en el recorrido automático" sí.
2. **Los umbrales van altos.** "Casi" no abre la puerta: la mitad de los
   productos que no se terminan estaban en 85% y alguien decidió que alcanzaba.

Lo importante es que **no hay criterio humano que negociar**. El jefe no decide
si ya se puede investigar: lo dice el número. `scripts/objetivo.sh`, configurado
en `.tablero/objetivo.conf`.

Y una vez abierta, se abre de verdad: ahí el equipo tiene que ser fanático de
mejorar, porque a esa altura mirar afuera **es** el trabajo.

## La política que hace todo esto rentable

Cuando los obreros son baratos —y más si son gratis e ilimitados— la aritmética
se da vuelta: **un panel apagado no ahorra nada, sólo desperdicia.**

1. **Ningún obrero ocioso, nunca.** No es aspiración, es la política. Si hay
   paneles apagados, ésa es la urgencia y va antes que cualquier otra cosa.
2. **Si lo puede hacer un obrero, lo hace un obrero.** Compilar, testear, buscar
   en el repo, generar catálogos, arreglar tipos. El supervisor entra sólo donde
   no hay reemplazo: estrategia, arquitectura, juzgar lo que volvió y mantener la
   máquina andando.
3. **El proyecto en curso va primero, segundo y tercero.** Otro repositorio es la
   últimísima instancia, y sólo para no dejar un panel apagado.
4. **El trabajo no puede depender de que alguien redacte.**

## Escribir un ítem que aterriza

- **Una zona exclusiva por ítem**, nombrada en rutas. Dos ítems tocando un
  archivo es la herida autoinfligida más común, y no la cura ninguna habilidad
  para mergear.
- **Autocontenido.** El obrero no tiene tu contexto ni ve tu pantalla: el spec
  real va pegado adentro.
- **Decí qué NO tocar**, sobre todo las piezas compartidas.
- **Nunca asignes por nombre.** Vos escribís *qué*; el repartidor elige quién.
