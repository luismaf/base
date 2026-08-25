# 🎨 Design System — AgroGestión Pro

> ⚠️ **ORDEN DE LECTURA (2026-08-20):** el canon VIVO es `docs/DESIGN.md
> §0.05` (lo que el dueño decidió hoy: la clase CollectionPage, sin cards,
> sin chips (n), sin acordeones en mobile, sin FABs, sin "+" en tabs,
> inglés en el código). **Si algo de este archivo lo contradice, quedó
> viejo y gana §0.05.**

> ## ⚠️ ESTE DOCUMENTO YA NO MANDA. MANDA `docs/DESIGN.md`.
>
> Los dos se declaraban "fuente única" y **se contradicen**: acá el patrón de
> lista es `DataView`; en `DESIGN.md` (2026-08-15, posterior) es
> `ListaDeFichas` / `FichaEnLista`, y las tarjetas sueltas están prohibidas.
> Costó caro: el 2026-08-16 un pedido mandó "arreglar" tres pantallas que ya
> estaban bien —`PedidosPage`, `EquipmentPage`, `TareasPage`— porque el
> inventario se había hecho contra ESTE archivo. El worker lo cazó a tiempo y
> no las tocó; si las tocaba, las alejaba del contrato en nombre de la
> consistencia.
>
> **Qué sigue sirviendo de acá**: los tokens de color, las superficies
> (lectura `bg-card` / escritura `bg-muted`), tipografía, espaciado y el
> catálogo de piezas con su porqué. **Qué NO**: el patrón de página de
> colección y todo lo que hable de `DataView` como destino — eso lo define
> `DESIGN.md`. Ante cualquier diferencia, gana `DESIGN.md`.

> Reemplaza (y consolida) `DESIGN_SYSTEM_2026_MATERIALIZED.md`,
> `DESIGN_SYSTEM_REFERENCE_2026.md`, `UX_AUDIT_2026.md` y `REDESIGN_PLAN_2026.md` — esos cuatro
> archivos documentaban generaciones sucesivas del mismo rediseño y quedaron desactualizados o
> redundantes entre sí; se borraron. La fuente única del CONTRATO de diseño es `docs/DESIGN.md`
> (ver aviso arriba); este archivo aporta tokens, superficies y catálogo de piezas. Complementos:
> `docs/NEXT_STEPS.md` (roadmap), `docs/DEBT.md`
> (deuda técnica), `docs/PAGE_INTERACTION_MAP.md` (qué CRUD tiene cada página),
> **`docs/HANDOFF.md` (estado del trabajo y próximos pasos — leelo primero)**.
>
> Última actualización: 2026-08-06.

---

## 1. El producto en 2 minutos

AgroGestión Pro es el sistema de gestión agropecuaria que un chacarero argentino o uruguayo usa
todos los días, en el campo (tablet) y en la oficina (escritorio y desktop Tauri). Hoy el foco es
AR/UY; la plataforma está diseñada para escalar a Brasil, USA y Europa (i18n es/pt-BR/en activo).

**Stack real (verificado contra `package.json` y `Cargo.toml`, no contra lo aspiracional):**

