# 👑 jefe.md — quién está a cargo (fuente única)

> **Cada panel lee ESTE archivo para saber a quién avisar al terminar.**
> No se hardcodea el panel en ningún script ni pedido: cuando el jefe rota, se
> cambia acá y todos los paneles siguen avisando bien.

## Quién es quién, ahora

| Rol | Dev | Panel | Modelo |
|---|---|---|---|
| **Jefe** | dev2 | `w5:p2` | — |
| **Subjefe** (manda cuando el jefe no está) | dev3 | `w5:p3` | — |

**Regla de oro:** cuando el jefe está ausente, el subjefe es "el que está a
cargo". Si el subjefe también está ocupado, el jefe deja nombrado un interino
en el handoff.

## La única regla de aviso

1. **Terminaste un bloque → avisás al jefe.** No te quedás mudo ni esperás que
   te vengan a mirar:
   `bash scripts/avisar-jefe.sh "2 líneas: qué commiteaste y qué sigue"`
2. **Si vos SOS el jefe:** no te avisás a vos mismo — actualizás el handoff y
   seguís.
3. **Si el jefe no recibe, el aviso escala solo:** jefe → subjefe → archivo de
   estado con fecha.
4. **Avisar NO es el final de tu turno.** Avisás y en el mismo turno agarrás el
   ítem siguiente de tu cola.

## Cómo se verifica la recepción

El script manda el aviso (prompt + Enter) y comprueba que el panel pasó a
**trabajando**. Si sigue ocioso, reintenta el Enter. No se consulta ninguna
herramienta externa: si el panel está vivo y arranca a trabajar con el aviso,
recibió; si no, no.

- Un panel que **ya estaba trabajando** en otra cosa: el aviso queda en su cola
  y se considera recibido (no escala).
- Un panel que **no procesa** (ocioso persistente o inexistente) = no operativo
  → salta al siguiente de la cadena.

## Historial de rotación

- AAAA-MM-DD: jefe = devN.
