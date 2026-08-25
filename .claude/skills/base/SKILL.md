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
cp ~/rust/base/{DESIGN.md,DESIGN_SYSTEM.md,STACK.md,METODOLOGIA.md} <repo>/docs/
latigo init --dir <repo>                                # rules, lessons, boss guide
```

Then fill every `{{HOLE}}` in the README. The most valuable line in it is the
one nobody writes: **where the project ends and what is out of scope.**
Everything that gets built by accident got built because that line was missing.

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

## Agent-tool agnostic

`scripts/harness.sh` isolates the three things the mechanism needs from whatever
runs the agents: `harness_list` (pane, state, directory, class), `harness_prompt`
(returns whether it *started*, not whether it was sent) and `harness_read`.
Backends ship for herdr and plain tmux, plus a `custom` one that is three
environment variables. Adapting to a different agent runner means editing that
file and nothing else.