| Capa | Tecnología |
|---|---|
| Backend | Rust: workspace `crates/` (`app-core`, `app-api`, `app-copilot`) · Axum + async-graphql 6 + sqlx 0.8/**Postgres únicamente** (no SQLite) |
| Frontend | React 18 + TypeScript strict + Vite 5 + Tailwind + shadcn/ui (Radix) + Apollo Client + TanStack Query/Table + react-router 6 + react-i18next |
| Estado | **Jotai** (no Zustand) |
| Desktop | Tauri (`src-tauri/`) — la misma web corre en ventana nativa; toda página debe probarse también ahí |
| Auth | JWT HS256 + **Argon2id** (no bcrypt) |
| IA | Copiloto schema-as-contract (LLM agnóstico, guided decoding), voz es-AR (dictado + TTS), clima Open-Meteo, precios (Yahoo + DolarAPI) |

**No están instalados** (a pesar de mencionarse en documentos viejos): framer-motion (el motion es
CSS/Tailwind `animate-in`), `cmdk`/command palette, `leaflet`/mapas — geolocalización de pedidos es
post-MVP (§8).

**Mercados objetivo (orden de expansión):** 🇦🇷/🇺🇾 ahora → 🇧🇷 → 🇺🇸 → 🇪🇺.

---

## 2. Principios de diseño (Swiss Startup, award-worthy)

1. **Precisión suiza**: nada es ambiguo. Cada número tiene unidad, cada badge es clickeable, cada
   estado tiene color semántico.
2. **Cero carga cognitiva**: el productor escanea en 3 segundos. La acción primaria de cada página
   es UNA.
3. **Formularios que respiran**: el alta nunca te arranca del contexto. El formulario BAJA debajo
   de su botón (`ExpandableForm`); la página no se reemplaza, no hay popup que tape lo que estás
   mirando.
4. **Grid/listado en todas las colecciones**: grid por defecto (el campo se lee en cards), listado
   ordenable para analizar.
5. **Responsive en serio**: móvil (campo, una mano) → tablet (cabina) → desktop (oficina) →
   ventana Tauri.
6. **Dark mode perfecto** en cada página (tokens semánticos, nunca hex sueltos).
7. **Cero callejones sin salida**: todo `EmptyState` tiene CTA que funciona de verdad; todo botón
   lleva a algo real (no a una ruta muerta ni a una mutation que no existe — ver §7 sobre por qué
   esto se repite tanto en la deuda técnica).
8. **Performance**: lazy loading de páginas pesadas, tablas virtuales cuando haya +500 filas.

---

## 3. Patrones de UI — la especificación (componentes reales, `components/shared/`)

> ⛔ **3.1 y 3.2 quedaron VIEJAS (2026-08-22):** `StatCard`, `MiniKpi` y
> `DataView` fueron BORRADOS del repo (`106aff8b`). La colección estándar hoy
> es la clase `CollectionPage` — manda `DESIGN.md §0.05`. Los ejemplos de
> abajo se conservan sólo por el porqué del layout (breadcrumbs → título →
> subtítulo → acción primaria); NO copiar los componentes que mencionan.

Un solo patrón por función. **`SortableView`, `Modal.tsx`, `InlineForm` duplicado, i18n legacy y
`mockData.ts` ya no existen en el repo** — si algún documento viejo o algún fork de esta sesión los
menciona, están desactualizados.

### 3.1 `PageShell` — layout de toda página

```tsx
import { PageShell, StatCard, DataView } from '@/components/shared';

<PageShell
  title="Depósitos"
  subtitle="Tablero de depósitos: ocupación, ADG y consumo"
  breadcrumbs={[{ label: 'Producción' }, { label: 'Depósitos' }]}
  actions={<ExpandableForm triggerLabel="Nuevo Depósito" ... />}
>
  <div className="grid grid-cols-2 sm:grid-cols-4 gap-3">
    <StatCard label="Total" value={n} onClick={...} />
  </div>
  <DataView ... />
</PageShell>
```

Breadcrumbs → título (`text-lg sm:text-xl` — no `text-2xl/3xl`, ver nota de espaciado abajo) →
subtítulo → una acción primaria arriba a la derecha. `space-y-4` entre bloques de cabecera,
`space-y-6` entre secciones de contenido dentro de `children`.

### 3.2 `DataView` — colección estándar

Grid por defecto + listado sortable (preferencia persistida en `localStorage` vía `storageKey`),
`aria-sort`, `useDeferredValue` para listas largas, respeta `prefers-reduced-motion`. El `toolbar`
prop recibe el buscador/selects de filtro de la página — **todo en UNA fila junto al toggle
grid/listado y el contador**, nunca un segundo renglón aparte (ese fue un bug real en `GruposPage`,
corregido).

```tsx
<DataView
  columns={[{ key: 'name', label: 'Nombre', sortValue: (l) => l.name }]}
  items={filtered}
  getRowKey={(l) => l.id}
  storageKey="lots-view"
  toolbar={<Input placeholder="Buscar..." ... />}
  countLabel={`${filtered.length} pedidos`}
  renderCard={(l) => <article onClick={...}>...</article>}
  renderRow={(l) => <tr onClick={...}>...</tr>}
  empty={<EmptyState ... />}
/>
```

### 3.3 Formularios: `FormPanel` vs `ExpandableForm` — cuál va dónde

Los dos son inline (nunca popup). La diferencia es **quién ya hizo el gesto de revelado**:

| Contexto | Componente | Por qué |
|---|---|---|
| Página de **detalle** + pestañas (pedido, depósito, grupo, depósito, alquiler, plantillas) | **`FormPanel`** — form siempre visible arriba, `HistoryPanel` abajo | Cambiar de pestaña YA ES el revelado. Si el usuario tocó "Alta" es porque quiere ver o cargar una alta; obligarlo a apretar "Registrar Alta" para que baje el form es un click de peaje sin información. |
| Página de **colección** (listado) | **`ExpandableForm`** — el form baja debajo del botón | Ahí el trabajo principal es navegar/buscar; el alta es secundaria y no debe empujar la lista hacia abajo por defecto. |

`FormPanel` trae un chevron de plegado en el **header del panel** (estado recordado por
`storageKey` en localStorage) para cuando el usuario viene sólo a mirar el historial. El control
va en el header, **nunca** como botón suelto arriba del contenido — ahí queda feo y reintroduce
justamente el click de peaje que quisimos eliminar.

**Contraste — la regla de superficies.** En light mode `--card` es blanco puro, idéntico a
`--background`: un panel de formulario `bg-card` es invisible salvo por el borde, y los inputs
(que son `bg-background`) se funden con él. Por eso:

- **superficie de LECTURA** (`HistoryPanel`, cards de Resumen, tablas) → `bg-card`
- **superficie de ESCRITURA** (`FormPanel`, panel de `ExpandableForm`) → `bg-muted/80 dark:bg-muted/45`

Así los campos saltan contra el panel, y de un vistazo se distingue dónde se escribe de dónde se
lee sin tener que interpretar títulos. Bloques anidados dentro de un form (totales calculados,
filas de producto) van a `bg-background` para elevarse sobre el panel teñido.

### 3.4 `SegmentedControl` — elegir entre 2-6 opciones

Tipo de labor, tipo de movimiento de animales, tipo de destino, categoría de insumo: todo eso es
**un campo más del formulario**, no el objetivo de la pantalla. Va en `SegmentedControl` compacto,
siempre visible dentro del form.

Anti-patrón que reemplaza (fue real en `TareaForm`): 4 tarjetas `p-6` con emoji de 32px ocupando
media pantalla, que además forzaban un estado previo ("elegí primero, después aparece el form")
más un botón "Cambiar tipo" para volver atrás. Con el segmented, cambiar de opción es un click y
no hay estado previo que administrar. Tarjetas grandes sólo si elegir ES el objetivo de la
pantalla (ej. elegir un pedido de una grilla).

### 3.5 `ExpandableForm` — detalles de comportamiento

El formulario baja debajo del botón con animación de altura; Escape cierra; foco vuelve al trigger.

- **Regla de oro:** alta de ≤6 campos → `ExpandableForm`. Flujo multi-paso o con dependencias
  complejas (cierre con N camiones, alta con selección de destino/insumo) → página-ruta
  dedicada (`/cierres/new`, `/plantings/new` etc.), pero esa página-ruta debe volver a la entidad
  de origen al guardar (`/lots/:id`), **no a un listado genérico** — ese fue un bug real
  (`CierreForm`/`AltaForm` volvían a `/cierres`/`/altas` en vez de al pedido).
- **¿Por qué no popup?** El popup tapa el contexto. `Dialog` queda reservado para:
  1. Confirmaciones destructivas: `useConfirmDelete` (papelera + Deshacer, SIN
     modal — reemplazó al viejo diálogo con tipeo del nombre) o
     `BorrarConNombre` cuando el borrado es irreversible de verdad.
  2. Selectores chicos que necesitan foco (ej. elegir destino de insumo con preview).
  3. Config de sistema puntual (`BackendConfigModal`).
  Nunca para crear/editar una entidad de dominio.
- `defaultOpen` sólo alta el estado inicial en el mount — para que un CTA de `EmptyState` en la
  MISMA ruta (`navigate('?new=1')`, sin remount) abra el form, `ExpandableForm` tiene un `useEffect`
  que reacciona si `defaultOpen` pasa a `true` después del montaje.

### 3.6 Otras piezas: `StatCard`, `StatusPill`, `MiniKpi`, `EmptyState`, `HistoryPanel`

- **`StatCard`**: KPI que si tiene `onClick` DEBE filtrar algo de verdad — no decorar. Un StatCard
  clickeable que no cambia ningún resultado visible es peor que uno sin `onClick` (fue un bug real
  en Campañas: el card "Cerradas" prendía un `ring` visual pero la lista de abajo nunca leía ese
  filtro).
- **`StatusPill`**: tono semántico (`success`/`warning`/`danger`/`info`/`default`), nunca color a
  mano.
- **`MiniKpi`**: grid 2×2 dentro de cards, tipografía `tabular-nums`.
- **`EmptyState`**: CTA siempre presente y siempre funcional — verificar que el `onAction` de verdad
  crea algo o navega a algo que existe.
- **`HistoryPanel`**: la mitad de abajo del patrón de detalle (`bg-card`, header con título en
  mayúsculas + contador). Absorbe el estado vacío vía `empty`/`emptyMessage`, así que la página no
  necesita el clásico `{items.length === 0 ? <div>…</div> : <table>…}`.

---

### 3.bis Errores: una sola forma de fallar (UX-08)

Un error dice QUÉ PASÓ y QUÉ HACER — nunca un stack trace.

- **El componente es `ErrorState`** (`ui/page-layout.tsx`): traduce la falla
  técnica (sesión vencida / sin permiso / sin conexión / timeout) a título +
  detalle accionable con botón Reintentar. El texto crudo va abajo, colapsado,
  para quien reporta. PROHIBIDO crear otro componente de error: el duplicado
  `ErrorDisplay` se eliminó por violar esto (título en inglés, mensaje crudo).
- **Los códigos estables del backend** se mapean a mensajes amables con
  `mensajeDeError()` (`lib/errores.ts`) dentro de los toasts.
- **Verificado en vivo** (2026-08-24): con la API caída, las pantallas muestran
  "No se pudieron cargar los datos / Reintentá / Detalle técnico" — nunca un
  stack. Prohibido `{error.message}` como texto visible fuera de `ErrorState`
  o `mensajeDeError`.

## 4. Rutas: inglés canónico, español como redirect

Todas las rutas nuevas van en inglés (`/depositos`, `/grupos`, `/depositos`, `/alquileres`, `/cierres`,
`/categorias`, `/debts`, `/accounts`, `/movements`, `/stock-movements`). Las rutas viejas en español
quedan como `<Navigate replace>` (o `ParamRedirect` para rutas con `:id`, ver `App.tsx`) — no se
borran, para no romper bookmarks. **Todo `navigate()` interno debe usar la ruta canónica en
inglés**, nunca la redirigida (si aparece un `navigate('/grupos/...')` en código nuevo, es un bug).

---

## 5. Design Tokens

**`frontend/index.css`** (colores semánticos, con dark mode):

```css
:root {
  --success: 160 84% 39%;     /* ingreso / cierre / ganancia */
  --warning: 45 93% 47%;      /* alerta / vencimiento / clima */
  --danger: 0 72% 51%;        /* egreso / deuda / muerte */
  --primary: 221 83% 53%;
  --radius: 0.75rem;
}
.dark {
  --success: 158 74% 55%; --warning: 45 100% 51%; --danger: 0 72% 60%; --primary: 217 91% 60%;
}
.tabular-nums { font-variant-numeric: tabular-nums; }
```

Tailwind expone `success`/`warning`/`danger` como clases (`text-success`, `bg-danger/10`, etc.).
**Prohibido hex hardcodeado en páginas**, y prohibido también el gris crudo de Tailwind
(`text-gray-500`, `text-gray-400`): sin `dark:` desaparece en oscuro, y con `dark:` duplica a mano
lo que `--muted-foreground` ya resuelve en los dos temas. Colores de dominio: pedidos verde ·
depósitos naranja · equipos azul · finanzas verde esmeralda · tareas amarillo · inventario índigo.

### 5.1 Contraste del texto secundario

`--muted-foreground` está calibrado a **AAA (≥7:1) sobre `bg-background`** y ≥6.8:1 sobre la
superficie de escritura `bg-muted`, en ambos temas:

| | valor | vs. fondo | vs. `bg-muted` |
|---|---|---|---|
| claro | `215 19% 35%` | 7.46:1 | 6.81:1 |
| oscuro | `215 22% 74%` | 10.07:1 | 7.70:1 |

Antes era `215 16% 47%` en claro (4.8:1): pasaba AA raspando y en labels de 11-12px —que es donde
más se usa— se leía lavado. **El color solo no alcanza**: el peso fino se come el contraste que
gana el color, así que las etiquetas chicas van `font-medium` (labels, hints) o `font-semibold`
(encabezados de tabla, label de `StatCard`, título de `HistoryPanel`).

### 5.2 Tipografía en rem, nunca en px

El control de tamaño de letra (`AccessibilityContext` → `AccessibilityMenu`, en el pie del menú)
ajusta el `font-size` del `<html>`. Como el sistema está en rem, **escala la interfaz entera y
proporcionada** — tipografía, espaciados, alto de inputs, iconos — en vez de agrandar texto dentro
de cajas que no crecen.

Por eso **nunca `text-[11px]` ni ningún tamaño en px**: se queda chiquito justo cuando el usuario
pidió letra más grande, que es el único momento en que le importa. Había 60 de esos en el repo y
se convirtieron a la escala Tailwind (`text-xs` / `text-sm` / `text-base`); el piso quedó en
`text-xs` (12px) porque 10-11px es ilegible en una tablet al sol.

---

## 6. Navegación

Sidebar (derecha, colapsable, con chat docked redimensionable). Todo menú entra a su primer
submenú:

```
🏠 Inicio       → /tablero     (Tablero, Tareas, Contactos)
📋 Ventas       → /pedidos     (Pedidos, Categorías, Campañas)
🏭 Producción   → /depositos   (Depósitos, Grupos → /grupos, Plantillas, Mediciones, Compras)
🔧 Equipos      → /equipos
📦 Inventario   → /inventario
💰 Finanzas     → /finanzas    (Cuentas, Alquileres)
⚙️ Configuración → /usuarios    (multi-empresa NO vive acá — ver §8)
```

---

## 7. Por qué tanta deuda técnica se repite: el patrón de bug más común

Durante el rediseño de 2026-08 aparecieron, una y otra vez, dos clases de bug que vale la pena
nombrar para no repetirlas:

1. **Resolver de backend con columna faltante.** Cuando se agrega una columna nueva a una tabla
   (ej. `campaign_id` en la migración `0057`), TODOS los `sqlx::query_as::<_, Struct>` que
   deserializan esa tabla necesitan la columna en su `SELECT`, no sólo el que se estaba editando en
   ese momento — el derive `FromRow` mapea por nombre de columna contra TODOS los campos del struct,
   incluso los que la query GraphQL del frontend no pidió. Se encontraron y corrigieron 5 resolvers
   con este bug exacto (creación de alta, `Pedido.categoriaActual`, `categorias_por_pedido`, alta/edición de
   compra de mercadería) — **al agregar una columna a un struct compartido, grepear todos los
   `query_as::<_, ESESTRUCT>` del repo**, no confiar en que "ya se actualizó en otro lado".
2. **Mutation con argumentos requeridos que un caller sólo llena parcialmente.** `update_campaign` y
   `update_transaction` tenían `name`/`counterparty_id`/etc. como no-opcionales o sin `COALESCE`,
   así que un update parcial (sólo cerrar la campaña, sólo tildar "conciliado") fallaba la
   validación de GraphQL o **borraba silenciosamente** el campo no reenviado. Todo `update_*` debe
   aceptar `Option<T>` en cada campo mutable y usar `COALESCE($n, columna)` en el `SET`.

---

## 8. Multi-empresa: no vive en Configuración normal

Cada empresa real = una organización. La versión base NO permite crear más de una empresa desde la
UI estándar. El CRUD de organizaciones está gateado a `is_sysadmin` (claim JWT `sys`, migración
`0055`) y vive en `/gestion` (ruta configurable vía `VITE_ADMIN_PATH`, deliberadamente no listada en
el sidebar normal). `/organizations` existe para que un miembro normal vea su propia empresa en
modo solo-lectura.

---

## 9. Campañas: una sola activa a la vez

**Regla de negocio confirmada y enforced a nivel DB** (no sólo convención de UI):
`CREATE UNIQUE INDEX one_active_campaign ON campaigns(organization_id) WHERE end_date IS NULL`
(migración `0053`). El modelo es binario: `end_date IS NULL` = abierta, si no, cerrada — no hay
estado intermedio "planning"/"closing" en el esquema actual. `campaign_id` es un FK explícito en 12+
tablas de eventos/gastos (migración `0057`) elegido al cargar cada registro, nunca inferido por
fecha — porque campañas productivas pueden solaparse en calendario aunque sólo una esté "abierta"
administrativamente a la vez (ej. cierre de gruesa saliente + alta de fina entrante en el mismo
mes). `campaign_id = NULL` es válido y significa gasto de estructura (sueldos, seguros generales,
impuestos del establecimiento) — no forzar todo a la campaña activa.

---

## 10. Checklist de "DONE" por página

- [ ] Usa `PageShell` con breadcrumbs + título + acción primaria.
- [ ] Colección → `DataView` con grid default + toggle listado + `storageKey`, toolbar en una sola
      fila.
- [ ] Alta de ≤6 campos → `ExpandableForm`. Nunca `Dialog` para crear/editar.
- [ ] Destrucción → `useConfirmDelete` (papelera + Deshacer) o `BorrarConNombre`
      si es irreversible. Nunca un `Dialog` de confirmación con tipeo.
- [ ] Todo `StatCard` con `onClick` filtra algo real.
- [ ] Todos los números/badges relevantes son clickeables (hipervínculos a la entidad).
- [ ] Rutas en inglés canónico; `navigate()` interno nunca usa la ruta española redirigida.
- [ ] Dark mode con tokens semánticos, sin hex hardcodeado.
- [ ] `organizationId` viene de `useOrganizationId()` (`@/lib/org`), nunca hardcodeado.
- [ ] `tsc --noEmit` + `npm run build` verdes; `cargo build && cargo test -p app-api` verdes si se
      tocó el backend.
- [ ] Si se agregó una columna a una tabla, se grepearon todos los `query_as` de ese struct (§7).
- [ ] Probado a mano en el navegador con el dev server corriendo (`scripts/restart-backend.sh` si se
      tocó Rust — el binario no hace hot-reload).

---

## 11. Investigación de referencia (por qué estos patrones)

Inspiración de mercado, no clonada literal — AgroGestión es un producto de campo con precisión
suiza, no un clon de SaaS genérico:

- **Linear**: drill-down con panel lateral, filtros como pills visuales, Cmd+K (aspiracional, no
  instalado todavía).
- **Notion**: todo editable inline, vistas intercambiables, disclosure progresivo.
- **Airtable**: registros vinculados clickeables, expansión de fila sin salir de la página.
- **Brex/Ramp/Mercury**: timeline de transacciones, saldo prominente, reconciliación con un click,
  cambio de cuenta fácil — la base de `/agro/finances` (§ Finanzas más abajo).
- **Gusto/Rippling**: persona como entidad primaria con drill-down completo, status pills en todos
  lados.

Análisis competitivo específico del agro (Aegro, Granular, etc.) en `docs/COMPETITIVE_ANALYSIS_RESEARCH.md`.

**Estado del arte 2026 (lo que confirmó las reglas de §3.3-3.4):** en interfaces densas de uso
diario, el contraste alto transporta información barata — separar visualmente las superficies vale
más que decorarlas. Linear muestra hasta dónde llega la densidad sin ensuciar (filas de ~36px,
chrome silencioso, teclado antes que mouse); la tendencia general en herramientas de trabajo es
dark-first, bordes de panel de bajo contraste y tipografía nítida. En formularios, el consenso es
disclosure progresivo *sólo donde se gana algo*: revelar campos cuando pasan a ser relevantes, no
esconder el formulario entero detrás de un click que no aporta información — que es exactamente la
distinción `FormPanel` vs `ExpandableForm`.

- [Form UX best practices 2026 — designstudiouiux](https://www.designstudiouiux.com/blog/form-ux-design-best-practices/)
- [Progressive disclosure in UX — IxDF](https://ixdf.org/literature/topics/progressive-disclosure)
- [Progressive disclosure in forms — orbitforms](https://orbitforms.ai/blog/progressive-disclosure-in-forms)
- [Dashboard design patterns 2026 — artofstyleframe](https://artofstyleframe.com/blog/dashboard-design-patterns-web-apps/)
- [Form design trends 2026 — formester](https://formester.com/blog/website-and-form-design-trends/)


## El tono: informar, nunca sermonear

**Regla (pedido explícito del dueño, 2026-08-07):**

> "Este pedido no tiene seguro vigente. *Si hay una alta en pie, una siniestro
> se lleva la campaña entera y los costos ya están hechos.*" ← **sacar la
> segunda oración.**
>
> "Estas cosas que agregás sin sentido enojan al productor: él sabe mejor que
> nadie sobre su campo, no necesita sermones."

El que usa esto lleva veinte o cuarenta años en el campo. Sabe qué le hace una
siniestro, sabe por qué importa la humedad y sabe cuánto cuesta un servicio de
cierre. Explicárselo desde una pantalla no es ayuda: es condescendencia, y se
siente.

**Qué SÍ va en un aviso:**
- El **hecho**: "Este pedido no tiene seguro vigente."
- La **acción**: "Cargá la póliza."
- Cuando aporta, **el dato que él no tiene a mano**: "Vence en 12 días",
  "el depósito descontó 0,4% de zarandeo y el estándar de tipo A es 0,25%".

**Qué NO va:**
- Explicar por qué su negocio funciona como funciona.
- Advertencias sobre consecuencias obvias del oficio.
- Adjetivos de urgencia ("¡crítico!", "¡atención!") cuando el número ya lo dice.

La excepción son los **cálculos y umbrales**: ahí sí hay que decir de dónde
sale un número (mandamiento 15), porque eso es información sobre EL SISTEMA, no
sobre el campo. "GDP 0,62 kg/día, por debajo de 0,8 la ración no se paga" es
útil; "recordá que engordar poco es malo" es un sermón.
