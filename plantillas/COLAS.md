# 📋 COLAS — qué hace cada dev, en orden

> **Para qué existe:** que cada dev sepa qué sigue sin preguntar, y que si el
> jefe no está —o si alguien pierde el contexto— nadie pierda el rumbo.
>
> El **qué** y el **por qué** están en el roadmap. Acá está el **orden**. Si los
> dos se contradicen, manda el roadmap.

## 0.1 Qué panel es cada dev (fuente única — la lee un script)

`scripts/nadie-ocioso.sh` saca de ESTA tabla a quién empujar y qué cola mandarle
a leer. Si cambia un panel, se cambia acá y nada más: **no puede haber una
segunda tabla de paneles en ningún otro documento.**

| Panel | Dev | Tema |
|---|---|---|
| `w5:p1` | dev1 | — |
| `w5:p2` | dev2 | jefe — reparte y decide lo que cruza territorios |
| `w5:p3` | dev3 | — (**subjefe**) |

Los paneles de OTROS repos no son de esta cuadrilla: el guardián filtra por
directorio de trabajo y no los toca.

## 0.2 Nadie ocioso

| Dirección | Script | Cuándo |
|---|---|---|
| ⬆️ el panel avisa que cerró | `scripts/avisar-jefe.sh` | al terminar un bloque |
| ⬇️ el ocioso recibe órdenes | `scripts/nadie-ocioso.sh` | solo, cada 2 minutos |

```
bash scripts/nadie-ocioso.sh --demonio     # arrancar el guardián
bash scripts/nadie-ocioso.sh --estado      # ¿corre? ¿a quién empujó?
bash scripts/nadie-ocioso.sh --parar
```

## 0. Cómo se trabaja acá

1. **Nadie espera.** Terminaste un ítem → agarrás el siguiente de tu cola.
2. **Encontrás algo roto → lo arreglás y lo commiteás.** No se documenta.
3. **Verificás con datos reales.** Los números verificados van en el commit.
4. **Un commit por idea**, con el POR QUÉ. Archivos por nombre, nunca `add -A`.
5. **Bloqueado ≠ parado.** Escribís una línea con lo que falta y **seguís**.
6. **No inventes hallazgos** para llenar una tabla.
7. **No ajustes un test para que pase.**
8. **99% código, 1% prosa.**

**Antes de commitear:** (el ritual de tu stack, siempre completo).

---

## devN — (el objetivo de este dev, en una frase)

1. **Bloque A.** … *Terminado cuando (criterio verificable).*
2. …

## Qué hacer cuando tu cola se termina

1. ¿Quedó algo tuyo sin el criterio de terminado cumplido? Cerralo.
2. Mirá el roadmap: ¿hay un bloque sin dueño o atrasado?
3. Preguntale al subjefe.
4. Recién ahí, esperá.

**Lo que NO se hace cuando sobra tiempo:** empezar algo de la lista de "no
entra". Cuando sobra tiempo, se cierra lo abierto.
