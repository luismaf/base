# base — how every project of ours starts

This is the starting kit: the stack, the design canon, the working method and
the fleet machinery. A new repo begins by taking this, filling the holes, and
inheriting everything the last project already paid for.

**Nothing here depends on any particular domain.** Copy it to another repo and
it still holds.

## If you just restarted with no memory

Read [`DESPUES-DE-UN-REINICIO.md`](DESPUES-DE-UN-REINICIO.md) first. A session
dies — it restarts, runs out of quota, fills its context, gets killed. What it
knew goes with it. **The only memory that survives is the one in the repository**,
and that file is the entry point back into it.

## Start a project

```bash
bash scripts/instalar.sh /path/to/new-repo 8444   # machinery, services, queues
cp plantillas/README.plantilla.md /path/to/new-repo/README.md
cp DESIGN.md INTERFAZ.md DESIGN_SYSTEM.md STACK.md METODOLOGIA.md /path/to/new-repo/docs/
cp MIGRACION_LEGACY.md /path/to/new-repo/docs/   # only if replacing an existing system
latigo init --dir /path/to/new-repo               # rules, lessons, boss guide

cd /path/to/new-repo && bash scripts/arrancar.sh  # ← and it is working
```

`arrancar.sh` is the whole point: one command takes a repo with the kit
installed to a fleet that is working. It checks the harness answers, opens as
many workers as the RAM actually allows, greets them before asking for anything,
fills the board, and starts the three loops that keep it running — dispatch with
the valves at zero so nobody sits idle, the boss clock that hands over the next
action already decided, and the focus guard that gives the screen back to the
person. `arrancar.sh --estado` says what is running; `--parar` stops the loops.

If something has to be started separately afterwards, that is a bug in this
script: whatever gets forgotten at start-up is exactly what turns up dark three
hours later.

Then fill every `{{HOLE}}` in the README, and write the one line that matters
most: **where this project ends and what is not in scope.**

## What is in here

| File | What it answers |
|---|---|
| `plantillas/README.plantilla.md` | The project README, with holes to fill. Start here. |
| `STACK.md` | What technology, and why — including **what is deliberately not installed**, the section that stops someone importing a library this project does not have. |
| `DESIGN.md` | The design contract. Read before touching a screen. Mobile first; if something appears twice it belongs to the system. |
| `INTERFAZ.md` | The exact shape: menu, forms with their own URL, two buttons, filters, search, colours and the shared pieces. Copied as-is into a new project. |
| `MIGRACION_LEGACY.md` | Start here when the project replaces a system that already works. The six stages, how to decide what is live and what is rubble, and the bridge that makes the second migration cheap. |
| `DESIGN_SYSTEM.md` | The concrete tokens and components. Read after `DESIGN.md`, which wins. |
| `METODOLOGIA.md` | How work happens: where the project ends, how work is delegated, how nobody sits idle, what gets tested. |
| `JEFE-LEEME.md` | For whoever runs the fleet: you stopped handing out work, you now keep a board stocked. |
| `KIT.md` | The original portable kit notes: the harness contract, the board in three lines, the trap that bites on day one. |
| `scripts/` | The machinery that makes the method a process instead of an intention. |
| `plantillas/` | The files a team needs on day one. |
| `maquina/` | Host-level guards: RAM watch, pane protection. |

## The stack we default to

| Layer | Technology |
|---|---|
| Backend | Rust, Axum 0.7, async-graphql 6, sqlx 0.8 (Postgres), JWT HS256 + Argon2id |
| Frontend | React 18, TypeScript (strict), Vite 5, Tailwind, shadcn/ui (Radix), Apollo Client, react-router 6, react-i18next, recharts |
| Data | PostgreSQL, additive reproducible migrations in `migrations/` |
| AI | OpenAI-compatible LLM (local llama-server / OpenRouter BYOK), Web Speech (dictation + TTS), Open-Meteo |
| CI/CD | GitHub Actions — `clippy -D warnings`, tests, typecheck + build |

If a project is language-agnostic — nothing forces another stack — it is built
with this one. Deviating is a decision someone makes on purpose and writes down,
not a default that drifts in.

## The two design rules that outlive every project

- **Mobile first.** A pixel on a phone is a gram of gold. Design for the
  smallest screen and grow from there.
- **Global skeletons, always.** If something appears twice it belongs to the
  system, and it gets fixed in the shared piece, never in the screen. Start from
  the skeleton that already exists: the screen decides only *what* it says, never
  how it looks. Fixing the screen instead leaves the product worse than before —
  where there was one mediocre way, now there are two. That is a Frankenstein,
  and it assembles itself one screen at a time while nobody decides it.

Make the canon executable: a test that walks every page and fails the build when
one deviates is worth more than any document. A document gets ignored; a red
build does not.

## The fleet

Work is handed out from a board, by a whip that verifies delivery, to workers in
terminal panes. See [`latigo`](https://github.com/luismaf/latigo) for the tool
and `METODOLOGIA.md` for the method.

The machinery is agent-tool agnostic: `scripts/harness.sh` isolates the only
three things the mechanism needs from whatever runs the agents
(`harness_list`, `harness_prompt`, `harness_read`). Backends ship for herdr and
plain tmux, plus a `custom` one that is three environment variables. Changing
tools means editing that one file and nothing else.
