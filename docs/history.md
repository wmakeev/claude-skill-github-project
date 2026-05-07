# History — Problems Found and Fixed

A running log of issues discovered in production use, their root causes, and the changes made. Newest entries at the top.

---

## 2026-05-06 — CLAUDE.md snippet was copied inline; drifted on skill updates

**Problem:** `setup-project.sh` copied the full text of `templates/CLAUDE.md.snippet` into the project's `CLAUDE.md`. Every time the skill was updated, the per-project copy became stale and required manual re-run to sync.

**Root cause:** Originally written before Claude Code supported `@path` imports in CLAUDE.md.

**Fix:** Step 7 now writes a single `@~/.claude/skills/github-project/templates/CLAUDE.md.snippet` import line between the markers instead of the full text. Claude Code expands it at session start, so the instructions are always read from the installed skill version. Migration path: if the section contains old inline text, the script offers to replace it with the import line.

---

## 2026-05-06 — Agent used bot token to merge PR, got "Resource not accessible by integration"

**Discovered by:** an agent in a target repo that tried `GH_TOKEN=$(... get_token.py) gh pr merge`.

**Symptom:** `GraphQL: Resource not accessible by integration (mergePullRequest)`.

**Root cause:** The `Bot-attributed actions` section in `templates/CLAUDE.md.snippet` listed "PR reviews" among bot actions without any caveat. An agent interpreted that as "all PR-related actions should use the bot token", including merge.

GitHub App installation tokens are intentionally blocked from `mergePullRequest` regardless of the App's permission grants — this is a GitHub platform restriction, not a configuration issue.

**Fix:** Rewrote the section as "Bot-attributed actions vs. user actions" with an explicit table. Bot column: comments, labels, project mutations. User column (no GH_TOKEN): push, merge PR, releases. Included the exact error message so an agent that hits it recognises the cause immediately.

---

## 2026-05-06 — Stale bot-token path leaked into target repos via CLAUDE.md snippet

**Discovered by:** an agent in a third-party repo that was set up via this skill.
The agent followed the workflow snippet in the project's CLAUDE.md and hit
`No such file: ~/.claude/github-bot/get_token.py`.

### Problem 1 — wrong path in `templates/CLAUDE.md.snippet`

**Symptom:** the documented command in any project set up by setup-project.sh
pointed at `~/.claude/github-bot/get_token.py`, which has never existed on
the standard install. Real path is `~/.config/claude-github-bot/get_token.py`.

