# Si arrancaste de cero, leé esto primero

Una sesión de agente se muere: se reinicia, se queda sin cuota, se le llena el
contexto, la mata el kernel. Cuando eso pasa, lo que sabía se va con ella.

**La única memoria que sobrevive es la que está en el repositorio.** Este archivo
es el punto de entrada: en cinco minutos te devuelve al estado del que te
caíste.

## Lo primero: mirá, no supongas

```bash
bash scripts/arrancar.sh --estado    # qué motores corren, cuántos obreros, tablero
bash scripts/mirador.sh              # flota y RAM en vivo
bash scripts/objetivo.sh             # cuánto falta para terminar, medido
./scripts/teatro.sh                  # ¿alguien parece trabajar sin producir?
git log --oneline -15                # qué pasó mientras no estabas
```

Si algo dice **NO PUEDO MEDIR**, ése es tu primer trabajo: un instrumento roto
es peor que ninguno, porque miente con cara de tranquilo.

## Lo segundo: los documentos que te devuelven el criterio

| Documento | Qué te devuelve |
|---|---|
| `skills/flota/SKILL.md` | **Empezá acá.** Cómo se conduce una flota, los modos de falla y cómo detectarlos |
| `DOCTRINA-DEL-JEFE.md` | El rol, la escalera de mejora, y §5 con el patrón de las fallas silenciosas |
| `METODOLOGIA.md` | Cómo se trabaja, la política de que nadie quede ocioso |
| `JEFE-LEEME.md` | Si te toca conducir: por qué un jefe se detiene y qué lo arregla |
| `INTERFAZ.md` | La forma exacta de la interfaz. Es lista cerrada, no guía de estilo |
| `MIGRACION_LEGACY.md` | Si el proyecto reemplaza un sistema viejo |

## Lo tercero: lo que más caro salió aprender

Si sólo te llevás una cosa de este archivo, que sea ésta.

**Casi todas las fallas que nos costaron horas tenían la misma forma: un
componente que ante su propia falla devuelve un valor plausible en vez de un
error. Y siempre disfrazado de la respuesta BUENA** — "todo bien", "cero
pendientes", "100%", "no hay nada que hacer". Nunca de la mala. Un componente
que falla diciendo "hay problema" se descubre en cinco minutos; uno que falla
diciendo "todo bien" vive meses.

Casos reales, todos medidos:

| Se rompió | Se veía como | Era |
|---|---|---|
| Filtro por clase de panel que no matchea | "cero obreros" | El harness decía otra palabra |
| Búsqueda por substring que matchea de más | "inventario cubierto" | Un ítem mencionaba un rango |
| `find -newermt` en ciertos montajes | "cero archivos tocados" | git mostraba 20 commits |
| Denominador en cero | "100% cumplido" | No se pudo medir — **y abría la compuerta** |
| `[ cond ] && acción` en un bucle con `set -e` | "no hay nada que hacer" | La función moría en la primera vuelta |
| `x=$(cmd \| grep)` con `pipefail` | Lo mismo | El grep no matcheó y mató la asignación |
| Un endpoint sin control de rol | Idéntico a uno que lo pasó | **La ausencia no se queja** |
| Una regla escrita sólo en un comentario | Código que la cumple | Documentación que miente |

**Las reglas que salieron de ahí:**

1. **Preguntale a toda medición nueva: ¿cómo se ve esto cuando el instrumento
   está roto?** Si la respuesta es "igual que cuando todo está bien", falta un
   control.
2. **Antes de confiar en un número, rompé el instrumento a propósito y mirá qué
   imprime.** Y después pasale algo sano y mirá que no lo acuse: se rompe en las
   dos direcciones, y un control que acusa a lo que está bien deja de ser creíble.
3. **Un instrumento no puede auditarse con el sensor que se le rompió.** El
   autocontrol necesita una segunda medición que falle por motivos distintos.
4. **Tres estados, no dos**: HAY PROBLEMA / NO HAY PROBLEMA / **NO PUEDO
   MEDIR**. El tercero casi nunca se implementa y es el que importa.
5. **Un instrumento roto nunca puede ABRIR una compuerta.** En el peor caso la
   deja cerrada: los dos errores no cuestan lo mismo.
6. **Contra un componente que miente, un segundo sensor. Contra uno que falta,
   hacer que su ausencia no compile.**

## Lo cuarto: no vuelvas a perder esto

Lo que sabés hoy y no está en un archivo, **se pierde en tu próximo reinicio**.
No es una posibilidad: es lo que acaba de pasar.

- Un hallazgo que no se escribió, no existe. Escribilo cuando lo encontrás, no
  "después".
- Va al repo **`base`**, que es lo que heredan los proyectos nuevos, y a los
  repos activos con el mismo problema.
- **Commiteá y pusheá.** Trabajo sin pushear se ve, desde afuera, exactamente
  igual que trabajo que no existe — a una sesión le pasó: vio un repo con un
  commit, supuso que estaba muerto y montó una flota encima.
- Y dejá el estado en un archivo, no en tu cabeza: cinco líneas de qué estabas
  haciendo y qué sigue.
