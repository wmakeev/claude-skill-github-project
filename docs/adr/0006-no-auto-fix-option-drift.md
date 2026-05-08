# ADR-0006: Field Option Drift Is Reported, Never Auto-Fixed

**Date:** 2026-05-07
**Status:** Accepted
**Supersedes:** —

## Context

When `Impact`, `Effort`, or `Status` options diverge from the spec (wrong names, missing options, wrong order), scripts could either report the drift or attempt to fix it automatically.

Auto-fixing options means renaming or deleting option values. GitHub project items that currently have a renamed/deleted option would lose their value silently — the card would end up with no value for that field.

This applies to both:
- **Status** — the field GitHub creates from the Board template; items are pinned to columns by Status value.
- **Custom fields** (Impact, Effort) — single-select fields where items carry a stored option reference.

## Decision

Scripts report option drift via `[WARN]` or `[FAIL]` lines in diagnose output but never modify existing options. The user resolves drift manually in the GitHub UI (where the consequences are visible), then re-runs `diagnose.sh`.

**This is the single most important safety property of the skill.** Auto-rewriting options would silently corrupt values on existing cards.

## Consequences

- Existing card data is never destroyed by a script run.
- Fixing drift requires a manual UI step, which adds friction but makes the consequences visible.
- Scripts must distinguish "field/option missing" (safe to create) from "option name mismatch" (unsafe to rename automatically).
