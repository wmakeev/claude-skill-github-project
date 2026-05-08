# 2026-05-07 — Agent skipped issue comments, missed scope corrections

## Context

Agent implemented the original issue description while ignoring scope corrections posted as comments. `gh issue view <num>` displays `comments: N` but does not show comment text, so the agent saw the count and proceeded from the body alone.

## Done

- Added Step 2 to the per-issue lifecycle in `templates/CLAUDE.md.snippet`: `gh issue view <num> --comments` must be run before any planning or branching.

## Errors and How They Were Resolved

**Error:** Agent built wrong scope — ignored four correction comments.

**Root cause:** `gh issue view` without `--comments` outputs only the issue body. The agent saw `comments: 4`, did not fetch the content, and never read the corrections.

**Fix:** Lifecycle Step 2 now mandates `--comments` flag. Comments are documented as the primary channel for post-creation scope changes.

## Decisions

Made it a numbered lifecycle step (not a note) so the agent cannot treat it as optional.

## Next Steps

_No open items._
