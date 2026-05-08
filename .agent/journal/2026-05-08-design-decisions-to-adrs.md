# 2026-05-08 — Migrate design-decisions.md to Individual ADRs

## Context

`docs/design-decisions.md` held 10 structural decisions in a single flat file.
The ADR practice was introduced (ADR-0000) in a prior session but the old file
remained. Task: extract each decision into its own ADR, following CLAUDE.md rules.

## Done

- Created ADR-0001 through ADR-0010 in `docs/adr/`, one per decision:
  - 0001: Bot config outside repo
  - 0002: Per-project config in repo root
  - 0003: No schema version in config
  - 0004: Hard-coded project spec
  - 0005: Direction field options are UI-managed
  - 0006: No auto-fix for option drift (Status + custom fields — merged into one ADR)
  - 0007: Diagnose-first entry point
  - 0008: Explicit confirmation before writes
  - 0009: `gh project` subcommands, not raw GraphQL
  - 0010: Workflow doc as CLAUDE.md snippet
- Updated `docs/adr/README.md` index with all 10 new entries.
- Deleted `docs/design-decisions.md`.
- Fixed stale reference in `CLAUDE.md` ("Docs to update" table now points to `docs/adr/`).
- All changes committed in two commits on `main`.

## Errors and How They Were Resolved

None.

## Decisions

- ADR-0006 merges two subsections from the original file (Status options and custom field drift) — they share the same root reason ("auto-rewriting options destroys card values") and a single ADR is cleaner than two nearly identical ones.
- All new ADRs set to `Accepted` (not `Draft`) because these are decisions already in force, not proposals.

## Next Steps

_Nothing remaining._
