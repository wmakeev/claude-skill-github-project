# 2026-05-06 — CLAUDE.md snippet copied inline, drifted on skill updates

## Context

`setup-project.sh` copied the full text of `templates/CLAUDE.md.snippet` into each project's `CLAUDE.md`. When the skill was updated, per-project copies became stale and required a manual re-run to sync.

## Done

- Changed Step 7 in `setup-project.sh` to write a single `@~/.claude/skills/github-project/templates/CLAUDE.md.snippet` import line instead of the full snippet text.
- Added migration path: if the section already contains old inline text, the script offers to replace it with the import line.

## Errors and How They Were Resolved

**Error:** Per-project CLAUDE.md drifted from the skill's current instructions after skill updates.

**Root cause:** The script was written before Claude Code supported `@path` imports in CLAUDE.md.

**Fix:** Claude Code expands the `@` import at session start, so instructions are always read from the installed skill version without any re-run.

## Decisions

Used `@path` import (not a symlink, not a submodule) — the native Claude Code mechanism, zero extra tooling required.

## Next Steps

_No open items._
