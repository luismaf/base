---
name: base
description: Start a new project the way we start every project — the default stack (Rust/Axum/async-graphql/sqlx/Postgres + React 18/TS/Vite/Tailwind/shadcn/Apollo), the design contract (mobile first, global skeletons, no Frankenstein), the working method (board + whip + panes) and the README template with holes to fill. Use whenever a new repo, project or scaffold is being created, or when an existing project needs to be brought in line with how we work. Skip only when explicitly told to start blank or in another stack.
---

# Starting a project

Every new repo starts from the kit in `~/rust/base`, so it inherits what the
last project already paid for instead of rediscovering it.

**Skip this only when told explicitly** — "start it blank", or a different stack
named outright. Otherwise this is the default, including when the choice of
language is open: if nothing forces another stack, it is built with ours.

## The default stack

| Layer | Technology |
|---|---|
| Backend | Rust, Axum 0.7, async-graphql 6, sqlx 0.8 (Postgres), JWT HS256 + Argon2id |
| Frontend | React 18, TypeScript (strict), Vite 5, Tailwind, shadcn/ui (Radix), Apollo Client, react-router 6, react-i18next, recharts |
| Data | PostgreSQL only — additive, reproducible migrations in `migrations/`, never edit an applied one |
| AI | OpenAI-compatible LLM (local llama-server / OpenRouter BYOK), Web Speech (dictation + TTS), Open-Meteo |
| CI/CD | GitHub Actions — `clippy -D warnings`, tests, typecheck + build |

Crate separation is the part that pays off most: `domain/` holds the rules and
calculations with no HTTP dependency so it tests on its own, `api/` holds the
transport.

## What to do

```bash
bash ~/rust/base/scripts/instalar.sh <repo> <port>     # fleet machinery
cp ~/rust/base/plantillas/README.plantilla.md <repo>/README.md
cp ~/rust/base/{DESIGN.md,INTERFAZ.md,DESIGN_SYSTEM.md,STACK.md,METODOLOGIA.md} <repo>/docs/
cp ~/rust/base/MIGRACION_LEGACY.md <repo>/docs/   # only if replacing an existing system
latigo init --dir <repo>                                # rules, lessons, boss guide

cd <repo> && bash scripts/arrancar.sh                   # ← and it is working
```

**`arrancar.sh` is the point of all of it.** One command takes a repo with the
kit installed to a fleet that is actually working: it checks the harness answers
(a silent harness is not "zero free panes", it is nobody to talk to), opens as
many workers as the RAM genuinely allows, greets them before asking anything,
fills the board, and starts the three loops — dispatch with the valves at zero so
nobody sits idle, the boss clock that hands over the next action already decided,
and the focus guard that gives the screen back to the person.

`--estado` says what is running, `--parar` stops the loops. If something has to
be started separately afterwards, that is a bug in the script: whatever gets
forgotten at start-up is exactly what turns up dark three hours later.

**Sizing the fleet is not "look at free memory".** An agent starts around 230 MB
and reaches 1.6 GB with hours of work on it, so the budget goes by the **p90 of
PSS**, not the median. And the full cost is charged **the moment a worker is
created**, not after measuring it: the growth is deferred, so measuring after
each one reads green right up until the machine drowns.

Then fill every `{{HOLE}}` in the README. The most valuable line in it is the
one nobody writes: **where the project ends and what is out of scope.**
Everything that gets built by accident got built because that line was missing.

`INTERFAZ.md` is the exact shape — menu, forms with their own URL, at most two
buttons, filters, search, colours, and the table of shared pieces. It gets copied
as-is: it is a closed list, not a style guide, and it is what stops a
Frankenstein assembling itself one screen at a time.

## When the project replaces something that already works

If there is an old system — or another product we are taking inspiration from —
read `MIGRACION_LEGACY.md` before anything else. The short version:

**The old system is the specification, and it is the only one.** Nobody wrote
down what it does; it lives in its screens, its tables and its code. And its
twin: **it specifies *what*, never *how*.** We take the function and the
vocabulary. We do not take its wear.

Six stages: inventory with numbers, extract the code and the schemas but never
the data, decide what is live by the **call graph and not by file dates**,
evaluate honestly with evidence, design a checklist that maps every field, and
migrate without a bad month — reconnaissance first, parallel run, cutover, then
re-import as a standing capability.

The part that makes the second migration cheap: the importer is not written, it
is **declared**. Raw schema, mapping tables, target model. Porting a different
legacy is loading rows, not writing code.

## The design contract

`DESIGN.md` is a contract, not a style guide. Two rules outrank the rest:

- **Mobile first.** A pixel on a phone is a gram of gold. Design for the
  smallest screen and grow from there, never the reverse.
- **Global skeletons.** If something appears twice, it belongs to the system and
  is fixed in the shared piece — never in the screen. Start from the skeleton
  that exists; the screen decides only *what* it says, never how it looks.
  Fixing the screen instead leaves the product worse: where there was one
  mediocre way there are now two. That is how a Frankenstein assembles itself,
  one screen at a time, without anyone deciding it.

Make the canon executable where possible: a test that walks every page and fails
the build on a deviation beats any document. Documents get ignored; red builds
do not.

## How work happens

Work comes off a board, is claimed atomically, and is handed out by a whip that
verifies it landed. The boss's job is keeping the board stocked — an empty board
means an idle fleet, because the whip deliberately does not invent work. See the
`latigo` skill for the mechanics.

