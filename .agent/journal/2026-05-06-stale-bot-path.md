# 2026-05-06 — Stale bot-token path leaked into target repos via CLAUDE.md snippet

## Context

An agent in a third-party repo set up via this skill hit `No such file: ~/.claude/github-bot/get_token.py`. The CLAUDE.md snippet inserted by `setup-project.sh` referenced a path that has never existed on a standard install. Investigating exposed four related problems.

## Done

- **Problem 1 — wrong path in snippet:** updated `templates/CLAUDE.md.snippet` to reference the correct `~/.config/claude-github-bot/get_token.py`. Existing repos can re-run `setup-project.sh` — the drift check at Step 7 detects the stale path and offers replacement.
- **Problem 2 — silent fallback to personal auth:** added an explicit "Verifying the token belongs to the bot" subsection. Includes a working GraphQL `viewer { login }` query, a one-liner to read `bot_login` from config, and a warning that `gh api user` without `GH_TOKEN` falls through to personal auth silently.
- **Problem 3 — `gh api user` returns 403 for installation tokens:** snippet now documents the GraphQL viewer query as the canonical identity check and explains the 403 is by design (not a bug to investigate).
- **Problem 4 — `diagnose.sh` did not flag stale path:** added a check that warns if `CLAUDE.md` still references `~/.claude/github-bot/get_token.py`, with a `setup-project.sh` suggestion.

## Errors and How They Were Resolved

**Error 1:** `No such file: ~/.claude/github-bot/get_token.py` — path in snippet never matched reality.

**Error 2:** `gh api user` without `GH_TOKEN` returned user's personal login — masked wrong identity.

**Error 3:** `gh api user` with a valid bot `GH_TOKEN` returned 403 — `GET /user` does not accept installation tokens; agents spent time debugging a non-bug.

**Error 4:** `diagnose.sh` passed silently on repos with the stale path.

## Decisions

Used `gh api graphql -f query='{ viewer { login } }'` as the canonical identity check — it works with both installation tokens and PATs, unlike `GET /user`.

## Next Steps

_No open items._
