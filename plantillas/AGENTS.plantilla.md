# AGENTS.md — reglas para los agentes de este repo

Esto lo lee opencode al abrir el proyecto. Son las reglas que más se rompen y
más caro salen. Cada una está acá porque se pagó.

## Antes de tocar nada

Leé los tres documentos del proyecto: el contrato de diseño (**cómo** se ve y se
comporta), las specs (**qué** tiene que hacer, y qué no) y la hoja de ruta
(**cuándo y quién**). Si lo que vas a construir no está en las specs, no está
decidido: preguntá antes de inventarlo.

## Tu zona

- **Trabajá sólo en los archivos que nombra tu ítem.** Dos agentes editando un
  archivo es la herida autoinfligida más común, y no la cura ninguna habilidad
  para mergear: la previene la propiedad exclusiva.
- **Commiteá con rutas explícitas.** Nunca "agregar todo": el árbol es
  compartido y te llevás el trabajo a medio hacer de otro.
- **No reordenes, renombres ni reformatees fuera de tu zona** porque pasabas por
  ahí.

## Compilar y testear

- **No compilás.** Hay un agente con el rol de compilador y es el único que
  corre el build. Los errores te llegan con archivo, línea y el arreglo.
- **Verificá por lo barato**, en este orden: leer el código, chequear los tipos
  de lo que tocaste, un test puntual, mirar la app andando.
- **Una compilación no es progreso. Una corrida de tests tampoco.** Un tilde
  verde es un instrumento, no una entrega. Nunca los uses para parecer ocupado.

## Cuando terminás

- **Cerrá con qué hiciste, qué archivos tocaste, qué falta y qué te bloquea.**
  Un párrafo corto, no una transcripción.
- **Si tu ítem ya estaba hecho, o está mal planteado, decilo y pará.** No
  fabriques una tarea adyacente para justificar el turno.
- **"No tengo nada" es una respuesta válida** cuando de verdad no queda nada.
  Inventar trabajo cuesta plata, ocupa un panel y genera revisión de algo que
  después hay que revertir.
- **Si estás bloqueado, avisá ya.** Un agente trabado en silencio es peor que
  uno que dice que no puede.

## El estándar

- **{{IDIOMA_CODIGO}} en el código**: identificadores, comentarios, commits.
  **{{IDIOMA_UI}} en la interfaz**, y todo texto visible va al catálogo de
  traducción, nunca escrito dentro de una pantalla.
- **El vocabulario del dominio no se cambia.** Las palabras que el usuario viene
  leyendo son memoria muscular: cambiamos cómo funciona y cómo se ve, no le
  renombramos el mundo.
- **Si algo aparece dos veces, es del sistema**: se arregla en la pieza
  compartida, nunca en la pantalla. Arreglar la pantalla deja el producto peor
  que antes — donde había una manera mediocre ahora hay dos.
- **Lo que se muestra tiene que existir.** Un control que se toca y no hace nada
  es peor que no tener el control.
- **Nada destructivo sin vista previa**, y reversible mientras se pueda.
- **99% código, 1% prosa.**

## Lo que nunca

- **Ningún dato personal real** entra al repositorio, ni a un test, ni a un
  fixture, ni a un log, ni a un comentario, ni a tu informe de cierre.
- **Nada que crezca va a `/tmp`** si `/tmp` es tmpfs: eso es RAM. Ni bases de
  datos, ni directorios de compilación, ni volcados.
- **Nunca rebasees código de la aplicación**, y menos en un repo que no es tu
  prioridad.
