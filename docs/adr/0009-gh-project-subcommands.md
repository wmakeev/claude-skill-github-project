# ADR-0009: Use `gh project` Subcommands, Not Raw GraphQL

**Date:** 2026-05-07
**Status:** Accepted
**Supersedes:** —

## Context

GitHub Projects v2 operations can be performed via:

- `gh project` subcommands (`gh project view`, `gh project field-list`, `gh project field-create`) — high-level, readable.
- `gh api graphql` — low-level, requires manual query construction, was the previous approach (`gql()` helper).

The user has the latest `gh` installed. `gh project` subcommands cover all required operations.

## Decision

All project operations use `gh project` subcommands. The `gql()` helper and all raw `gh api graphql` calls have been removed. Minimum required version: `gh` ≥ 2.20.

`diagnose.sh` checks the installed `gh` version and fails fast if it is too old.

## Consequences

- Scripts are more readable and do not require understanding GraphQL node IDs inline.
- **Known limitation:** `gh project field-create --single-select-options` does not support per-option colors. `Impact` and `Effort` are created with correct option names but no colors. Colors must be assigned once in the GitHub UI after initial setup; subsequent idempotent runs do not touch them.
- Machines with `gh` < 2.20 cannot use the skill without upgrading.
