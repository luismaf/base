<!--
  PROJECT README TEMPLATE.

  Fill every {{HOLE}}. Delete the sections that genuinely do not apply — but
  delete them, do not leave them empty: an empty section reads as "unfinished",
  a missing one reads as "not part of this product".

  The rule that keeps this file useful: IT DESCRIBES WHAT EXISTS, verified
  against package.json and Cargo.toml, never what was planned. If this file and
  the code disagree, the code wins and this file gets corrected.
-->

# {{PROJECT_NAME}}

{{ONE_LINE_WHAT_IT_IS}} — **Rust (Axum + async-graphql + Postgres)** on the
back end, **React 18 + TypeScript + Vite + Tailwind** on the front end.

> {{WHO_IT_IS_FOR_AND_WHAT_THEY_DO_WITH_IT}} — real data in a real database, no
> mockups.

**Status: {{STATUS}}** — {{WHAT_WORKS_TODAY_IN_ONE_PARAGRAPH}}.
See `docs/STATE.md` for the current state and `KNOWN_LIMITATIONS.md` for what
is deliberately not done yet.

---

## Where this project ends

{{SCOPE}}

**Not in scope:** {{OUT_OF_SCOPE}}

> Writing down what does *not* belong here is the single cheapest thing in this
> file. Everything that gets built by accident got built because nobody wrote
> this line.

---

## Quick start (dev)

Requirements: `rust {{RUST_VERSION}}`, `node >= 20`, `postgres` on the PATH.

```bash
./start.sh          # start · stop · status · --force
```

Step by step, equivalent:

```bash
# 1. Build the database from scratch (schema + sample data)
./scripts/db-reset.sh --seed

# 2. Backend — GraphQL at http://127.0.0.1:{{API_PORT}}/graphql
export DATABASE_URL=postgres://{{DB_USER}}:{{DB_PASS}}@localhost:5432/{{DB_NAME}}
cargo run -p {{API_CRATE}}

# 3. Frontend — dev server at http://localhost:{{WEB_PORT}}
cd frontend && npm install && npm run dev
```

Dev logins: {{DEV_CREDENTIALS}}

---

## Stack

| Layer | Technology |
|---|---|
| Backend | Rust, Axum 0.7, async-graphql 6, sqlx 0.8 (Postgres), JWT HS256 + Argon2id |
| Frontend | React 18, TypeScript (strict), Vite 5, Tailwind, shadcn/ui (Radix), Apollo Client, react-router 6, react-i18next, recharts |
| Data | PostgreSQL — additive, reproducible migrations in `migrations/` |
| AI | OpenAI-compatible LLM ({{LLM_PROVIDER}}), Web Speech (dictation {{LOCALE}} + TTS), {{EXTERNAL_APIS}} |
| CI/CD | GitHub Actions — `clippy -D warnings`, {{TEST_COUNT}} tests, typecheck + build |

`docs/STACK.md` explains **why** each piece, and lists what is deliberately
**not** installed — that section is what stops the next contributor importing a
library this project does not have.

---

## Layout

```
crates/
  domain/      # rules and calculations. No HTTP. Tested on its own.
  api/         # Axum + GraphQL + data access
  {{EXTRA_CRATES}}
frontend/      # React app
migrations/    # numbered, incremental, never edited once applied
docs/          # DESIGN.md is the contract, not a suggestion
.latigo/       # how the fleet works here: rules, lessons, board
```

---

## Before you touch a screen

Read `docs/DESIGN.md`. It is a contract, not a style guide: every rule in it is
there because someone broke it once and it cost a full round to fix.

The two rules that matter most:

- **Mobile first.** A pixel on a phone is a gram of gold. The layout is designed
  for the smallest screen and grows from there, never the other way round.
- **If something appears twice, it belongs to the system.** Start from the global
  skeleton — the screen decides only *what* it says, never how it looks. Fixing a
  screen instead of the shared piece leaves the product worse than before: where
  there was one mediocre way, now there are two different ones. That is how a
  Frankenstein is born, one screen at a time.

---

## How work happens here

The fleet runs on a board, not on someone remembering to hand things out.

```bash
latigo init                  # rules, lessons and the boss guide, once
latigo deploy -n {{WORKERS}} # workers into panes
latigo board add "..."       # the boss keeps this stocked; empty board = idle fleet
latigo sweep --loop 120      # hands out claimed work and verifies it landed
```

`.latigo/rules.md` travels attached to every request. Its short version:
**a build is not progress and a test run is not progress** — never use either to
look busy; verify the cheap way first; one build at a time per machine; English
everywhere; 99% code, 1% prose.

---

## Tests

{{WHAT_IS_TESTED}} — money, quantities that drive decisions, and the domain
rules. A failing test is a bug found, not an inconvenience.

```bash
{{TEST_COMMAND}}
```

---

## Documents that are worth reading

| File | Answers |
|---|---|
| `docs/DESIGN.md` | How anything on screen must look and behave |
| `docs/STACK.md` | What technology is here, and what is not |
| `docs/STATE.md` | What actually works today |
| `KNOWN_LIMITATIONS.md` | What is knowingly missing |
| `RUNBOOK.md` | How to operate it when it is running |
| `.latigo/LESSONS.md` | Mistakes already paid for once |
