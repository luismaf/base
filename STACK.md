# 🏗 El stack, y por qué cada pieza

> **La regla que hace útil a este archivo:** describe lo que HAY, verificado
> contra `package.json` y `Cargo.toml`, no lo que se planeó. Si algo acá no
> coincide con el código, **gana el código** y esto se corrige.
>
> Y la sección más valiosa es la última: **lo que NO está instalado.** Un
> documento que sólo lista lo que hay hace que el próximo agente escriba
> `import { motion } from 'framer-motion'` porque un doc viejo lo mencionaba.

---

## Backend

| Pieza | Elección | Por qué |
|---|---|---|
| Lenguaje | **Rust**, workspace con varios crates | El dominio (cálculos que deciden plata) separado del transporte HTTP: se testea sin levantar un servidor. |
| HTTP + API | **Axum + async-graphql** | Un solo endpoint tipado; el esquema es el contrato con el frontend. Resolvers en un archivo por dominio, no un archivo de 5.000 líneas. |
| Base de datos | **PostgreSQL, y sólo Postgres** | No hay "SQLite en dev". Dos motores = dos comportamientos de tipos numéricos y de fechas, y el bug aparece recién en producción. |
| Acceso a datos | **sqlx** con caché offline | Las consultas se verifican **en tiempo de compilación** contra el esquema real. La caché permite compilar sin base levantada. |
| Migraciones | Archivos numerados, incrementales | **Nunca se edita una ya aplicada.** El script de reset DROPEA la base: no se usa para aplicar una migración nueva. |
| Auth | **Argon2id + JWT** | Argon2id, no bcrypt. |

**Separación de crates, que es lo que más se paga:**

```
crates/
├── dominio/     # cálculos y reglas. Cero dependencias de HTTP. Se testea solo.
├── api/         # Axum + GraphQL + acceso a datos
└── asistente/   # LLM + herramientas
```

---

## Frontend

| Pieza | Elección | Por qué |
|---|---|---|
| Base | **React + TypeScript strict + Vite** | — |
| Estilos | **Tailwind + componentes sobre Radix** | Accesibilidad (foco, teclado, ARIA) resuelta por la base; el estilo, propio. |
| Datos | **Apollo Client** | Una sola forma de traer datos en todo el repo. Dos librerías de fetching conviven mal: se duplica la caché y nadie sabe cuál invalidar. |
| Estado global | **Jotai** | Átomos chicos; no hay un store gigante que todos toquen. |
| Formularios | **react-hook-form + Zod** donde se justifica | Los ABM chicos usan estado controlado a mano: montar un esquema para tres campos es más código que el formulario. |
| i18n | **react-i18next** | Detección por almacenamiento local → navegador, con idioma de respaldo. |
| Gráficos / fechas | **recharts** / **date-fns** | — |
| Escritorio y móvil | **Tauri** | La misma aplicación web en ventana nativa y en APK. **Toda página se prueba también ahí**, no sólo en el navegador. |

---

## Offline (si el producto se usa donde no hay señal)

La arquitectura que funcionó, en cuatro piezas:

1. **SQLite local en el dispositivo**, poblado por una bajada periódica.
2. **Una cola de salida (outbox)** para lo que se carga sin señal, con reintentos
   y retroceso exponencial.
3. **Un identificador de cliente (`clientUuid`) por operación.** Es la clave de
   todo: el servidor **deduplica contra él**, así que re-sincronizar la misma
   operación deja UNA sola fila. Sin eso, cada reintento es un duplicado.
4. **Un hook que lee lo local AL MONTAR**, en paralelo con la red. En el campo,
   una petición a un servidor inalcanzable queda pendiente mucho tiempo: si la
   pantalla espera a que falle, el usuario mira un spinner. Lee lo del
   dispositivo ya, y si después llega lo del servidor, eso gana.

Y las dos reglas que evitan que el offline mienta:

- **Un dato que no bajó va como raya, nunca como cero.** Un `$0` o un "Al día"
  le dice al usuario que no debe nada.
- **Un dato local avisa que es local**, y de cuándo es.

Errores de dominio no se reintentan en bucle: se suben, el servidor responde su
error de validación, y la operación queda marcada — nunca se confirma contra una
respuesta vacía.

---

## El asistente con LLM

- **Agnóstico del proveedor**, con cadena de respaldo configurable, y una
  función que responde **quién contestó**.
- **Catálogo de modelos con costos** para medir gasto sin gastar tokens
  midiendo: el precio sale del catálogo y los tokens del `usage` que ya devuelve
  cada llamada real. **Cero llamadas extra para medir.**
- **El LLM decide la intención; el código valida y ejecuta.** Las herramientas
  son funciones con entrada y salida propias, testeables sin LLM.

---

## Lo que NO está instalado (la sección que evita que alguien lo importe)

Estas piezas aparecen en documentos viejos y **no existen en el repo**:

- **Librería de animación.** Las transiciones son CSS, respetando
  `prefers-reduced-motion`. No hizo falta.
- **Paleta de comandos ⌘K.** Aspiracional.
- **Mapas.** Es una fase posterior; el esquema ya tiene los campos geográficos,
  el código no tiene la librería.
- **Datos de mentira (mock data).** El archivo se borró a propósito: toda página
  lee de la API real y muestra estados reales de carga, error y vacío.
- **Segunda librería de fetching.**

---

## El ritual de verificación

Antes de commitear, siempre el mismo y siempre completo:

```
# Frontend
npx tsc --noEmit && npx vitest run && npm run build

# Backend (la caché offline evita necesitar la base levantada)
SQLX_OFFLINE=true cargo build && cargo test
SQLX_OFFLINE=true cargo clippy --all-targets

# Migraciones: incrementales. NUNCA el reset para agregar una nueva.
```

**El número de tests no puede bajar.** Y si el binario de desarrollo no hace
recarga en caliente, dejalo escrito junto al comando de reinicio: se pierde
media hora probando un cambio que nunca se cargó.
