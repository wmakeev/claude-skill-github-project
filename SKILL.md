---
name: github-project
description: Set up, diagnose, and maintain a GitHub Project (board) for a repository, including a GitHub App bot for automated actions, custom fields (Impact, Effort, Direction), repository labels, an issue template, and a workflow section in CLAUDE.md. Use this skill whenever the user wants to "set up the project", "configure the kanban board", "set up issue tracking", "configure the bot", "diagnose project setup", or works on a repo that already has a `claude-project.json` and asks anything related to issues, the project board, custom fields, branch naming, or PR workflow. Also use it when the user mentions a stale or broken token, a clone on a new machine, or asks why a project mutation failed — the diagnose script is the entry point for all of that.
---

# github-project

Manages an opinionated GitHub Project (Board) setup for issue-driven development. Bundles a one-time bot setup, an idempotent project configurator, and a self-diagnostic.

## When to use

- The user says "set up the project / kanban / issue tracking" on a repo
- The user works on a repo that already has `claude-project.json` and asks about issues, the board, fields, or workflow
- A bot token, project mutation, or labelling action fails
- The user clones an existing repo on a new machine and bot/project actions fail
- The user wants to re-sync the project state with the spec after manual edits

## Prerequisites

- `gh` CLI installed and authenticated as the user (`gh auth status`)
- `python3`, `jq`, `git` available
- For the bot: `pip install --user PyJWT requests`

## Workflow — always start here

**Run `scripts/diagnose.sh` first.** It is non-destructive and produces a structured report of the state of every component. Use its output to decide what to do next:

- All `[PASS]` → nothing to do; report status to the user
- Any `[FAIL]` → blocking; the report includes a `[INFO] suggestion:` line per failure with the exact command to run
- Only `[WARN]` → setup works but has drift; ask the user whether to repair

```bash
bash scripts/diagnose.sh
# or with absolute path (when CWD is not the skill directory):
bash ~/.claude/skills/github-project/scripts/diagnose.sh
```

Exit codes: `0` = clean, `1` = warnings/skipped, `2` = failures.

## Running from Claude Code (non-interactive)

Claude Code's Bash tool runs without a controlling terminal, so any
`read </dev/tty` would fail. Set parameters via env vars instead:

```bash
# Bot setup (one-time per machine)
BOT_APP_ID=3172171 \
BOT_INSTALLATION_ID=118624077 \
BOT_KEY_PATH=~/key.pem \
NONINTERACTIVE=1 \
bash ~/.claude/skills/github-project/scripts/setup-bot.sh

# Project setup (per repo)
GITHUB_PROJECT_NUMBER=7 \
NONINTERACTIVE=1 \
bash ~/.claude/skills/github-project/scripts/setup-project.sh

# Diagnose (always safe, no env needed)
bash ~/.claude/skills/github-project/scripts/diagnose.sh
```

`NONINTERACTIVE=1` disables all confirmation prompts and is required for any
write operation. Without it, the script will refuse to proceed if no TTY is
available and will print a clear message naming the env var to set.

## Components

### 1. Bot setup (one-time per machine)

`scripts/setup-bot.sh` configures `~/.config/claude-github-bot/` with the App's private key, `config.json`, and the `get_token.py` helper. The bot is shared across all the user's projects, so this runs once per machine and again only when:

- the App's installation ID changes (e.g. installed on more repos)
- the private key is rotated
- the user clones the skill onto a new machine

The script is interactive and idempotent: existing values are pre-filled as defaults, and changes are confirmed.

After setup, programmatic actions are token-prefixed:

```bash
GH_TOKEN=$(python3 ~/.config/claude-github-bot/get_token.py) gh issue comment 42 --body "..."
```

### 2. Project setup (per repo)

`scripts/setup-project.sh` brings the GitHub Project for the current repo into alignment with the spec in `scripts/lib/project-spec.sh`. It:

1. Creates `claude-project.json` (owner + project number) on first run, asking interactively
2. Resolves the project's node ID and current fields via GraphQL
3. For each managed custom field (`Impact`, `Effort`, `Direction`), creates it if missing; if it exists but options drift, **reports the drift but does not auto-fix** (auto-fixing would risk losing values on existing items)
4. Verifies the `Status` field has the expected columns (`Backlog → Todo → In Progress → In Review → Done`)
5. Creates missing repo labels (`bug`, `feature`, `refactor`, `chore`, `docs`)
6. Installs `.github/ISSUE_TEMPLATE/task.md`
7. Inserts the workflow section into `CLAUDE.md` between markers, or updates it if drifted

Every modification is preceded by a confirmation prompt. Re-running on a clean setup is a no-op.

```bash
bash scripts/setup-project.sh
```

The Project itself (the empty board) must be created manually first via `https://github.com/users/<owner>/projects → New project → Board`. The script will tell the user this and ask for the project number on first run.

### 3. Spec — what counts as "configured"

`scripts/lib/project-spec.sh` is the single source of truth for the desired state. It hard-codes:

- `Impact`: Very High / High / Medium / Low (red → blue, traffic-light by importance)
- `Effort`: Trivial / Small / Medium / Large (green → red, traffic-light by cost)
- `Direction`: field exists, options managed manually in the UI (project-specific)
- `Status`: Backlog / Todo / In Progress / In Review / Done
- Labels: `bug`, `feature`, `refactor`, `chore`, `docs`

Edit this file when the convention itself changes; both `setup-project.sh` and `diagnose.sh` will pick it up automatically.

## Storage layout

| What | Where | In repo? |
|---|---|---|
| Private key | `~/.config/claude-github-bot/<name>.private-key.pem` | No |
| Bot config (App ID, installation ID, login) | `~/.config/claude-github-bot/config.json` | No |
| Token helper | `~/.config/claude-github-bot/get_token.py` | No |
| Project pointer (owner, project number) | `claude-project.json` (repo root) | Yes |
| Issue template | `.github/ISSUE_TEMPLATE/task.md` | Yes |
| Workflow doc | `CLAUDE.md` (between markers) | Yes |

All other GitHub-side IDs (project node ID, field IDs, option IDs) are resolved on every run via GraphQL — there is no client-side cache that can go stale.

## Common scenarios

**Fresh repo, never set up before**
```
1. bash scripts/diagnose.sh           # will show what's missing
2. bash scripts/setup-bot.sh          # only if bot isn't set up yet
3. (create the project in GitHub UI)
4. bash scripts/setup-project.sh
5. bash scripts/diagnose.sh           # confirm clean
```

**Cloned on a new machine**
```
1. bash scripts/diagnose.sh           # will likely flag missing bot
2. bash scripts/setup-bot.sh          # restore ~/.config/claude-github-bot/
3. (claude-project.json is already in the repo, nothing else needed)
```

**Spec changed (e.g. new label added to project-spec.sh)**
```
1. bash scripts/setup-project.sh      # applies only the missing pieces
```

**Token suddenly fails**
```
1. bash scripts/diagnose.sh           # surfaces the exact failure
2. follow the [INFO] suggestion lines
```

## Notes for future iterations

- This is the v1 of the skill; the workflow execution side (creating branches from issues, opening PRs, capturing decisions) is intentionally not covered yet — see the source guide's "Next Steps" section.
- The Direction field's options are managed manually in the UI rather than in the spec because they are codebase-specific. If multiple projects converge on the same set, lift them into the spec.
- The Status options drift check is read-only; GitHub's project UI is the right place to manage them, since auto-rewriting would corrupt the cards already pinned to specific columns.