**Root cause:** snippet drifted from the rest of the skill (lib/common.sh,
get_token.py, SKILL.md, this repo's CLAUDE.md all referenced the correct path).

**Fix:** updated `templates/CLAUDE.md.snippet`. Re-running `setup-project.sh`
in already-configured repos detects the drift via the existing snippet diff
check (setup-project.sh step 7) and offers to replace.

### Problem 2 — silent fallback to personal `gh auth` masquerading as bot

**Symptom:** when the documented command failed, the agent tried `gh api user`
without `GH_TOKEN` to verify identity. `gh` silently used the user's personal
auth and returned the user's login — agent could have continued posting
comments under the wrong identity.

**Fix:** added an explicit "Verifying the token belongs to the bot" subsection
to the snippet with a working GraphQL command (`viewer { login }`), a one-liner
to read `bot_login` from config, and a warning that `gh api user` without
`GH_TOKEN` falls through to personal auth.

### Problem 3 — `gh api user` returns 403 for installation tokens (rediscovered)

**Symptom:** even with the right `GH_TOKEN`, `gh api user` returns 403 — agents
spend time investigating a non-bug. This is the same pitfall already fixed for
setup-bot.sh / diagnose.sh in 2026-05-02, but the snippet inserted into target
repos didn't carry that knowledge.

**Fix:** snippet now documents the GraphQL viewer query as the canonical
identity check and explains the 403 is by design.

### Problem 4 — diagnose.sh did not flag the stale path in already-configured repos

**Fix:** added a check in `diagnose.sh` that warns if `CLAUDE.md` still
references `~/.claude/github-bot/get_token.py`, with a `setup-project.sh`
suggestion.

---

## 2026-05-02 — Non-TTY compatibility + diagnose correctness

**Discovered by:** a Claude Code agent running in the `wmakeev/simplex` repo. The agent invoked the skill's setup scripts via the Bash tool, which runs without a controlling terminal.

### Problem 1 — `setup-bot.sh` and `setup-project.sh` crashed without a TTY

**Symptom:** Both scripts called `read -r -p "..." </dev/tty` directly. In a non-TTY environment (Claude Code, CI, `</dev/null` redirect) this produced a "no such device" error and exited immediately.

**Root cause:** No fallback path for headless invocation.

**Fix:** Added `is_tty()` helper to `lib/common.sh`. Both scripts now use an env → TTY → error fallback chain:
- `BOT_APP_ID` / `BOT_INSTALLATION_ID` / `BOT_KEY_PATH` for `setup-bot.sh`
- `GITHUB_PROJECT_NUMBER` / `GITHUB_OWNER` for `setup-project.sh`

If no TTY and the env var is absent, the script exits with a clear message naming the variable to set. `confirm()` received the same treatment — it refuses gracefully instead of hanging.

### Problem 2 — `setup-bot.sh` and `diagnose.sh` used `GET /user` to verify bot identity

**Symptom:** `login=$(GH_TOKEN="$token" gh api user --jq '.login')` returned a 403 error. `bot_login` in `config.json` was left empty; `diagnose.sh` showed a false pass or a confusing warn.

**Root cause:** `GET /user` is an OAuth endpoint — it works for personal access tokens but returns 403 for GitHub App installation tokens.

**Fix:**
- Added `--app-info` mode to `get_token.py`: calls `GET /app` with a JWT (not an installation token), which always returns the App's slug. Login is derived as `<slug>[bot]`.
- `setup-bot.sh` now calls `get_token.py --app-info` to populate `bot_login`, then separately requests an installation token to verify the installation is reachable.
- `diagnose.sh` uses `gh api graphql -f query='{ viewer { login } }'` for identity, which works correctly with installation tokens.

### Problem 3 — `diagnose.sh` could hang indefinitely on network issues

**Symptom:** If the GitHub API was unreachable, `python3 get_token.py` blocked forever. The diagnostic run never finished.

**Fix:** Wrapped the Python call in `timeout 15`. Exit code 124 (timeout) produces a `[SKIP]` entry in the output rather than a silent hang. The GraphQL identity check is wrapped in `timeout 10` as well.

### Problem 4 — `diagnose.sh` showed no summary; skipped checks looked like passes

**Symptom:** When the bot-token check was skipped or failed early, subsequent checks still printed `[PASS]` lines, giving the impression everything was fine. There was no way to see at a glance how many checks ran vs. were skipped.

**Fix:** Added a `skip()` function and per-category counters (`_CNT_PASS`, `_CNT_WARN`, `_CNT_FAIL`, `_CNT_SKIP`). Every run now ends with:
```
=== Summary ===
PASS: 17  WARN: 0  FAIL: 0  SKIPPED: 1
Skipped: bot-token
```
Exit code is 1 (warn) when any check is skipped.

### Collateral — `design-decisions.md` and `docs/roadmap.md` stale after v1 migration

The `447da90` commit (migrate from `gh api graphql` to `gh project`) had left two stale references:
- `design-decisions.md` contained a "GraphQL via direct string assembly" section describing `build_options_literal`, which no longer exists.
- `roadmap.md` still said "scripts use `gh api graphql` exclusively".

Both were corrected. Also updated the `NONINTERACTIVE=1` documentation: it was described as "for tests only" but is now the official mechanism for any non-interactive caller.