The house rules that travel attached to every request: a build is not progress
and a test run is not progress, never use either to look busy; verify the cheap
way first; one build at a time per machine; only work that moves the project
toward its objective counts; English everywhere — code, comments, identifiers,
commits, docs; 99% code, 1% prose; prolific and professional.

## Talk to an agent before asking it for anything

The first message to a fresh agent window is **"hola"**, never the request.

A cold window that receives a forty-line request as its first message responds
badly: it drifts, half-answers, or does not start. The same agent, greeted with
one word and given a few seconds, then takes the long request without trouble.
`scripts/saludar-agentes.sh` does it across the fleet.

The greeting costs a handful of tokens and avoids the expensive case: a long
request that has to be rewritten and resent because the window was cold.

**It is also how a stuck pane gets rescued.** When one stops answering, carries
an error that does not matter, or has already been nudged three times, a fourth
reminder is the most expensive way to achieve nothing. What works is a fresh
session and "hola" — `--nuevo`.

Skip it only when the conversation with that pane is already running.

## The focus belongs to the person, not to the system

Holds on screen and in the machinery around it, and we learned it by breaking it
in both.

**Nothing takes the user's attention without giving it back.** Not the cursor,
not the scroll, not the keyboard, not a box that opens over what they are
reading. The focus does not move on its own; after saving it returns to where the
work was, not to the top of the form. Nothing steals the keyboard while somebody
is typing. Nothing shifts the page under a thumb. And if something must take
control — a barcode reader that needs the field, a confirmation that cannot wait
— **it gives it back the moment it is done, exactly where it was.**

Outside the screen it is the same rule: a fleet mechanism that focuses panes to
send messages steals the screen from whoever is working. What makes the fix
precise is telling apart who moved the focus — if the system moved it, give it
back; if the person moved it, leave it alone. `scripts/foco.sh`.

**A system working can never cost the person using it their attention.**

## Company policy: the worker is cheap, the supervisor is not

This applies to every project, existing or new, and it outranks the rest of this
document.

**Workers are cheap agents; the supervisor is the expensive one.** When they also
run on an unlimited, free model, the arithmetic inverts completely: an idle pane
saves nothing, it only wastes.

1. **No worker idle, ever.** Not an aspiration — the policy. An idle worker is
   the one guaranteed way to lose money, and dark panes are the urgency that
   comes before anything else.
2. **If a worker can do it, a worker does it.** Compiling, running tests, writing
   code, searching the repo, fixing type errors. The supervisor enters only where
   there is no substitute: strategy, architecture, judging what came back, and
   keeping the machine running.
3. **The project in hand comes first, second and third.** Another repository is
   the very last resort, and only to keep a pane from going dark.
4. **Work must never depend on somebody writing prose.** Where the project has an
   inventory of what is missing, a script turns it into items on its own. An
   empty board for lack of prose is a design error, not bad luck.

The uncomfortable corollary: **a compile error does not need somebody expensive,
it needs somebody constant.** So a worker holds the compiler role permanently,
and the supervisor stays out of that loop.

## Nobody idle when the workers are free

When the fleet runs on an unlimited, free model, the arithmetic inverts: an idle
pane saves nothing, it only wastes. **An idle worker is the one guaranteed way to
lose.**

First, second and third comes the project in hand — interface, security,
performance, coverage, documentation, how it is sold. There is always something,
and while there is, nobody looks elsewhere. Another project is the very last
resort, as a hobby, rather than leaving a pane dark.

The asymmetry that follows: **the supervisor's tokens are expensive and the
workers' are not.** If a worker can do it, a worker does it. The supervisor is
interrupted only for what only it can do — compiling, deciding architecture,
judging what comes back.

And the mechanical floor: board refilling must never depend on somebody writing
prose. Where the project has a numbered inventory of functionality, a script
turns unclosed rows into items on its own, and the boss clock runs it before
asking the boss for anything. The boss still writes the items that need
judgement; the machine covers the rest.

## The boss has to be woken, or it stops

A boss agent does not stop for lack of will. It stops because its turn ends and
nothing wakes it. Persistence is not a property of the agent; it is a property
of the system that wakes it.

The whip wakes the workers and skips the boss, since the boss takes no items —
which leaves the one who restocks everybody else's work as the only one nothing
restarts. `scripts/jefe.sh --loop` closes that hole: it fires on an interval and
hands over the next action **already decided**, never a question. Below the
worker count, restock, and it names the source. At or above, climb one rung of
the improvement ladder — interface, security, performance, data quality,
coverage, documentation, selling it, the web — which rotates and never completes.

The exit condition is impossible on purpose: the loop ends when the board is
full *and* nothing on any rung can be improved.

The guard rail that keeps it honest: every rung points at **a document or a
measurement**, never at the boss's imagination. "This rung is clean" is a
correct answer; inventing an item is not, because an item that does not move the
project is worse than an empty board.

## Agent-tool agnostic

`scripts/harness.sh` isolates the three things the mechanism needs from whatever
runs the agents: `harness_list` (pane, state, directory, class), `harness_prompt`
(returns whether it *started*, not whether it was sent) and `harness_read`.
Backends ship for herdr and plain tmux, plus a `custom` one that is three
environment variables. Adapting to a different agent runner means editing that
file and nothing else.
