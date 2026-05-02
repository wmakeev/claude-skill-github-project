# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A Claude Code skill that sets up and maintains an opinionated GitHub Project (Kanban board) for issue-driven development. Installed as a skill at `~/.claude/skills/github-project/` — the `SKILL.md` at the repo root is the skill entrypoint.

## Architecture

Three operational layers, each with a corresponding script:

| Layer | Script | Scope |
|---|---|---|
| Bot config | `scripts/setup-bot.sh` | One-time per machine (`~/.config/claude-github-bot/`) |
| Project config | `scripts/setup-project.sh` | Per repo (`claude-project.json`) |
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
| Project pointer (owner + project number) | `claude-project.json` (repo root, committed) |
| Issue template | `.github/ISSUE_TEMPLATE/task.md` |
| Workflow doc snippet | `templates/CLAUDE.md.snippet` (inserted between markers in project CLAUDE.md) |

All GitHub-side IDs (project node ID, field IDs, option IDs) are resolved via `gh project` on every run — no client-side cache.

## Key design constraints

- **No auto-fix for option drift** — if `Impact`/`Effort`/`Status` options diverge from spec, scripts report it but do not modify. Auto-rewrite would corrupt values pinned to existing cards.
- **Confirmation before every write** — `confirm()` defaults to "no"; bypass with `NONINTERACTIVE=1` (for tests only).
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

## Distribution

Development machine: the repo is cloned somewhere and symlinked to `~/.claude/skills/github-project`. Edits are immediately visible; `git push` is the publish step. Consumer machines: direct `git clone` into `~/.claude/skills/github-project`, updated via `git pull`.
