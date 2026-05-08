# 2026-05-06 — Bot token blocked on PR merge ("Resource not accessible by integration")

## Context

An agent in a target repo used `GH_TOKEN=$(python3 get_token.py) gh pr merge` and received a GraphQL error. The old snippet listed "PR reviews" under bot actions without restricting merge.

## Done

- Rewrote the "Bot-attributed actions" section of `templates/CLAUDE.md.snippet` as a two-column table: **Bot token** (comments, labels, project mutations) vs. **User token / no GH_TOKEN** (push, merge PR, releases).
- Added the exact error message to the snippet so an agent that hits it recognises the cause immediately.

## Errors and How They Were Resolved

**Error:** `GraphQL: Resource not accessible by integration (mergePullRequest)`.

**Root cause:** GitHub App installation tokens are intentionally blocked from `mergePullRequest` at the platform level — this is not a permission configuration issue. The snippet's vague "PR reviews" entry led the agent to use the bot token for merge.

**Fix:** Explicit table clearly separates bot and user actions. Merge is in the user column.

## Decisions

Kept the exact error string in the snippet — a future agent seeing that string will find the explanation without searching.

## Next Steps

_No open items._
