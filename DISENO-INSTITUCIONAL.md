# Perfil: diseño institucional

Un perfil es una decisión estética completa —color, tipografía, densidad,
íconos— que un proyecto adopta entera. `INTERFAZ.md` dice la **forma** (dónde va
cada cosa) y vale siempre; esto dice el **tono**, y se elige según qué es el
producto.

Éste es el tono para software **serio y formal**: un sistema de gestión pública,
un back-office, cualquier cosa donde el usuario no eligió estar y necesita
confiar en lo que ve. No es el tono de un producto de consumo.

## La idea, en una línea

**Lo institucional se lee en la regla, no en el adorno.** Línea fina, cifra
tabular, blanco generoso, una sola familia tipográfica. Nada decorativo: cada
pieza existe porque alguien la usa todos los días.

Es disciplina suiza, no paleta suiza — el error más común es creer que "suizo"
es un color. Es la ausencia de lo que sobra.

## Color

Tinta, papel y **un** acento. Nada más.

| Ficha | Día | Noche | Para qué |
|---|---|---|---|
| tinta | `#16181C` | `#EDEBE5` | Texto y **la acción principal** |
| tinta-suave | `#6B6F76` | `#94989E` | Texto secundario |
| papel | `#FAFAF8` | `#121317` | Fondo |
| superficie | `#FFFFFF` | `#191B1F` | Tarjetas |
| borde | `#E3E1DB` | `#2C2F35` | Línea fina, nunca sombra |
| acento | `#33565C` | `#6FA3AB` | Foco, selección, marca |
| vencido | `#A03A2C` | `#D9776A` | **Estado**, nunca acción |
| pago | `#3E6B4A` | `#7FB68E` | **Estado**, nunca acción |

**La acción principal es tinta sobre papel**, no el acento. Un botón negro es
más institucional y más legible que un botón de color, y deja el acento libre
para lo que de verdad necesita destacarse.

**Rojo y verde son estado y jamás acción.** Un verde que en una pantalla es
«cobrado» y en otra «activo» ya rompió el sistema. Y no son rojo y verde puros:
ladrillo y musgo apagados, que en una pantalla llena de números no gritan.

### Elegir el acento: mirá quién es el dueño

La parte que no es obvia y que cuesta cara. **Un color puede tener dueño en el
país donde se usa el software**, y un usuario que abre una herramienta del
Estado y ve los colores de un partido o de un club no ve una paleta: ve una
declaración.

En Argentina, por ejemplo, quedan descartados de entrada el rojo con blanco, el
azul con amarillo y el celeste con blanco — entre partidos políticos y clubes de
fútbol, casi todo el espectro obvio ya está tomado, y el fanatismo es real.

Por eso el acento acá es un **petróleo apagado**: sobrio, con carácter, y
deliberadamente de nadie. La regla general: antes de fijar un acento, preguntá
de quién es ese color en el lugar donde se va a usar. Es una pregunta de dos
minutos que evita una discusión de años.

## Tipografía

Una familia, cuatro tamaños. Un sistema con seis tamaños de letra no es más
expresivo: es uno donde nadie decidió.

- **Archivo** para títulos y cifras, **Instrument Sans** para texto corrido.
  Cualquier grotesco con buenas cifras tabulares sirve; lo que no sirve es
  ninguna decisión y caer en la fuente por defecto del sistema.
- **Cifras tabulares en todo importe.** Donde se comparan columnas de plata todo
  el día, que los dígitos no bailen no es un gusto: es legibilidad.
- Títulos con `letter-spacing` levemente negativo; texto corrido a 1.6 de
  interlínea y ancho máximo de ~70 caracteres.

## Densidad y forma

- **Radio de 4 px**, no más. El redondeo grande lee a producto de consumo.
- **Línea fina antes que sombra.** La sombra simula profundidad; la línea afirma
  estructura, que es lo que este tipo de producto necesita.
- **Base de 4** para todo el espaciado.
- **Blanco generoso.** Es lo que hace legible una pantalla que alguien mira diez
  horas, y es lo primero que se sacrifica cuando alguien quiere meter una cosa
  más.

## Íconos

- **Trazo de 1.6 en grilla de 24**, terminaciones rectas, sin relleno, sin
  esquinas redondeadas. Geométricos, no ilustrados: un ícono que quiere ser
  simpático envejece mal donde se trabaja diez horas.
- **Dos tamaños: 20 en filas densas, 24 en encabezados.** Nunca 16 — a esa
  escala el trazo se ensucia y el ícono pierde el poco significado que tenía.
- **Ninguno va solo: todo ícono lleva su palabra al lado.** Un pictograma sin
  etiqueta es una adivinanza, y donde se maneja plata o trámites nadie tiene que
  adivinar.
- Nunca emoji.

## Modo noche

**Elección del usuario, en sus ajustes — no del reloj del sistema.** Alguien que
trabaja de día con la persiana baja quiere el modo oscuro a las tres de la
tarde, y el reloj no lo sabe.

Se declara una vez, arriba, con las mismas fichas semánticas: sólo cambian los
valores. **Ninguna pantalla redefine un color y ninguna sabe en qué modo está.**
Un color literal dentro de una pantalla es un error, no una decisión de diseño.

## Cómo se adopta

Copiá la tabla de fichas a la definición de tokens del proyecto, con esos
nombres. Después `INTERFAZ.md` manda sobre la forma, y esto sobre el tono. Si el
proyecto no es institucional, no uses este perfil: escribí el suyo y guardalo al
lado.
