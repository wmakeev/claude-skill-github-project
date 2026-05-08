# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A Claude Code skill that sets up and maintains an opinionated GitHub Project (Kanban board) for issue-driven development. Installed as a skill at `~/.claude/skills/github-project/` — the `SKILL.md` at the repo root is the skill entrypoint.

## Architecture

Three operational layers, each with a corresponding script:

| Layer | Script | Scope |
|---|---|---|
| Bot config | `scripts/setup-bot.sh` | One-time per machine (`~/.config/claude-github-bot/`) |
| Project config | `scripts/setup-project.sh` | Per repo (`github-project.json`) |
| Diagnostic | `scripts/diagnose.sh` | Read-only; always the first step |

**Always run `diagnose.sh` first.** It produces `[PASS]`/`[WARN]`/`[FAIL]` lines with `[INFO] suggestion:` hints. Exit code: 0 = clean, 1 = warnings, 2 = failures.

### Shared libraries

- `scripts/lib/common.sh` — paths, logging helpers, `confirm()`, `detect_repo()`, `bot_token()`
- `scripts/lib/project-spec.sh` — single source of truth for desired project state (field names, option colors, status columns, labels). Edit here when conventions change; both scripts pick it up automatically.

### Storage layout

| What | Where |
|---|---|
| Bot private key + config | `~/.config/claude-github-bot/` (never in repo) |
| Token helper | `~/.config/claude-github-bot/get_token.py` |
| Project pointer (owner + project number) | `github-project.json` (repo root, committed) |
| Issue template | `.github/ISSUE_TEMPLATE/task.md` |
| Workflow doc snippet | `templates/CLAUDE.md.snippet` (inserted between markers in project CLAUDE.md) |

All GitHub-side IDs (project node ID, field IDs, option IDs) are resolved via `gh project` on every run — no client-side cache.

## Key design constraints

- **No auto-fix for option drift** — if `Impact`/`Effort`/`Status` options diverge from spec, scripts report it but do not modify. Auto-rewrite would corrupt values pinned to existing cards.
- **Confirmation before every write** — `confirm()` defaults to "no"; bypass with `NONINTERACTIVE=1` for non-interactive environments (Claude Code, CI).
- **`gh` ≥ 2.20 required** — scripts use `gh project` subcommands; `diagnose.sh` checks the version.
- **One bot, all projects** — bot config is per-machine in `~/.config/claude-github-bot/`, not per-repo.

## Running the scripts

```bash
bash scripts/diagnose.sh          # check current state
bash scripts/setup-bot.sh         # one-time bot installation (interactive)
bash scripts/setup-project.sh     # configure project for current repo (interactive)
```

Get a bot token for programmatic `gh` calls:
```bash
GH_TOKEN=$(python3 ~/.config/claude-github-bot/get_token.py) gh issue comment 42 --body "..."
```

## No automated tests

There is no test suite (see `docs/roadmap.md#test-coverage`). Validation is done by running `diagnose.sh` against a real GitHub project.

## Docs to update after making changes

| File | When to update |
|---|---|
| `docs/adr/` | When a structural decision changes or a new tradeoff is made — write or update an ADR. |
| `docs/roadmap.md` | When a planned item is implemented or a new known gap is identified. |

## Agent Journal Protocol

Paths:
- Journal index: `.agent/INDEX.md`
- Journal entries: `.agent/journal/YYYY-MM-DD-<slug>.md`
- Entry template: `.agent/journal/_template.md`
- Current handoff: `.agent/HANDOFF.md`

Rules:
- At the start of every task: read `.agent/INDEX.md` and `.agent/HANDOFF.md`
- Open specific journal entries only when past context is needed
- At the end of every session: create or update a journal entry, update `INDEX.md`, update `HANDOFF.md`
- Entry filename slug: 2–4 words describing the task (e.g. `2026-05-07-pipeline-backpressure.md`)
- Use `.agent/journal/_template.md` as the template for new entries

## Architecture Decision Records

All significant architectural decisions are recorded in `docs/adr/`.
The index is at `docs/adr/README.md`.

**Before planning any non-trivial change:**
1. Read `docs/adr/README.md` to see what decisions exist.
2. Read ADRs relevant to the area you are about to modify.
3. Treat every `Accepted` ADR as a hard constraint unless the user explicitly
   asks to revisit it — and if so, suggest writing a new ADR first.

**When to create a new ADR:**
- The user is making a decision that will affect the project for months.
- A significant trade-off is being made (stack, module boundary, data model).
- The decision would surprise a future reader who only reads the code.

**Proactively suggest creating one when you notice any of the above** —
phrase it as a suggestion ("this looks ADR-worthy because X — want me to
draft one?"), then wait for confirmation. Do not draft unprompted.

**How to create an ADR:**
1. Copy `docs/adr/_template.md`.
2. Name it `NNNN-short-title.md` (next number in sequence).
3. Fill in Context, Decision, Consequences.
4. Set Status to `Draft` — the user confirms before changing to `Accepted`.
5. Add a row to `docs/adr/README.md`.

For minor follow-ups to an existing decision, use a dated
`## Update YYYY-MM-DD` section in the existing ADR — but **only for
non-reversals**. If the direction changes, create a new ADR with
`Supersedes: ADR-NNNN` and set the old one's status to `Superseded by ADR-NNNN`.

**Never:**
- Create an ADR without an explicit user request or confirmation — ADRs record human decisions, not agent guesses.
- Create an ADR post-hoc to justify an already-made change without flagging it.
- Modify the body of an `Accepted` ADR to reverse it silently.
- Create an ADR for library version bumps or obvious conventions.

## Distribution

Development machine: the repo is cloned somewhere and symlinked to `~/.claude/skills/github-project`. Edits are immediately visible; `git push` is the publish step. Consumer machines: direct `git clone` into `~/.claude/skills/github-project`, updated via `git pull`.
