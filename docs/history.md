# History — Problems Found and Fixed

A running log of issues discovered in production use, their root causes, and the changes made. Newest entries at the top.

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
