# ADR-0010: Workflow Doc Inserted as a Snippet into CLAUDE.md

**Date:** 2026-05-07
**Status:** Accepted
**Supersedes:** —

## Context

The skill needs to provide workflow rules (branch naming, card status transitions, PR conventions) to Claude Code in every session of the target project. Two delivery options were considered:

- A separate file (e.g. `docs/github-workflow.md`) that Claude reads on demand.
- A section injected into the project's `CLAUDE.md` between well-known markers.

Claude Code reads `CLAUDE.md` automatically at session start. A separate file would require Claude to know to fetch it — an extra step that can be missed.

## Decision

The workflow section is inserted into the project's `CLAUDE.md` between:

```
<!-- BEGIN github-project skill workflow -->
<!-- END github-project skill workflow -->
```

The canonical snippet lives in `templates/CLAUDE.md.snippet`. `setup-project.sh` inserts or replaces the block between the markers.

## Consequences

- Workflow rules are always in context at the start of every Claude session — no extra read step required.
- Mixing skill-managed content with user-written content in the same file requires marker-based replacement logic, which is fragile. Mitigated by: checking for marker presence before writing, and prompting the user before modifying.
- Updating the skill's workflow rules requires re-running `setup-project.sh` to push the new snippet into each project's `CLAUDE.md`.
