# 2026-05-02 — Non-TTY compatibility + diagnose correctness

## Context

A Claude Code agent running in the `wmakeev/simplex` repo invoked setup scripts via the Bash tool (no controlling terminal). Scripts crashed immediately. Investigation uncovered four separate problems.

## Done

- **Problem 1 — TTY crash:** added `is_tty()` helper to `lib/common.sh`. Both `setup-bot.sh` and `setup-project.sh` now use an env → TTY → error fallback chain. Missing env var in non-TTY exits with a clear message naming the variable to set. `confirm()` refuses gracefully instead of hanging. `NONINTERACTIVE=1` is now the official mechanism for all non-interactive callers.
- **Problem 2 — `GET /user` returns 403 for installation tokens:** added `--app-info` mode to `get_token.py` (calls `GET /app` with a JWT, returns App slug; login derived as `<slug>[bot]`). `setup-bot.sh` now populates `bot_login` via `--app-info`, then requests an installation token separately to verify the installation is reachable. `diagnose.sh` switched to `gh api graphql -f query='{ viewer { login } }'` for identity.
- **Problem 3 — `get_token.py` could hang indefinitely:** wrapped the Python call in `timeout 15`; GraphQL identity check in `timeout 10`. Exit code 124 produces a `[SKIP]` rather than a silent hang.
- **Problem 4 — `diagnose.sh` had no summary; skipped checks looked like passes:** added `skip()` function and per-category counters (`_CNT_PASS`, `_CNT_WARN`, `_CNT_FAIL`, `_CNT_SKIP`). Every run ends with a summary block. Exit code is 1 when any check is skipped.
- **Collateral — stale docs:** corrected `design-decisions.md` (removed obsolete `build_options_literal` section) and `roadmap.md` (removed claim that scripts use `gh api graphql` exclusively).

## Errors and How They Were Resolved

**Error 1:** `read -r -p "..." </dev/tty` → "no such device" in non-TTY — no fallback path existed.

**Error 2:** `login=$(GH_TOKEN="$token" gh api user --jq '.login')` → 403 — `GET /user` is an OAuth endpoint, not usable with installation tokens.

**Error 3:** `python3 get_token.py` blocked forever when GitHub API was unreachable.

**Error 4:** Failed or skipped checks still showed subsequent `[PASS]` lines — no way to assess run completeness at a glance.

## Decisions

- `NONINTERACTIVE=1` promoted from "tests only" to the documented official flag — cleaner than adding more env-var fallbacks per prompt.
- `GET /app` with a JWT (not an installation token) chosen for bot identity — the only GitHub endpoint that works pre-installation and returns the App slug reliably.

## Next Steps

_No open items._
