# 2026-05-07 — Card not moved to «In Review» after opening PR

## Context

After the agent opened a PR, the project card remained in «In Progress» instead of moving to «In Review». The workflow documentation implied that GitHub Projects v2 auto-moves cards when a PR is opened.

## Done

- Updated Step 5 of the per-issue lifecycle in `templates/CLAUDE.md.snippet` to include explicit `gh project item-edit` commands.
- Commands resolve the Status field ID, the «In Review» option ID, and the issue's item ID, then set the status via the bot token.

## Errors and How They Were Resolved

**Error:** Card stayed in «In Progress» after PR was opened.

**Root cause:** `Closes #<num>` in the PR body only auto-closes the issue on merge — it does not touch GitHub Projects v2 Status columns at all. The old wording "→ moves to In Review" falsely implied an automatic transition.

**Fix:** Step 5 now contains explicit shell commands the agent must run to move the card.

## Decisions

Kept the bot token for project mutations (not the user token) — consistent with the existing "Bot-attributed actions" table.

## Next Steps

_No open items._
